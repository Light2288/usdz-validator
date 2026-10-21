import Darwin
import Foundation
import TestSupport
import USDZValidation
import XCTest

@testable import USDZValidatorCLI

final class ReportDestinationTests: XCTestCase {
  private func withFiles(_ body: (URL, URL, URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let input = try Fixtures.write(Fixtures.validUSDA(), basename: "input", in: directory)
    let output = try Fixtures.write(Data("previous report".utf8), basename: "report", in: directory)
    try body(directory, input, output)
  }

  private func writeThroughDriver(_ output: URL, input: URL) -> Int32 {
    CommandDriver.run(
      arguments: ["validate", input.path, "--format", "json", "--output", output.path],
      streams: CLIStreams(
        stdout: { _ in XCTFail("--output must leave stdout empty") }, stderr: { _ in }),
      validate: { url, configuration in
        try Validator().validate(fileAt: url, configuration: configuration)
      })
  }

  func testAliasesAndReplacement() throws {
    try withFiles { directory, input, output in
      let original = try Data(contentsOf: input)
      let hardLink = directory.appendingPathComponent("hardlink")
      XCTAssertEqual(link(input.path, hardLink.path), 0)
      let symlink = directory.appendingPathComponent("symlink")
      try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: output)
      let fifo = directory.appendingPathComponent("fifo")
      XCTAssertEqual(mkfifo(fifo.path, 0o600), 0)
      for destination in [
        input, directory.appendingPathComponent("./input"), hardLink, symlink, directory, fifo,
        directory.appendingPathComponent("missing/report"),
      ] {
        XCTAssertThrowsError(
          try ReportDestination.write(Data("complete report\n".utf8), to: destination, input: input)
        )
        XCTAssertEqual(
          writeThroughDriver(destination, input: input), 3, destination.lastPathComponent)
        XCTAssertEqual(try Data(contentsOf: input), original)
        XCTAssertEqual(try Data(contentsOf: output), Data("previous report".utf8))
      }
      XCTAssertEqual(writeThroughDriver(output, input: input), 0)
      let encoded = try Data(contentsOf: output)
      XCTAssertEqual(encoded.first, 123)
      if encoded.first == 123 {
        let report = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(report["exitCode"] as? Int, 0)
      }
      XCTAssertEqual(try Data(contentsOf: input), original)
      let oldReader = Darwin.open(output.path, O_RDONLY | O_CLOEXEC)
      XCTAssertGreaterThanOrEqual(oldReader, 0)
      defer { _ = Darwin.close(oldReader) }
      let complete = Data("complete replacement\n".utf8)
      try ReportDestination.write(complete, to: output, input: input)
      XCTAssertEqual(try Data(contentsOf: output), complete)
      var oldBytes = [UInt8](repeating: 0, count: encoded.count)
      XCTAssertEqual(Darwin.read(oldReader, &oldBytes, oldBytes.count), encoded.count)
      XCTAssertEqual(Data(oldBytes), encoded, "Existing readers retain the complete old inode")
      var permissions = stat()
      XCTAssertEqual(lstat(output.path, &permissions), 0)
      XCTAssertEqual(permissions.st_mode & 0o777, 0o600)
      let fresh = directory.appendingPathComponent("fresh")
      try ReportDestination.write(complete, to: fresh, input: input)
      XCTAssertEqual(try Data(contentsOf: fresh), complete)
      XCTAssertEqual(try Data(contentsOf: input), original)
    }
  }

  func testFailurePreservesDestination() throws {
    for stage in ["write", "zeroWrite", "close", "rename"] {
      try withFiles { directory, input, output in
        let previous = try Data(contentsOf: output)
        let original = try Data(contentsOf: input)
        var operations = ReportDestination.Operations()
        if stage == "write" {
          var writes = 0
          operations.write = { descriptor, bytes, _ in
            writes += 1
            if writes == 1 { return Darwin.write(descriptor, bytes, 1) }
            errno = EIO
            return -1
          }
        } else if stage == "zeroWrite" {
          operations.write = { _, _, _ in 0 }
        } else if stage == "close" {
          operations.close = { descriptor in
            XCTAssertEqual(Darwin.close(descriptor), 0)
            errno = EIO
            return -1
          }
        } else {
          operations.rename = { _, _, _, _ in
            errno = EIO
            return -1
          }
        }
        XCTAssertThrowsError(
          try ReportDestination.write(
            Data("complete replacement\n".utf8), to: output, input: input, operations: operations)
        ) { error in
          XCTAssertEqual(error as? USDZValidation.ValidationError, .operational(.outputWriteFailed))
        }
        XCTAssertEqual(try Data(contentsOf: output), previous, stage)
        XCTAssertEqual(try Data(contentsOf: input), original, stage)
        XCTAssertEqual(
          try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted(),
          ["input", "report"], stage)
        let fresh = directory.appendingPathComponent("fresh")
        XCTAssertThrowsError(
          try ReportDestination.write(
            Data("new report".utf8), to: fresh, input: input, operations: operations))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fresh.path))
        XCTAssertEqual(
          try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted(),
          ["input", "report"])
      }
    }
  }

  func testShortWritesAndInterruptsCompleteBeforeReplacement() throws {
    try withFiles { directory, input, output in
      var operations = ReportDestination.Operations()
      var interrupted = false
      operations.write = { descriptor, bytes, count in
        if !interrupted {
          interrupted = true
          errno = EINTR
          return -1
        }
        return Darwin.write(descriptor, bytes, min(count, 7))
      }
      let complete = Data(repeating: 65, count: 70_000)
      try ReportDestination.write(complete, to: output, input: input, operations: operations)
      XCTAssertEqual(try Data(contentsOf: output), complete)
      XCTAssertEqual(
        try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted(),
        ["input", "report"])
    }
  }

  func testDetectableMetadataRacesPreserveBytes() throws {
    for changed in ["input", "report", "temporary"] {
      try withFiles { directory, input, output in
        let previous = try Data(contentsOf: output)
        let original = try Data(contentsOf: input)
        var operations = ReportDestination.Operations()
        operations.close = { descriptor in
          if changed == "temporary" {
            XCTAssertEqual(fchmod(descriptor, 0o400), 0)
          } else {
            XCTAssertEqual(chmod((changed == "input" ? input : output).path, 0o400), 0)
          }
          return Darwin.close(descriptor)
        }
        XCTAssertThrowsError(
          try ReportDestination.write(
            Data("replacement\n".utf8), to: output, input: input, operations: operations)
        ) { error in
          XCTAssertEqual(error as? USDZValidation.ValidationError, .operational(.outputUnsafe))
        }
        XCTAssertEqual(try Data(contentsOf: output), previous)
        XCTAssertEqual(try Data(contentsOf: input), original)
        XCTAssertEqual(
          try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted(),
          ["input", "report"])
      }
    }
  }

  func testPathReplacementAndHardLinkRacesAreDetected() throws {
    for changed in ["input", "report", "missingReport"] {
      try withFiles { directory, input, output in
        let previous = try Data(contentsOf: output)
        let original = try Data(contentsOf: input)
        let saved = directory.appendingPathComponent("saved")
        let destination =
          changed == "missingReport" ? directory.appendingPathComponent("fresh") : output
        var operations = ReportDestination.Operations()
        operations.close = { descriptor in
          let result = Darwin.close(descriptor)
          let replaced = changed == "input" ? input : destination
          if changed != "missingReport" {
            XCTAssertEqual(Darwin.rename(replaced.path, saved.path), 0)
          }
          XCTAssertEqual(Darwin.link((changed == "input" ? output : input).path, replaced.path), 0)
          return result
        }
        XCTAssertThrowsError(
          try ReportDestination.write(
            Data("replacement\n".utf8), to: destination, input: input, operations: operations))
        if changed == "input" {
          XCTAssertEqual(try Data(contentsOf: saved), original)
          XCTAssertEqual(try Data(contentsOf: output), previous)
        } else {
          XCTAssertEqual(try Data(contentsOf: input), original)
          XCTAssertEqual(try Data(contentsOf: destination), original)
          if changed == "report" { XCTAssertEqual(try Data(contentsOf: saved), previous) }
        }
        XCTAssertFalse(
          try FileManager.default.contentsOfDirectory(atPath: directory.path).contains {
            $0.hasPrefix(".usdz-validator-report-")
          })
      }
    }
  }

  func testParentReplacementIsDetectedAndOwnedTemporaryIsRemoved() throws {
    try withFiles { directory, input, _ in
      let parent = directory.appendingPathComponent("reports")
      let moved = directory.appendingPathComponent("moved")
      try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
      let output = try Fixtures.write(Data("previous report".utf8), basename: "report", in: parent)
      var operations = ReportDestination.Operations()
      operations.close = { descriptor in
        let result = Darwin.close(descriptor)
        XCTAssertEqual(Darwin.rename(parent.path, moved.path), 0)
        XCTAssertEqual(mkdir(parent.path, 0o700), 0)
        return result
      }
      XCTAssertThrowsError(
        try ReportDestination.write(
          Data("replacement\n".utf8), to: output, input: input, operations: operations))
      XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: moved.path), ["report"])
      XCTAssertEqual(
        try Data(contentsOf: moved.appendingPathComponent("report")), Data("previous report".utf8))
      XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: parent.path).isEmpty)
    }
  }

  func testSubstitutedTemporaryIsRejectedWithoutRemovingForeignFile() throws {
    try withFiles { directory, input, output in
      let previous = try Data(contentsOf: output)
      var substituted: URL?
      var operations = ReportDestination.Operations()
      operations.close = { descriptor in
        do {
          let name = try XCTUnwrap(
            FileManager.default.contentsOfDirectory(atPath: directory.path).first {
              $0.hasPrefix(".usdz-validator-report-")
            })
          let temporary = directory.appendingPathComponent(name)
          XCTAssertEqual(unlink(temporary.path), 0)
          try Data("foreign bytes".utf8).write(to: temporary)
          substituted = temporary
        } catch { XCTFail("Cannot arrange temporary substitution: \(error)") }
        return Darwin.close(descriptor)
      }
      XCTAssertThrowsError(
        try ReportDestination.write(
          Data("replacement\n".utf8), to: output, input: input, operations: operations))
      XCTAssertEqual(try Data(contentsOf: output), previous)
      XCTAssertEqual(try Data(contentsOf: XCTUnwrap(substituted)), Data("foreign bytes".utf8))
    }
  }

  func testMissingInputStillAllowsOperationalReport() throws {
    try withFiles { directory, _, output in
      let complete = Data("complete operational report\n".utf8)
      try ReportDestination.write(
        complete, to: output, input: directory.appendingPathComponent("missing"))
      XCTAssertEqual(try Data(contentsOf: output), complete)
      let parentLink = directory.appendingPathComponent("parentLink")
      try FileManager.default.createSymbolicLink(at: parentLink, withDestinationURL: directory)
      XCTAssertThrowsError(
        try ReportDestination.write(
          complete, to: parentLink.appendingPathComponent("report"),
          input: directory.appendingPathComponent("missing")))
      XCTAssertEqual(try Data(contentsOf: output), complete)
    }
  }

  func testDestinationFailurePreservesHigherPriorityCodes() throws {
    struct FailedDiagnostic: Error {}
    try withFiles { directory, input, _ in
      for (failure, expected): (USDZValidation.ValidationError, Int32) in [
        (.configuration(.invalidValue), 64), (.internalFailure(.invariantViolation), 70),
        (.operational(.inputReadFailed), 3),
      ] {
        for failsDiagnostic in [false, true] {
          let code = CommandDriver.run(
            arguments: ["validate", input.path, "--output", directory.path],
            streams: CLIStreams(
              stdout: { _ in XCTFail("--output stdout is empty") },
              stderr: { _ in if failsDiagnostic { throw FailedDiagnostic() } }),
            validate: { _, _ in throw failure })
          XCTAssertEqual(code, expected)
        }
      }
    }
  }
}

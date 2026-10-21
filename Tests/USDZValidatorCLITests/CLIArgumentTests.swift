import ArgumentParser
import Darwin
import Foundation
import TestSupport
import USDZValidation
import XCTest

@testable import USDZValidatorCLI

final class CLIArgumentTests: XCTestCase {
  func testParserOptionsAndTermination() throws {
    let command = try XCTUnwrap(
      USDZValidatorCommand.parseAsRoot([
        "validate", "--profile", "apple-portable-v1", "--format", "sarif", "--fail-on", "warning",
        "--allow-incomplete", "--usdchecker", "--include-sensitive-details", "--", "-asset",
      ]) as? ValidateCommand)
    XCTAssertEqual(command.input, "-asset")
    XCTAssertEqual(command.profile, "apple-portable-v1")
    XCTAssertTrue(command.usdchecker)
    XCTAssertThrowsError(try USDZValidatorCommand.parseAsRoot(["validate"]))
  }
  func testCatalogueProfilesNeverOpenConfigurationOrValidate() throws {
    for profile in ["general-v1", "apple-portable-v1"] {
      var output = Data()
      let code = CommandDriver.run(
        arguments: ["rules", "--format", "json", "--profile", profile],
        streams: CLIStreams(
          stdout: { output.append($0) }, stderr: { _ in XCTFail("No diagnostic") }),
        loadConfiguration: { _ in
          XCTFail("No config lookup")
          return Data()
        },
        validate: { _, _ in
          XCTFail("No asset or tool")
          throw USDZValidation.ValidationError.internalFailure(.unexpectedFailure)
        })
      XCTAssertEqual(code, 0)
      let document = try XCTUnwrap(JSONSerialization.jsonObject(with: output) as? [String: Any])
      XCTAssertEqual(document["schemaVersion"] as? Int, 1)
      XCTAssertEqual(document["profile"] as? String, profile)
      let rules = try XCTUnwrap(document["rules"] as? [[String: Any]])
      let ids = rules.compactMap { $0["ruleID"] as? String }
      XCTAssertEqual(ids, ids.sorted())
      XCTAssertTrue(ids.contains("UVK-RES-001"))
      let advice = rules.filter { ($0["ruleID"] as? String)?.hasPrefix("UVK-APL-") == true }
      XCTAssertEqual(advice.count, profile == "apple-portable-v1" ? 2 : 0)
      XCTAssertTrue(advice.allSatisfy { $0["defaultSeverity"] as? String == "warning" })
    }
  }
  func testUnexpectedFailureIsContextualizedWithoutRawErrorText() throws {
    struct Unexpected: Error, CustomStringConvertible {
      let description = "/private/raw-sensitive-diagnostic"
    }
    var output = Data()
    var diagnostic = Data()
    let code = CommandDriver.run(
      arguments: ["validate", "/missing/input", "--format", "json"],
      streams: CLIStreams(stdout: { output.append($0) }, stderr: { diagnostic.append($0) }),
      validate: { _, _ in throw Unexpected() })
    XCTAssertEqual(code, 70)
    XCTAssertTrue(String(decoding: diagnostic, as: UTF8.self).contains("unexpectedFailure"))
    XCTAssertFalse(String(decoding: output + diagnostic, as: UTF8.self).contains("raw-sensitive"))
  }
  func testInvalidConfigurationNeverValidatesAndUsesExplicitOpener() throws {
    var opens = [URL]()
    var validates = 0
    var stdout = Data()
    var stderr = Data()
    let streams = CLIStreams(stdout: { stdout.append($0) }, stderr: { stderr.append($0) })
    let code = CommandDriver.run(
      arguments: ["validate", "/missing/asset", "--config", "/explicit/config", "--usdchecker"],
      streams: streams,
      loadConfiguration: { url in
        opens.append(url)
        return Data("{}".utf8)
      },
      validate: { _, _ in
        validates += 1
        throw USDZValidation.ValidationError.internalFailure(.unexpectedFailure)
      })
    XCTAssertEqual(code, 64)
    XCTAssertEqual(opens.map(\.path), ["/explicit/config"])
    XCTAssertEqual(validates, 0)
    XCTAssertTrue(stdout.isEmpty)
    XCTAssertFalse(stderr.isEmpty)
  }
  func testDefaultConfigurationDoesNotOpenConfiguration() throws {
    var opened = false
    var validates = 0
    let code = CommandDriver.run(
      arguments: ["validate", "/missing/asset"],
      streams: CLIStreams(stdout: { _ in }, stderr: { _ in }),
      loadConfiguration: { _ in
        opened = true
        return Data()
      },
      validate: { _, configuration in
        validates += 1
        XCTAssertEqual(configuration, try ValidationConfiguration())
        throw USDZValidation.ValidationError.operational(.inputUnavailable)
      })
    XCTAssertEqual(code, 3)
    XCTAssertFalse(opened)
    XCTAssertEqual(validates, 1)
  }
  func testTypedFailureMappingAndWriteErrors() throws {
    for (error, expected): (USDZValidation.ValidationError, Int32) in [
      (.configuration(.invalidBudget), 64), (.operational(.inputReadFailed), 3),
      (.internalFailure(.invariantViolation), 70),
    ] {
      var out = Data()
      var err = Data()
      let code = CommandDriver.run(
        arguments: ["validate", "/missing/input", "--format", "json"],
        streams: CLIStreams(stdout: { out.append($0) }, stderr: { err.append($0) }),
        validate: { _, _ in throw error })
      XCTAssertEqual(code, expected)
      XCTAssertFalse(err.isEmpty)
      if expected == 64 {
        XCTAssertTrue(out.isEmpty)
      } else {
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: out) as? [String: Any])
        XCTAssertEqual(document["exitCode"] as? Int, Int(expected))
      }
    }
    struct WriteFailure: Error {}
    var diagnostic = Data()
    XCTAssertEqual(
      CommandDriver.run(
        arguments: ["rules"],
        streams: CLIStreams(
          stdout: { _ in throw WriteFailure() }, stderr: { diagnostic.append($0) }),
        validate: { _, _ in throw WriteFailure() }), 3)
    XCTAssertFalse(diagnostic.isEmpty)
    XCTAssertEqual(
      CommandDriver.run(
        arguments: ["rules"],
        streams: CLIStreams(
          stdout: { _ in throw WriteFailure() }, stderr: { _ in throw WriteFailure() }),
        validate: { _, _ in throw WriteFailure() }), 3)
  }
  func testBoundedConfigurationRejectsSpecialFilesWithoutBlocking() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let fifo = directory.appendingPathComponent("fifo")
    XCTAssertEqual(mkfifo(fifo.path, 0o600), 0)
    let oversized = try Fixtures.write(
      Data(repeating: 32, count: 65_537), basename: "large", in: directory)
    let valid = try Fixtures.write(
      Data(#"{"schemaVersion":1,"budgets":{}}"#.utf8), basename: "valid", in: directory)
    let link = directory.appendingPathComponent("link")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: valid)
    for url in [fifo, oversized, directory, link] {
      var validates = 0
      let started = Date()
      let code = CommandDriver.run(
        arguments: ["validate", "/missing/input", "--config", url.path],
        streams: CLIStreams(stdout: { _ in XCTFail("No report") }, stderr: { _ in }),
        validate: { _, _ in
          validates += 1
          throw USDZValidation.ValidationError.internalFailure(.unexpectedFailure)
        })
      XCTAssertEqual(code, 64)
      XCTAssertEqual(validates, 0)
      XCTAssertLessThan(Date().timeIntervalSince(started), 2)
    }
  }
}

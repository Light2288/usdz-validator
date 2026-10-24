import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

final class ValidatorTests: XCTestCase {
  func testRawBasenameIsEscapedOnceAndURIKeepsActualFilename() throws {
    try withInput(Fixtures.validUSDA()) { original in
      let name = "input\\segment\u{001B}\n.usdz"
      let renamed = original.deletingLastPathComponent().appendingPathComponent(name)
      try FileManager.default.moveItem(at: original, to: renamed)
      let report = try Validator().validate(
        fileAt: renamed, configuration: ValidationConfiguration())
      XCTAssertEqual(report.input.displayName, name)
      XCTAssertFalse(report.input.displayName.contains(original.deletingLastPathComponent().path))
      let json = try XCTUnwrap(
        JSONSerialization.jsonObject(with: ReportEncoder.encode(report, format: .json))
          as? [String: Any])
      XCTAssertEqual(
        (json["input"] as? [String: Any])?["displayName"] as? String,
        "input\\\\segment\\u{001B}\\n.usdz")
      let text = String(decoding: try ReportEncoder.encode(report, format: .text), as: UTF8.self)
      XCTAssertTrue(text.contains("input: input\\\\segment\\u{001B}\\n.usdz\n"))
      let sarif = try XCTUnwrap(
        JSONSerialization.jsonObject(with: ReportEncoder.encode(report, format: .sarif))
          as? [String: Any])
      let run = try XCTUnwrap((sarif["runs"] as? [[String: Any]])?.first)
      let artifact = try XCTUnwrap((run["artifacts"] as? [[String: Any]])?.first)
      XCTAssertEqual(
        (artifact["location"] as? [String: Any])?["uri"] as? String, "input%5Csegment%1B%0A.usdz")
    }
  }

  func testCompletePublicValidationAndSafeIdentity() throws {
    let url = Fixtures.root.appendingPathComponent("valid-usda.usdz")
    let report = try Validator().validate(fileAt: url, configuration: ValidationConfiguration())
    XCTAssertEqual(report.exitCode, 0)
    XCTAssertTrue(report.coverage.isComplete)
    XCTAssertTrue(report.nativeFindings.isEmpty)
    XCTAssertEqual(report.input.displayName, "valid-usda.usdz")
    XCTAssertEqual(report.input.byteSize, Int64(try Data(contentsOf: url).count))
    XCTAssertNil(report.input.sensitiveDetails)
    XCTAssertEqual(report.externalCheck, .notRequested)
    let disclosed = try Validator().validate(
      fileAt: url, configuration: ValidationConfiguration(includeSensitiveDetails: true))
    XCTAssertEqual(disclosed.input.sensitiveDetails?.absolutePath, url.path)
  }

  // Unsupported versions remain gateable limitations; truncated supported bootstrap is an error.
  func testTruncatedBinaryIsConclusiveCorruptionEvenWhenIncompleteAllowed() throws {
    try withInput(
      ArchiveRecipe(entries: [
        .init(nameBytes: Data("root.usdc".utf8), payload: Data("PXR-USDC".utf8))
      ]).encode()
    ) { url in
      let report = try Validator().validate(
        fileAt: url,
        configuration: ValidationConfiguration(
          gatePolicy: GatePolicy(allowIncomplete: true)))
      XCTAssertEqual(report.exitCode, 1)
      XCTAssertTrue(report.nativeFindings.contains { $0.ruleID == "UVK-USD-001" })
      XCTAssertTrue(report.nativeFindings.contains { $0.ruleID == "UVK-LIM-002" })
    }
  }

  func testNativeSubtreesUnchanged() throws {
    let binary = try ArchiveRecipe(entries: [
      .init(nameBytes: Data("root.usdc".utf8), payload: USDCFixtures.unsupportedVersion())
    ]).encode()
    for bytes in [try Fixtures.validUSDA(), binary] {
      try withInput(bytes) { url in
        let validator = Validator(adapter: successfulAdapter())
        let disabled = try validator.validate(fileAt: url, configuration: ValidationConfiguration())
        let enabled = try validator.validate(
          fileAt: url, configuration: ValidationConfiguration(externalCheck: .usdchecker))
        XCTAssertEqual(enabled.nativeFindings, disabled.nativeFindings)
        XCTAssertEqual(enabled.coverage, disabled.coverage)
        XCTAssertEqual(enabled.externalCheck.status, .completed)
        if bytes == binary {
          XCTAssertEqual(enabled.coverage.areas[.references]?.state, .partial)
          XCTAssertEqual(enabled.exitCode, 2)
          let accepted = try validator.validate(
            fileAt: url,
            configuration: ValidationConfiguration(
              gatePolicy: GatePolicy(allowIncomplete: true), externalCheck: .usdchecker))
          XCTAssertEqual(accepted.exitCode, 0)
          XCTAssertTrue(accepted.acceptedIncomplete)
          XCTAssertEqual(accepted.coverage, disabled.coverage)
          XCTAssertEqual(accepted.nativeFindings, disabled.nativeFindings)
        } else {
          XCTAssertEqual(enabled.exitCode, 0)
        }
      }
    }
  }

  func testUnsafeInputNeverProbesAndRequestedFailuresRemainBlocking() throws {
    var probes = 0
    let missing = USDCheckerAdapter(
      execute: { _ in
        XCTFail("No executable exists")
        return self.process()
      },
      isExecutable: { _ in
        probes += 1
        return false
      })
    let configuration = try ValidationConfiguration(
      gatePolicy: GatePolicy(allowIncomplete: true), externalCheck: .usdchecker)
    try withInput(Data("not a ZIP".utf8)) { url in
      let report = try Validator(adapter: missing).validate(
        fileAt: url, configuration: configuration)
      XCTAssertEqual(report.externalCheck.status, .skippedUnsafeInput)
      XCTAssertEqual(report.exitCode, 1)
      XCTAssertEqual(probes, 0)
    }
    let valid = Fixtures.root.appendingPathComponent("valid-usda.usdz")
    let unavailable = try Validator(adapter: missing).validate(
      fileAt: valid, configuration: configuration)
    XCTAssertEqual(unavailable.exitCode, 2)
    XCTAssertEqual(unavailable.externalCheck.status, .unavailable)
    XCTAssertEqual(probes, 1)
    let failure = try Validator(adapter: successfulAdapter(exit: 17)).validate(
      fileAt: valid, configuration: configuration)
    XCTAssertEqual(failure.exitCode, 1)
    XCTAssertEqual(failure.nativeFindings, [])
    XCTAssertEqual(failure.summary.native.bySeverity[.error], 0)
    XCTAssertEqual(failure.summary.external.bySeverity[.error], 1)
  }

  func testTypedFailuresPrecedeToolAndUnexpectedFailuresAreContextualized() throws {
    var probes = 0
    let adapter = USDCheckerAdapter(
      execute: { _ in
        XCTFail("No tool after input error")
        return self.process()
      },
      isExecutable: { _ in
        probes += 1
        return true
      })
    let configuration = try ValidationConfiguration(externalCheck: .usdchecker)
    XCTAssertThrowsError(
      try Validator(adapter: adapter).validate(
        fileAt: URL(string: "https://example.invalid/input")!, configuration: configuration)
    ) { XCTAssertEqual($0 as? ValidationError, .operational(.inputUnavailable)) }
    let valid = Fixtures.root.appendingPathComponent("valid-usda.usdz")
    for failure: ValidationError in [
      .operational(.inputReadFailed), .internalFailure(.invariantViolation),
    ] {
      let validator = Validator(adapter: adapter, inspect: { _, _ in throw failure })
      XCTAssertThrowsError(try validator.validate(fileAt: valid, configuration: configuration)) {
        XCTAssertEqual($0 as? ValidationError, failure)
      }
    }
    struct Unexpected: Error {}
    let unexpected = Validator(adapter: adapter, inspect: { _, _ in throw Unexpected() })
    XCTAssertThrowsError(try unexpected.validate(fileAt: valid, configuration: configuration)) {
      XCTAssertEqual($0 as? ValidationError, .internalFailure(.unexpectedFailure))
    }
    XCTAssertEqual(probes, 0)
  }

  func testChangesBeforeAndAfterExternalExecutionAreRejected() throws {
    let bytes = try Fixtures.validUSDA()
    for changeDuringNative in [true, false] {
      try withInput(bytes) { url in
        var calls = 0
        let adapter = USDCheckerAdapter(
          execute: { _ in
            calls += 1
            if calls == 2 {
              do {
                try Data("replacement".utf8).write(to: url, options: .atomic)
              } catch {
                XCTFail("Failed to replace the controlled fixture: \(error)")
              }
            }
            return self.process(stdout: calls == 1 ? "Apple USD Tools (0.25.11)\n" : "")
          }, isExecutable: { _ in true })
        let validator = Validator(
          adapter: adapter,
          inspect: { snapshot, configuration in
            let native = try NativeEngine.inspect(snapshot: snapshot, configuration: configuration)
            if changeDuringNative { try Data("replacement".utf8).write(to: url, options: .atomic) }
            return native
          })
        XCTAssertThrowsError(
          try validator.validate(
            fileAt: url, configuration: ValidationConfiguration(externalCheck: .usdchecker))
        ) { XCTAssertEqual($0 as? ValidationError, .operational(.inputChanged)) }
        XCTAssertEqual(calls, changeDuringNative ? 0 : 2)
      }
    }
  }

  func testFailureReportUsesGatePolicyAndNotRunCoverage() throws {
    for (failure, expected): (ValidationError, Int32) in [
      (.operational(.inputUnavailable), 3), (.internalFailure(.unexpectedFailure), 70),
    ] {
      for profile: Profile in [.generalV1, .applePortableV1] {
        let report = ValidationReport(
          failure: failure, fileAt: URL(fileURLWithPath: "/private/user/input.usdz"),
          configuration: try ValidationConfiguration(profile: profile, externalCheck: .usdchecker))
        XCTAssertEqual(report.exitCode, expected)
        XCTAssertEqual(report.validationStatus, .error)
        XCTAssertEqual(report.operationalErrors, [failure])
        XCTAssertEqual(report.input.displayName, "input.usdz")
        XCTAssertNil(report.input.byteSize)
        XCTAssertNil(report.input.sensitiveDetails)
        XCTAssertTrue(report.nativeFindings.isEmpty)
        XCTAssertEqual(report.coverage.areas.count, 6)
        XCTAssertTrue(report.coverage.areas.values.allSatisfy { $0.state == .notRun })
        XCTAssertEqual(report.coverage.areas[.appleAdvice]?.requested, profile == .applePortableV1)
        XCTAssertEqual(report.externalCheck.status, .skippedUnsafeInput)
      }
    }
  }

  func testNativeSizeConversionIsChecked() throws {
    let adapter = successfulAdapter()
    let validator = Validator(
      adapter: adapter,
      inspect: { _, _ in
        NativeResult(
          inputByteSize: UInt64.max, findings: [], coverage: Coverage(areas: [:]),
          containerSafeForExternal: false)
      })
    XCTAssertThrowsError(
      try validator.validate(
        fileAt: Fixtures.root.appendingPathComponent("valid-usda.usdz"),
        configuration: ValidationConfiguration())
    ) { XCTAssertEqual($0 as? ValidationError, .internalFailure(.invariantViolation)) }
  }

  private func successfulAdapter(exit: Int32 = 0) -> USDCheckerAdapter {
    USDCheckerAdapter(
      execute: { request in
        self.process(
          exit: request.arguments == ["--version"] ? 0 : exit,
          stdout: request.arguments == ["--version"] ? "Apple USD Tools (0.25.11)\n" : "")
      }, isExecutable: { _ in true })
  }

  private func process(exit: Int32 = 0, stdout: String = "") -> ProcessResult {
    ProcessResult(
      outcome: .completed, exitCode: exit, signal: nil, stdout: Data(stdout.utf8), stderr: Data(),
      stdoutByteCount: UInt64(stdout.utf8.count), stderrByteCount: 0, truncated: false,
      terminationReason: .exited, processIdentifier: 42, childReaped: true)
  }

  private func withInput(_ bytes: Data, body: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    try body(Fixtures.write(bytes, basename: "input.usdz", in: directory))
  }
}

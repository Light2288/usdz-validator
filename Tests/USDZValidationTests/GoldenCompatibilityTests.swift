import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

/// Fixed expectations are authored independently in Tools/README.md, never captured here.
final class GoldenCompatibilityTests: XCTestCase {
  private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
  private let version = "Apple USD Tools (0.25.11)"
  private let nativeID = "c9dce5d1e8d7ef85ae24d92062192f27535322e1aca4d933944d3115222579b4"
  private let externalID = "be443812e7c3baf9fffaa43e1d5ac4f7367768fffc34382bf68c06c7a1fa8f0e"

  func testV1Compatibility() throws {
    for kind in ["complete", "incomplete", "operational"] {
      let external =
        kind == "incomplete" ? checker(outcome: .noFailureReported, legacy: true) : .notRequested
      let report = try fixedReport(kind, external: external)
      try compare(report, format: .json, filename: "report-\(kind)-v1.json")
      try assertTextMeaning(report)
      let sarif = try ReportEncoder.encode(report, format: .sarif)
      let runs = try XCTUnwrap(try object(sarif)["runs"] as? [[String: Any]])
      let invocation = try XCTUnwrap((runs[0]["invocations"] as? [[String: Any]])?.first)
      XCTAssertEqual(invocation["executionSuccessful"] as? Bool, kind != "operational")
      let props = try XCTUnwrap(runs[0]["properties"] as? [String: Any])
      XCTAssertEqual(props["exitCode"] as? Int32, report.exitCode)
      XCTAssertEqual(props["validationStatus"] as? String, report.validationStatus.rawValue)
      try export(sarif, filename: "report-\(kind)-v1.sarif")
    }
    for (name, external) in [
      ("native", ExternalCheck.notRequested),
      (
        "external-unavailable",
        ExternalCheck(
          requested: true, phase: .versionProbe,
          availability: .unavailable, policy: .general, status: .unavailable)
      ),
      ("external-failure", checker(outcome: .failureReported, legacy: true)),
    ] {
      let report = try fixedReport("incomplete", external: external)
      try compare(report, format: .sarif, filename: "\(name)-v1.sarif")
    }
    for (name, outcome) in [
      ("success", ExternalOutcome.noFailureReported), ("failure", .failureReported),
    ] {
      let report = try fixedReport("complete", external: checker(outcome: outcome))
      try compare(report, format: .json, filename: "external-\(name)-v1.json")
      try assertTextMeaning(report)
    }
    let catalogue = try ReportEncoder.encodeCatalogue(profile: .applePortableV1, format: .json)
    XCTAssertEqual(
      catalogue,
      try Data(contentsOf: root.appendingPathComponent("Tests/Goldens/rule-catalogue-v1.json")))
    try export(catalogue, filename: "catalogue-apple-v1.json")
    try export(
      ReportEncoder.encodeCatalogue(profile: .generalV1, format: .json),
      filename: "catalogue-general-v1.json")
    try assertExternalStates()
    try assertRelocationAndIdentity()
  }

  private func assertExternalStates() throws {
    let cases: [(String, ExternalCheck)] = [
      ("not-requested", .notRequested),
      (
        "unavailable",
        ExternalCheck(
          requested: true, phase: .versionProbe, availability: .unavailable,
          policy: .general, status: .unavailable)
      ),
      (
        "unsupported",
        ExternalCheck(
          requested: true, phase: .versionProbe, availability: .available,
          version: "unsupported", policy: .general, status: .unsupportedVersion, exitCode: 0,
          terminationReason: .exited)
      ),
      ("unsafe", ExternalCheck(requested: true, policy: .general, status: .skippedUnsafeInput)),
      ("success", checker(outcome: .noFailureReported)),
      ("failure", checker(outcome: .failureReported)),
      (
        "missing-outcome",
        ExternalCheck(
          requested: true, phase: .validation, availability: .available,
          policy: .general, status: .completed, exitCode: 0, terminationReason: .exited)
      ),
      (
        "launch",
        ExternalCheck(
          requested: true, phase: .versionProbe, policy: .general,
          status: .launchFailed, terminationReason: .launchError)
      ),
      (
        "invalid-request",
        ExternalCheck(
          requested: true, phase: .validation, availability: .available,
          policy: .general, status: .launchFailed, terminationReason: .invalidRequest)
      ),
      (
        "capture",
        ExternalCheck(
          requested: true, phase: .validation, availability: .available,
          policy: .general, status: .launchFailed, terminationReason: .captureError)
      ),
      (
        "reap",
        ExternalCheck(
          requested: true, phase: .validation, availability: .available,
          policy: .general, status: .launchFailed, terminationReason: .reapError)
      ),
      (
        "signal",
        ExternalCheck(
          requested: true, phase: .validation, availability: .available,
          policy: .general, status: .launchFailed, signal: 9, terminationReason: .uncaughtSignal)
      ),
      (
        "timeout",
        ExternalCheck(
          requested: true, phase: .validation, availability: .available,
          policy: .general, status: .timedOut, signal: 15, terminationReason: .terminated)
      ),
      (
        "output-cap",
        ExternalCheck(
          requested: true, phase: .versionProbe, policy: .applePortable,
          status: .outputLimitExceeded, signal: 9, terminationReason: .killed,
          stdoutBytes: 16_384, hasStdout: true)
      ),
      (
        "failure-unknown-version",
        ExternalCheck(
          requested: true, phase: .validation,
          availability: .available, policy: .general, status: .completed, outcome: .failureReported,
          exitCode: 17, findings: [externalFinding(version: nil)])
      ),
    ]
    for (name, external) in cases {
      for sensitive in [false, true] {
        let report = try fixedReport("incomplete", external: external, sensitive: sensitive)
        let jsonBytes = try ReportEncoder.encode(report, format: .json)
        let sarifBytes = try ReportEncoder.encode(report, format: .sarif)
        let json = try object(jsonBytes)
        let encoded = try XCTUnwrap(json["externalCheck"] as? [String: Any])
        XCTAssertEqual(encoded["status"] as? String, external.status.rawValue, name)
        XCTAssertEqual(encoded["requested"] as? Bool, external.requested, name)
        XCTAssertEqual(encoded["availability"] as? String, external.availability.rawValue, name)
        for (key, value) in [
          ("phase", external.phase?.rawValue), ("version", external.version),
          ("policy", external.policy?.rawValue), ("outcome", external.outcome?.rawValue),
          ("terminationReason", external.terminationReason?.rawValue),
        ] {
          if let value {
            XCTAssertEqual(encoded[key] as? String, value, "\(name):\(key)")
          } else {
            XCTAssertTrue(encoded[key] is NSNull, "\(name):\(key)")
          }
        }
        for (key, value) in [("exitCode", external.exitCode), ("signal", external.signal)] {
          if let value {
            XCTAssertEqual(encoded[key] as? Int32, value)
          } else {
            XCTAssertTrue(encoded[key] is NSNull, key)
          }
        }
        XCTAssertEqual(encoded["stdoutBytes"] as? Int64, external.stdoutBytes)
        XCTAssertEqual(encoded["stderrBytes"] as? Int64, external.stderrBytes)
        XCTAssertEqual(encoded["hasStdout"] as? Bool, external.hasStdout)
        XCTAssertEqual(encoded["hasStderr"] as? Bool, external.hasStderr)
        XCTAssertEqual((encoded["findings"] as? [Any])?.count, external.findings.count)
        if !sensitive {
          XCTAssertNil(encoded["sensitiveDetails"])
          XCTAssertFalse(String(decoding: jsonBytes, as: UTF8.self).contains("private-invocation"))
        } else if external.sensitiveDetails == nil {
          XCTAssertTrue(encoded["sensitiveDetails"] is NSNull)
        }
        let runs = try XCTUnwrap(try object(sarifBytes)["runs"] as? [[String: Any]])
        XCTAssertEqual(runs.count, external.requested ? 2 : 1, name)
        let nativeResults = try XCTUnwrap(runs[0]["results"] as? [[String: Any]])
        XCTAssertEqual(nativeResults.map { $0["ruleId"] as? String }, ["UVK-LIM-002"])
        XCTAssertEqual(
          ((runs[0]["properties"] as? [String: Any])?["coverage"] as? [String: Any])?["isComplete"]
            as? Bool, false)
        if external.requested {
          let run = runs[1]
          let properties = try XCTUnwrap(run["properties"] as? [String: Any])
          let checker = try XCTUnwrap(properties["externalCheck"] as? [String: Any])
          let invocation = try XCTUnwrap((run["invocations"] as? [[String: Any]])?.first)
          let successful = external.status == .completed && external.outcome != nil
          XCTAssertEqual(invocation["executionSuccessful"] as? Bool, successful)
          XCTAssertEqual(invocation["exitCode"] as? Int32, external.exitCode)
          XCTAssertEqual(invocation["exitSignalNumber"] as? Int32, external.signal)
          XCTAssertEqual(invocation["toolExecutionNotifications"] == nil, successful)
          for key in [
            "phase", "version", "policy", "outcome", "exitCode", "signal", "terminationReason",
          ] {
            if encoded[key] is NSNull {
              XCTAssertNil(checker[key], key)
            } else {
              XCTAssertEqual(
                checker[key] as? NSObject, encoded[key] as? NSObject, key)
            }
          }
          let results = try XCTUnwrap(run["results"] as? [[String: Any]])
          XCTAssertEqual(results.count, external.findings.count)
          for result in results {
            XCTAssertEqual(result["ruleId"] as? String, "USDCK-001")
            XCTAssertNil(result["locations"])
            let provenance = try XCTUnwrap(
              (result["properties"] as? [String: Any])?["provenance"] as? [String: Any])
            XCTAssertEqual(provenance["kind"] as? String, "usdchecker")
            if external.version == nil { XCTAssertNil(provenance["version"]) }
          }
        }
        try assertTextMeaning(report)
        let suffix = sensitive ? "-sensitive" : ""
        try export(jsonBytes, filename: "state-\(name)\(suffix).json")
        try export(sarifBytes, filename: "state-\(name)\(suffix).sarif")
      }
    }
  }

  private func assertRelocationAndIdentity() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let moved = folder.appendingPathComponent("moved")
    try FileManager.default.createDirectory(at: moved, withIntermediateDirectories: false)
    let bytes = try ArchiveRecipe(entries: [
      .init(
        nameBytes: Data("root.usda".utf8),
        payload: Data("#usda 1.0\n@missing.png@".utf8))
    ]).encode()
    func inspect(_ name: String, _ directory: URL) throws -> ValidationReport {
      let url = try Fixtures.write(bytes, basename: name, in: directory)
      return try Validator().validate(fileAt: url, configuration: ValidationConfiguration())
    }
    let first = try inspect("input.usdz", folder)
    let repeated = try inspect("input.usdz", folder)
    let relocated = try inspect("input.usdz", moved)
    let renamed = try inspect("renamed.usdz", folder)
    XCTAssertFalse(first.nativeFindings.isEmpty)
    for report in [repeated, relocated, renamed] {
      XCTAssertEqual(first.nativeFindings, report.nativeFindings)
      XCTAssertEqual(first.coverage, report.coverage)
    }
    for format in [ReportFormat.json, .sarif, .text] {
      let original = try ReportEncoder.encode(first, format: format)
      XCTAssertEqual(original, try ReportEncoder.encode(repeated, format: format))
      XCTAssertEqual(original, try ReportEncoder.encode(relocated, format: format))
    }
    for (name, expected) in [
      ("é #?%\\\n.usdz", "%C3%A9%20%23%3F%25%5C%0A.usdz"),
      (".", "%2E"), ("..", "%2E%2E"), ("C:x.usdz", "C%3Ax.usdz"),
    ] {
      let report = try fixedReport("complete", name: name)
      let runs = try XCTUnwrap(
        try object(ReportEncoder.encode(report, format: .sarif))["runs"] as? [[String: Any]])
      let artifact = try XCTUnwrap((runs[0]["artifacts"] as? [[String: Any]])?.first)
      XCTAssertEqual((artifact["location"] as? [String: String])?["uri"], expected)
    }
  }

  private func compare(_ report: ValidationReport, format: ReportFormat, filename: String) throws {
    let bytes = try ReportEncoder.encode(report, format: format)
    let path = root.appendingPathComponent("Tests/Goldens/\(filename)")
    XCTAssertTrue(
      FileManager.default.fileExists(atPath: path.path), "Missing independent golden: \(filename)")
    if FileManager.default.fileExists(atPath: path.path) {
      XCTAssertEqual(bytes, try Data(contentsOf: path), filename)
    }
    XCTAssertEqual(bytes, try ReportEncoder.encode(report, format: format))
    try export(bytes, filename: filename)
  }

  private func assertTextMeaning(_ report: ValidationReport) throws {
    let text = String(decoding: try ReportEncoder.encode(report, format: .text), as: UTF8.self)
    for line in [
      "validationStatus: \(report.validationStatus.rawValue)",
      "gate: \(report.gateDecision.rawValue)",
      "acceptedIncomplete: \(report.acceptedIncomplete)", "exit: \(report.exitCode)",
      "native findings: \(report.nativeFindings.count)",
      "external findings: \(report.externalCheck.findings.count)",
      "external status: \(report.externalCheck.status.rawValue)",
      "external outcome: \(report.externalCheck.outcome?.rawValue ?? "unavailable")",
    ] {
      XCTAssertTrue(text.contains(line + "\n"), line)
    }
    for (area, result) in report.coverage.areas {
      XCTAssertTrue(
        text.contains(
          "coverage \(area.rawValue): \(result.state.rawValue) requested: \(result.requested)\n"))
      for reason in result.reasons {
        XCTAssertTrue(text.contains("  reason: \(reason.ruleID) \(reason.reasonID)\n"))
      }
    }
    for (source, counts) in [
      ("native", report.summary.native), ("external", report.summary.external),
    ] {
      for severity in Severity.allCases {
        XCTAssertTrue(
          text.contains(
            "\(source) count \(severity.rawValue): \(counts.bySeverity[severity] ?? 0)\n"))
      }
      for category in FindingCategory.allCases {
        XCTAssertTrue(
          text.contains(
            "\(source) count \(category.rawValue): \(counts.byCategory[category] ?? 0)\n"))
      }
    }
    for finding in report.nativeFindings + report.externalCheck.findings {
      XCTAssertTrue(
        text.contains(
          "finding: \(finding.ruleID) \(finding.category.rawValue) \(finding.severity.rawValue) \(finding.occurrenceID)\n"
        ))
      XCTAssertTrue(text.contains("  message: \(finding.message)\n"))
      switch finding.provenance {
      case .native(let version):
        XCTAssertTrue(text.contains("  provenance: native \(version)\n"))
      case .usdchecker(let tool, let version, _):
        XCTAssertTrue(
          text.contains("  provenance: usdchecker \(tool) \(version ?? "unavailable")\n"))
      }
    }
  }

  private func fixedReport(
    _ kind: String, external: ExternalCheck = .notRequested,
    sensitive: Bool = false, name: String = "input.usdz"
  ) throws -> ValidationReport {
    var areas: [CoverageArea: CoverageAreaResult] = [:]
    for area in CoverageArea.allCases {
      let requested = area != .appleAdvice
      areas[area] = CoverageAreaResult(
        requested: requested,
        state: requested && kind != "operational" ? .complete : .notRun, reasons: [])
    }
    let location = FindingLocation(
      entryName: "root.usdc", archiveByteOffset: 64, layerByteOffset: 0)
    var findings: [Finding] = []
    if kind == "incomplete" {
      areas[.references] = CoverageAreaResult(
        requested: true, state: .partial,
        reasons: [
          CoverageReason(ruleID: "UVK-LIM-002", reasonID: "binaryReferences", location: location)
        ])
      findings = [
        Finding(
          ruleID: "UVK-LIM-002", occurrenceID: nativeID, category: .validatorLimitation,
          severity: .warning, message: "Native reference inspection is unavailable for binary USD.",
          evidence: [
            "binary": .boolean(true), "bytes": .integer(8), "reason": .string("binaryReferences"),
            "unknown": .null,
          ],
          location: location, provenance: .native(validatorVersion: "0.1.0"))
      ]
    }
    return ValidationReport(
      input: ReportInput(
        displayName: name, byteSize: kind == "operational" ? nil : 123,
        sensitiveDetails: InputSensitiveDetails(absolutePath: "/Users/fixture-owner/\(name)")),
      configuration: try ValidationConfiguration(
        includeSensitiveDetails: sensitive,
        externalCheck: external.requested ? .usdchecker : .disabled),
      coverage: Coverage(areas: areas), nativeFindings: findings, externalCheck: external,
      operationalErrors: kind == "operational" ? [.operational(.inputUnavailable)] : [])
  }

  private func checker(outcome: ExternalOutcome, legacy: Bool = false) -> ExternalCheck {
    ExternalCheck(
      requested: true, phase: .validation, availability: .available, version: version,
      policy: .general, status: .completed, outcome: outcome,
      exitCode: outcome == .failureReported ? 17 : 0,
      terminationReason: legacy ? nil : .exited,
      stderrBytes: legacy || outcome == .failureReported ? 12 : 0,
      hasStderr: legacy || outcome == .failureReported,
      sensitiveDetails: ExternalSensitiveDetails(
        arguments: ["/usr/bin/usdchecker"], stdout: "", stderr: "raw tool text"),
      findings: outcome == .failureReported
        ? [externalFinding(version: version, legacy: legacy)] : [])
  }

  private func externalFinding(version: String?, legacy: Bool = false) -> Finding {
    Finding(
      ruleID: "USDCK-001", occurrenceID: legacy ? "external-occurrence" : externalID,
      category: .appleCompatibility, severity: .error, message: "Checker reported failure.",
      evidence: [:], location: nil,
      provenance: .usdchecker(
        tool: "usdchecker", version: version, invocationID: "private-invocation"))
  }

  private func object(_ bytes: Data) throws -> [String: Any] {
    try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
  }

  private func export(_ bytes: Data, filename: String) throws {
    guard let path = ProcessInfo.processInfo.environment["UVK_COMPAT_EXPORT_DIR"] else { return }
    let directory = URL(fileURLWithPath: path, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try bytes.write(to: directory.appendingPathComponent(filename), options: .atomic)
  }
}

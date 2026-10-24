import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

final class JSONReportTests: XCTestCase {
  func testSafeTerminationReasonInJSONAndText() throws {
    for reason: ExternalTerminationReason? in [nil, .reapError, .captureError, .uncaughtSignal] {
      let report = ValidationReport(
        input: ReportInput(displayName: "input.usdz", byteSize: 1),
        configuration: try ValidationConfiguration(externalCheck: .usdchecker),
        coverage: Coverage(areas: [:]), nativeFindings: [],
        externalCheck: ExternalCheck(
          requested: true, status: .launchFailed, terminationReason: reason))
      let json = try object(ReportEncoder.encode(report, format: .json))
      let check = try XCTUnwrap(json["externalCheck"] as? [String: Any])
      if let reason {
        XCTAssertEqual(check["terminationReason"] as? String, reason.rawValue)
      } else {
        XCTAssertTrue(check["terminationReason"] is NSNull)
      }
      let text = String(decoding: try ReportEncoder.encode(report, format: .text), as: UTF8.self)
      XCTAssertTrue(
        text.contains("external termination reason: \(reason?.rawValue ?? "unavailable")\n"))
    }
  }

  func testCanonicalV1Envelope() throws {
    let output = try ReportEncoder.encode(makeReport(.complete), format: .json)
    let document = try object(output)
    XCTAssertEqual(
      Set(document.keys),
      [
        "schemaVersion", "tool", "input", "configuration", "coverage", "nativeFindings",
        "externalCheck", "operationalErrors", "summary", "validationStatus", "gateDecision",
        "acceptedIncomplete", "exitCode",
      ])
    XCTAssertEqual(document["schemaVersion"] as? Int, 1)
    XCTAssertEqual((document["tool"] as? [String: String])?["version"], "0.2.0")
    XCTAssertEqual(
      (document["configuration"] as? [String: Any])?["safetyEnvelopeVersion"] as? Int, 2)
    XCTAssertEqual(document["exitCode"] as? Int, 0)
    XCTAssertEqual(document["validationStatus"] as? String, "passed")
    XCTAssertEqual((document["nativeFindings"] as? [Any])?.count, 0)
    XCTAssertEqual((document["operationalErrors"] as? [Any])?.count, 0)
    let external = try XCTUnwrap(document["externalCheck"] as? [String: Any])
    for key in ["phase", "version", "policy", "outcome", "exitCode", "signal"] {
      XCTAssertTrue(external[key] is NSNull, key)
    }
    XCTAssertEqual(external["availability"] as? String, "unknown")
    XCTAssertEqual(external["status"] as? String, "notRequested")
    XCTAssertEqual((external["findings"] as? [Any])?.count, 0)
    XCTAssertNil(external["sensitiveDetails"])
    XCTAssertNil((document["input"] as? [String: Any])?["sensitiveDetails"])
    XCTAssertEqual(output.last, 0x0a)
    XCTAssertEqual(output.filter { $0 == 0x0a }.count, 1)
    XCTAssertFalse(output.starts(with: [0xef, 0xbb, 0xbf]))
    XCTAssertFalse(String(decoding: output, as: UTF8.self).contains(": "))
    XCTAssertEqual(output, try ReportEncoder.encode(makeReport(.complete), format: .json))

    let incomplete = try object(ReportEncoder.encode(makeReport(.incomplete), format: .json))
    XCTAssertEqual(incomplete["validationStatus"] as? String, "incomplete")
    XCTAssertEqual(incomplete["acceptedIncomplete"] as? Bool, false)
    XCTAssertEqual(incomplete["exitCode"] as? Int, 2)
    let summary = try XCTUnwrap(incomplete["summary"] as? [String: Any])
    let native = try XCTUnwrap(summary["native"] as? [String: Any])
    XCTAssertEqual((native["bySeverity"] as? [String: Int])?["warning"], 1)
    XCTAssertEqual((native["byCategory"] as? [String: Int])?["validatorLimitation"], 1)
    let externalCounts = try XCTUnwrap(summary["external"] as? [String: Any])
    XCTAssertEqual((externalCounts["bySeverity"] as? [String: Int])?["warning"], 0)
    let operational = try object(ReportEncoder.encode(makeReport(.operational), format: .json))
    XCTAssertTrue((operational["input"] as? [String: Any])?["byteSize"] is NSNull)
    XCTAssertEqual(operational["exitCode"] as? Int, 3)
  }

  func testReportGoldens() throws {
    for kind in ReportKind.allCases {
      let output = try ReportEncoder.encode(makeReport(kind), format: .json)
      let goldenBytes = try golden("report-\(kind.rawValue)-v1.json")
      XCTAssertEqual(output, goldenBytes, kind.rawValue)
    }
  }

  func testCombiningMarkPrivacyInActualJSON() throws {
    let path = "/\u{0301}Users/fixture-owner/input"
    let prose = "detail=\u{0345}/Users/fixture-owner/input"
    let safe = "Textures/a\u{0345}/b.png"
    let finding = Finding(
      ruleID: "UVK-PATH-004", occurrenceID: "stable-id", category: .policy, severity: .error,
      message: prose, evidence: ["unsafe": .string(path), "safe": .string(safe)],
      location: FindingLocation(entryName: path), provenance: .native(validatorVersion: "0.2.0"))
    func report(_ path: String, sensitive: Bool = false) throws -> ValidationReport {
      ValidationReport(
        input: ReportInput(
          displayName: path, byteSize: 123,
          sensitiveDetails: InputSensitiveDetails(absolutePath: path)),
        configuration: try ValidationConfiguration(includeSensitiveDetails: sensitive),
        coverage: Coverage(areas: [:]), nativeFindings: [finding],
        externalCheck: ExternalCheck(
          requested: false, status: .notRequested,
          sensitiveDetails: ExternalSensitiveDetails(
            arguments: ["/usr/bin/usdchecker"], stdout: "raw output", stderr: "raw error")))
    }
    let output = try ReportEncoder.encode(report("/private/\u{0301}input.usdz"), format: .json)
    let document = try object(output)
    XCTAssertEqual(
      (document["input"] as? [String: Any])?["displayName"] as? String, "\u{0301}input.usdz")
    let rendered = try XCTUnwrap((document["nativeFindings"] as? [[String: Any]])?.first)
    XCTAssertEqual(rendered["message"] as? String, "[redacted path]")
    XCTAssertEqual(
      (rendered["location"] as? [String: Any])?["entryName"] as? String, "[redacted path]")
    XCTAssertEqual(
      (rendered["evidence"] as? [String: Any])?["unsafe"] as? String, "[redacted path]")
    XCTAssertEqual((rendered["evidence"] as? [String: Any])?["safe"] as? String, safe)
    let text = String(decoding: output, as: UTF8.self)
    for secret in ["fixture-owner", "private/", "sensitiveDetails", "raw output", "raw error"] {
      XCTAssertFalse(text.contains(secret), secret)
    }
    let relocatedOutput = try ReportEncoder.encode(
      report("/elsewhere/\u{0301}input.usdz"), format: .json)
    XCTAssertEqual(output, relocatedOutput)
    let disclosed = try object(
      ReportEncoder.encode(report("/private/\u{0301}input.usdz", sensitive: true), format: .json))
    let input = try XCTUnwrap(disclosed["input"] as? [String: Any])
    XCTAssertEqual(
      (input["sensitiveDetails"] as? [String: Any])?["absolutePath"] as? String,
      "/private/\u{0301}input.usdz")
    let disclosedFinding = try XCTUnwrap((disclosed["nativeFindings"] as? [[String: Any]])?.first)
    XCTAssertEqual(disclosedFinding["message"] as? String, prose)
    XCTAssertEqual(finding.message, prose)
  }

  func testEscapingAndRelocation() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let bytes = try ArchiveRecipe(entries: [
      .init(nameBytes: Data("root.usda".utf8), payload: Data("#usda 1.0\n@missing.png@".utf8))
    ]).encode()
    let configuration = try ValidationConfiguration(budgets: WarningBudgets(fileBytes: 1))
    func inspect(_ name: String, in folder: URL) throws -> ValidationReport {
      let url = try Fixtures.write(bytes, basename: name, in: folder)
      let snapshot = try FileSnapshot.open(url)
      defer { try? snapshot.close() }
      let result = try NativeEngine.inspect(snapshot: snapshot, configuration: configuration)
      return ValidationReport(
        input: ReportInput(displayName: url.path, byteSize: Int64(result.inputByteSize)),
        configuration: configuration, coverage: result.coverage, nativeFindings: result.findings)
    }
    let first = try inspect("input.usdz", in: directory)
    XCTAssertGreaterThanOrEqual(first.nativeFindings.count, 2)
    let renamed = try inspect("renamed.usdz", in: directory)
    XCTAssertEqual(
      first.nativeFindings.map(\.occurrenceID), renamed.nativeFindings.map(\.occurrenceID))
    XCTAssertEqual(first.nativeFindings, renamed.nativeFindings)
    let movedDirectory = directory.appendingPathComponent("moved")
    try FileManager.default.createDirectory(at: movedDirectory, withIntermediateDirectories: false)
    let relocated = try inspect("input.usdz", in: movedDirectory)
    XCTAssertEqual(first.nativeFindings, relocated.nativeFindings)
    XCTAssertEqual(first.coverage, relocated.coverage)
    let output = try ReportEncoder.encode(first, format: .json)
    let relocatedOutput = try ReportEncoder.encode(relocated, format: .json)
    XCTAssertEqual(output, relocatedOutput)
    XCTAssertEqual(output, try ReportEncoder.encode(first, format: .json))
  }

  func testCanonicalEscapesUTF8KeyOrderAndCheckedIntegers() throws {
    var buffer = CappedBuffer()
    try CanonicalJSON.encode(
      .object([
        "😀": .null, "é": .bool(false), "a": .integer(Int64.min),
        "e\u{0301}x": .integer(1), "f": .integer(2),
        "Z": .array([
          .unsignedInteger(UInt64.max), .string("\"\\/\u{0000}\u{0008}\u{000c}\n\r\t\u{001f}é😀"),
        ]),
      ]), into: &buffer)
    let expected =
      "{\"Z\":[18446744073709551615,\"\\\"\\\\/\\u0000\\b\\f\\n\\r\\t\\u001fé😀\"],\"a\":-9223372036854775808,\"e\u{0301}x\":1,\"f\":2,\"é\":false,\"😀\":null}\n"
    XCTAssertEqual(buffer.finish(), Data(expected.utf8))
    _ = try JSONSerialization.jsonObject(with: buffer.finish())
    var exact = CappedBuffer(limit: 5)
    try CanonicalJSON.encode(.null, into: &exact)
    XCTAssertEqual(exact.finish(), Data("null\n".utf8))
    var below = CappedBuffer(limit: 4)
    XCTAssertThrowsError(try CanonicalJSON.encode(.null, into: &below)) {
      XCTAssertEqual($0 as? ValidationError, .operational(.reportLimitExceeded))
    }
  }

  func testEveryJSONControlByteEscapesDeterministically() throws {
    let controls = String(String.UnicodeScalarView((0...31).compactMap(Unicode.Scalar.init)))
    var buffer = CappedBuffer()
    try CanonicalJSON.encode(.string(controls), into: &buffer)
    let expected =
      #""\u0000\u0001\u0002\u0003\u0004\u0005\u0006\u0007\b\t\n\u000b\f\r\u000e\u000f\u0010\u0011\u0012\u0013\u0014\u0015\u0016\u0017\u0018\u0019\u001a\u001b\u001c\u001d\u001e\u001f""#
      + "\n"
    XCTAssertEqual(buffer.finish(), Data(expected.utf8))
  }

  func testCatalogueGoldenAndProfileSelection() throws {
    let output = try ReportEncoder.encodeCatalogue(profile: .applePortableV1, format: .json)
    XCTAssertEqual(output, try golden("rule-catalogue-v1.json"))
    let document = try object(output)
    XCTAssertEqual(Set(document.keys), ["schemaVersion", "tool", "profile", "rules"])
    let rules = try XCTUnwrap(document["rules"] as? [[String: Any]])
    XCTAssertEqual(rules.count, 34)
    XCTAssertTrue(
      try XCTUnwrap(rules.first { $0["ruleID"] as? String == "UVK-RES-001" })["family"] is NSNull)
    let general = try object(ReportEncoder.encodeCatalogue(profile: .generalV1, format: .json))
    let generalRules = try XCTUnwrap(general["rules"] as? [[String: Any]])
    XCTAssertEqual(generalRules.count, 32)
    XCTAssertFalse(generalRules.contains { $0["category"] as? String == "appleCompatibility" })
    let text = String(
      decoding: try ReportEncoder.encodeCatalogue(profile: .generalV1, format: .text), as: UTF8.self
    )
    XCTAssertTrue(text.contains("UVK-ARC-001"))
    XCTAssertTrue(text.contains("archiveSpecification"))
    XCTAssertTrue(text.contains("Skip"))
    XCTAssertFalse(text.contains("UVK-APL-001"))
    XCTAssertTrue(text.hasSuffix("\n"))
  }

  func testExternalSeparationSensitiveFieldsAndLocationNulls() throws {
    let externalFinding = Finding(
      ruleID: "USDCK-001", occurrenceID: "external-id", category: .appleCompatibility,
      severity: .error, message: "Checker reported failure.", evidence: [:], location: nil,
      provenance: .usdchecker(tool: "usdchecker", version: nil, invocationID: "random-private-id"))
    for sensitive in [false, true] {
      let report = ValidationReport(
        input: ReportInput(displayName: "input.usdz", byteSize: nil),
        configuration: try ValidationConfiguration(
          budgets: WarningBudgets(textureMaxDimension: nil),
          includeSensitiveDetails: sensitive, externalCheck: .usdchecker),
        coverage: Coverage(areas: [:]), nativeFindings: [],
        externalCheck: ExternalCheck(
          requested: true, phase: .validation, availability: .available, policy: .general,
          status: .completed, outcome: .failureReported, exitCode: 17, signal: 9,
          stdoutBytes: 42, stderrBytes: 19, hasStdout: true, hasStderr: true,
          sensitiveDetails: ExternalSensitiveDetails(
            arguments: ["/private/input.usdz"], stdout: "raw\u{001b}out", stderr: "raw\nerror"),
          findings: [externalFinding]))
      let output = try ReportEncoder.encode(report, format: .json)
      let document = try object(output)
      XCTAssertEqual(document["exitCode"] as? Int, 1)
      XCTAssertEqual((document["nativeFindings"] as? [Any])?.count, 0)
      let external = try XCTUnwrap(document["externalCheck"] as? [String: Any])
      XCTAssertEqual(external["exitCode"] as? Int, 17)
      XCTAssertEqual(external["signal"] as? Int, 9)
      XCTAssertEqual(external["stdoutBytes"] as? Int, 42)
      let finding = try XCTUnwrap((external["findings"] as? [[String: Any]])?.first)
      XCTAssertTrue(finding["location"] is NSNull)
      let provenance = try XCTUnwrap(finding["provenance"] as? [String: Any])
      XCTAssertEqual(provenance["kind"] as? String, "usdchecker")
      XCTAssertTrue(provenance["version"] is NSNull)
      let summary = try XCTUnwrap(document["summary"] as? [String: Any])
      XCTAssertEqual(
        ((summary["external"] as? [String: Any])?["bySeverity"] as? [String: Int])?["error"], 1)
      XCTAssertEqual(
        ((summary["native"] as? [String: Any])?["bySeverity"] as? [String: Int])?["error"], 0)
      if sensitive {
        XCTAssertTrue((document["input"] as? [String: Any])?["sensitiveDetails"] is NSNull)
        let details = try XCTUnwrap(external["sensitiveDetails"] as? [String: Any])
        XCTAssertEqual(details["stdout"] as? String, "raw\\u{001B}out")
        XCTAssertEqual(details["stderr"] as? String, "raw\\nerror")
        XCTAssertEqual(
          (provenance["sensitiveDetails"] as? [String: Any])?["invocationID"] as? String,
          "random-private-id")
      } else {
        XCTAssertNil(external["sensitiveDetails"])
        XCTAssertNil(provenance["sensitiveDetails"])
        XCTAssertFalse(String(decoding: output, as: UTF8.self).contains("random-private-id"))
        XCTAssertFalse(String(decoding: output, as: UTF8.self).contains("raw"))
      }
    }
  }

  func testPrivacyKeyCollisionFailsInsteadOfDroppingEvidence() throws {
    let finding = Finding(
      ruleID: "UVK-PATH-004", occurrenceID: "id", category: .policy, severity: .error,
      message: "Unsafe paths.", evidence: ["/private/a": .integer(1), "/private/b": .integer(2)],
      location: nil, provenance: .native(validatorVersion: "0.2.0"))
    let report = ValidationReport(
      input: ReportInput(displayName: "input.usdz", byteSize: 1),
      configuration: try ValidationConfiguration(), coverage: Coverage(areas: [:]),
      nativeFindings: [finding])
    XCTAssertThrowsError(try ReportEncoder.encode(report, format: .json)) {
      XCTAssertEqual($0 as? ValidationError, .operational(.reportEncodingFailed))
    }
  }

  func testJSONFieldAndReportCapsIncludeEscapeExpansion() throws {
    let finding = Finding(
      ruleID: "UVK-PATH-006", occurrenceID: "id", category: .policy, severity: .error,
      message: String(repeating: "é", count: 1024),
      evidence: ["detail": .string(String(repeating: "\"", count: 4096))], location: nil,
      provenance: .native(validatorVersion: "0.2.0"))
    func report(count: Int) throws -> ValidationReport {
      ValidationReport(
        input: ReportInput(displayName: "input.usdz", byteSize: 1),
        configuration: try ValidationConfiguration(), coverage: Coverage(areas: [:]),
        nativeFindings: Array(repeating: finding, count: count))
    }
    let document = try object(ReportEncoder.encode(report(count: 1), format: .json))
    let value = try XCTUnwrap((document["nativeFindings"] as? [[String: Any]])?.first)
    let message = try XCTUnwrap(value["message"] as? String)
    XCTAssertLessThanOrEqual(message.utf8.count, 1024)
    XCTAssertTrue(message.hasSuffix("[truncated]"))
    XCTAssertEqual((value["evidence"] as? [String: String])?["detail"]?.utf8.count, 4096)
    XCTAssertThrowsError(try ReportEncoder.encode(report(count: 4200), format: .json)) {
      XCTAssertEqual($0 as? ValidationError, .operational(.reportLimitExceeded))
    }
  }

  private enum ReportKind: String, CaseIterable { case complete, incomplete, operational }

  private func makeReport(_ kind: ReportKind) throws -> ValidationReport {
    var areas: [CoverageArea: CoverageAreaResult] = [:]
    for area in CoverageArea.allCases {
      let requested = area != .appleAdvice
      areas[area] = CoverageAreaResult(
        requested: requested, state: requested && kind != .operational ? .complete : .notRun,
        reasons: [])
    }
    let location = FindingLocation(
      entryName: "root.usdc", archiveByteOffset: 64, layerByteOffset: 0)
    var findings: [Finding] = []
    if kind == .incomplete {
      areas[.references] = CoverageAreaResult(
        requested: true, state: .partial,
        reasons: [
          CoverageReason(ruleID: "UVK-LIM-002", reasonID: "binaryReferences", location: location)
        ])
      findings = [
        Finding(
          ruleID: "UVK-LIM-002",
          occurrenceID: "c9dce5d1e8d7ef85ae24d92062192f27535322e1aca4d933944d3115222579b4",
          category: .validatorLimitation, severity: .warning,
          message: "Native reference inspection is unavailable for binary USD.",
          evidence: [
            "binary": .boolean(true), "bytes": .integer(8), "reason": .string("binaryReferences"),
            "unknown": .null,
          ],
          location: location, provenance: .native(validatorVersion: "0.2.0"))
      ]
    }
    return ValidationReport(
      input: ReportInput(
        displayName: "/Users/fixture-owner/input.usdz", byteSize: kind == .operational ? nil : 123,
        sensitiveDetails: InputSensitiveDetails(absolutePath: "/Users/fixture-owner/input.usdz")),
      configuration: try ValidationConfiguration(
        externalCheck: kind == .incomplete ? .usdchecker : .disabled),
      coverage: Coverage(areas: areas), nativeFindings: findings,
      externalCheck: kind == .incomplete
        ? ExternalCheck(
          requested: true, phase: .validation, availability: .available,
          version: "Apple USD Tools (0.25.11)", policy: .general, status: .completed,
          outcome: .noFailureReported, exitCode: 0, stderrBytes: 12, hasStderr: true,
          sensitiveDetails: ExternalSensitiveDetails(
            arguments: ["/usr/bin/usdchecker"], stdout: "", stderr: "raw tool text"))
        : .notRequested,
      operationalErrors: kind == .operational ? [.operational(.inputUnavailable)] : [])
  }

  private func object(_ data: Data) throws -> [String: Any] {
    try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  private func golden(_ name: String) throws -> Data {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent("Goldens/" + name)
    return try Data(contentsOf: url)
  }
}

import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

final class SARIFReportTests: XCTestCase {
  func testRunsAndLocations() throws {
    let report = try makeReport(.native)
    let document = try object(ReportEncoder.encode(report, format: .sarif))
    XCTAssertEqual(document["version"] as? String, "2.1.0")
    XCTAssertEqual(
      document["$schema"] as? String,
      "https://docs.oasis-open.org/sarif/sarif/v2.1.0/os/schemas/sarif-schema-2.1.0.json")
    let nativeOnlyRuns = try XCTUnwrap(document["runs"] as? [[String: Any]])
    XCTAssertEqual(nativeOnlyRuns.count, 1)
    let native = try XCTUnwrap(nativeOnlyRuns.first)
    let driver = try XCTUnwrap((native["tool"] as? [String: Any])?["driver"] as? [String: Any])
    XCTAssertEqual(driver["name"] as? String, "usdz-validator")
    let rules = try XCTUnwrap(driver["rules"] as? [[String: Any]])
    XCTAssertEqual(rules.count, 30)
    XCTAssertEqual(rules.first?["id"] as? String, "UVK-ARC-001")
    XCTAssertFalse(rules.contains { $0["id"] as? String == "USDCK-001" })
    let rule = try XCTUnwrap(rules.first { $0["id"] as? String == "UVK-LIM-002" })
    XCTAssertEqual((rule["defaultConfiguration"] as? [String: Any])?["level"] as? String, "warning")
    XCTAssertEqual(
      (rule["properties"] as? [String: Any])?["category"] as? String, "validatorLimitation")
    let result = try XCTUnwrap((native["results"] as? [[String: Any]])?.first)
    XCTAssertEqual(result["ruleId"] as? String, "UVK-LIM-002")
    XCTAssertEqual(result["level"] as? String, "warning")
    XCTAssertEqual(
      (result["partialFingerprints"] as? [String: String])?["uvkOccurrence/v1"], nativeID)
    let properties = try XCTUnwrap(result["properties"] as? [String: Any])
    XCTAssertEqual(properties["category"] as? String, "validatorLimitation")
    XCTAssertEqual((properties["evidence"] as? [String: Any])?["bytes"] as? Int, 8)
    XCTAssertTrue((properties["evidence"] as? [String: Any])?["unknown"] is NSNull)
    XCTAssertEqual((properties["provenance"] as? [String: String])?["kind"], "native")
    let location = try XCTUnwrap((result["locations"] as? [[String: Any]])?.first)
    let physical = try XCTUnwrap(location["physicalLocation"] as? [String: Any])
    XCTAssertEqual(
      (physical["artifactLocation"] as? [String: Any])?["uri"] as? String, "input.usdz")
    let region = try XCTUnwrap(physical["region"] as? [String: Any])
    XCTAssertEqual(region["byteOffset"] as? Int, 64)
    XCTAssertEqual(Set(region.keys), ["byteOffset"])
    let logical = try XCTUnwrap((location["logicalLocations"] as? [[String: Any]])?.first)
    XCTAssertEqual(logical["fullyQualifiedName"] as? String, "root.usdc")
    XCTAssertEqual((logical["properties"] as? [String: Any])?["layerByteOffset"] as? Int, 0)
    XCTAssertNil((logical["properties"] as? [String: Any])?["line"])
  }

  func testInvocationAndCoverage() throws {
    let native = try runs(makeReport(.native))[0]
    XCTAssertEqual(try invocation(native)["executionSuccessful"] as? Bool, true)
    let properties = try XCTUnwrap(native["properties"] as? [String: Any])
    XCTAssertEqual((properties["coverage"] as? [String: Any])?["isComplete"] as? Bool, false)
    XCTAssertEqual(properties["validationStatus"] as? String, "incomplete")
    XCTAssertEqual(properties["gateDecision"] as? String, "fail")
    XCTAssertEqual(properties["exitCode"] as? Int, 2)
    XCTAssertEqual(
      (properties["configuration"] as? [String: Any])?["profile"] as? String, "general-v1")
    XCTAssertEqual(
      ((properties["counts"] as? [String: Any])?["bySeverity"] as? [String: Int])?["warning"], 1)
    let requestedUnavailableRuns = try runs(makeReport(.unavailable))
    XCTAssertEqual(requestedUnavailableRuns.count, 2)
    let unavailable = try invocation(requestedUnavailableRuns[1])
    XCTAssertEqual(unavailable["executionSuccessful"] as? Bool, false)
    let notification = try XCTUnwrap(
      (unavailable["toolExecutionNotifications"] as? [[String: Any]])?.first)
    XCTAssertEqual(
      (notification["message"] as? [String: String])?["text"],
      "usdchecker invocation did not complete: unavailable.")
    XCTAssertNil(unavailable["exitCode"])
    let external = try XCTUnwrap(
      (requestedUnavailableRuns[1]["properties"] as? [String: Any])?["externalCheck"]
        as? [String: Any])
    for key in ["version", "exitCode", "signal", "outcome", "sensitiveDetails"] {
      XCTAssertNil(external[key], key)
    }
    let failedRuns = try runs(makeReport(.failure))
    XCTAssertEqual(try invocation(failedRuns[1])["executionSuccessful"] as? Bool, true)
    XCTAssertEqual(try invocation(failedRuns[1])["exitCode"] as? Int, 17)
    XCTAssertNil(try invocation(failedRuns[1])["toolExecutionNotifications"])
    XCTAssertEqual((failedRuns[1]["results"] as? [Any])?.count, 1)
    XCTAssertEqual((failedRuns[0]["results"] as? [Any])?.count, 1)
    let driver = try XCTUnwrap(
      (failedRuns[1]["tool"] as? [String: Any])?["driver"] as? [String: Any])
    XCTAssertEqual(driver["name"] as? String, "usdchecker")
    XCTAssertEqual(
      (driver["rules"] as? [[String: Any]])?.map { $0["id"] as? String }, ["USDCK-001"])
    let result = try XCTUnwrap((failedRuns[1]["results"] as? [[String: Any]])?.first)
    XCTAssertNil(result["locations"])
    XCTAssertEqual(
      (result["partialFingerprints"] as? [String: String])?["uvkOccurrence/v1"],
      "external-occurrence")
    XCTAssertEqual(
      ((result["properties"] as? [String: Any])?["provenance"] as? [String: Any])?["kind"]
        as? String, "usdchecker")
    let successful = try customReport(
      external: ExternalCheck(
        requested: true, status: .completed, outcome: .noFailureReported, exitCode: 0))
    XCTAssertEqual(try invocation(runs(successful)[1])["executionSuccessful"] as? Bool, true)
    XCTAssertEqual((try runs(successful)[1]["results"] as? [Any])?.count, 0)
    XCTAssertEqual(
      (try runs(successful)[0]["properties"] as? [String: Any])?["exitCode"] as? Int, 0)
  }

  func testUnsuccessfulInvocationsAndCompletedFailureRemainDistinct() throws {
    for status in [
      ExternalStatus.unavailable, .unsupportedVersion, .skippedUnsafeInput, .launchFailed,
      .timedOut, .outputLimitExceeded, .completed,
    ] {
      let report = try customReport(external: ExternalCheck(requested: true, status: status))
      let external = try runs(report)[1]
      XCTAssertEqual(
        try invocation(external)["executionSuccessful"] as? Bool, false, status.rawValue)
      XCTAssertEqual((try invocation(external)["toolExecutionNotifications"] as? [Any])?.count, 1)
      XCTAssertEqual((external["results"] as? [Any])?.count, 0)
    }
    let operational = try customReport(errors: [.operational(.inputUnavailable)])
    let native = try runs(operational)[0]
    XCTAssertEqual(try invocation(native)["executionSuccessful"] as? Bool, false)
    let notification = try XCTUnwrap(
      (try invocation(native)["toolExecutionNotifications"] as? [[String: Any]])?.first)
    XCTAssertEqual(
      (notification["message"] as? [String: String])?["text"], "operational: inputUnavailable")
    let internalFailure = try customReport(internalFailure: true)
    XCTAssertEqual(try invocation(runs(internalFailure)[0])["executionSuccessful"] as? Bool, false)
  }

  func testGoldensAndEquivalentResultMeaning() throws {
    for kind in Kind.allCases {
      let report = try makeReport(kind)
      let output = try ReportEncoder.encode(report, format: .sarif)
      let name: String
      switch kind {
      case .native: name = "native"
      case .unavailable: name = "external-unavailable"
      case .failure: name = "external-failure"
      }
      let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("Goldens/\(name)-v1.sarif")
      let goldenBytes = try Data(contentsOf: url)
      XCTAssertEqual(output, goldenBytes, name)
      XCTAssertEqual(output, try ReportEncoder.encode(report, format: .sarif))
      XCTAssertEqual(output.last, 0x0a)
      XCTAssertEqual(output.filter { $0 == 0x0a }.count, 1)
      XCTAssertFalse(output.starts(with: [0xef, 0xbb, 0xbf]))
      let json = try object(ReportEncoder.encode(report, format: .json))
      let native = try runs(report)[0]
      let properties = try XCTUnwrap(native["properties"] as? [String: Any])
      for key in [
        "configuration", "coverage", "validationStatus", "gateDecision", "acceptedIncomplete",
        "exitCode",
      ] {
        let expected =
          key == "coverage" ? omittingNulls(try XCTUnwrap(json[key])) : try XCTUnwrap(json[key])
        XCTAssertEqual(try fragment(properties[key]), try fragment(expected), key)
      }
      let jsonFindings = try XCTUnwrap(json["nativeFindings"] as? [[String: Any]])
      let results = try XCTUnwrap(native["results"] as? [[String: Any]])
      XCTAssertEqual(
        results.map { $0["ruleId"] as? String }, jsonFindings.map { $0["ruleID"] as? String })
      for (result, finding) in zip(results, jsonFindings) {
        XCTAssertEqual(result["level"] as? String, finding["severity"] as? String)
        for key in ["category", "evidence", "provenance"] {
          XCTAssertEqual(
            try fragment((result["properties"] as? [String: Any])?[key]), try fragment(finding[key])
          )
        }
      }
      let jsonSummary = try XCTUnwrap(json["summary"] as? [String: Any])
      XCTAssertEqual(try fragment(properties["counts"]), try fragment(jsonSummary["native"]))
      if kind != .native {
        let checkerRun = try runs(report)[1]
        let checkerProperties = try XCTUnwrap(checkerRun["properties"] as? [String: Any])
        var jsonChecker = try XCTUnwrap(json["externalCheck"] as? [String: Any])
        let checkerFindings = try XCTUnwrap(
          jsonChecker.removeValue(forKey: "findings") as? [[String: Any]])
        XCTAssertEqual(
          try fragment(checkerProperties["externalCheck"]), try fragment(omittingNulls(jsonChecker))
        )
        XCTAssertEqual(
          try fragment(checkerProperties["counts"]), try fragment(jsonSummary["external"]))
        let checkerResults = try XCTUnwrap(checkerRun["results"] as? [[String: Any]])
        XCTAssertEqual(checkerResults.count, checkerFindings.count)
        for (result, finding) in zip(checkerResults, checkerFindings) {
          XCTAssertEqual(result["ruleId"] as? String, finding["ruleID"] as? String)
          XCTAssertEqual(result["level"] as? String, finding["severity"] as? String)
          XCTAssertEqual(
            (result["message"] as? [String: String])?["text"], finding["message"] as? String)
          for key in ["category", "evidence", "provenance"] {
            XCTAssertEqual(
              try fragment((result["properties"] as? [String: Any])?[key]),
              try fragment(finding[key]))
          }
        }
      }
      let text = String(decoding: try ReportEncoder.encode(report, format: .text), as: UTF8.self)
      XCTAssertTrue(text.contains("coverage references: partial"))
      XCTAssertTrue(text.contains("native count warning: 1"))
      XCTAssertTrue(text.contains("gate: fail"))
      XCTAssertTrue(text.contains("exit: \(report.exitCode)"))
      if kind == .failure { XCTAssertTrue(text.contains("external count error: 1")) }
    }
  }

  func testRealArchiveByteLocationsAndLogicalLayerLines() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let payload = Data("#usda 1.0\n@missing.png@".utf8)
    let bytes = try ArchiveRecipe(entries: [
      .init(nameBytes: Data("root.usda".utf8), payload: payload)
    ]).encode()
    func inspect(_ basename: String, directory: URL) throws -> ValidationReport {
      let url = try Fixtures.write(bytes, basename: basename, in: directory)
      let snapshot = try FileSnapshot.open(url)
      defer { try? snapshot.close() }
      let configuration = try ValidationConfiguration()
      let result = try NativeEngine.inspect(snapshot: snapshot, configuration: configuration)
      return ValidationReport(
        input: ReportInput(displayName: url.path, byteSize: Int64(bytes.count)),
        configuration: configuration, coverage: result.coverage, nativeFindings: result.findings)
    }
    let report = try inspect("sp ace#?%.usdz", directory: directory)
    let finding = try XCTUnwrap(report.nativeFindings.first { $0.ruleID == "UVK-PATH-006" })
    let offset = try XCTUnwrap(finding.location?.archiveByteOffset)
    XCTAssertEqual(bytes[Int(offset)], 0x40)
    XCTAssertEqual(finding.location?.line, 2)
    let result = try XCTUnwrap(
      (runs(report)[0]["results"] as? [[String: Any]])?.first {
        $0["ruleId"] as? String == "UVK-PATH-006"
      })
    let location = try XCTUnwrap((result["locations"] as? [[String: Any]])?.first)
    let physical = try XCTUnwrap(location["physicalLocation"] as? [String: Any])
    XCTAssertEqual(
      (physical["artifactLocation"] as? [String: Any])?["uri"] as? String,
      "sp%20ace%23%3F%25.usdz")
    let region = try XCTUnwrap(physical["region"] as? [String: Any])
    XCTAssertEqual(region["byteOffset"] as? UInt64, offset)
    XCTAssertNil(region["startLine"])
    XCTAssertNil(region["startColumn"])
    let logical = try XCTUnwrap((location["logicalLocations"] as? [[String: Any]])?.first)
    XCTAssertEqual((logical["properties"] as? [String: Any])?["line"] as? Int, 2)
    XCTAssertEqual((logical["properties"] as? [String: Any])?["layerByteOffset"] as? Int, 10)
    let moved = directory.appendingPathComponent("moved")
    try FileManager.default.createDirectory(at: moved, withIntermediateDirectories: false)
    let relocated = try inspect("sp ace#?%.usdz", directory: moved)
    XCTAssertEqual(
      try ReportEncoder.encode(report, format: .sarif),
      try ReportEncoder.encode(relocated, format: .sarif))
    let renamed = try inspect("renamed.usdz", directory: directory)
    XCTAssertEqual(report.nativeFindings, renamed.nativeFindings)
    XCTAssertEqual(report.coverage, renamed.coverage)
  }

  func testPrivacyCombiningMarksRelativeURIAndSensitiveOptIn() throws {
    let path = "/\u{0301}Users/fixture-owner/input"
    let prose = "detail=\u{0345}/Users/fixture-owner/input"
    let finding = Finding(
      ruleID: "UVK-PATH-004", occurrenceID: "id", category: .policy, severity: .error,
      message: prose,
      evidence: ["unsafe": .string(path), "safe": .string("Textures/a\u{0345}/b.png")],
      location: FindingLocation(entryName: path, line: 2, column: 1),
      provenance: .native(validatorVersion: "0.1.0"))
    func report(sensitive: Bool) throws -> ValidationReport {
      try customReport(
        findings: [finding],
        external: ExternalCheck(
          requested: true, status: .completed,
          sensitiveDetails: ExternalSensitiveDetails(
            arguments: ["/private/input.usdz"], stdout: String(repeating: "x", count: 5000),
            stderr: "raw\u{001b}error")), sensitive: sensitive,
        displayName: "/private/\u{0301}input.usdz")
    }
    let output = try ReportEncoder.encode(report(sensitive: false), format: .sarif)
    let native = try runs(report(sensitive: false))[0]
    let result = try XCTUnwrap((native["results"] as? [[String: Any]])?.first)
    XCTAssertEqual((result["message"] as? [String: String])?["text"], "[redacted path]")
    let location = try XCTUnwrap((result["locations"] as? [[String: Any]])?.first)
    XCTAssertEqual(
      ((location["physicalLocation"] as? [String: Any])?["artifactLocation"] as? [String: String])?[
        "uri"], "%CC%81input.usdz")
    XCTAssertNil((location["physicalLocation"] as? [String: Any])?["region"])
    XCTAssertEqual(
      ((location["logicalLocations"] as? [[String: Any]])?.first)?["fullyQualifiedName"] as? String,
      "[redacted path]")
    let evidence = try XCTUnwrap(
      (result["properties"] as? [String: Any])?["evidence"] as? [String: String])
    XCTAssertEqual(evidence["unsafe"], "[redacted path]")
    XCTAssertEqual(evidence["safe"], "Textures/a\u{0345}/b.png")
    let text = String(decoding: output, as: UTF8.self)
    for secret in ["fixture-owner", "private/", "raw", "sensitiveDetails", "invocationID"] {
      XCTAssertFalse(text.contains(secret), secret)
    }
    let disclosed = try runs(report(sensitive: true))
    let external = try XCTUnwrap(
      (disclosed[1]["properties"] as? [String: Any])?["externalCheck"] as? [String: Any])
    let details = try XCTUnwrap(external["sensitiveDetails"] as? [String: Any])
    XCTAssertEqual((details["stdout"] as? String)?.utf8.count, 4096)
    XCTAssertTrue((details["stdout"] as? String)?.hasSuffix("[truncated]") == true)
    XCTAssertEqual(details["stderr"] as? String, "raw\\u{001B}error")
    let input = try XCTUnwrap(
      (disclosed[0]["properties"] as? [String: Any])?["input"] as? [String: Any])
    XCTAssertEqual(
      (input["sensitiveDetails"] as? [String: String])?["absolutePath"],
      "/private/\u{0301}input.usdz")
    let sensitiveFailure = try runs(makeReport(.failure, sensitive: true))[1]
    let externalResult = try XCTUnwrap((sensitiveFailure["results"] as? [[String: Any]])?.first)
    XCTAssertEqual(
      (((externalResult["properties"] as? [String: Any])?["provenance"] as? [String: Any])?[
        "sensitiveDetails"] as? [String: String])?["invocationID"], "private-invocation")
    for basename in [".", "..", "C:input.usdz", "a\\b.usdz"] {
      let run = try runs(customReport(displayName: basename))[0]
      let artifact = try XCTUnwrap((run["artifacts"] as? [[String: Any]])?.first)
      let uri = try XCTUnwrap((artifact["location"] as? [String: String])?["uri"])
      XCTAssertFalse(uri.hasPrefix("/"))
      XCTAssertFalse(uri.contains(":"))
      XCTAssertFalse(uri.contains("\\"))
      XCTAssertFalse(uri == "." || uri == "..")
    }
  }

  func testEvidenceCollisionAndReportLimitFailWithoutPartialDocument() throws {
    let collision = Finding(
      ruleID: "UVK-PATH-004", occurrenceID: "id", category: .policy, severity: .error,
      message: "Unsafe paths.", evidence: ["/private/a": .integer(1), "/private/b": .integer(2)],
      location: nil, provenance: .native(validatorVersion: "0.1.0"))
    XCTAssertThrowsError(
      try ReportEncoder.encode(customReport(findings: [collision]), format: .sarif)
    ) {
      XCTAssertEqual($0 as? ValidationError, .operational(.reportEncodingFailed))
    }
    let large = Finding(
      ruleID: "UVK-PATH-004", occurrenceID: "id", category: .policy, severity: .error,
      message: String(repeating: "é", count: 1024),
      evidence: ["detail": .string(String(repeating: "\"", count: 4096))], location: nil,
      provenance: .native(validatorVersion: "0.1.0"))
    let result = try XCTUnwrap(
      (runs(customReport(findings: [large]))[0]["results"] as? [[String: Any]])?.first)
    let message = try XCTUnwrap((result["message"] as? [String: String])?["text"])
    XCTAssertLessThanOrEqual(message.utf8.count, 1024)
    XCTAssertTrue(message.hasSuffix("[truncated]"))
    XCTAssertThrowsError(
      try ReportEncoder.encode(
        customReport(findings: Array(repeating: large, count: 4200)), format: .sarif)
    ) {
      XCTAssertEqual($0 as? ValidationError, .operational(.reportLimitExceeded))
    }
  }

  func testPackageURIEncodesOriginalBasenameBytes() throws {
    for (name, expected) in [
      ("/private/\u{0301}input.usdz", "%CC%81input.usdz"),
      ("/private/\u{0301}/é.usdz", "%C3%A9.usdz"),
      ("/private/line\nname.usdz", "line%0Aname.usdz"),
      ("/private/tab\tname.usdz", "tab%09name.usdz"),
      ("C:input.usdz", "C%3Ainput.usdz"),
      ("a\\b.usdz", "a%5Cb.usdz"),
      ("/private/a\\b.usdz", "a%5Cb.usdz"),
    ] {
      let native = try runs(customReport(displayName: name))[0]
      let artifact = try XCTUnwrap((native["artifacts"] as? [[String: Any]])?.first)
      XCTAssertEqual((artifact["location"] as? [String: String])?["uri"], expected)
    }
  }

  func testRealMacOSBackslashBasenameIdentifiesPackageAcrossReports() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let bytes = try ArchiveRecipe(entries: [
      .init(nameBytes: Data("root.usda".utf8), payload: Data("#usda 1.0\n@missing.png@".utf8))
    ]).encode()
    let url = directory.appendingPathComponent("a\\b.usdz", isDirectory: false)
    try bytes.write(to: url)
    XCTAssertEqual(url.lastPathComponent, "a\\b.usdz")
    XCTAssertEqual(try Data(contentsOf: url), bytes)
    let snapshot = try FileSnapshot.open(url)
    defer { try? snapshot.close() }
    let configuration = try ValidationConfiguration()
    let inspected = try NativeEngine.inspect(snapshot: snapshot, configuration: configuration)
    let report = ValidationReport(
      input: ReportInput(displayName: url.path, byteSize: Int64(bytes.count)),
      configuration: configuration, coverage: inspected.coverage, nativeFindings: inspected.findings
    )
    let native = try runs(report)[0]
    let artifact = try XCTUnwrap((native["artifacts"] as? [[String: Any]])?.first)
    XCTAssertEqual((artifact["location"] as? [String: String])?["uri"], "a%5Cb.usdz")
    let results = try XCTUnwrap(native["results"] as? [[String: Any]])
    let result = try XCTUnwrap(results.first { $0["ruleId"] as? String == "UVK-PATH-006" })
    let finding = try XCTUnwrap(inspected.findings.first { $0.ruleID == "UVK-PATH-006" })
    let offset = try XCTUnwrap(finding.location?.archiveByteOffset)
    XCTAssertEqual(bytes[Int(offset)], 0x40)
    let location = try XCTUnwrap((result["locations"] as? [[String: Any]])?.first)
    let physical = try XCTUnwrap(location["physicalLocation"] as? [String: Any])
    XCTAssertEqual((physical["artifactLocation"] as? [String: String])?["uri"], "a%5Cb.usdz")
    XCTAssertEqual((physical["region"] as? [String: UInt64])?["byteOffset"], offset)
    let sarifInput = try XCTUnwrap(
      (native["properties"] as? [String: Any])?["input"] as? [String: Any])
    XCTAssertEqual(sarifInput["displayName"] as? String, "a\\\\b.usdz")
    let json = try object(ReportEncoder.encode(report, format: .json))
    XCTAssertEqual((json["input"] as? [String: Any])?["displayName"] as? String, "a\\\\b.usdz")
    let text = String(decoding: try ReportEncoder.encode(report, format: .text), as: UTF8.self)
    XCTAssertTrue(text.contains("input: a\\\\b.usdz\n"))
    for format in ReportFormat.allCases {
      let output = String(decoding: try ReportEncoder.encode(report, format: format), as: UTF8.self)
      XCTAssertFalse(output.contains(directory.path), format.rawValue)
    }
    let distinct = try runs(customReport(displayName: "/private/b.usdz"))[0]
    let distinctArtifact = try XCTUnwrap((distinct["artifacts"] as? [[String: Any]])?.first)
    XCTAssertEqual((distinctArtifact["location"] as? [String: String])?["uri"], "b.usdz")
    XCTAssertNotEqual(
      (artifact["location"] as? [String: String])?["uri"],
      (distinctArtifact["location"] as? [String: String])?["uri"])
  }

  func testAppleProfileLevelsCategoriesAndAcceptedIncompleteMeaning() throws {
    let finding = Finding(
      ruleID: "UVK-LIM-002", occurrenceID: "note-id", category: .validatorLimitation,
      severity: .note, message: "Limited inspection.", evidence: [:], location: nil,
      provenance: .native(validatorVersion: "0.1.0"))
    let coverage = Coverage(areas: [
      .references: CoverageAreaResult(requested: true, state: .partial, reasons: [])
    ])
    let report = ValidationReport(
      input: ReportInput(displayName: "input.usdz", byteSize: nil),
      configuration: try ValidationConfiguration(
        profile: .applePortableV1, budgets: WarningBudgets(textureMaxDimension: nil),
        gatePolicy: GatePolicy(allowIncomplete: true)), coverage: coverage,
      nativeFindings: [finding])
    let native = try runs(report)[0]
    let driver = try XCTUnwrap((native["tool"] as? [String: Any])?["driver"] as? [String: Any])
    let rules = try XCTUnwrap(driver["rules"] as? [[String: Any]])
    XCTAssertEqual(rules.count, 32)
    XCTAssertEqual(rules.first?["id"] as? String, "UVK-APL-001")
    XCTAssertEqual(
      (rules.first?["properties"] as? [String: String])?["category"], "appleCompatibility")
    let result = try XCTUnwrap((native["results"] as? [[String: Any]])?.first)
    XCTAssertEqual(result["level"] as? String, "note")
    XCTAssertNil(result["locations"])
    let properties = try XCTUnwrap(native["properties"] as? [String: Any])
    XCTAssertEqual(properties["acceptedIncomplete"] as? Bool, true)
    XCTAssertEqual(properties["validationStatus"] as? String, "incomplete")
    XCTAssertEqual(properties["gateDecision"] as? String, "pass")
    XCTAssertEqual(properties["exitCode"] as? Int, 0)
    XCTAssertEqual((properties["coverage"] as? [String: Any])?["isComplete"] as? Bool, false)
    XCTAssertNil((properties["input"] as? [String: Any])?["byteSize"])
    let configuration = try XCTUnwrap(properties["configuration"] as? [String: Any])
    XCTAssertEqual(configuration["profile"] as? String, "apple-portable-v1")
    XCTAssertTrue((configuration["budgets"] as? [String: Any])?["textureMaxDimension"] is NSNull)
    XCTAssertEqual(try invocation(native)["executionSuccessful"] as? Bool, true)
  }

  private enum Kind: CaseIterable { case native, unavailable, failure }
  private let nativeID = "c9dce5d1e8d7ef85ae24d92062192f27535322e1aca4d933944d3115222579b4"

  private func makeReport(_ kind: Kind, sensitive: Bool = false) throws -> ValidationReport {
    let location = FindingLocation(
      entryName: "root.usdc", archiveByteOffset: 64, layerByteOffset: 0)
    let finding = Finding(
      ruleID: "UVK-LIM-002", occurrenceID: nativeID, category: .validatorLimitation,
      severity: .warning, message: "Native reference inspection is unavailable for binary USD.",
      evidence: [
        "binary": .boolean(true), "bytes": .integer(8), "reason": .string("binaryReferences"),
        "unknown": .null,
      ], location: location, provenance: .native(validatorVersion: "0.1.0"))
    let externalFinding = Finding(
      ruleID: "USDCK-001", occurrenceID: "external-occurrence", category: .appleCompatibility,
      severity: .error, message: "Checker reported failure.", evidence: [:], location: nil,
      provenance: .usdchecker(
        tool: "usdchecker", version: "Apple USD Tools (0.25.11)", invocationID: "private-invocation"
      ))
    var areas: [CoverageArea: CoverageAreaResult] = [:]
    for area in CoverageArea.allCases {
      areas[area] = CoverageAreaResult(
        requested: area != .appleAdvice, state: area == .appleAdvice ? .notRun : .complete,
        reasons: [])
    }
    areas[.references] = CoverageAreaResult(
      requested: true, state: .partial,
      reasons: [
        CoverageReason(ruleID: "UVK-LIM-002", reasonID: "binaryReferences", location: location)
      ])
    let external: ExternalCheck
    switch kind {
    case .native: external = .notRequested
    case .unavailable:
      external = ExternalCheck(
        requested: true, phase: .versionProbe, availability: .unavailable, policy: .general,
        status: .unavailable)
    case .failure:
      external = ExternalCheck(
        requested: true, phase: .validation, availability: .available,
        version: "Apple USD Tools (0.25.11)", policy: .general, status: .completed,
        outcome: .failureReported, exitCode: 17, stdoutBytes: 0, stderrBytes: 12, hasStderr: true,
        sensitiveDetails: ExternalSensitiveDetails(
          arguments: ["/usr/bin/usdchecker"], stdout: "", stderr: "raw tool text"),
        findings: [externalFinding])
    }
    return ValidationReport(
      input: ReportInput(
        displayName: "/Users/fixture-owner/input.usdz", byteSize: 123,
        sensitiveDetails: InputSensitiveDetails(absolutePath: "/Users/fixture-owner/input.usdz")),
      configuration: try ValidationConfiguration(
        includeSensitiveDetails: sensitive, externalCheck: kind == .native ? .disabled : .usdchecker
      ), coverage: Coverage(areas: areas), nativeFindings: [finding], externalCheck: external)
  }

  private func customReport(
    findings: [Finding] = [], external: ExternalCheck = .notRequested,
    errors: [ValidationError] = [], internalFailure: Bool = false, sensitive: Bool = false,
    displayName: String = "input.usdz"
  ) throws -> ValidationReport {
    ValidationReport(
      input: ReportInput(
        displayName: displayName, byteSize: nil,
        sensitiveDetails: InputSensitiveDetails(absolutePath: displayName)),
      configuration: try ValidationConfiguration(
        includeSensitiveDetails: sensitive,
        externalCheck: external.requested ? .usdchecker : .disabled),
      coverage: Coverage(areas: [:]), nativeFindings: findings, externalCheck: external,
      operationalErrors: errors, internalFailure: internalFailure)
  }

  private func object(_ data: Data) throws -> [String: Any] {
    try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }
  private func runs(_ report: ValidationReport) throws -> [[String: Any]] {
    try XCTUnwrap(object(ReportEncoder.encode(report, format: .sarif))["runs"] as? [[String: Any]])
  }
  private func invocation(_ run: [String: Any]) throws -> [String: Any] {
    try XCTUnwrap((run["invocations"] as? [[String: Any]])?.first)
  }
  private func fragment(_ value: Any?) throws -> Data {
    try JSONSerialization.data(
      withJSONObject: XCTUnwrap(value), options: [.fragmentsAllowed, .sortedKeys])
  }
  private func omittingNulls(_ value: Any) -> Any {
    if let fields = value as? [String: Any] {
      return fields.compactMapValues { $0 is NSNull ? nil : omittingNulls($0) }
    }
    if let values = value as? [Any] { return values.map(omittingNulls) }
    return value
  }
}

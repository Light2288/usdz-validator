import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

final class USDCReportTests: XCTestCase {
  // Flattening shared bodies, inventing offsets, or leaking authored values breaks this boundary.
  func testBinaryIdentityLocationsAndSeparateExternalRun() throws {
    let report = try Self.fixedReport("duplicates")
    XCTAssertEqual(
      report.nativeFindings.map(\.occurrenceID),
      [
        "5398f4182331ac6b1a6c0989e4c2b1a890b101524c4fe3c24fd5720c4bb4a352",
        "b55784978fdd8273a72795e54dc6ff45f49fe6fb88ff49dbce096b08ffb14b44",
      ])
    XCTAssertEqual(report.nativeFindings.map(\.category), [.policy, .policy])
    for format: ReportFormat in [.json, .sarif] {
      let bytes = try ReportEncoder.encode(report, format: format)
      XCTAssertEqual(bytes, try ReportEncoder.encode(report, format: format))
      let text = String(decoding: bytes, as: UTF8.self)
      for secret in ["authored-private-value", "private-owner", "authored-key", "scene-path"] {
        XCTAssertFalse(text.contains(secret), secret)
      }
      let document = try object(bytes)
      if format == .sarif {
        let run = try XCTUnwrap((document["runs"] as? [[String: Any]])?.first)
        for result in try XCTUnwrap(run["results"] as? [[String: Any]]) {
          let location = try XCTUnwrap((result["locations"] as? [[String: Any]])?.first)
          XCTAssertNil((location["physicalLocation"] as? [String: Any])?["region"])
          let logical = try XCTUnwrap((location["logicalLocations"] as? [[String: Any]])?.first)
          XCTAssertEqual(logical["fullyQualifiedName"] as? String, "root.usdc")
          XCTAssertNil(logical["properties"])
        }
      } else {
        for finding in try XCTUnwrap(document["nativeFindings"] as? [[String: Any]]) {
          let location = try XCTUnwrap(finding["location"] as? [String: Any])
          for key in ["archiveByteOffset", "layerByteOffset", "line", "column"] {
            XCTAssertTrue(location[key] is NSNull, key)
          }
        }
      }
    }
    let external = ExternalCheck(
      requested: true, phase: .validation, availability: .available, version: "test-checker",
      policy: .general, status: .completed, outcome: .noFailureReported, exitCode: 0)
    let separate = try Self.fixedReport("partial", external: external)
    let runs = try XCTUnwrap(
      try object(ReportEncoder.encode(separate, format: .sarif))["runs"] as? [[String: Any]])
    XCTAssertEqual(runs.count, 2)
    XCTAssertEqual((runs[0]["results"] as? [Any])?.count, 2)
    XCTAssertEqual((runs[1]["results"] as? [Any])?.count, 0)
    XCTAssertFalse(separate.coverage.isComplete)
    XCTAssertEqual(separate.exitCode, 2)
  }

  // Accepting a gap may relax completeness but may never erase errors or the fail-on gate.
  func testProfilesAllowIncompleteAndFailOnRemainIndependent() throws {
    for profile: Profile in [.generalV1, .applePortableV1] {
      for failOn: FailureThreshold in [.error, .warning] {
        let configuration = try ValidationConfiguration(
          profile: profile, gatePolicy: GatePolicy(failOn: failOn, allowIncomplete: true))
        let partial = try Self.fixedReport("partial", configuration: configuration)
        XCTAssertEqual(partial.nativeFindings.map(\.ruleID), ["UVK-LIM-007", "UVK-LIM-007"])
        XCTAssertTrue(partial.nativeFindings.allSatisfy { $0.category == .validatorLimitation })
        XCTAssertEqual(partial.exitCode, failOn == .error ? 0 : 1)
        XCTAssertEqual(partial.acceptedIncomplete, failOn == .error)
        let malformed = try Self.fixedReport("malformed", configuration: configuration)
        XCTAssertEqual(malformed.nativeFindings.map(\.ruleID), ["UVK-USD-001", "UVK-LIM-002"])
        XCTAssertEqual(malformed.exitCode, 1)
        XCTAssertEqual(malformed.nativeFindings.first?.category, .policy)
        XCTAssertEqual(partial.coverage.areas[.appleAdvice]?.requested, profile == .applePortableV1)
      }
    }
  }

  // The final retained slot must disclose truncation, with repeatable binary IDs and bytes.
  func testBinaryFindingTruncationIsDeterministic() throws {
    let (_, entry) = try Self.package()
    func report() throws -> ValidationReport {
      let diagnostics = NativeDiagnostics()
      for index in 0...10_000 {
        USDCReporting.record(
          issue: USDCIssue(
            failure: .unsupported(.unsupportedValue),
            locator: try USDCReferenceLocator(specIndex: UInt64(index), fieldOrdinal: 0)),
          entry: entry, diagnostics: diagnostics)
      }
      let (findings, coverage) = diagnostics.finish()
      XCTAssertEqual(findings.count, 10_000)
      XCTAssertEqual(findings.filter { $0.ruleID == "UVK-RES-001" }.count, 1)
      XCTAssertEqual(findings.filter { $0.ruleID == "UVK-LIM-007" }.count, 9_999)
      return ValidationReport(
        input: ReportInput(displayName: "input.usdz", byteSize: 123),
        configuration: try ValidationConfiguration(), coverage: coverage, nativeFindings: findings)
    }
    let first = try report()
    let second = try report()
    XCTAssertEqual(first.nativeFindings, second.nativeFindings)
    XCTAssertEqual(
      try ReportEncoder.encode(first, format: .json),
      try ReportEncoder.encode(second, format: .json))
  }

  static func fixedReport(
    _ kind: String, configuration: ValidationConfiguration? = nil,
    external: ExternalCheck = .notRequested
  ) throws -> ValidationReport {
    let configuration =
      try configuration
      ?? ValidationConfiguration(
        externalCheck: external.requested ? .usdchecker : .disabled)
    let (namespace, entry) = try package()
    let diagnostics = NativeDiagnostics(profile: configuration.profile)
    if kind == "partial" {
      USDCReporting.record(
        issue: USDCIssue(
          failure: .unsupported(.unsupportedValue),
          locator: try USDCReferenceLocator(specIndex: 7, fieldOrdinal: 3)),
        entry: entry, diagnostics: diagnostics)
      USDCReporting.record(
        ruleID: "UVK-LIM-007", reason: "partialBinaryReferences",
        message: "Native reference inspection is incomplete for this binary USD layer.",
        locator: nil, entry: entry, diagnostics: diagnostics)
    } else if kind == "malformed" {
      USDCReporting.record(
        issue: USDCIssue(failure: .malformed(.invalidHeader), locator: nil),
        entry: entry, diagnostics: diagnostics)
      USDCReporting.record(
        ruleID: "UVK-LIM-002", reason: "binaryReferences",
        message: "Native reference inspection is unavailable for this binary USD layer.",
        locator: nil, entry: entry, diagnostics: diagnostics)
    } else if kind == "duplicates" {
      for index: UInt64 in [0, 1, 0] {
        ReferenceResolver.check(
          occurrence: ReferenceOccurrence(
            valueBytes: Data("authored-private-value.png".utf8), classification: .literal,
            site: .usdc(
              try USDCReferenceLocator(
                specIndex: 7, fieldOrdinal: 3, steps: [.init(kind: .array, index: index)]))),
          author: entry, namespace: namespace, diagnostics: diagnostics)
      }
    }
    for area in CoverageArea.allCases { diagnostics.complete(area: area) }
    let (findings, coverage) = diagnostics.finish()
    return ValidationReport(
      input: ReportInput(
        displayName: "input.usdz", byteSize: 123,
        sensitiveDetails: InputSensitiveDetails(absolutePath: "/private-owner/input.usdz")),
      configuration: configuration, coverage: coverage, nativeFindings: findings,
      externalCheck: external)
  }

  private static func package() throws -> (PackageNamespace, ZIPEntry) {
    let bytes = try ArchiveRecipe(entries: [
      .init(nameBytes: Data("root.usdc".utf8), payload: Data("PXR-USDC".utf8), flags: 0x0800)
    ]).encode()
    let diagnostics = NativeDiagnostics()
    let reader = BoundedReader(size: UInt64(bytes.count), ledger: ResourceLedger()) {
      offset, count in bytes[Int(offset)..<(Int(offset) + count)]
    }
    let directory = try XCTUnwrap(ZIPDirectory.read(from: reader, diagnostics: diagnostics))
    let index = try XCTUnwrap(
      ZIPIndex.build(directory: directory, reader: reader, diagnostics: diagnostics))
    let namespace = try XCTUnwrap(PackageNamespace.build(index: index, diagnostics: diagnostics))
    return (namespace, try XCTUnwrap(namespace.defaultEntry))
  }

  private func object(_ bytes: Data) throws -> [String: Any] {
    try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
  }
}

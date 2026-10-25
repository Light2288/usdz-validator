import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

final class USDCReportingTests: XCTestCase {
  func testSharedBinaryBodiesKeepDistinctSitesAndOmitInventedRegions() throws {
    let (namespace, entry) = try package()
    let diagnostics = NativeDiagnostics()
    let locators = try [0, 1, 0].map {
      try USDCReferenceLocator(
        specIndex: 7, fieldOrdinal: 3, steps: [.init(kind: .array, index: UInt64($0))])
    }
    for locator in locators {
      ReferenceResolver.check(
        occurrence: ReferenceOccurrence(
          valueBytes: Data("privacy-sentinel-missing.png".utf8), classification: .literal,
          site: .usdc(locator)), author: entry, namespace: namespace, diagnostics: diagnostics)
    }
    let (findings, coverage) = diagnostics.finish()
    XCTAssertEqual(findings.count, 2)
    XCTAssertEqual(
      Set(findings.map(\.occurrenceID)),
      [
        "5398f4182331ac6b1a6c0989e4c2b1a890b101524c4fe3c24fd5720c4bb4a352",
        "b55784978fdd8273a72795e54dc6ff45f49fe6fb88ff49dbce096b08ffb14b44",
      ])
    for finding in findings {
      XCTAssertEqual(finding.location?.entryName, "root.usdc")
      XCTAssertNil(finding.location?.archiveByteOffset)
      XCTAssertNil(finding.location?.layerByteOffset)
      XCTAssertNil(finding.location?.line)
      XCTAssertNil(finding.location?.column)
      XCTAssertEqual(finding.evidence, ["reason": .string("missingTarget")])
    }
    XCTAssertEqual(coverage.areas[.references]?.state, .partial)
    for input in ["/private/first.usdz", "/different/renamed.usdz"] {
      let report = ValidationReport(
        input: ReportInput(displayName: input, byteSize: nil),
        configuration: try ValidationConfiguration(), coverage: coverage, nativeFindings: findings)
      for format: ReportFormat in [.json, .sarif] {
        let data = try ReportEncoder.encode(report, format: format)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("privacy-sentinel"))
        for finding in findings { XCTAssertTrue(text.contains(finding.occurrenceID)) }
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        if format == .json {
          let records = try XCTUnwrap(document["nativeFindings"] as? [[String: Any]])
          for record in records {
            let location = try XCTUnwrap(record["location"] as? [String: Any])
            for coordinate in ["archiveByteOffset", "layerByteOffset", "line", "column"] {
              XCTAssertTrue(location[coordinate] is NSNull, coordinate)
            }
          }
        } else {
          XCTAssertFalse(text.contains("layerByteOffset"))
          let run = try XCTUnwrap((document["runs"] as? [[String: Any]])?.first)
          let results = try XCTUnwrap(run["results"] as? [[String: Any]])
          for result in results {
            let location = try XCTUnwrap((result["locations"] as? [[String: Any]])?.first)
            let physical = location["physicalLocation"] as? [String: Any]
            XCTAssertNil(physical?["region"])
          }
        }
      }
    }
  }

  func testUnsupportedAndMalformedIssuesHaveDistinctPoliciesAndSafeEvidence() throws {
    let (_, entry) = try package()
    let cases: [(USDCFailure, String, String, FindingCategory, Severity)] = [
      (
        .unsupported(.unsupportedVersion), "unsupportedVersion", "UVK-LIM-007",
        .validatorLimitation, .warning
      ),
      (
        .unsupported(.unsupportedSection), "unsupportedSection", "UVK-LIM-007",
        .validatorLimitation, .warning
      ),
      (
        .unsupported(.unsupportedEncoding), "unsupportedEncoding", "UVK-LIM-007",
        .validatorLimitation, .warning
      ),
      (
        .unsupported(.unsupportedValue), "unsupportedValue", "UVK-LIM-007", .validatorLimitation,
        .warning
      ),
      (.malformed(.invalidRange), "invalidRange", "UVK-USD-001", .policy, .error),
      (.malformed(.invalidHeader), "invalidHeader", "UVK-USD-001", .policy, .error),
      (.malformed(.invalidSection), "invalidSection", "UVK-USD-001", .policy, .error),
      (.malformed(.invalidCompression), "invalidCompression", "UVK-USD-001", .policy, .error),
      (.malformed(.invalidTable), "invalidTable", "UVK-USD-001", .policy, .error),
      (.malformed(.invalidIndex), "invalidIndex", "UVK-USD-001", .policy, .error),
      (.malformed(.invalidValue), "invalidValue", "UVK-USD-001", .policy, .error),
      (.malformed(.invalidPath), "invalidPath", "UVK-USD-001", .policy, .error),
      (.malformed(.invalidGraph), "invalidGraph", "UVK-USD-001", .policy, .error),
    ]
    for (failure, reason, rule, category, severity) in cases {
      for locator in [nil, try USDCReferenceLocator(specIndex: 9, fieldOrdinal: 2)] {
        let diagnostics = NativeDiagnostics()
        USDCReporting.record(
          issue: USDCIssue(failure: failure, locator: locator), entry: entry,
          diagnostics: diagnostics)
        let (findings, coverage) = diagnostics.finish()
        let finding = try XCTUnwrap(findings.first)
        XCTAssertEqual(findings.count, 1)
        XCTAssertEqual(finding.ruleID, rule)
        XCTAssertEqual(finding.category, category)
        XCTAssertEqual(finding.severity, severity)
        XCTAssertEqual(finding.evidence, ["reason": .string(reason)])
        XCTAssertNil(finding.location?.archiveByteOffset)
        XCTAssertNil(finding.location?.layerByteOffset)
        XCTAssertNil(finding.location?.line)
        XCTAssertNil(finding.location?.column)
        XCTAssertEqual(coverage.areas[.references]?.state, .partial)
        XCTAssertEqual(coverage.areas[.references]?.reasons.first?.reasonID, reason)
        XCTAssertEqual(coverage.areas[.references]?.reasons.first?.location, finding.location)
      }
    }
  }

  func testLocatorCapacityFitsAllCoordinatesAtMaximumValueDepth() throws {
    // Three coordinates per value level accommodate bucket/item and customData sites.
    let kinds: [USDCReferenceLocator.Kind] = [
      .array, .dictionary, .listBucket, .listItem, .sample, .wrapper, .referenceCustomData,
    ]
    let steps = (0..<96).map {
      USDCReferenceLocator.Step(kind: kinds[$0 % kinds.count], index: .max)
    }
    let locator = try USDCReferenceLocator(specIndex: .max, fieldOrdinal: .max, steps: steps)
    let discriminator = locator.discriminator(reason: "unsupportedReference")
    XCTAssertLessThan(discriminator.utf8.count, 4_096)
    XCTAssertTrue(discriminator.utf8.allSatisfy { $0 < 0x80 })
    XCTAssertEqual(locator.steps.count, 96)
    XCTAssertThrowsError(
      try USDCReferenceLocator(
        specIndex: 0, fieldOrdinal: 0, steps: steps + [.init(kind: .array, index: 0)])
    ) { error in
      XCTAssertEqual(error as? InspectionFailure, .resourceLimit(.usdcDepth))
    }
    let diagnostics = NativeDiagnostics()
    let (_, entry) = try package()
    USDCReporting.record(
      issue: USDCIssue(failure: .unsupported(.unsupportedValue), locator: locator),
      entry: entry, diagnostics: diagnostics)
    XCTAssertEqual(diagnostics.finish().0.map(\.ruleID), ["UVK-LIM-007"])
  }

  func testSharedClassifierPreservesByteSyntaxBoundaries() {
    for value in [
      "a`b", "a[b", "a]b", "${ROOT}", "a.<UDIM>", "a.<UVTILE>", "a.####", "a.%04d", "a.%d",
      "resolver:thing",
    ] {
      XCTAssertEqual(ReferenceClassifier.classify(Data(value.utf8)), .unsupportedExpression, value)
    }
    for value in ["", "asset.png", "a.%04s", "a.%", "a.$ROOT", "C:relative", "c:/asset", "a\\@@@b"]
    {
      XCTAssertEqual(ReferenceClassifier.classify(Data(value.utf8)), .literal, value)
    }
    XCTAssertEqual(ReferenceClassifier.classify(Data([0xff, 0xfe])), .literal)
  }

  private func package() throws -> (PackageNamespace, ZIPEntry) {
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
}

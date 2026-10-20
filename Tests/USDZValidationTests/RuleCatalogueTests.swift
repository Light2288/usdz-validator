import Foundation
import XCTest

@testable import USDZValidation

final class RuleCatalogueTests: XCTestCase {
  func testPermanentDescriptors() throws {
    let apple = RuleCatalogue.descriptors(profile: .applePortableV1)
    let general = RuleCatalogue.descriptors(profile: .generalV1)
    let expected: [(String, FindingCategory, Severity, RuleFamily?)] = [
      ("UVK-APL-001", .appleCompatibility, .warning, .container),
      ("UVK-APL-002", .appleCompatibility, .warning, .budgets),
      ("UVK-ARC-001", .archiveSpecification, .error, .container),
      ("UVK-ARC-002", .archiveSpecification, .error, .container),
      ("UVK-ARC-003", .archiveSpecification, .error, .container),
      ("UVK-ARC-004", .archiveSpecification, .error, .container),
      ("UVK-ARC-005", .archiveSpecification, .error, .container),
      ("UVK-ARC-006", .archiveSpecification, .error, .container),
      ("UVK-ARC-007", .archiveSpecification, .error, .container),
      ("UVK-BUD-001", .policy, .warning, .budgets),
      ("UVK-BUD-002", .policy, .warning, .budgets),
      ("UVK-BUD-003", .policy, .warning, .budgets),
      ("UVK-BUD-004", .policy, .warning, .budgets),
      ("UVK-BUD-005", .policy, .warning, .budgets),
      ("UVK-BUD-006", .policy, .warning, .budgets),
      ("UVK-BUD-007", .policy, .error, .budgets),
      ("UVK-LIM-001", .validatorLimitation, .warning, .container),
      ("UVK-LIM-002", .validatorLimitation, .warning, .references),
      ("UVK-LIM-003", .validatorLimitation, .warning, .references),
      ("UVK-LIM-004", .validatorLimitation, .warning, .references),
      ("UVK-LIM-005", .validatorLimitation, .warning, .budgets),
      ("UVK-LIM-006", .validatorLimitation, .warning, .container),
      ("UVK-PATH-001", .policy, .error, .references),
      ("UVK-PATH-002", .policy, .error, .references),
      ("UVK-PATH-003", .policy, .error, .references),
      ("UVK-PATH-004", .policy, .error, .references),
      ("UVK-PATH-005", .policy, .error, .references),
      ("UVK-PATH-006", .policy, .error, .references),
      ("UVK-PATH-007", .policy, .error, .references),
      ("UVK-POL-001", .policy, .error, .container),
      ("UVK-POL-002", .policy, .error, .container),
      ("UVK-RES-001", .policy, .error, nil),
    ]
    XCTAssertEqual(apple.map(\.ruleID), expected.map { $0.0 })
    XCTAssertEqual(Set(apple.map(\.ruleID)).count, 32)
    XCTAssertEqual(general.map(\.ruleID), expected.dropFirst(2).map { $0.0 })
    for (rule, category, severity, family) in expected {
      let descriptor = try XCTUnwrap(apple.first { $0.ruleID == rule })
      XCTAssertEqual(descriptor.category, category, rule)
      XCTAssertEqual(descriptor.defaultSeverity, severity, rule)
      XCTAssertEqual(descriptor.family, family, rule)
      XCTAssertFalse(descriptor.title.isEmpty, rule)
      XCTAssertFalse(descriptor.description.isEmpty, rule)
      XCTAssertFalse(descriptor.applicability.isEmpty, rule)
      XCTAssertFalse(descriptor.rationale.isEmpty, rule)
    }
    XCTAssertFalse(general.contains { $0.category == .appleCompatibility })
    XCTAssertEqual(
      apple.filter { $0.category == .appleCompatibility }.map(\.defaultSeverity),
      [.warning, .warning])
  }

  func testCatalogueGoldenPinsPublishedMeanings() throws {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent("Goldens/rule-catalogue-v1.json")
    let golden = try JSONDecoder().decode(CatalogueGolden.self, from: Data(contentsOf: url))
    XCTAssertEqual(golden.schemaVersion, 1)
    let actual = RuleCatalogue.descriptors(profile: .applePortableV1).map { descriptor in
      GoldenDescriptor(
        ruleID: descriptor.ruleID, family: descriptor.family?.rawValue,
        category: descriptor.category.rawValue,
        defaultSeverity: descriptor.defaultSeverity.rawValue,
        title: descriptor.title, description: descriptor.description,
        applicability: descriptor.applicability, rationale: descriptor.rationale)
    }
    XCTAssertEqual(actual, golden.rules)
  }
}

private struct CatalogueGolden: Decodable {
  let schemaVersion: Int
  let rules: [GoldenDescriptor]
}

private struct GoldenDescriptor: Decodable, Equatable {
  let ruleID: String
  let family: String?
  let category: String
  let defaultSeverity: String
  let title: String
  let description: String
  let applicability: String
  let rationale: String
}

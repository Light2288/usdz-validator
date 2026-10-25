import Foundation
import XCTest

@testable import USDZValidation

final class FindingIdentityTests: XCTestCase {
  func testSharedValueIdentityVectors() throws {
    // Independent Python hashlib/struct v1 tuple vectors; content offsets are absent.
    let first = try USDCReferenceLocator(
      specIndex: 7, fieldOrdinal: 3, steps: [.init(kind: .array, index: 0)])
    let second = try USDCReferenceLocator(
      specIndex: 7, fieldOrdinal: 3, steps: [.init(kind: .array, index: 1)])
    XCTAssertEqual(
      first.discriminator(reason: "missingTarget"), "missingTarget|usdc-v1|s:7|f:3|0:0")
    XCTAssertEqual(
      second.discriminator(reason: "missingTarget"), "missingTarget|usdc-v1|s:7|f:3|0:1")
    func identity(_ locator: USDCReferenceLocator) -> String {
      FindingIdentity.native(
        FindingKey(
          ruleID: "UVK-PATH-006", entryNameBytes: Data("root.usdc".utf8), entryOffset: 0,
          contentOffset: nil, discriminator: locator.discriminator(reason: "missingTarget")))
    }
    let firstID = identity(first)
    let secondID = identity(second)
    XCTAssertNotEqual(firstID, secondID)
    XCTAssertEqual(firstID, "5398f4182331ac6b1a6c0989e4c2b1a890b101524c4fe3c24fd5720c4bb4a352")
    XCTAssertEqual(secondID, "b55784978fdd8273a72795e54dc6ff45f49fe6fb88ff49dbce096b08ffb14b44")
  }

  func testLengthDelimitedIdentityAndExclusions() {
    // Literal vectors were independently calculated with Python hashlib/struct, not product code.
    let originalKey = FindingKey(
      ruleID: "UVK-PATH-006", entryNameBytes: Data("root.usda".utf8), entryOffset: 64,
      contentOffset: 123, discriminator: "asset-path")
    let relocatedKey = FindingKey(
      ruleID: "UVK-PATH-006", entryNameBytes: Data("root.usda".utf8), entryOffset: 64,
      contentOffset: 123, discriminator: "asset-path")
    let otherTokenKey = FindingKey(
      ruleID: "UVK-PATH-006", entryNameBytes: Data("root.usda".utf8), entryOffset: 64,
      contentOffset: 124, discriminator: "asset-path")
    XCTAssertEqual(
      FindingIdentity.native(originalKey),
      "206c71a529cec05d5c0ca1e88faf4bb12fa0ec7871d08412e4e29eb95d85546e")
    XCTAssertEqual(FindingIdentity.native(originalKey), FindingIdentity.native(relocatedKey))
    XCTAssertNotEqual(FindingIdentity.native(originalKey), FindingIdentity.native(otherTokenKey))
    XCTAssertNotEqual(
      FindingIdentity.native(originalKey),
      FindingIdentity.native(
        .init(
          ruleID: "UVK-PATH-006", entryNameBytes: Data("root.usda".utf8), entryOffset: 128,
          contentOffset: 123, discriminator: "asset-path")))

    let vectors: [(FindingKey, String)] = [
      (
        .init(
          ruleID: "ab", entryNameBytes: Data("c".utf8), entryOffset: nil,
          contentOffset: nil, discriminator: ""),
        "979e0d8e12ae3abddc39799b0002b38b55d4a2170554dbed59948e7ddb412a01"
      ),
      (
        .init(
          ruleID: "a", entryNameBytes: Data("bc".utf8), entryOffset: nil,
          contentOffset: nil, discriminator: ""),
        "f128b76c18107b5cfbd13cdee476524c283590be8faf433482e5324cc9f9d608"
      ),
      (
        .init(
          ruleID: "UVK-ARC-001", entryNameBytes: nil, entryOffset: nil,
          contentOffset: nil, discriminator: ""),
        "becfddb369af6e6506fe235f4e11f962bc4e54696bbbb4d83377fd4728f2c89b"
      ),
      (
        .init(
          ruleID: "UVK-ARC-001", entryNameBytes: Data(), entryOffset: nil,
          contentOffset: nil, discriminator: ""),
        "e3cc60dbe3cf1d38cf4c0ff15176b6c677a15bdbd41d0be12b64a3acd289abb6"
      ),
      (
        .init(
          ruleID: "UVK-ARC-001", entryNameBytes: Data([0xff, 0, 0x41]), entryOffset: .max,
          contentOffset: 0, discriminator: "range"),
        "0b7e945bcf3bb575d5b7c5695e76470e21dca6b54bb6d771be4be8dd45868867"
      ),
    ]
    for (key, expected) in vectors {
      XCTAssertEqual(FindingIdentity.native(key), expected)
    }
    XCTAssertNotEqual(FindingIdentity.native(vectors[0].0), FindingIdentity.native(vectors[1].0))
    XCTAssertNotEqual(FindingIdentity.native(vectors[2].0), FindingIdentity.native(vectors[3].0))
    for offsetKey in [
      FindingKey(
        ruleID: "UVK-ARC-001", entryNameBytes: nil, entryOffset: 0,
        contentOffset: nil, discriminator: ""),
      FindingKey(
        ruleID: "UVK-ARC-001", entryNameBytes: nil, entryOffset: nil,
        contentOffset: 0, discriminator: ""),
    ] {
      XCTAssertNotEqual(FindingIdentity.native(offsetKey), FindingIdentity.native(vectors[2].0))
    }
    XCTAssertNotEqual(
      FindingIdentity.native(originalKey),
      FindingIdentity.native(
        .init(
          ruleID: originalKey.ruleID,
          entryNameBytes: originalKey.entryNameBytes, entryOffset: originalKey.entryOffset,
          contentOffset: originalKey.contentOffset, discriminator: "another-check")))

    // Input basename, prose, display redaction, severity and thresholds belong to reports, not keys.
    let original = finding(
      key: originalKey, id: FindingIdentity.native(originalKey),
      message: "asset.usdz: original wording", threshold: 10, displayName: "root.usda")
    let renamed = finding(
      key: relocatedKey, id: FindingIdentity.native(relocatedKey),
      message: "renamed.usdz: revised wording", threshold: 20, displayName: "[redacted]")
    XCTAssertNotEqual(original.message, renamed.message)
    XCTAssertNotEqual(original.evidence, renamed.evidence)
    XCTAssertEqual(original.occurrenceID, renamed.occurrenceID)
  }

  func testExternalIdentityVectors() {
    let version = "Apple USD Tools (0.25.11)"
    let failed = FindingIdentity.external(
      toolVersion: version, ruleID: "USDCK-001", outcome: "failureReported")
    XCTAssertEqual(failed, "be443812e7c3baf9fffaa43e1d5ac4f7367768fffc34382bf68c06c7a1fa8f0e")
    XCTAssertEqual(
      FindingIdentity.external(
        toolVersion: version, ruleID: "USDCK-001", outcome: "noFailureReported"),
      "c89b4a2a2ce6506e42e0eb64b6bd1b92c472d9b147a2048f5dd97d58d5839183")
    XCTAssertNotEqual(
      failed,
      FindingIdentity.external(
        toolVersion: version + " ", ruleID: "USDCK-001", outcome: "failureReported"))
    XCTAssertNotEqual(
      failed,
      FindingIdentity.external(
        toolVersion: version, ruleID: "USDCK-002", outcome: "failureReported"))
    XCTAssertNotEqual(
      failed,
      FindingIdentity.external(
        toolVersion: version, ruleID: "USDCK-001", outcome: "noFailureReported"))
  }

  func testByteAndCategoryOrder() {
    let categories: [(FindingCategory, String)] = [
      (.validatorLimitation, "limitation"), (.policy, "policy"),
      (.appleCompatibility, "apple"), (.archiveSpecification, "archive"),
    ]
    let categoryRecords = categories.map { category, id in
      record(id, category: category)
    }
    XCTAssertEqual(
      FindingOrder.sorted(categoryRecords).map(\.occurrenceID),
      ["archive", "apple", "policy", "limitation"])

    let records = [
      record("last-rule", rule: "UVK-PATH-007"),
      record("composed", name: Data("\u{00e9}".utf8)),
      record("decomposed", name: Data("e\u{0301}".utf8)),
      record("lower", name: Data("a".utf8)),
      record("upper-ten", name: Data("A".utf8), entry: 10),
      record("upper-two-ten", name: Data("A".utf8), entry: 2, content: 10),
      record("upper-two-two", name: Data("A".utf8), entry: 2, content: 2),
      record("upper-two-nil", name: Data("A".utf8), entry: 2),
      record("upper-nil", name: Data("A".utf8)),
      record("empty", name: Data()),
      record("missing"),
      record("first-rule", rule: "UVK-PATH-005", name: Data([0xff])),
    ]
    let expected = [
      "first-rule", "missing", "empty", "upper-nil", "upper-two-nil",
      "upper-two-two", "upper-two-ten", "upper-ten", "lower", "decomposed", "composed", "last-rule",
    ]
    XCTAssertEqual(FindingOrder.sorted(records).map(\.occurrenceID), expected)
    XCTAssertEqual(FindingOrder.sorted(records.reversed()).map(\.occurrenceID), expected)

    // Display names are deliberately identical. Only the retained raw keys determine the order.
    let ties = [record("z", discriminator: "second"), record("a", discriminator: "first")]
    XCTAssertEqual(FindingOrder.sorted(ties).map(\.occurrenceID), ["a", "z"])
  }

  func testRawIdentityDoesNotNormalizeUnicode() {
    let first = record("one", name: Data("e\u{0301}".utf8))
    let second = record("two", name: Data("\u{00e9}".utf8))
    XCTAssertEqual(FindingOrder.sorted([second, first]).map(\.occurrenceID), ["one", "two"])
    XCTAssertNotEqual(FindingIdentity.native(first.key), FindingIdentity.native(second.key))
    let distinctDiscriminators = [
      record("one", discriminator: "e\u{0301}"),
      record("two", discriminator: "\u{00e9}"),
    ]
    XCTAssertNotEqual(
      FindingIdentity.native(distinctDiscriminators[0].key),
      FindingIdentity.native(distinctDiscriminators[1].key))
  }

  private func record(
    _ id: String, category: FindingCategory = .policy, rule: String = "UVK-PATH-006",
    name: Data? = nil, entry: UInt64? = nil, content: UInt64? = nil, discriminator: String = ""
  ) -> (finding: Finding, key: FindingKey) {
    let key = FindingKey(
      ruleID: rule, entryNameBytes: name, entryOffset: entry,
      contentOffset: content, discriminator: discriminator)
    return (finding(key: key, id: id, category: category), key)
  }

  private func finding(
    key: FindingKey, id: String, category: FindingCategory = .policy, message: String = "Finding",
    threshold: Int64 = 10, displayName: String = "[redacted]"
  ) -> Finding {
    Finding(
      ruleID: key.ruleID, occurrenceID: id, category: category, severity: .error,
      message: message, evidence: ["threshold": .integer(threshold)],
      location: FindingLocation(entryName: displayName),
      provenance: .native(validatorVersion: "0.1.0"))
  }
}

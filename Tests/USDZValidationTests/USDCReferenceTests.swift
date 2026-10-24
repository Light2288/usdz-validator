import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

final class USDCReferenceTests: XCTestCase {
  // Missing a live bucket/container/variant or deduplicating a value loses this independent corpus.
  func testAll71AuthoredOccurrencesAndSites() throws {
    var count = 0
    for fixture in try USDCFixtures.cases() {
      let result = try Self.scan(fixture.crate)
      XCTAssertEqual(
        result.references.map(\.valueBytes).sorted(by: Self.order),
        fixture.expectedValues.sorted(by: Self.order), fixture.id)
      XCTAssertEqual(
        result.state, fixture.expectedInspectionComplete ? .complete : .partial,
        "\(fixture.id): \(result.issues)")
      XCTAssertEqual(result.issues.isEmpty, fixture.expectedInspectionComplete, fixture.id)
      let input = Self.input(fixture.crate, ledger: ResourceLedger())
      let tables = try USDCTables.read(input: input)
      var fields: [USDCLiveField] = []
      try tables.forEachLiveField { fields.append($0) }
      var actualSites: [String] = []
      for occurrence in result.references {
        guard case .usdc(let locator) = occurrence.site else {
          return XCTFail("binary site required")
        }
        let field = try XCTUnwrap(
          fields.first {
            UInt64($0.specIndex) == locator.specIndex
              && UInt64($0.fieldOrdinal) == locator.fieldOrdinal
          })
        var path: UInt32? = field.pathIndex
        var parts: [String] = []
        while let index = path {
          let element = try tables.pathElement(at: index)
          let token = try tables.withTokenBytes(at: element.tokenIndex) {
            String(decoding: $0, as: UTF8.self)
          }
          parts.append(element.parentIndex == nil ? "/" : (element.isProperty ? "." : "") + token)
          path = element.parentIndex
        }
        let name = try tables.withTokenBytes(at: field.nameTokenIndex) {
          String(decoding: $0, as: UTF8.self)
        }
        actualSites.append(
          parts.reversed().joined(separator: "|") + ":" + name + ":"
            + occurrence.valueBytes.base64EncodedString() + ":"
            + locator.steps.map { "\($0.kind.rawValue):\($0.index)" }.joined(separator: "|"))
      }
      let expectedSites = fixture.metadata.expectedSites.map {
        $0.pathElements.joined(separator: "|") + ":" + $0.field + ":"
          + Data($0.value.utf8).base64EncodedString() + ":"
          + Self.expectedSteps($0, fixtureID: fixture.id)
      }
      XCTAssertEqual(actualSites.sorted(), expectedSites.sorted(), fixture.id)
      count += result.references.count
    }
    XCTAssertEqual(count, 71)
  }

  // Reusing a body must emit both authored sites and release scratch after synchronous callbacks.
  func testSharedValueKeepsDistinctSites() throws {
    let crate = try USDCMutationRecipe.valueCrate(
      reps: [0x800c_0000_0000_0058, 0x800c_0000_0000_0058],
      body: Self.word(2) + Self.word(0, 4) + Self.word(0, 4))
    let ledger = ResourceLedger()
    let result = try Self.scan(crate, ledger: ledger)
    XCTAssertEqual(result.state, .complete)
    XCTAssertEqual(
      result.references.map(\.valueBytes), Array(repeating: Data("a.png".utf8), count: 4))
    let locators = result.references.compactMap {
      if case .usdc(let site) = $0.site { return site.discriminator(reason: "test") }
      return nil
    }
    XCTAssertEqual(Set(locators).count, 4)
    XCTAssertEqual(
      locators,
      [
        "test|usdc-v1|s:0|f:0|0:0", "test|usdc-v1|s:0|f:0|0:1",
        "test|usdc-v1|s:0|f:1|0:0", "test|usdc-v1|s:0|f:1|0:1",
      ])
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
  }

  // An empty literal still consumes the invocation-wide occurrence allowance before a callback.
  func testEmptyAssetsConsumeSharedTokensAndLengthIsCheckedBeforeCopy() throws {
    let empty = try USDCMutationRecipe.valueCrate(reps: [0x400c_0000_0000_0003])
    let ledger = ResourceLedger()
    try ledger.consumeTokens(100_000)
    XCTAssertThrowsError(try Self.scan(empty, ledger: ledger)) {
      XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.tokenCount))
    }
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
    let large = try USDCMutationRecipe.valueCrate(
      reps: [0x400c_0000_0000_0002],
      tokens: ["/", "default", String(repeating: "é", count: 2049), ""])
    XCTAssertThrowsError(try Self.scan(large)) {
      XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.tokenBytes))
    }
  }

  // Failed structural prerequisites cannot certify empty coverage; independent values retain findings.
  func testUninspectedPrerequisitesAndPartialIndependentFields() throws {
    XCTAssertEqual(try Self.scan(Data("PXR-USDC".utf8)).state, .uninspected)
    let result = try Self.scan(
      USDCMutationRecipe.valueCrate(reps: [0x003f_0000_0000_0000, 0x400c_0000_0000_0002]))
    XCTAssertEqual(result.state, .partial)
    XCTAssertEqual(result.references.map(\.valueBytes), [Data("a.png".utf8)])
    XCTAssertEqual(result.issues.map(\.failure), [.unsupported(.unsupportedValue)])
    XCTAssertEqual(try Self.scan(USDCMutationRecipe.valueCrate(reps: [])).state, .complete)
  }

  // Authored dictionary keys are lexicographically ordered by the writer's map.
  // The only multi-key dictionaries on asset sites have clock/texture, scenePaths/texture,
  // or pattern/texture. These literal ordinals come from committed source, not decoding.
  static func expectedSteps(_ site: USDCFixtureSite, fixtureID: String) -> String {
    // crateData.cpp::_FromPayloadListOpValue stores this single explicit external
    // payload as legacy tag47, so the binary structural site has no list coordinates.
    if fixtureID == "baseline/listops", site.pathElements == ["/", "payload_explicit"] {
      return ""
    }
    var result: [String] = []
    var i = 0
    while i < site.container.count {
      switch site.container[i] {
      case .index(let index): result.append("0:\(index)")
      case .key(let key):
        let buckets = [
          "explicit": 0, "added": 1, "prepended": 2, "appended": 3, "deleted": 4, "ordered": 5,
        ]
        if let bucket = buckets[key], i + 1 < site.container.count,
          case .index(let index) = site.container[i + 1]
        {
          result += ["2:\(bucket)", "3:\(index)"]
          i += 1
        } else if key == "sample", i + 1 < site.container.count,
          case .index(let index) = site.container[i + 1]
        {
          result.append("4:\(index)")
          i += 1
        } else if key == "wrapped" {
          result.append("5:0")
        } else if key == "customData" {
          result.append("6:0")
        } else if key == "texture" {
          result.append("1:1")
        } else if ["nested", "inner", "paths"].contains(key) {
          result.append("1:0")
        } else {
          XCTFail("Missing independently authored dictionary ordinal: \(fixtureID) \(key)")
        }
      }
      i += 1
    }
    return result.joined(separator: "|")
  }

  static func scan(_ bytes: Data, ledger: ResourceLedger = ResourceLedger()) throws -> (
    state: USDCScanState, references: [ReferenceOccurrence], issues: [USDCIssue]
  ) {
    let input = input(bytes, ledger: ledger)
    var references: [ReferenceOccurrence] = []
    var issues: [USDCIssue] = []
    let state = try USDCReader.scan(
      entry: input.entry, reader: input.reader, onReference: { references.append($0) },
      onIssue: { issues.append($0) })
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
    return (state, references, issues)
  }
  static func order(_ a: Data, _ b: Data) -> Bool { a.lexicographicallyPrecedes(b) }
  static func word(_ n: UInt64, _ width: Int = 8) -> Data {
    Data((0..<width).map { UInt8(truncatingIfNeeded: n >> ($0 * 8)) })
  }
  static func input(_ bytes: Data, ledger: ResourceLedger) -> USDCInput {
    let size = UInt64(bytes.count)
    let reader = BoundedReader(size: size, ledger: ledger) { offset, count in
      bytes.subdata(in: Int(offset)..<(Int(offset) + count))
    }
    let record = ZIPDirectory.Record(
      nameBytes: Data("root.usdc".utf8), versionMadeBy: 0x0314, versionNeeded: 20, flags: 0,
      method: 0, modificationTime: 0, modificationDate: 0x21, crc32: 0, compressedSize: size,
      uncompressedSize: size, diskNumber: 0, internalAttributes: 0, externalAttributes: 0x81a4_0000,
      localHeaderOffset: 0, centralHeaderOffset: 0)
    return USDCInput(
      entry: ZIPEntry(
        record: record, recordRange: 0..<0, headerRange: 0..<0, payloadRange: 0..<size),
      reader: reader)
  }
}

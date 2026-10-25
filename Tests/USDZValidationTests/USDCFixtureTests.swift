import CryptoKit
import Foundation
import TestSupport
import XCTest

final class USDCFixtureTests: XCTestCase {
  // Losing duplicates, empty literals or a writer's original bytes would weaken later reader tests.
  func testPreservedCorpusHas23CasesAnd71Occurrences() throws {
    let cases = try USDCFixtures.cases()
    XCTAssertEqual(cases.count, 23)
    XCTAssertEqual(cases.reduce(0) { $0 + $1.expectedValues.count }, 71)
    let baseline = cases.filter { $0.id.hasPrefix("baseline/") }
    let newer = cases.filter { $0.id.hasPrefix("version/") }
    XCTAssertEqual(baseline.count, 9)
    XCTAssertEqual(newer.count, 14)
    XCTAssertEqual(baseline.reduce(0) { $0 + $1.expectedValues.count }, 41)
    XCTAssertEqual(newer.reduce(0) { $0 + $1.expectedValues.count }, 30)
    XCTAssertEqual(cases.flatMap(\.expectedValues).filter(\.isEmpty).count, 1)
    XCTAssertEqual(Set(cases.map(\.id)).count, 23)
    struct Observations: Decodable {
      let cases: [Observation]
      struct Observation: Decodable {
        let name: String
        let writer: String
        let newTypeFlags: [String: Int]
      }
    }
    let observations = try JSONDecoder().decode(
      Observations.self,
      from: Data(
        contentsOf:
          USDCFixtures.root.appendingPathComponent("evidence/live-type-observations.json")))
    XCTAssertEqual(observations.cases.count, 14)
    for fixture in cases {
      XCTAssertEqual(Data(fixture.crate.prefix(8)), Data("PXR-USDC".utf8), fixture.id)
      XCTAssertEqual(Array(fixture.crate[8..<11]), fixture.version, fixture.id)
      XCTAssertEqual(
        fixture.version,
        fixture.id.hasPrefix("baseline/")
          ? [0, 8, 0]
          : fixture.id.contains("tc09-") ? [0, 9, 0] : [0, 10, 0])
      if fixture.version == [0, 9, 0] {
        XCTAssertTrue(fixture.metadata.liveTypeEvidence.contains { $0.tag == 56 })
      } else if fixture.version == [0, 10, 0] {
        XCTAssertTrue(fixture.metadata.liveTypeEvidence.contains { $0.tag == 57 })
      }
      if !fixture.id.hasPrefix("baseline/") {
        let parts = fixture.id.split(separator: "/")
        let observation = try XCTUnwrap(
          observations.cases.first {
            $0.name == parts[1] && $0.writer == parts[2]
          })
        let tag = fixture.version == [0, 9, 0] ? "56/" : "57/"
        XCTAssertGreaterThan(
          observation.newTypeFlags.filter { $0.key.hasPrefix(tag) }
            .values.reduce(0, +), 0, fixture.id)
      }
    }
    for name in [
      "tc09-scalars", "tc09-arrays", "tc09-empty", "pe10-mixed",
      "pe10-containers", "pe10-empty", "pe10-asset-expression",
    ] {
      let writers = newer.filter { $0.id.hasPrefix("version/\(name)/") }
      XCTAssertEqual(Set(writers.map { $0.metadata.writer }), ["apple", "openusd"])
      XCTAssertEqual(Set(writers.map { $0.metadata.crateSHA256 }).count, 2)
    }
  }

  // An empty API result must not turn raw unknown metadata into certified complete inspection.
  func testExpectationsAreIndependentAndRawWrapperRemainsPartial() throws {
    let cases = try USDCFixtures.cases()
    struct Oracle: Decodable {
      let cases: [Case]
      struct Case: Decodable {
        let id: String
        let references: [USDCFixtureSite]
      }
    }
    let oracle = try JSONDecoder().decode(
      Oracle.self,
      from: Data(
        contentsOf:
          USDCFixtures.root.appendingPathComponent("evidence/independent-oracle.json")))
    XCTAssertEqual(oracle.cases.count, 23)
    let raw = try XCTUnwrap(cases.first { $0.id == "baseline/unregistered-raw" })
    XCTAssertTrue(raw.expectedValues.isEmpty)
    XCTAssertFalse(raw.expectedInspectionComplete)
    XCTAssertEqual(raw.metadata.rawUnregisteredValues, ["raw-unregistered.png"])
    let wrapped = try XCTUnwrap(cases.first { $0.id == "baseline/unregistered" })
    XCTAssertEqual(wrapped.expectedValues, [Data("wrapped.png".utf8)])
    XCTAssertTrue(wrapped.expectedInspectionComplete)
    XCTAssertEqual(wrapped.metadata.expectedSites.first?.field, "arbitraryMetadata")
    XCTAssertEqual(wrapped.metadata.oracleOmissions, ["ListInfoKeys omits arbitraryMetadata"])
    XCTAssertEqual(raw.metadata.oracleOmissions, wrapped.metadata.oracleOmissions)
    let minimal = try XCTUnwrap(cases.first { $0.id == "baseline/minimal" })
    XCTAssertTrue(
      minimal.metadata.oracleOmissions.contains("GetInfo subLayerOffsets converter TypeError"))
    for fixture in cases {
      XCTAssertEqual(
        fixture.metadata.expectedSites.map { Data($0.value.utf8) }.sorted(by: dataOrder),
        fixture.expectedValues.sorted(by: dataOrder), fixture.id)
      XCTAssertTrue(
        fixture.metadata.expectedSites.allSatisfy {
          !$0.pathElements.isEmpty && !$0.field.isEmpty
        }, fixture.id)
      let corroboration = try XCTUnwrap(oracle.cases.first { $0.id == fixture.id })
      if fixture.id == "baseline/unregistered" {
        XCTAssertTrue(corroboration.references.isEmpty)
      } else {
        XCTAssertEqual(
          corroboration.references.count, fixture.metadata.expectedSites.count, fixture.id)
        for expected in fixture.metadata.expectedSites {
          XCTAssertEqual(
            corroboration.references.filter {
              $0.value == expected.value && $0.pathElements == expected.pathElements
                && $0.field == expected.field && $0.container == expected.container
            }.count, 1, fixture.id)
        }
      }
      let source = try String(
        contentsOf: USDCFixtures.root.appendingPathComponent(fixture.metadata.source),
        encoding: .utf8)
      for evidence in fixture.metadata.liveTypeEvidence {
        XCTAssertTrue(source.contains(evidence.authoredDeclaration), fixture.id)
        XCTAssertFalse(evidence.logicalSite.isEmpty)
        XCTAssertTrue([56, 57].contains(evidence.tag))
      }
      if fixture.id.contains("asset-expression") {
        XCTAssertEqual(fixture.expectedValues, [Data("`\"${TEXTURE}\"`".utf8)])
      }
    }
    let exported = try String(
      contentsOf: USDCFixtures.root.appendingPathComponent(
        "evidence/unregistered.export.usda"), encoding: .utf8)
    XCTAssertTrue(exported.contains("asset nested = @wrapped.png@"))
    let exportedRaw = try String(
      contentsOf: USDCFixtures.root.appendingPathComponent(
        "evidence/unregistered-raw.export.usda"), encoding: .utf8)
    XCTAssertTrue(exportedRaw.contains("arbitraryMetadata = @raw-unregistered.png@"))
  }

  // Pin the archived hashes, so regenerated or header-relabeled crates cannot become positive evidence.
  func testProvenanceAndHashesPreserveOriginalBytes() throws {
    for fixture in try USDCFixtures.cases() {
      XCTAssertEqual(hash(fixture.crate), fixture.metadata.crateSHA256, fixture.id)
      let source = try Data(
        contentsOf: USDCFixtures.root.appendingPathComponent(fixture.metadata.source))
      XCTAssertEqual(hash(source), fixture.metadata.sourceSHA256, fixture.id)
      XCTAssertEqual(fixture.metadata.sourceLicense, "MIT")
      XCTAssertFalse(fixture.metadata.writerVersion.isEmpty)
      XCTAssertFalse(fixture.metadata.arguments.isEmpty)
      XCTAssertFalse(fixture.metadata.arguments.joined().contains("/Users/"))
      XCTAssertEqual(fixture.metadata.expectationOrigin, "authored-source")
      XCTAssertFalse(fixture.metadata.provenanceRecords.isEmpty)
    }
  }

  // Wrong count/length widths make hostile compression fixtures exercise the wrong parser path.
  func testLiteralFrameRecipeHasFixedBytes() throws {
    XCTAssertEqual(USDCMutationRecipe.literalBlock(Data()), Data([0]))
    XCTAssertEqual(
      USDCMutationRecipe.literalBlock(Data([0x61, 0x62, 0x63])),
      Data([0x30, 0x61, 0x62, 0x63]))
    XCTAssertEqual(
      USDCMutationRecipe.literalBlock(Data(repeating: 0x61, count: 15)),
      Data([0xf0, 0]) + Data(repeating: 0x61, count: 15))
    XCTAssertEqual(
      USDCMutationRecipe.literalBlock(Data(repeating: 0x61, count: 270)),
      Data([0xf0, 0xff, 0]) + Data(repeating: 0x61, count: 270))
    XCTAssertEqual(
      try USDCMutationRecipe.literalFrame([Data([0x61, 0x62, 0x63])]),
      Data([0, 0x30, 0x61, 0x62, 0x63]))
    XCTAssertEqual(
      try USDCMutationRecipe.literalFrame([Data([0x61]), Data([0x62, 0x63])]),
      Data([2, 2, 0, 0, 0, 0x10, 0x61, 3, 0, 0, 0, 0x20, 0x62, 0x63]))
    XCTAssertThrowsError(try USDCMutationRecipe.literalFrame([]))
    XCTAssertThrowsError(try USDCMutationRecipe.literalFrame(Array(repeating: Data(), count: 256)))
  }

  func testPatchesRejectOutOfRangeWithoutChangingOriginal() throws {
    let original = Data([1, 2, 3])
    XCTAssertEqual(
      try USDCMutationRecipe.patch(original, at: 1, bytes: Data([9, 8])), Data([1, 9, 8]))
    XCTAssertEqual(try USDCMutationRecipe.patch(original, at: 3, bytes: Data()), original)
    for offset in [-1, 3, Int.max] {
      XCTAssertThrowsError(try USDCMutationRecipe.patch(original, at: offset, bytes: Data([0])))
    }
    XCTAssertEqual(original, Data([1, 2, 3]))
  }

  private func hash(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  private func dataOrder(_ lhs: Data, _ rhs: Data) -> Bool { lhs.lexicographicallyPrecedes(rhs) }
}

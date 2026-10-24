import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

final class USDCValueTypeTests: XCTestCase {
  // Genuine writer versions exercise scalar/array/empty/sample forms without file false positives.
  func testGenuineTimeCodeAndPathExpressionForms() throws {
    for fixture in try USDCFixtures.cases().filter({ $0.id.hasPrefix("version/") }) {
      let result = try USDCReferenceTests.scan(fixture.crate)
      XCTAssertEqual(result.state, .complete, fixture.id)
      XCTAssertEqual(
        result.references.map(\.valueBytes).sorted(by: USDCReferenceTests.order),
        fixture.expectedValues.sorted(by: USDCReferenceTests.order), fixture.id)
    }
  }

  // Unproved flag combinations or a new type under an older version cannot be silently skipped.
  func testUnknownFlagsAndVersionFloorsRemainGaps() throws {
    for rep: UInt64 in [
      0x200c_0000_0000_0058, 0xc00c_0000_0000_0000, 0x401f_0000_0000_0001, 0x4038_0000_0000_0000,
      0xa039_0000_0000_0000, 0x8001_0000_0000_0000 | (1 << 56), 0x0038_0000_0000_0058,
      0x0039_0000_0000_0058, 0x003a_0000_0000_0058,
    ] {
      let result = try USDCReferenceTests.scan(
        USDCMutationRecipe.valueCrate(reps: [rep], body: Data(repeating: 0, count: 16)))
      XCTAssertEqual(result.state, .partial, String(rep, radix: 16))
      XCTAssertFalse(result.issues.isEmpty)
    }
  }

  // Clip template strings require path semantics even though ordinary string values are harmless.
  func testClipTemplateStringCannotCertifyCoverage() throws {
    for value in ["clips.###.usd", ""] {
      let bytes = try USDCMutationRecipe.valueCrate(
        reps: [0x400a_0000_0000_0000], tokens: ["/", "templateAssetPath", value], strings: [2])
      let result = try USDCReferenceTests.scan(bytes)
      XCTAssertEqual(result.issues.isEmpty, value.isEmpty)
      XCTAssertTrue(result.references.isEmpty)
    }
    let unrelated = try USDCReferenceTests.scan(
      USDCMutationRecipe.valueCrate(reps: [0x400a_0000_0000_0000]))
    XCTAssertEqual(unrelated.state, .complete)
  }

  // Recursive values must reject cycles and 33 levels while allowing a 32-level chain.
  func testCyclesDepthAndRepeatedValueWork() throws {
    let cycle = try USDCMutationRecipe.valueCrate(
      reps: [0x0034_0000_0000_0058],
      body: USDCReferenceTests.word(8) + USDCReferenceTests.word(0x0034_0000_0000_0058))
    XCTAssertEqual(
      try USDCReferenceTests.scan(cycle).issues.map(\.failure), [.malformed(.invalidGraph)])
    for depth in [32, 33] {
      var body = Data()
      for i in 0..<(depth - 1) {
        body += USDCReferenceTests.word(8)
        body += USDCReferenceTests.word(
          i == depth - 2 ? 0x400c_0000_0000_0002 : 0x0034_0000_0000_0000 | UInt64(88 + (i + 1) * 16)
        )
      }
      let bytes = try USDCMutationRecipe.valueCrate(reps: [0x0034_0000_0000_0058], body: body)
      if depth == 32 {
        XCTAssertEqual(try USDCReferenceTests.scan(bytes).references.count, 1)
      } else {
        XCTAssertThrowsError(try USDCReferenceTests.scan(bytes)) {
          XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcDepth))
        }
      }
    }
  }
}

extension USDCValueTypeTests {
  // All authored operation buckets must be read in source wire order, retaining item coordinates.
  func testAllSixListBucketsIndividuallyAndTogetherAndLegacyPayload() throws {
    let bits: [UInt8] = [2, 4, 32, 64, 8, 16]
    for tag: UInt64 in [35, 55] {
      for mask in bits + [126] {
        var body = Data([mask])
        var expected: [String] = []
        for (bucket, bit) in bits.enumerated() where mask & bit != 0 {
          body +=
            USDCReferenceTests.word(1) + USDCReferenceTests.word(0, 4)
            + USDCReferenceTests.word(0xffff_ffff, 4) + Data(repeating: 0, count: 16)
          if tag == 35 { body += USDCReferenceTests.word(0) }
          expected.append("2:\(bucket)|3:0")
        }
        let result = try USDCReferenceTests.scan(
          USDCMutationRecipe.valueCrate(reps: [(tag << 48) | 88], body: body))
        XCTAssertEqual(result.state, .complete)
        XCTAssertEqual(
          result.references.map { occurrence in
            guard case .usdc(let locator) = occurrence.site else { return "text" }
            return locator.steps.map { "\($0.kind.rawValue):\($0.index)" }.joined(separator: "|")
          }, expected)
      }
    }
    let payload =
      USDCReferenceTests.word(0, 4) + USDCReferenceTests.word(0xffff_ffff, 4)
      + Data(repeating: 0, count: 16)
    let result = try USDCReferenceTests.scan(
      USDCMutationRecipe.valueCrate(reps: [0x002f_0000_0000_0058], body: payload))
    XCTAssertEqual(result.state, .complete)
    XCTAssertEqual(result.references.map(\.valueBytes), [Data("a.png".utf8)])
  }

  // Original supplementary crates pin nonempty templates, raw unregistered list ops, and internal customData.
  func testSupplementaryOriginalEvidence() throws {
    for fixture in try USDCFixtures.extraCases() {
      let result = try USDCReferenceTests.scan(fixture.crate)
      XCTAssertEqual(
        result.state, fixture.expectedInspectionComplete ? .complete : .partial,
        "\(fixture.id): \(result.issues)")
      XCTAssertEqual(result.references.map(\.valueBytes), fixture.expectedValues, fixture.id)
      if fixture.id == "extra/internal-reference-customdata" {
        guard case .usdc(let locator) = try XCTUnwrap(result.references.first).site else {
          return XCTFail("binary site")
        }
        XCTAssertEqual(
          locator.steps,
          [
            .init(kind: .listBucket, index: 0), .init(kind: .listItem, index: 0),
            .init(kind: .referenceCustomData, index: 0), .init(kind: .dictionary, index: 0),
          ])
      }
    }
  }

  // Pinned Read<VtValue> requires a relative pointer; a direct ValueRep is never a fallback.
  func testSourceNormativeRelativeValueWrapperAndNoDirectFallback() throws {
    let relative = try USDCMutationRecipe.valueCrate(
      reps: [0x0034_0000_0000_0058],
      body: USDCReferenceTests.word(8) + USDCReferenceTests.word(0x400c_0000_0000_0002))
    let result = try USDCReferenceTests.scan(relative)
    XCTAssertEqual(result.state, .complete)
    XCTAssertEqual(result.references.map(\.valueBytes), [Data("a.png".utf8)])
    let direct = try USDCMutationRecipe.valueCrate(
      reps: [0x0034_0000_0000_0058], body: USDCReferenceTests.word(0x400c_0000_0000_0002))
    XCTAssertEqual(
      try USDCReferenceTests.scan(direct).issues.map(\.failure), [.malformed(.invalidRange)])
  }

  // A dictionary key valid in TOKENS but absent in STRINGS must not trigger alternate decoding.
  func testDictionaryIndexCountAndSampleMismatchAreMalformed() throws {
    let keyBody =
      USDCReferenceTests.word(1) + USDCReferenceTests.word(3, 4) + USDCReferenceTests.word(8)
      + USDCReferenceTests.word(0x400c_0000_0000_0002)
    XCTAssertEqual(
      try USDCReferenceTests.scan(
        USDCMutationRecipe.valueCrate(reps: [0x001f_0000_0000_0058], body: keyBody)
      ).issues.map(\.failure), [.malformed(.invalidIndex)])
    let invalidAsset = try USDCMutationRecipe.valueCrate(
      reps: [0x800c_0000_0000_0058],
      body: USDCReferenceTests.word(1) + USDCReferenceTests.word(2, 4))
    XCTAssertEqual(
      try USDCReferenceTests.scan(invalidAsset).issues.map(\.failure), [.malformed(.invalidIndex)])
    let oversized = try USDCMutationRecipe.valueCrate(
      reps: [0x800c_0000_0000_0058], body: USDCReferenceTests.word(250_001))
    let ledger = ResourceLedger()
    XCTAssertThrowsError(try USDCReferenceTests.scan(oversized, ledger: ledger)) {
      XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcItems))
    }
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
    let samples =
      USDCReferenceTests.word(8) + USDCReferenceTests.word(0x0030_0000_0000_0078)
      + USDCReferenceTests.word(8) + USDCReferenceTests.word(0) + USDCReferenceTests.word(1)
      + USDCReferenceTests.word(0)
    XCTAssertEqual(
      try USDCReferenceTests.scan(
        USDCMutationRecipe.valueCrate(reps: [0x002e_0000_0000_0058], body: samples)
      ).issues.map(\.failure), [.malformed(.invalidValue)])
  }

  // Exact version floors and every unproved flag on special types must retain a coverage gap.
  func testPerTagNegativeFlagsAndVersionFloorVectors() throws {
    let allowed: [UInt64: Set<UInt8>] = [
      12: [0, 64, 128], 31: [0, 64], 35: [0], 46: [0], 47: [0], 50: [0], 52: [0], 53: [0], 54: [0],
      55: [0], 56: [0, 128], 57: [0, 128],
    ]
    for (tag, accepted) in allowed {
      for flag: UInt8 in [0, 0x20, 0x40, 0x60, 0x80, 0xa0, 0xc0, 0xe0, 1]
      where !accepted.contains(flag) {
        let bytes = try USDCMutationRecipe.valueCrate(
          reps: [(UInt64(flag) << 56) | (tag << 48) | 88], body: Data(repeating: 0, count: 32),
          version: [0, 10, 0])
        XCTAssertEqual(
          try USDCReferenceTests.scan(bytes).issues.map(\.failure),
          [.unsupported(.unsupportedValue)], "tag \(tag), flag \(flag)")
      }
    }
    for (tag, version): (UInt64, [UInt8]) in [(56, [0, 8, 0]), (57, [0, 8, 0]), (57, [0, 9, 0])] {
      let bytes = try USDCMutationRecipe.valueCrate(
        reps: [(tag << 48) | 88], body: Data(repeating: 0, count: 8), version: version)
      XCTAssertEqual(
        try USDCReferenceTests.scan(bytes).issues.map(\.failure), [.unsupported(.unsupportedValue)])
    }
  }

  // A raw unsupported list item cannot hide a later independently locatable typed dictionary.
  func testUnregisteredListRetainsLaterTypedItemsAfterRawGap() throws {
    let body =
      Data([4]) + USDCReferenceTests.word(2)
      + USDCReferenceTests.word(8) + USDCReferenceTests.word(0x400a_0000_0000_0000)
      + USDCReferenceTests.word(8) + USDCReferenceTests.word(0x001f_0000_0000_0081)
      + USDCReferenceTests.word(1) + USDCReferenceTests.word(0, 4)
      + USDCReferenceTests.word(8) + USDCReferenceTests.word(0x400c_0000_0000_0002)
    let result = try USDCReferenceTests.scan(
      USDCMutationRecipe.valueCrate(reps: [0x0036_0000_0000_0058], body: body))
    XCTAssertEqual(result.state, .partial)
    XCTAssertEqual(result.references.map(\.valueBytes), [Data("a.png".utf8)])
    XCTAssertEqual(result.issues.count, 1)
    guard case .usdc(let locator) = try XCTUnwrap(result.references.first).site else {
      return XCTFail("binary site")
    }
    XCTAssertEqual(
      locator.steps,
      [
        .init(kind: .listBucket, index: 1), .init(kind: .listItem, index: 1),
        .init(kind: .wrapper, index: 0), .init(kind: .dictionary, index: 0),
      ])
  }

  // Skips must depend on each proven type/flag pair, never only the type number.
  // Synthetic opaque bodies test reference inventory classification, not geometry validity.
  func testSourceProvenNonAssetFlagMatrix() throws {
    let groups: [([UInt64], Set<UInt8>)] = [
      ([1, 2], [0x40, 0x80]), ([3, 4], [0x40, 0x80, 0xa0]),
      ([5, 6, 9], [0, 0x40, 0x80, 0xa0]), ([7, 8], [0x40, 0x80, 0xa0]),
      ([10, 11], [0x40, 0x80]),
      ([13, 14, 15, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30], [0, 0x40, 0x80]),
      ([16, 17, 18], [0, 0x80]), ([32, 33, 34, 36, 37, 38, 39, 40, 41, 45, 48, 49], [0]),
      ([42, 43, 44, 51], [0x40]),
    ]
    for (tags, flags) in groups {
      for tag in tags {
        for flag: UInt8 in [0, 0x20, 0x40, 0x60, 0x80, 0xa0, 0xc0, 0xe0, 1] {
          let payload: UInt64 = flag == 0x40 ? 0 : 88
          let bytes = try USDCMutationRecipe.valueCrate(
            reps: [(UInt64(flag) << 56) | (tag << 48) | payload],
            body: Data(repeating: 0, count: 16))
          let result = try USDCReferenceTests.scan(bytes)
          XCTAssertEqual(
            result.state, flags.contains(flag) ? .complete : .partial, "tag \(tag) flag \(flag)")
          XCTAssertTrue(result.references.isEmpty)
        }
      }
    }
  }

  // Borrowed bytes, classifier copies, locator arrays and scratch stay charged through the callback.
  func testCallbackStorageIsChargedAndWorkingLimitPrecedesEmission() throws {
    let bytes = try USDCMutationRecipe.valueCrate(reps: [0x400c_0000_0000_0002])
    let ledger = ResourceLedger()
    let input = USDCReferenceTests.input(bytes, ledger: ledger)
    let tables = try USDCTables.read(input: input)
    let baseline = ledger.usdcLiveBytes
    var callbacks = 0
    try tables.forEachLiveField { field in
      try USDCValues.walk(
        field: field, tables: tables, input: input,
        onReference: { _ in
          callbacks += 1
          XCTAssertGreaterThanOrEqual(ledger.usdcLiveBytes, baseline + 1792 + 1044 + 256)
        }, onIssue: { _ in XCTFail("unexpected gap") })
    }
    XCTAssertEqual(callbacks, 1)
    XCTAssertEqual(ledger.usdcLiveBytes, baseline)
    let held = try ledger.reserveUSDCStorage(
      SafetyResource.usdcWorkingBytes.limit - baseline - 1792 - 1000)
    defer { held.release() }
    XCTAssertThrowsError(
      try tables.forEachLiveField { field in
        try USDCValues.walk(
          field: field, tables: tables, input: input,
          onReference: { _ in XCTFail("copy reservation must stop before emission") },
          onIssue: { _ in XCTFail("resource error must propagate") })
      }
    ) { XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcWorkingBytes)) }
    XCTAssertEqual(ledger.usdcLiveBytes, SafetyResource.usdcWorkingBytes.limit - 1792 - 1000)
  }

  // Inline reference customData contributes depth but no ValueRep; stale sibling reps are not ancestors.
  func testReferenceCustomDataDoesNotInheritSiblingCycleState() throws {
    let w = USDCReferenceTests.word
    let root =
      w(2, 8) + w(0, 4) + w(8, 8) + w(0x001f_0000_0000_009c, 8)
      + w(1, 4) + w(8, 8) + w(0x0023_0000_0000_00b8, 8) + Data(repeating: 0, count: 20)
    let nested = w(1, 8) + w(0, 4) + w(8, 8) + w(0x400c_0000_0000_0002, 8)
    let refs =
      Data([2]) + w(1, 8) + w(1, 4) + w(0xffff_ffff, 4) + Data(repeating: 0, count: 16)
      + w(1, 8) + w(0, 4) + w(8, 8) + w(0x400c_0000_0000_0002, 8)
    let result = try USDCReferenceTests.scan(
      USDCMutationRecipe.valueCrate(reps: [0x001f_0000_0000_0058], body: root + nested + refs))
    XCTAssertEqual(result.state, .complete)
    XCTAssertTrue(result.issues.isEmpty)
    XCTAssertEqual(result.references.map(\.valueBytes), [Data("a.png".utf8), Data("a.png".utf8)])
  }

  // String vectors only acquire file-reference semantics at the top-level subLayers field.
  func testUnrelatedStringVectorIsNotGuessedAsAssetReferences() throws {
    let body = USDCReferenceTests.word(1) + USDCReferenceTests.word(0, 4)
    let ordinary = try USDCReferenceTests.scan(
      USDCMutationRecipe.valueCrate(reps: [0x0032_0000_0000_0058], body: body))
    XCTAssertEqual(ordinary.state, .complete)
    XCTAssertTrue(ordinary.references.isEmpty)
    let sublayers = try USDCReferenceTests.scan(
      USDCMutationRecipe.valueCrate(
        reps: [0x0032_0000_0000_0058], body: body, tokens: ["/", "subLayers", "a.png", ""]))
    XCTAssertEqual(sublayers.state, .complete)
    XCTAssertEqual(sublayers.references.map(\.valueBytes), [Data("a.png".utf8)])
  }

  // Classification preserves serialized expression syntax without evaluation or USDA unescaping.
  func testAuthoredAssetExpressionBytesAndClassificationArePreserved() throws {
    for fixture in try USDCFixtures.cases().filter({ $0.id.contains("pe10-asset-expression") }) {
      let result = try USDCReferenceTests.scan(fixture.crate)
      XCTAssertEqual(result.references.map(\.valueBytes), [Data("`\"${TEXTURE}\"`".utf8)])
      XCTAssertEqual(result.references.map(\.classification), [.unsupportedExpression])
    }
  }

  // Snapshot faults are operational, and repeated shared bodies consume work before expansion.
  func testSnapshotErrorPropagationAndAmplificationBeforeCallbacks() throws {
    enum SnapshotError: Error { case changed }
    let original = USDCReferenceTests.input(
      try USDCMutationRecipe.valueCrate(reps: []), ledger: ResourceLedger())
    let reader = BoundedReader(size: original.reader.size, ledger: original.reader.ledger) { _, _ in
      throw SnapshotError.changed
    }
    XCTAssertThrowsError(
      try USDCReader.scan(
        entry: original.entry, reader: reader, onReference: { _ in XCTFail("callback") },
        onIssue: { _ in XCTFail("operational fault is not content") })
    ) { XCTAssertTrue($0 is SnapshotError) }
    XCTAssertEqual(reader.ledger.usdcLiveBytes, 0)
    let bytes = try USDCMutationRecipe.valueCrate(
      reps: [0x800c_0000_0000_0058],
      body: USDCReferenceTests.word(10_000) + Data(repeating: 0, count: 40_000))
    let ledger = ResourceLedger()
    let input = USDCReferenceTests.input(bytes, ledger: ledger)
    let tables = try USDCTables.read(input: input)
    try ledger.consumeUSDCWork(2_000_000 - ledger.usdcWorkUnits - 500)
    XCTAssertThrowsError(
      try tables.forEachLiveField { field in
        try USDCValues.walk(
          field: field, tables: tables, input: input,
          onReference: { _ in XCTFail("must stop before expansion") },
          onIssue: { _ in XCTFail("hard safety stop") })
      }
    ) { XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcWork)) }
  }
}

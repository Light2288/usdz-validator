import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

final class USDCNumericArrayTests: XCTestCase {
  private let w = USDCReferenceTests.word

  // Charging skipped elements, decoding their bodies, or widening admission breaks this matrix.
  func testAdmittedNumericCountsAreOpaque() throws {
    let forms: [(UInt64, UInt64)] =
      (Array(1...9) + Array(13...30)).map { (UInt64($0), 0x80) }
      + Array(3...9).map { (UInt64($0), 0xa0) }
    for version: [UInt8] in [[0, 8, 0], [0, 9, 0], [0, 10, 0]] {
      for (tag, flags) in forms {
        var baseline: Receipt?
        for count: UInt64 in [0, 250_000, 250_001, .max] {
          let bytes = try USDCMutationRecipe.valueCrate(
            reps: [(flags << 56) | (tag << 48) | 88], body: w(count, 8), version: version)
          let receipt = try inspect(bytes, valueRange: 88..<96)
          XCTAssertEqual(receipt.state, .complete)
          XCTAssertTrue(receipt.references.isEmpty)
          XCTAssertTrue(receipt.issues.isEmpty)
          XCTAssertEqual(receipt.events.filter { $0.offset == 88 }.map(\.count), [8])
          if let baseline {
            XCTAssertEqual(
              receipt.work, baseline.work, "tag \(tag), flags \(flags), count \(count)")
            XCTAssertEqual(receipt.decode, baseline.decode)
            XCTAssertEqual(receipt.events, baseline.events)
          } else {
            baseline = receipt
          }
        }
        let empty = try inspect(
          USDCMutationRecipe.valueCrate(
            reps: [(flags << 56) | (tag << 48)], body: w(.max, 8), version: version),
          valueRange: 88..<96)
        XCTAssertEqual(empty.state, .complete)
        XCTAssertTrue(empty.references.isEmpty)
        XCTAssertTrue(empty.issues.isEmpty)
        XCTAssertTrue(empty.events.allSatisfy { $0.offset != 88 })
      }
    }
    let decoy = try inspect(
      USDCMutationRecipe.valueCrate(
        reps: [0x8003_0000_0000_0058], body: w(.max, 8) + Data("@invented.png@".utf8)),
      valueRange: 88..<110)
    XCTAssertEqual(decoy.state, .complete)
    XCTAssertTrue(decoy.references.isEmpty)
    XCTAssertEqual(decoy.events.filter { $0.offset == 88 }.map(\.count), [8])
  }

  // Removing the bounded cursor/header read must expose malformed pointers or truncated headers.
  func testNumericHeaderAndValueRegionRemainBounded() throws {
    for prefix: UInt64 in [0x8003_0000_0000_0000, 0xa003_0000_0000_0000] {
      for (pointer, body, end): (UInt64, Data, UInt64) in [
        (88, Data(repeating: 0, count: 7), 95),
        (87, w(0, 8), 96), (96, w(0, 8), 96),
        (0x0000_ffff_ffff_ffff, w(0, 8), 96),
      ] {
        let receipt = try inspect(
          USDCMutationRecipe.valueCrate(reps: [prefix | pointer], body: body),
          valueRange: 88..<end)
        XCTAssertEqual(receipt.state, .partial)
        XCTAssertEqual(receipt.issues, [.malformed(.invalidRange)])
        XCTAssertTrue(receipt.references.isEmpty)
        XCTAssertTrue(receipt.events.allSatisfy { $0.offset != 88 })
      }
      let exact = try inspect(
        USDCMutationRecipe.valueCrate(reps: [prefix | 88], body: w(.max, 8)),
        valueRange: 88..<96)
      XCTAssertEqual(exact.state, .complete)
      XCTAssertTrue(exact.issues.isEmpty)
      XCTAssertEqual(exact.events.filter { $0.offset == 88 }.map(\.count), [8])
    }
  }

  // An offset cache or an exemption applied by payload would hide real asset occurrences.
  func testSharedNumericOffsetDoesNotHideAssetArray() throws {
    for reps: [UInt64] in [
      [0x8003_0000_0000_0058, 0x800c_0000_0000_0058, 0x800c_0000_0000_0058],
      [0x800c_0000_0000_0058, 0x800c_0000_0000_0058, 0x8003_0000_0000_0058],
    ] {
      let result = try USDCReferenceTests.scan(
        USDCMutationRecipe.valueCrate(reps: reps, body: w(2, 8) + w(0, 4) + w(0, 4)))
      XCTAssertEqual(result.state, .complete)
      XCTAssertEqual(
        result.references.map(\.valueBytes), Array(repeating: Data("a.png".utf8), count: 4))
      let sites = result.references.compactMap { occurrence in
        if case .usdc(let locator) = occurrence.site {
          return locator.discriminator(reason: "test")
        }
        return nil
      }
      XCTAssertEqual(Set(sites).count, 4)
      XCTAssertTrue(result.issues.isEmpty)
    }
    for reps: [UInt64] in [
      [0x8003_0000_0000_0058, 0x800c_0000_0000_0058],
      [0x800c_0000_0000_0058, 0x8003_0000_0000_0058],
    ] {
      XCTAssertThrowsError(
        try USDCReferenceTests.scan(
          USDCMutationRecipe.valueCrate(reps: reps, body: w(250_001, 8)))
      ) { XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcItems)) }
    }
  }

  // Unknown flags cannot activate skipping, and their gap must not erase a later asset.
  func testUnknownNumericRepresentationRetainsLaterAsset() throws {
    for rep: UInt64 in [0xc003_0000_0000_0058, 0xa001_0000_0000_0058, 0x8103_0000_0000_0058] {
      let result = try USDCReferenceTests.scan(
        USDCMutationRecipe.valueCrate(
          reps: [rep, 0x400c_0000_0000_0002], body: w(.max, 8)))
      XCTAssertEqual(result.state, .partial)
      XCTAssertEqual(result.references.map(\.valueBytes), [Data("a.png".utf8)])
      XCTAssertEqual(result.issues.map(\.failure), [.unsupported(.unsupportedValue)])
    }
    for version: [UInt8] in [[0, 7, 0], [0, 8, 1], [0, 11, 0], [1, 8, 0]] {
      let result = try USDCReferenceTests.scan(
        USDCMutationRecipe.valueCrate(
          reps: [0x8003_0000_0000_0058, 0x400c_0000_0000_0002],
          body: w(.max, 8), version: version))
      XCTAssertEqual(result.state, .uninspected)
      XCTAssertTrue(result.references.isEmpty)
      XCTAssertEqual(result.issues.map(\.failure), [.unsupported(.unsupportedVersion)])
    }
  }

  // Skipping a nested numeric leaf must retain dictionary, relative-edge, sample and depth costs.
  func testNestedNumericCountsLeaveEnclosingContainersCharged() throws {
    for count: UInt64 in [0, 250_001, .max] {
      let cases: [(UInt64, Data, UInt64)] = [
        (
          0x001f_0000_0000_0058,
          w(1, 8) + w(0, 4) + w(8, 8) + w(0x8003_0000_0000_0074, 8) + w(count, 8), 253
        ),
        (
          0x0034_0000_0000_0058,
          w(8, 8) + w(0xa003_0000_0000_0068, 8) + w(count, 8), 250
        ),
        (
          0x002e_0000_0000_0058,
          w(8, 8) + w(0x0030_0000_0000_0080, 8) + w(8, 8) + w(1, 8)
            + w(0x8003_0000_0000_0090, 8) + w(1, 8) + w(0, 8) + w(count, 8), 254
        ),
      ]
      for (rep, body, work) in cases {
        let ledger = ResourceLedger()
        let result = try USDCReferenceTests.scan(
          USDCMutationRecipe.valueCrate(reps: [rep], body: body), ledger: ledger)
        XCTAssertEqual(result.state, .complete)
        XCTAssertTrue(result.references.isEmpty)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(ledger.usdcWorkUnits, work)
      }
    }
    // Counts remain item-limited for strings/tokens/assets, TimeCode/PathExpression,
    // dictionaries, sublayers, list operations and time-sample time vectors.
    for (rep, body): (UInt64, Data) in [
      (0x800a_0000_0000_0058, w(250_001, 8)),
      (0x800b_0000_0000_0058, w(250_001, 8)),
      (0x800c_0000_0000_0058, w(250_001, 8)),
      (0x8038_0000_0000_0058, w(250_001, 8)),
      (0x8039_0000_0000_0058, w(250_001, 8)),
      (0x001f_0000_0000_0058, w(250_001, 8)),
      (0x0032_0000_0000_0058, w(250_001, 8)),
      (0x0023_0000_0000_0058, Data([2]) + w(250_001, 8)),
      (
        0x002e_0000_0000_0058,
        w(8, 8) + w(0x0030_0000_0000_0068, 8) + w(250_001, 8)
      ),
    ] {
      XCTAssertThrowsError(
        try USDCReferenceTests.scan(
          USDCMutationRecipe.valueCrate(
            reps: [rep], body: body, tokens: ["/", "subLayers", "a.png", ""], version: [0, 10, 0])),
        String(rep, radix: 16)
      ) { XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcItems)) }
    }
    var deep = Data()
    for i in 0..<32 {
      deep += w(8, 8)
      deep += w(i == 31 ? 0x8003_0000_0000_0258 : 0x0034_0000_0000_0000 | UInt64(104 + i * 16), 8)
    }
    deep += w(.max, 8)
    XCTAssertThrowsError(
      try USDCReferenceTests.scan(
        USDCMutationRecipe.valueCrate(reps: [0x0034_0000_0000_0058], body: deep))
    ) { XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcDepth)) }
  }

  private struct ReadEvent: Equatable {
    let offset: UInt64
    let count: Int
    let live: UInt64
  }

  private struct Receipt {
    let state: USDCScanState
    let references: [ReferenceOccurrence]
    let issues: [USDCFailure]
    let work: UInt64
    let decode: UInt64
    let events: [ReadEvent]
  }

  private func inspect(_ bytes: Data, valueRange: Range<UInt64>) throws -> Receipt {
    let ledger = ResourceLedger()
    let original = USDCReferenceTests.input(bytes, ledger: ledger)
    var events: [ReadEvent] = []
    let reader = BoundedReader(size: UInt64(bytes.count), ledger: ledger) { offset, count in
      let end = offset + UInt64(count)
      XCTAssertLessThanOrEqual(end, UInt64(bytes.count))
      if valueRange.contains(offset) {
        XCTAssertLessThanOrEqual(end, valueRange.upperBound)
      }
      events.append(ReadEvent(offset: offset, count: count, live: ledger.usdcLiveBytes))
      return bytes.subdata(in: Int(offset)..<Int(end))
    }
    var references: [ReferenceOccurrence] = []
    var issues: [USDCFailure] = []
    let state = try USDCReader.scan(
      entry: original.entry, reader: reader, onReference: { references.append($0) },
      onIssue: { issues.append($0.failure) })
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
    return Receipt(
      state: state, references: references, issues: issues, work: ledger.usdcWorkUnits,
      decode: ledger.usdcDecodeBytes, events: events)
  }
}

import Foundation
import XCTest

@testable import USDZValidation

final class USDCInputTests: XCTestCase {
  // Layer-relative overflow or an oversized chunk must not reach neighboring member bytes.
  func testLayerRangesNeverReadAnotherMember() throws {
    let ledger = ResourceLedger()
    var reads: [Range<UInt64>] = []
    let reader = BoundedReader(size: 200_000, ledger: ledger) { offset, count in
      reads.append(offset..<(offset + UInt64(count)))
      XCTAssertGreaterThanOrEqual(offset, 64)
      XCTAssertLessThanOrEqual(offset + UInt64(count), 100_064)
      XCTAssertLessThanOrEqual(count, 65_536)
      return Data(repeating: 0x61, count: count)
    }
    let input = USDCInput(entry: entry(range: 64..<100_064), reader: reader)
    XCTAssertEqual(try input.withBytes(offset: 0, count: 65_536) { $0.count }, 65_536)
    XCTAssertEqual(try input.withBytes(offset: 99_999, count: 1) { Array($0) }, [0x61])
    XCTAssertEqual(try input.withBytes(offset: 100_000, count: 0) { $0.count }, 0)
    XCTAssertEqual(reads, [64..<65_600, 100_063..<100_064])
    for (offset, count): (UInt64, Int) in [
      (.max, 1), (0, -1), (100_001, 0), (100_000, 1), (0, Int.max),
    ] {
      XCTAssertThrowsError(
        try input.withBytes(offset: offset, count: count) { _ in XCTFail("Invalid range") }
      ) {
        XCTAssertEqual($0 as? USDCFailure, .malformed(.invalidRange))
      }
    }
    XCTAssertThrowsError(
      try input.withBytes(offset: 0, count: 65_537) { _ in XCTFail("Oversized chunk") }
    ) {
      XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.readChunkBytes))
    }
    XCTAssertEqual(reads.count, 2)
    let outside = USDCInput(entry: entry(range: 199_999..<200_001), reader: reader)
    XCTAssertThrowsError(
      try outside.withBytes(offset: 0, count: 1) { _ in XCTFail("Invalid payload") })
    let overflowing = USDCInput(entry: entry(range: (.max - 1)..<(.max)), reader: reader)
    XCTAssertThrowsError(
      try overflowing.withBytes(offset: 1, count: 1) { _ in XCTFail("Overflow") })
    XCTAssertEqual(reads.count, 2)
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
  }

  // Compressed staging and raw output must both remain charged during decoding and on throw.
  func testBorrowedStagingRemainsChargedAlongsideOutputAndReleasesOnThrow() throws {
    let ledger = ResourceLedger()
    let stagingCapacity = try USDCInput.stagingCapacity(byteCount: 16)
    let reader = BoundedReader(size: 128, ledger: ledger) { _, count in
      XCTAssertEqual(ledger.usdcLiveBytes, stagingCapacity)
      return Data(repeating: 0x62, count: count)
    }
    let input = USDCInput(entry: entry(range: 64..<128), reader: reader)
    enum Stop: Error { case sentinel }
    XCTAssertThrowsError(
      try input.withBytes(offset: 0, count: 16) { bytes in
        XCTAssertEqual(Array(bytes), Array(repeating: 0x62, count: 16))
        XCTAssertEqual(ledger.usdcLiveBytes, stagingCapacity)
        let output = try USDCStorage.allocate(byteCount: 32, ledger: ledger)
        XCTAssertEqual(ledger.usdcLiveBytes, stagingCapacity + 32)
        try output.withUnsafeMutableBytes { destination in
          destination[0] = bytes[0]
          return 1
        }
        throw Stop.sentinel
      }
    ) { XCTAssertTrue($0 is Stop) }
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
    let all = try ledger.reserveUSDCStorage(67_108_864)
    XCTAssertThrowsError(try input.withBytes(offset: 0, count: 16) { _ in XCTFail("Rejected") }) {
      XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcWorkingBytes))
    }
    all.release()
    XCTAssertEqual(ledger.totalReadBytes, 16, "Rejected staging must not issue a source read")
  }

  // The Foundation staging allowance must cover payload capacity before allocation.
  func testStagingCapacityIsConservativeAndRejectsOversizedRequests() throws {
    XCTAssertEqual(try USDCInput.stagingCapacity(byteCount: 0), 0)
    XCTAssertEqual(try USDCInput.stagingCapacity(byteCount: 16), 288)
    XCTAssertEqual(try USDCInput.stagingCapacity(byteCount: 65_536), 131_328)
    for bytes: UInt64 in [65_537, .max] {
      XCTAssertThrowsError(try USDCInput.stagingCapacity(byteCount: bytes)) {
        XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.readChunkBytes))
      }
    }
  }

  // Snapshot failures must survive the input boundary unchanged, with no leaked staging charge.
  func testOperationalAndShortReadFailuresPropagateAndReleaseStaging() {
    for sentinel in [ValidationError.operational(.inputChanged), .operational(.inputReadFailed)] {
      let ledger = ResourceLedger()
      let reader = BoundedReader(size: 128, ledger: ledger) { _, _ in throw sentinel }
      let input = USDCInput(entry: entry(range: 64..<128), reader: reader)
      XCTAssertThrowsError(try input.withBytes(offset: 0, count: 1) { _ in XCTFail("Failed") }) {
        XCTAssertEqual($0 as? ValidationError, sentinel)
      }
      XCTAssertEqual(ledger.usdcLiveBytes, 0)
    }
    let ledger = ResourceLedger()
    let reader = BoundedReader(size: 128, ledger: ledger) { _, _ in Data() }
    let input = USDCInput(entry: entry(range: 64..<128), reader: reader)
    XCTAssertThrowsError(try input.withBytes(offset: 0, count: 1) { _ in XCTFail("Short") }) {
      XCTAssertEqual($0 as? InspectionFailure, .shortRead)
    }
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
  }

  private func entry(range: Range<UInt64>) -> ZIPEntry {
    let size = range.upperBound - range.lowerBound
    let record = ZIPDirectory.Record(
      nameBytes: Data("root.usdc".utf8), versionMadeBy: 0x0314, versionNeeded: 20, flags: 0,
      method: 0, modificationTime: 0, modificationDate: 0x21, crc32: 0,
      compressedSize: size, uncompressedSize: size, diskNumber: 0, internalAttributes: 0,
      externalAttributes: 0x81a4_0000, localHeaderOffset: 0, centralHeaderOffset: 0)
    return ZIPEntry(record: record, recordRange: 0..<0, headerRange: 0..<0, payloadRange: range)
  }
}

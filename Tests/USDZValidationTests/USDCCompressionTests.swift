import Foundation
import XCTest

@testable import USDZValidation

final class USDCCompressionTests: XCTestCase {
  // A widened count/length field, wrong chunk cursor, or exact-capacity assumption loses literals.
  func testPinnedSingleAndTwoChunkFrames() throws {
    let vectors: [([UInt8], UInt64, [UInt8], UInt64)] = [
      ([0, 0x30, 0x61, 0x62, 0x63], 8, [0x61, 0x62, 0x63], 1),
      ([1, 4, 0, 0, 0, 0x30, 0x61, 0x62, 0x63], 3, [0x61, 0x62, 0x63], 1),
      (
        [
          2, 4, 0, 0, 0, 0x30, 0x61, 0x62, 0x63,
          3, 0, 0, 0, 0x20, 0x64, 0x65,
        ], 9, [0x61, 0x62, 0x63, 0x64, 0x65], 2
      ),
      ([0, 0], 0, [], 1),
    ]
    for (frame, capacity, expectedLiteralBytes, chunks) in vectors {
      let ledger = ResourceLedger()
      do {
        let decoded = try USDCCompression.decode(
          input: input(frame, ledger: ledger), range: 0..<UInt64(frame.count),
          decodedCapacity: capacity)
        let outputBytes = decoded.withUnsafeBytes { Array($0) }
        XCTAssertEqual(outputBytes, expectedLiteralBytes)
        XCTAssertEqual(decoded.capacity, Int(capacity))
        XCTAssertEqual(ledger.usdcLiveBytes, capacity)
      }
      XCTAssertEqual(ledger.usdcLiveBytes, 0)
      XCTAssertEqual(ledger.usdcDecodeBytes, capacity)
      XCTAssertEqual(ledger.usdcWorkUnits, chunks)
    }
  }

  // Alternative eight-byte fields fail the sole LZ4 attempt; no parser fallback may succeed.
  func testAlternateFramingDoesNotFallback() throws {
    let frame: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0x30, 0x61, 0x62, 0x63]
    let ledger = ResourceLedger()
    XCTAssertThrowsError(
      try USDCCompression.decode(
        input: input(frame, ledger: ledger),
        range: 0..<UInt64(frame.count), decodedCapacity: 8)
    ) { XCTAssertEqual($0 as? USDCFailure, .unsupported(.unsupportedEncoding)) }
    // This vector reaches C; each attempted chunk consumes one structural work unit.
    let decodeAttempts = ledger.usdcWorkUnits
    XCTAssertEqual(decodeAttempts, 1)
    XCTAssertEqual(ledger.usdcDecodeBytes, 8)
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
  }

  // Signed lengths, incomplete headers/bodies and an explicit frame's trailing bytes are corruption.
  func testTruncatedAndImpossibleFramesAreMalformed() throws {
    let frames: [[UInt8]] = [
      [], [0], [1], [1, 4, 0, 0], [1, 0xff, 0xff, 0xff, 0xff],
      [1, 0, 0, 0, 0], [1, 4, 0, 0, 0, 0x30, 0x61],
      [1, 0xff, 0xff, 0xff, 0x7f],
      [1, 4, 0, 0, 0, 0x30, 0x61, 0x62, 0x63, 0x00],
      [2, 4, 0, 0, 0, 0x30, 0x61, 0x62, 0x63],
    ]
    for frame in frames {
      let ledger = ResourceLedger()
      XCTAssertThrowsError(
        try USDCCompression.decode(
          input: input(frame, ledger: ledger),
          range: 0..<UInt64(frame.count), decodedCapacity: 8)
      ) { XCTAssertEqual($0 as? USDCFailure, .malformed(.invalidCompression), "\(frame)") }
      XCTAssertEqual(ledger.usdcLiveBytes, 0)
    }
  }

  // Failed C decoding and expansion beyond the remaining destination never expose partial output.
  func testInvalidLZ4AndExcessExpansionStayUnsupportedAndConsumeCapacity() throws {
    let vectors: [([UInt8], UInt64, UInt64)] = [
      ([0, 0x30, 0x61], 8, 1),
      ([0, 0x30, 0x61, 0x62, 0x63], 2, 1),
      (
        [
          2, 4, 0, 0, 0, 0x30, 0x61, 0x62, 0x63,
          3, 0, 0, 0, 0x20, 0x64, 0x65,
        ], 4, 2
      ),
      ([0x80, 0], 8, 0),
    ]
    for (frame, capacity, work) in vectors {
      let ledger = ResourceLedger()
      XCTAssertThrowsError(
        try USDCCompression.decode(
          input: input(frame, ledger: ledger),
          range: 0..<UInt64(frame.count), decodedCapacity: capacity)
      ) { XCTAssertEqual($0 as? USDCFailure, .unsupported(.unsupportedEncoding)) }
      XCTAssertEqual(ledger.usdcDecodeBytes, capacity)
      XCTAssertEqual(ledger.usdcWorkUnits, work)
      XCTAssertEqual(ledger.usdcLiveBytes, 0)
    }
    let ledger = ResourceLedger()
    let broken = input([0, 0xff], ledger: ledger)
    for _ in 0..<2 {
      XCTAssertThrowsError(
        try USDCCompression.decode(
          input: broken, range: 0..<2, decodedCapacity: 16_777_216)
      ) {
        XCTAssertEqual($0 as? USDCFailure, .unsupported(.unsupportedEncoding))
      }
    }
    XCTAssertThrowsError(
      try USDCCompression.decode(
        input: broken, range: 0..<2, decodedCapacity: 1)
    ) {
      XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcDecodeBytes))
    }
    XCTAssertEqual(ledger.usdcDecodeBytes, 33_554_432)
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
  }

  // Impossible ranges and block-size arithmetic must fail before any storage allocation or read.
  func testOversizedBlocksAndInvalidRangesAreRejectedBeforeAllocation() throws {
    let ledger = ResourceLedger()
    let occupied = try ledger.reserveUSDCStorage(67_108_864)
    defer { occupied.release() }
    let reader = BoundedReader(size: 268_435_456, ledger: ledger) { _, _ in
      XCTFail("Rejected input must not read")
      return Data()
    }
    let source = USDCInput(entry: entry(size: 268_435_456), reader: reader)
    for capacity: UInt64 in [16_777_217, .max] {
      XCTAssertThrowsError(
        try USDCCompression.decode(
          input: source, range: 0..<2, decodedCapacity: capacity)
      ) {
        XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcMetadataBlockBytes))
      }
    }
    for range: Range<UInt64> in [0..<16_777_217, 0..<UInt64.max] {
      XCTAssertThrowsError(
        try USDCCompression.decode(
          input: source, range: range, decodedCapacity: 8)
      ) {
        if range.upperBound == UInt64.max {
          XCTAssertEqual($0 as? USDCFailure, .malformed(.invalidRange))
        } else {
          XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcMetadataBlockBytes))
        }
      }
    }
    XCTAssertEqual(ledger.usdcDecodeBytes, 0)
    XCTAssertEqual(ledger.totalReadBytes, 0)
    XCTAssertEqual(ledger.usdcLiveBytes, 67_108_864)
  }

  // Retained compressed bytes must be charged before I/O, and all source reads stay <=64 KiB.
  func testCompressedStagingIsChargedAndChunkedAndFailuresReleaseIt() throws {
    // LZ4 literal-only block: 65,540 literals, 256 length extension bytes of 255 and a final 245.
    let literals = [UInt8](repeating: 0x61, count: 65_540)
    let frame = [UInt8]([0, 0xf0]) + [UInt8](repeating: 255, count: 256) + [245] + literals
    let ledger = ResourceLedger()
    var reads: [Int] = []
    let source = input(frame, ledger: ledger) { count in
      reads.append(count)
      XCTAssertGreaterThanOrEqual(
        ledger.usdcLiveBytes,
        UInt64(frame.count) + (try USDCInput.stagingCapacity(byteCount: UInt64(count))))
    }
    do {
      let decoded = try USDCCompression.decode(
        input: source, range: 0..<UInt64(frame.count), decodedCapacity: 65_540)
      XCTAssertEqual(decoded.withUnsafeBytes { Array($0) }, literals)
    }
    XCTAssertEqual(reads, [65_536, 263])
    XCTAssertEqual(ledger.usdcLiveBytes, 0)

    let failedLedger = ResourceLedger()
    let failing = USDCInput(
      entry: entry(size: 2),
      reader: BoundedReader(
        size: 2, ledger: failedLedger,
        readAt: { _, _ in
          throw ValidationError.operational(.inputChanged)
        }))
    XCTAssertThrowsError(
      try USDCCompression.decode(
        input: failing, range: 0..<2, decodedCapacity: 8)
    ) {
      XCTAssertEqual($0 as? ValidationError, .operational(.inputChanged))
    }
    XCTAssertEqual(failedLedger.usdcLiveBytes, 0)
    XCTAssertEqual(failedLedger.usdcDecodeBytes, 8)
  }

  // Exhausted work/storage cannot reach C or source allocation, and failed quota is not refunded.
  func testWorkAndLiveLimitsPreventDecoding() throws {
    let ledger = ResourceLedger()
    try ledger.consumeUSDCWork(2_000_000)
    XCTAssertThrowsError(
      try USDCCompression.decode(
        input: input([0, 0], ledger: ledger), range: 0..<2, decodedCapacity: 8)
    ) {
      XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcWork))
    }
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
    XCTAssertEqual(ledger.usdcDecodeBytes, 8)
    let occupied = try ledger.reserveUSDCStorage(67_108_864)
    defer { occupied.release() }
    XCTAssertThrowsError(
      try USDCCompression.decode(
        input: input([0, 0], ledger: ledger), range: 0..<2, decodedCapacity: 8)
    ) {
      XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcWorkingBytes))
    }
    XCTAssertEqual(ledger.totalReadBytes, 2)
    XCTAssertEqual(ledger.usdcDecodeBytes, 16)
  }

  private func input(
    _ bytes: [UInt8], ledger: ResourceLedger,
    onRead: ((Int) throws -> Void)? = nil
  ) -> USDCInput {
    let reader = BoundedReader(size: UInt64(bytes.count), ledger: ledger) { offset, count in
      try onRead?(count)
      return Data(bytes[Int(offset)..<(Int(offset) + count)])
    }
    return USDCInput(entry: entry(size: UInt64(bytes.count)), reader: reader)
  }

  private func entry(size: UInt64) -> ZIPEntry {
    let record = ZIPDirectory.Record(
      nameBytes: Data("root.usdc".utf8), versionMadeBy: 0x0314, versionNeeded: 20, flags: 0,
      method: 0, modificationTime: 0, modificationDate: 0x21, crc32: 0,
      compressedSize: size, uncompressedSize: size, diskNumber: 0, internalAttributes: 0,
      externalAttributes: 0x81a4_0000, localHeaderOffset: 0, centralHeaderOffset: 0)
    return ZIPEntry(record: record, recordRange: 0..<0, headerRange: 0..<0, payloadRange: 0..<size)
  }
}

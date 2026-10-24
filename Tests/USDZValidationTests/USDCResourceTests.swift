import Foundation
import XCTest

@testable import USDZValidation

final class USDCResourceTests: XCTestCase {
  // A released working allocation must not refund cumulative decode, work or occurrence costs.
  func testLiveReservationsReleaseWithoutRefundingCumulativeCounters() throws {
    let ledger = ResourceLedger()
    try ledger.reserveUSDCDecode(16_777_216)
    try ledger.reserveUSDCDecode(16_777_216)
    try ledger.consumeUSDCWork(1_999_999)
    try ledger.consumeUSDCWork(1)
    try ledger.consumeTokens(100_000)
    var reservation: USDCStorageReservation? = try ledger.reserveUSDCStorage(67_108_864)
    XCTAssertEqual(ledger.usdcLiveBytes, 67_108_864)
    XCTAssertThrowsError(try ledger.reserveUSDCStorage(1)) {
      XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcWorkingBytes))
    }
    XCTAssertThrowsError(try ledger.reserveUSDCStorage(.max)) {
      XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcWorkingBytes))
    }
    XCTAssertEqual(ledger.usdcLiveBytes, 67_108_864)
    reservation?.release()
    reservation?.release()
    reservation = nil
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
    XCTAssertEqual(ledger.usdcDecodeBytes, 33_554_432)
    XCTAssertEqual(ledger.usdcWorkUnits, 2_000_000)
    for amount: UInt64 in [1, .max] {
      XCTAssertThrowsError(try ledger.reserveUSDCDecode(amount)) {
        XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcDecodeBytes))
      }
      XCTAssertThrowsError(try ledger.consumeUSDCWork(amount)) {
        XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcWork))
      }
      XCTAssertThrowsError(try ledger.consumeTokens(amount)) {
        XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.tokenCount))
      }
    }
    XCTAssertEqual(ledger.usdcDecodeBytes, 33_554_432)
    XCTAssertEqual(ledger.usdcWorkUnits, 2_000_000)
    XCTAssertNoThrow(try ledger.reserveUSDCDecode(0))
    XCTAssertNoThrow(try ledger.consumeUSDCWork(0))
    do {
      let live = try ledger.reserveUSDCStorage(17)
      XCTAssertEqual(ledger.usdcLiveBytes, 17)
      withExtendedLifetime(live) {}
    }
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
  }

  // Untrusted sizes must be rejected before reaching the allocator, including overflow.
  func testReservationsPrecedeAllocationAndReleaseOnThrow() throws {
    let ledger = ResourceLedger()
    var allocationCalls = 0
    for bytes: UInt64 in [67_108_865, UInt64(Int.max) + 1, .max] {
      XCTAssertThrowsError(
        try USDCStorage.allocate(byteCount: bytes, ledger: ledger) { count in
          allocationCalls += 1
          return UnsafeMutableRawPointer.allocate(byteCount: count, alignment: 16)
        }
      ) {
        XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcWorkingBytes))
      }
    }
    XCTAssertEqual(allocationCalls, 0)
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
    enum Stop: Error { case sentinel }
    XCTAssertThrowsError(
      try USDCStorage.allocate(byteCount: 7, ledger: ledger) { _ in
        allocationCalls += 1
        XCTAssertEqual(ledger.usdcLiveBytes, 7)
        throw Stop.sentinel
      }
    ) { XCTAssertTrue($0 is Stop) }
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
    XCTAssertThrowsError(
      try {
        let storage = try USDCStorage.allocate(byteCount: 7, ledger: ledger)
        try storage.withUnsafeMutableBytes { _ in throw Stop.sentinel }
      }()
    ) { XCTAssertTrue($0 is Stop) }
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
  }

  // Capacity is not initialized content; invalid writes cannot expose uninitialized bytes.
  func testStorageBorrowsOnlyInitializedBytesAndReleasesOwnedCapacity() throws {
    let ledger = ResourceLedger()
    do {
      let storage = try USDCStorage.allocate(byteCount: 8, ledger: ledger)
      XCTAssertEqual(storage.capacity, 8)
      XCTAssertEqual(storage.count, 0)
      storage.withUnsafeBytes { XCTAssertEqual($0.count, 0) }
      try storage.withUnsafeMutableBytes { bytes in
        XCTAssertEqual(bytes.count, 8)
        bytes[0] = 0x41
        bytes[1] = 0x42
        return 2
      }
      XCTAssertEqual(storage.count, 2)
      storage.withUnsafeBytes { XCTAssertEqual(Array($0), [0x41, 0x42]) }
      for invalidCount in [-1, 9] {
        XCTAssertThrowsError(try storage.withUnsafeMutableBytes { _ in invalidCount }) {
          XCTAssertEqual($0 as? USDCFailure, .malformed(.invalidRange))
        }
        XCTAssertEqual(storage.count, 2)
      }
      XCTAssertEqual(ledger.usdcLiveBytes, 8)
    }
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
    let empty = try USDCStorage.allocate(byteCount: 0, ledger: ledger)
    XCTAssertEqual(empty.capacity, 0)
    try empty.withUnsafeMutableBytes {
      XCTAssertEqual($0.count, 0)
      return 0
    }
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
  }

  // Overflow and oversized tables must never wrap to a cheap allocation.
  func testCheckedTableByteCountsRejectOverflowAndItemExcess() throws {
    XCTAssertEqual(try USDCStorage.checkedByteCount(count: 250_000, stride: 16), 4_000_000)
    XCTAssertEqual(try USDCStorage.checkedByteCount(count: 1, stride: 67_108_864), 67_108_864)
    for (count, stride, resource): (UInt64, UInt64, SafetyResource) in [
      (250_001, 1, .usdcItems), (2, .max, .usdcWorkingBytes),
      (1, 67_108_865, .usdcWorkingBytes), (1, UInt64(Int.max) + 1, .usdcWorkingBytes),
    ] {
      XCTAssertThrowsError(try USDCStorage.checkedByteCount(count: count, stride: stride)) {
        XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(resource))
      }
    }
  }

  // USDC ceilings stop reference coverage without contaminating unrelated native areas.
  func testUSDCLimitsMarkOnlyReferenceCoveragePartial() {
    for resource: SafetyResource in [
      .usdcMetadataBlockBytes, .usdcDecodeBytes, .usdcWorkingBytes,
      .usdcItems, .usdcWork, .usdcDepth,
    ] {
      let diagnostics = NativeDiagnostics()
      for area in CoverageArea.allCases { diagnostics.complete(area: area) }
      diagnostics.limit(resource, location: nil)
      let (findings, coverage) = diagnostics.finish()
      XCTAssertEqual(findings.count, 1)
      XCTAssertEqual(findings[0].ruleID, "UVK-RES-001")
      XCTAssertEqual(coverage.areas[.references]?.state, .partial)
      XCTAssertEqual(coverage.areas[.containerStructure]?.state, .complete)
      XCTAssertEqual(coverage.areas[.entrySafety]?.state, .complete)
    }
  }
}

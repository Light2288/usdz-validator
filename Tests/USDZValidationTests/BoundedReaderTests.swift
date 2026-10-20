import Foundation
import XCTest

@testable import USDZValidation

final class BoundedReaderTests: XCTestCase {
  func testCheckedRangesBeforeIO() throws {
    var calls = 0
    let ledger = ResourceLedger()
    let reader = BoundedReader(size: 8, ledger: ledger) { _, count in
      calls += 1
      return Data(repeating: 0x41, count: count)
    }
    for (offset, count) in [(UInt64.max, 1), (0, -1), (9, 0), (7, 2), (0, Int.max)] {
      XCTAssertThrowsError(try reader.read(offset: offset, count: count)) { error in
        XCTAssertEqual(error as? InspectionFailure, .malformedRange)
      }
    }
    XCTAssertEqual(calls, 0)
    XCTAssertEqual(ledger.totalReadBytes, 0)
    XCTAssertEqual(try reader.read(offset: 8, count: 0), Data())
    XCTAssertEqual(calls, 0)
    XCTAssertEqual(try reader.read(offset: 7, count: 1), Data([0x41]))
    XCTAssertEqual(calls, 1)
    XCTAssertEqual(ledger.totalReadBytes, 1)

    let shortReader = BoundedReader(size: 8, ledger: ledger) { _, _ in Data([0]) }
    XCTAssertThrowsError(try shortReader.read(offset: 0, count: 2)) { error in
      XCTAssertEqual(error as? InspectionFailure, .shortRead)
    }
    let longReader = BoundedReader(size: 8, ledger: ledger) { _, _ in Data([0, 1, 2]) }
    XCTAssertThrowsError(try longReader.read(offset: 0, count: 2)) { error in
      XCTAssertEqual(error as? InspectionFailure, .shortRead)
    }
  }

  func testChunkAndCumulativeBoundaries() throws {
    let ledger = ResourceLedger()
    var calls = 0
    let reader = BoundedReader(size: 536_870_912, ledger: ledger) { _, count in
      calls += 1
      XCTAssertLessThanOrEqual(count, 65_536)
      return Data(repeating: 0, count: count)
    }
    XCTAssertEqual(try reader.read(offset: 0, count: 65_536).count, 65_536)
    XCTAssertThrowsError(try reader.read(offset: 0, count: 65_537)) { error in
      XCTAssertEqual(error as? InspectionFailure, .resourceLimit(.readChunkBytes))
    }
    XCTAssertEqual(calls, 1)
    // Charge prior logical reads without allocating their bytes.
    try ledger.consumeRead(1_207_894_015)
    XCTAssertEqual(try reader.read(offset: 0, count: 1).count, 1)
    XCTAssertEqual(ledger.totalReadBytes, 1_207_959_552)
    XCTAssertThrowsError(try reader.read(offset: 0, count: 1)) { error in
      XCTAssertEqual(error as? InspectionFailure, .resourceLimit(.totalReadBytes))
    }
    XCTAssertEqual(calls, 2)
    XCTAssertEqual(ledger.totalReadBytes, 1_207_959_552)
  }

  func testOversizedArchiveAndOperationalFailure() {
    var calls = 0
    let reader = BoundedReader(size: 536_870_913, ledger: ResourceLedger()) { _, _ in
      calls += 1
      return Data()
    }
    XCTAssertThrowsError(try reader.read(offset: 0, count: 1)) { error in
      XCTAssertEqual(error as? InspectionFailure, .resourceLimit(.archiveBytes))
    }
    XCTAssertEqual(calls, 0)
    let failed = BoundedReader(size: 1, ledger: ResourceLedger()) { _, _ in
      throw ValidationError.operational(.inputReadFailed)
    }
    XCTAssertThrowsError(try failed.read(offset: 0, count: 1)) { error in
      XCTAssertEqual(error as? ValidationError, .operational(.inputReadFailed))
    }
  }
}

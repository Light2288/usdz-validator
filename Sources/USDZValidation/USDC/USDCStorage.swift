import Foundation

/// Raw storage avoids hidden capacity growth and copy-on-write copies in metadata tables.
final class USDCStorage {
  let capacity: Int
  private(set) var count: Int = 0
  private let pointer: UnsafeMutableRawPointer?
  private let reservation: USDCStorageReservation

  private init(
    capacity: Int, pointer: UnsafeMutableRawPointer?, reservation: USDCStorageReservation
  ) {
    self.capacity = capacity
    self.pointer = pointer
    self.reservation = reservation
  }

  static func allocate(
    byteCount: UInt64, ledger: ResourceLedger,
    allocator: (Int) throws -> UnsafeMutableRawPointer = {
      UnsafeMutableRawPointer.allocate(byteCount: $0, alignment: 16)
    }
  ) throws -> USDCStorage {
    let reservation = try ledger.reserveUSDCStorage(byteCount)
    do {
      guard let capacity = Int(exactly: byteCount) else {
        throw InspectionFailure.resourceLimit(.usdcWorkingBytes)
      }
      let pointer = capacity == 0 ? nil : try allocator(capacity)
      return USDCStorage(capacity: capacity, pointer: pointer, reservation: reservation)
    } catch {
      reservation.release()
      throw error
    }
  }

  /// Every table and scratch allocation uses checked count × stride before allocation.
  static func checkedByteCount(count: UInt64, stride: UInt64) throws -> UInt64 {
    guard count <= SafetyResource.usdcItems.limit else {
      throw InspectionFailure.resourceLimit(.usdcItems)
    }
    let (bytes, overflow) = count.multipliedReportingOverflow(by: stride)
    guard !overflow, bytes <= SafetyResource.usdcWorkingBytes.limit,
      Int(exactly: bytes) != nil
    else { throw InspectionFailure.resourceLimit(.usdcWorkingBytes) }
    return bytes
  }

  func withUnsafeBytes<Result>(
    _ body: (UnsafeRawBufferPointer) throws -> Result
  ) rethrows -> Result {
    try body(UnsafeRawBufferPointer(start: pointer, count: count))
  }

  /// The writer returns the initialized prefix; reads never expose unwritten capacity.
  func withUnsafeMutableBytes(
    _ body: (UnsafeMutableRawBufferPointer) throws -> Int
  ) throws {
    let initialized = try body(UnsafeMutableRawBufferPointer(start: pointer, count: capacity))
    guard initialized >= 0, initialized <= capacity else {
      throw USDCFailure.malformed(.invalidRange)
    }
    count = initialized
  }

  deinit {
    pointer?.deallocate()
    reservation.release()
  }
}

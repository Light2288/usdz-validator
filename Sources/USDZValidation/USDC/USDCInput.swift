import Foundation

/// Fixed reason codes never retain authored content or underlying system diagnostics.
enum USDCGapReason: String, Equatable {
  case unsupportedVersion
  case unsupportedSection
  case unsupportedEncoding
  case unsupportedValue
}

enum USDCCorruptionReason: String, Equatable {
  case invalidRange
  case invalidHeader
  case invalidSection
  case invalidCompression
  case invalidTable
  case invalidIndex
  case invalidValue
  case invalidPath
  case invalidGraph
}

enum USDCFailure: Error, Equatable {
  case unsupported(USDCGapReason)
  case malformed(USDCCorruptionReason)
}

/// Layer-relative reads keep staging capacity charged for the entire borrowed lifetime.
struct USDCInput {
  let entry: ZIPEntry
  let reader: BoundedReader

  /// Data does not expose capacity: charge twice the requested payload plus 256 bytes
  /// for staging overhead. This is conservative accounting, not a Foundation/RSS bound.
  static func stagingCapacity(byteCount: UInt64) throws -> UInt64 {
    guard byteCount <= SafetyResource.readChunkBytes.limit else {
      throw InspectionFailure.resourceLimit(.readChunkBytes)
    }
    guard byteCount > 0 else { return 0 }
    let (doubled, multiplicationOverflow) = byteCount.multipliedReportingOverflow(by: 2)
    let (capacity, additionOverflow) = doubled.addingReportingOverflow(256)
    guard !multiplicationOverflow, !additionOverflow else {
      throw InspectionFailure.resourceLimit(.usdcWorkingBytes)
    }
    return capacity
  }

  /// A retained copy must obtain its own storage reservation before copying these bytes.
  func withBytes<Result>(
    offset: UInt64, count: Int, _ body: (UnsafeRawBufferPointer) throws -> Result
  ) throws -> Result {
    guard let bytes = UInt64(exactly: count) else {
      throw USDCFailure.malformed(.invalidRange)
    }
    let payload = entry.payloadRange
    let size = payload.upperBound - payload.lowerBound
    let (end, overflow) = offset.addingReportingOverflow(bytes)
    guard !overflow, end <= size, payload.upperBound <= reader.size else {
      throw USDCFailure.malformed(.invalidRange)
    }
    let (absoluteOffset, absoluteOverflow) = payload.lowerBound.addingReportingOverflow(offset)
    guard !absoluteOverflow else { throw USDCFailure.malformed(.invalidRange) }
    let capacity = try Self.stagingCapacity(byteCount: bytes)
    let reservation = try reader.ledger.reserveUSDCStorage(capacity)
    defer { reservation.release() }
    // The inner scope destroys staging before the outer reservation is released.
    return try { () throws -> Result in
      let data = try reader.read(offset: absoluteOffset, count: count)
      return try data.withUnsafeBytes(body)
    }()
  }
}

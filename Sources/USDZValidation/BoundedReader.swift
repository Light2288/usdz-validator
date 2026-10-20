import Foundation

struct BoundedReader {
  let size: UInt64
  private let ledger: ResourceLedger
  private let readAt: (UInt64, Int) throws -> Data

  init(size: UInt64, ledger: ResourceLedger, readAt: @escaping (UInt64, Int) throws -> Data) {
    self.size = size
    self.ledger = ledger
    self.readAt = readAt
  }

  func read(offset: UInt64, count: Int) throws -> Data {
    guard let bytes = UInt64(exactly: count) else { throw InspectionFailure.malformedRange }
    let (end, overflow) = offset.addingReportingOverflow(bytes)
    guard !overflow, end <= size else { throw InspectionFailure.malformedRange }
    try ledger.check(resource: .archiveBytes, value: size)
    try ledger.check(resource: .readChunkBytes, value: bytes)
    guard count > 0 else { return Data() }
    // Charge before the source can allocate or issue I/O, including failed/short attempts.
    try ledger.consumeRead(bytes)
    let data = try readAt(offset, count)
    guard data.count == count else { throw InspectionFailure.shortRead }
    return data
  }
}

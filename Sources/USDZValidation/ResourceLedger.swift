import Foundation

/// Fixed safety envelope v2. Warning configuration never changes these ceilings.
enum SafetyResource: String, CaseIterable {
  case archiveBytes, entryCount, centralDirectoryBytes, entryBytes, aggregateEntryBytes
  case textLayerBytes, entryNameBytes, tokenBytes, tokenCount, readChunkBytes
  case textureHeaderBytes, totalReadBytes, findings, messageBytes, evidenceStringBytes
  case configurationBytes, reportBytes
  case usdcMetadataBlockBytes, usdcDecodeBytes, usdcWorkingBytes, usdcItems, usdcWork, usdcDepth

  var limit: UInt64 {
    switch self {
    case .archiveBytes, .aggregateEntryBytes: 536_870_912
    case .entryBytes: 268_435_456
    case .centralDirectoryBytes, .textLayerBytes, .usdcMetadataBlockBytes: 16_777_216
    case .entryCount, .findings: 10_000
    case .entryNameBytes, .tokenBytes, .evidenceStringBytes: 4_096
    case .tokenCount: 100_000
    case .readChunkBytes, .configurationBytes: 65_536
    case .textureHeaderBytes: 1_048_576
    case .totalReadBytes: 1_207_959_552
    case .messageBytes: 1_024
    case .reportBytes, .usdcDecodeBytes: 33_554_432
    case .usdcWorkingBytes: 67_108_864
    case .usdcItems: 250_000
    case .usdcWork: 2_000_000
    case .usdcDepth: 32
    }
  }
}

/// Content-range failures become findings; descriptor failures remain ValidationError values.
/// The texture-header scan stop is mapped to UVK-LIM-005 rather than a hard resource error.
enum InspectionFailure: Error, Equatable {
  case malformedRange
  case shortRead
  case resourceLimit(SafetyResource)
}

/// Shared by every native reader/scanner in one synchronous invocation.
final class ResourceLedger {
  private(set) var totalReadBytes: UInt64 = 0
  private var totalTokens: UInt64 = 0
  private(set) var usdcLiveBytes: UInt64 = 0
  private(set) var usdcDecodeBytes: UInt64 = 0
  private(set) var usdcWorkUnits: UInt64 = 0

  func check(resource: SafetyResource, value: UInt64) throws {
    guard value <= resource.limit else { throw InspectionFailure.resourceLimit(resource) }
  }

  func consumeRead(_ bytes: UInt64) throws {
    let (total, overflow) = totalReadBytes.addingReportingOverflow(bytes)
    guard !overflow else { throw InspectionFailure.resourceLimit(.totalReadBytes) }
    try check(resource: .totalReadBytes, value: total)
    totalReadBytes = total
  }

  func consumeTokens(_ count: UInt64) throws {
    let (total, overflow) = totalTokens.addingReportingOverflow(count)
    guard !overflow else { throw InspectionFailure.resourceLimit(.tokenCount) }
    try check(resource: .tokenCount, value: total)
    totalTokens = total
  }

  /// Decoded capacity is cumulative across layers, including abandoned decode attempts.
  func reserveUSDCDecode(_ capacity: UInt64) throws {
    let (total, overflow) = usdcDecodeBytes.addingReportingOverflow(capacity)
    guard !overflow else { throw InspectionFailure.resourceLimit(.usdcDecodeBytes) }
    try check(resource: .usdcDecodeBytes, value: total)
    usdcDecodeBytes = total
  }

  func consumeUSDCWork(_ units: UInt64) throws {
    let (total, overflow) = usdcWorkUnits.addingReportingOverflow(units)
    guard !overflow else { throw InspectionFailure.resourceLimit(.usdcWork) }
    try check(resource: .usdcWork, value: total)
    usdcWorkUnits = total
  }

  func reserveUSDCStorage(_ bytes: UInt64) throws -> USDCStorageReservation {
    let (total, overflow) = usdcLiveBytes.addingReportingOverflow(bytes)
    guard !overflow else { throw InspectionFailure.resourceLimit(.usdcWorkingBytes) }
    try check(resource: .usdcWorkingBytes, value: total)
    usdcLiveBytes = total
    return USDCStorageReservation(bytes: bytes, ledger: self)
  }

  fileprivate func releaseUSDCStorage(_ bytes: UInt64) {
    usdcLiveBytes -= bytes
  }
}

/// Owns one live charge. Cumulative decode, work and occurrence counters are never refunded.
final class USDCStorageReservation {
  private var bytes: UInt64
  private let ledger: ResourceLedger

  fileprivate init(bytes: UInt64, ledger: ResourceLedger) {
    self.bytes = bytes
    self.ledger = ledger
  }

  func release() {
    let released = bytes
    bytes = 0
    ledger.releaseUSDCStorage(released)
  }

  deinit { release() }
}

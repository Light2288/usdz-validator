import Foundation

enum StoredPayload {
  /// Call only after trusted local mapping (and, in the engine, safe namespace validation).
  /// A true result permits content inspection; this stage never completes engine coverage.
  static func check(entry: ZIPEntry, reader: BoundedReader, diagnostics: NativeDiagnostics) throws
    -> Bool
  {
    let location = FindingLocation(archiveByteOffset: entry.payloadRange.lowerBound)
    let contentEligible = checkMetadata(entry: entry, diagnostics: diagnostics)
    do {
      // Repeat per-entry eligibility at this boundary, even for direct internal callers.
      // Aggregate declarations belong to ZIPDirectory, which sees the whole archive.
      guard reader.size <= SafetyResource.archiveBytes.limit else {
        throw InspectionFailure.resourceLimit(.archiveBytes)
      }
      guard entry.compressedSize <= SafetyResource.entryBytes.limit,
        entry.uncompressedSize <= SafetyResource.entryBytes.limit
      else { throw InspectionFailure.resourceLimit(.entryBytes) }
      guard contentEligible else { return false }
      let payload = entry.payloadRange
      guard payload.upperBound <= reader.size,
        payload.upperBound - payload.lowerBound == entry.compressedSize,
        entry.recordRange.lowerBound == entry.localHeaderOffset,
        entry.headerRange.lowerBound == entry.recordRange.lowerBound,
        entry.headerRange.upperBound == payload.lowerBound,
        entry.recordRange.upperBound == payload.upperBound
      else { throw InspectionFailure.malformedRange }
      var crc = StreamingCRC32()
      var offset = payload.lowerBound
      while offset < payload.upperBound {
        let count = Int(min(SafetyResource.readChunkBytes.limit, payload.upperBound - offset))
        crc.update(try reader.read(offset: offset, count: count))
        // Subtraction above proves this addition cannot wrap or leave the payload range.
        offset += UInt64(count)
      }
      guard crc.value == entry.crc32 else {
        emit(
          "UVK-ARC-003", entry: entry, diagnostics: diagnostics,
          message: "The stored payload CRC does not match its recorded value.", reason: "crc32",
          evidence: [
            "recordedCRC32": .integer(Int64(entry.crc32)),
            "observedCRC32": .integer(Int64(crc.value)),
          ])
        return false
      }
      return entry.payloadRange.lowerBound % 64 == 0
    } catch let failure as InspectionFailure {
      switch failure {
      case .resourceLimit(let resource): diagnostics.limit(resource, location: location)
      case .malformedRange, .shortRead:
        emit(
          "UVK-ARC-001", entry: entry, diagnostics: diagnostics,
          message: "The stored payload range is malformed or truncated.", reason: "payloadRead")
      }
      return false
    }
  }

  /// Metadata-only prerequisite checks for text-size preflight. Alignment remains
  /// a known finding even when a processing ceiling forbids the later CRC read.
  /// A true result permits CRC work; it does not establish alignment or integrity.
  static func checkMetadata(entry: ZIPEntry, diagnostics: NativeDiagnostics) -> Bool {
    var stored = true
    if entry.method != 0 || entry.compressedSize != entry.uncompressedSize {
      emit(
        "UVK-ARC-004", entry: entry, diagnostics: diagnostics,
        message: "The entry is not stored with equal encoded and uncompressed sizes.",
        reason: "storage", evidence: ["method": .integer(Int64(entry.method))])
      stored = false
    }
    if entry.flags & 1 != 0 {
      emit(
        "UVK-ARC-005", entry: entry, diagnostics: diagnostics,
        message: "The entry is encrypted.", reason: "encryption")
      stored = false
    }
    if entry.flags & ~UInt16(0x0801) != 0 || entry.record.versionNeeded > 20
      || entry.record.diskNumber != 0
    {
      emit(
        "UVK-LIM-001", entry: entry, diagnostics: diagnostics,
        message: "The entry requires unsupported ZIP interpretation.", reason: "payloadMetadata")
      stored = false
    }
    let regular = isKnownRegular(entry)
    let aligned = entry.payloadRange.lowerBound % 64 == 0
    if regular && !aligned {
      emit(
        "UVK-ARC-006", entry: entry, diagnostics: diagnostics,
        message: "The regular-file payload is not 64-byte aligned.", reason: "alignment")
    }
    return stored && regular
  }

  /// Applicability only: Task 8 owns authoritative namespace/type diagnostics.
  /// Unknown host semantics and non-regular Unix types never grant content eligibility.
  private static func isKnownRegular(_ entry: ZIPEntry) -> Bool {
    let host = entry.versionMadeBy >> 8
    guard host == 0 || host == 3 else { return false }
    if host == 3 {
      let type = (entry.externalAttributes >> 16) & 0o170000
      if type != 0 { return type == 0o100000 }
    }
    return entry.externalAttributes & 0x10 == 0
  }

  private static func emit(
    _ ruleID: String, entry: ZIPEntry, diagnostics: NativeDiagnostics,
    message: String, reason: String, evidence: [String: EvidenceValue] = [:]
  ) {
    diagnostics.emit(
      ruleID: ruleID, message: message, evidence: evidence,
      location: FindingLocation(archiveByteOffset: entry.payloadRange.lowerBound),
      key: FindingKey(
        ruleID: ruleID, entryNameBytes: entry.nameBytes, entryOffset: entry.localHeaderOffset,
        contentOffset: entry.payloadRange.lowerBound, discriminator: reason))
  }
}

/// CRC-32/ISO-HDLC state is fixed size, independent of the payload length.
private struct StreamingCRC32 {
  private var state: UInt32 = 0xffff_ffff
  private static let table: [UInt32] = (0..<256).map { byte in
    var value = UInt32(byte)
    for _ in 0..<8 { value = (value >> 1) ^ (value & 1 == 1 ? 0xedb8_8320 : 0) }
    return value
  }

  mutating func update(_ chunk: Data) {
    for byte in chunk {
      state = (state >> 8) ^ Self.table[Int((state ^ UInt32(byte)) & 0xff)]
    }
  }

  var value: UInt32 { state ^ 0xffff_ffff }
}

import Foundation

struct ZIPEntry {
  let record: ZIPDirectory.Record
  let recordRange: Range<UInt64>
  let headerRange: Range<UInt64>
  let payloadRange: Range<UInt64>

  var nameBytes: Data { record.nameBytes }
  var flags: UInt16 { record.flags }
  var method: UInt16 { record.method }
  var crc32: UInt32 { record.crc32 }
  var compressedSize: UInt64 { record.compressedSize }
  var uncompressedSize: UInt64 { record.uncompressedSize }
  var localHeaderOffset: UInt64 { record.localHeaderOffset }
  var versionMadeBy: UInt16 { record.versionMadeBy }
  var externalAttributes: UInt32 { record.externalAttributes }
}

struct ZIPIndex {
  let entries: [ZIPEntry]

  static func build(directory: ZIPDirectory, reader: BoundedReader, diagnostics: NativeDiagnostics)
    throws -> ZIPIndex?
  {
    do {
      let records = directory.records.sorted { $0.localHeaderOffset < $1.localHeaderOffset }
      var entries: [ZIPEntry] = []
      entries.reserveCapacity(records.count)
      for (index, record) in records.enumerated() {
        let start = record.localHeaderOffset
        if index > 0, records[index - 1].localHeaderOffset == start {
          throw Failure.ownership("duplicateLocalHeader", start)
        }
        let boundary =
          index + 1 < records.count
          ? records[index + 1].localHeaderOffset : directory.centralDirectoryRange.lowerBound
        entries.append(try map(record, boundary: boundary, reader: reader))
      }
      var cursor: UInt64 = 0
      for entry in entries {
        if cursor < entry.recordRange.lowerBound {
          try rejectGap(cursor..<entry.recordRange.lowerBound, reader: reader)
        }
        // Every interval was checked against the next local header and the directory.
        cursor = entry.recordRange.upperBound
      }
      if cursor < directory.centralDirectoryRange.lowerBound {
        try rejectGap(cursor..<directory.centralDirectoryRange.lowerBound, reader: reader)
      }
      return ZIPIndex(entries: entries)
    } catch let failure as Failure {
      let ruleID: String
      let reason: String
      let offset: UInt64
      switch failure {
      case .malformed(let field, let position):
        (ruleID, reason, offset) = ("UVK-ARC-001", field, position)
      case .ownership(let field, let position):
        (ruleID, reason, offset) = ("UVK-ARC-002", field, position)
      case .unsupported(let field, let position):
        (ruleID, reason, offset) = ("UVK-LIM-001", field, position)
      }
      recordFailure(diagnostics, ruleID: ruleID, reason: reason, offset: offset)
      return nil
    } catch let failure as InspectionFailure {
      switch failure {
      case .resourceLimit(let resource): diagnostics.limit(resource, location: nil)
      case .malformedRange, .shortRead:
        recordFailure(diagnostics, ruleID: "UVK-ARC-001", reason: "localRead", offset: nil)
      }
      return nil
    }
  }

  private enum Failure: Error {
    case malformed(String, UInt64)
    case ownership(String, UInt64)
    case unsupported(String, UInt64)
  }

  private static func map(
    _ record: ZIPDirectory.Record, boundary: UInt64, reader: BoundedReader
  ) throws -> ZIPEntry {
    let start = record.localHeaderOffset
    let fixedEnd = try adding(start, 30, at: start)
    guard fixedEnd <= reader.size else { throw Failure.malformed("localHeader", start) }
    guard fixedEnd <= boundary else { throw Failure.ownership("headerOverlap", start) }
    let header = try reader.read(offset: start, count: 30)
    guard u32(header, 0) == 0x0403_4b50 else {
      throw Failure.malformed("localSignature", start)
    }
    let nameLength = UInt64(u16(header, 26))
    let nameEnd = try adding(fixedEnd, nameLength, at: start)
    let payloadStart = try adding(nameEnd, UInt64(u16(header, 28)), at: start)
    guard payloadStart <= reader.size else { throw Failure.malformed("localFields", start) }
    guard u16(header, 4) == record.versionNeeded, u16(header, 6) == record.flags,
      u16(header, 8) == record.method, u16(header, 10) == record.modificationTime,
      u16(header, 12) == record.modificationDate, u32(header, 14) == record.crc32,
      UInt64(u32(header, 18)) == record.compressedSize,
      UInt64(u32(header, 22)) == record.uncompressedSize,
      nameLength == UInt64(record.nameBytes.count)
    else { throw Failure.ownership("localFieldsDisagree", start) }
    let payloadEnd = try adding(payloadStart, record.compressedSize, at: start)
    guard payloadEnd <= boundary else { throw Failure.ownership("recordOverlap", start) }
    let name = try reader.read(offset: fixedEnd, count: Int(nameLength))
    guard name == record.nameBytes else { throw Failure.ownership("localNameDisagrees", start) }
    try inspectExtras(nameEnd..<payloadStart, reader: reader)
    return ZIPEntry(
      record: record, recordRange: start..<payloadEnd, headerRange: start..<payloadStart,
      payloadRange: payloadStart..<payloadEnd)
  }

  /// Only the record boundary is inspected. A known payload is never searched for markers.
  /// A complete unindexed local record establishes contradictory ownership; arbitrary
  /// prefixes and gaps do not establish a member and remain unsupported layouts.
  private static func rejectGap(_ range: Range<UInt64>, reader: BoundedReader) throws {
    let start = range.lowerBound
    guard range.count >= 4,
      u32(try reader.read(offset: start, count: 4), 0) == 0x0403_4b50
    else { throw Failure.unsupported("recordLayout", start) }
    guard range.count >= 30 else { throw Failure.malformed("unindexedHeader", start) }
    let header = try reader.read(offset: start + 4, count: 26)
    // This header omits the already-read signature, so its fields are shifted by four.
    let nameEnd = try adding(start + 30, UInt64(u16(header, 22)), at: start)
    let payloadStart = try adding(nameEnd, UInt64(u16(header, 24)), at: start)
    guard payloadStart <= range.upperBound else {
      throw Failure.malformed("unindexedFields", start)
    }
    try inspectExtras(nameEnd..<payloadStart, reader: reader)
    if u16(header, 0) > 20 || u16(header, 2) & ~UInt16(0x0801) != 0
      || u32(header, 14) == .max || u32(header, 18) == .max
    {
      throw Failure.unsupported("unindexedFeature", start)
    }
    let payloadEnd = try adding(payloadStart, UInt64(u32(header, 14)), at: start)
    guard payloadEnd <= range.upperBound else {
      throw Failure.ownership("unindexedOverlap", start)
    }
    throw Failure.ownership("unindexedLocalHeader", start)
  }

  private static func inspectExtras(_ range: Range<UInt64>, reader: BoundedReader) throws {
    var cursor = range.lowerBound
    var zip64 = false
    while cursor < range.upperBound {
      guard range.upperBound - cursor >= 4 else {
        throw Failure.malformed("localExtraField", cursor)
      }
      let header = try reader.read(offset: cursor, count: 4)
      let next = try adding(cursor + 4, UInt64(u16(header, 2)), at: cursor)
      guard next <= range.upperBound else { throw Failure.malformed("localExtraField", cursor) }
      zip64 = zip64 || u16(header, 0) == 1
      cursor = next
    }
    if zip64 { throw Failure.unsupported("localZip64Extra", range.lowerBound) }
  }

  private static func adding(_ left: UInt64, _ right: UInt64, at offset: UInt64) throws -> UInt64 {
    let (sum, overflow) = left.addingReportingOverflow(right)
    guard !overflow else { throw Failure.malformed("localOverflow", offset) }
    return sum
  }

  private static func recordFailure(
    _ diagnostics: NativeDiagnostics, ruleID: String, reason: String, offset: UInt64?
  ) {
    let location = offset.map { FindingLocation(archiveByteOffset: $0) }
    diagnostics.emit(
      ruleID: ruleID,
      message: ruleID == "UVK-LIM-001"
        ? "ZIP local records use an unsupported feature or layout."
        : "ZIP local records are malformed or have contradictory ownership.",
      evidence: ["reason": .string(reason)], location: location,
      key: FindingKey(
        ruleID: ruleID, entryNameBytes: nil, entryOffset: nil, contentOffset: offset,
        discriminator: reason))
    let coverageReason = CoverageReason(ruleID: ruleID, reasonID: reason, location: location)
    diagnostics.mark(area: .containerStructure, state: .partial, reason: coverageReason)
    for area in CoverageArea.allCases where area != .containerStructure {
      diagnostics.mark(area: area, state: .notRun, reason: coverageReason)
    }
  }

  private static func u16(_ bytes: Data, _ offset: Int) -> UInt16 {
    let start = bytes.startIndex + offset
    return UInt16(bytes[start]) | UInt16(bytes[start + 1]) << 8
  }

  private static func u32(_ bytes: Data, _ offset: Int) -> UInt32 {
    UInt32(u16(bytes, offset)) | UInt32(u16(bytes, offset + 2)) << 16
  }
}

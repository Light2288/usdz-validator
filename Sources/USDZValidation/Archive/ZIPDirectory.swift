import Foundation

struct ZIPDirectory {
  struct Record {
    let nameBytes: Data
    let versionMadeBy: UInt16
    let versionNeeded: UInt16
    let flags: UInt16
    let method: UInt16
    let modificationTime: UInt16
    let modificationDate: UInt16
    let crc32: UInt32
    let compressedSize: UInt64
    let uncompressedSize: UInt64
    let diskNumber: UInt16
    let internalAttributes: UInt16
    let externalAttributes: UInt32
    let localHeaderOffset: UInt64
    let centralHeaderOffset: UInt64
  }

  let records: [Record]
  let centralDirectoryRange: Range<UInt64>
  let endRecordOffset: UInt64
  let archiveCommentLength: UInt16

  /// Discovers bounded metadata only. The EOCD search may overlap content in a small
  /// archive; no member is opened, decoded, decompressed, or CRC-scanned here.
  static func read(from reader: BoundedReader, diagnostics: NativeDiagnostics) throws
    -> ZIPDirectory?
  {
    do {
      try check(.archiveBytes, reader.size)
      guard reader.size >= 22 else { throw Failure.malformed("endRecord", nil) }
      let tailLength = min(reader.size, 65_557)
      let tailOffset = reader.size - tailLength
      var tail = Data()
      tail.reserveCapacity(Int(tailLength))
      var position = tailOffset
      while position < reader.size {
        let count = Int(min(65_536, reader.size - position))
        tail.append(try reader.read(offset: position, count: count))
        position += UInt64(count)
      }
      guard let endIndex = try endRecord(in: tail, offset: tailOffset, reader: reader) else {
        throw Failure.malformed("endRecord", nil)
      }
      let endOffset = tailOffset + UInt64(endIndex)
      let disk = u16(tail, endIndex + 4)
      let directoryDisk = u16(tail, endIndex + 6)
      let diskCount = u16(tail, endIndex + 8)
      let count = u16(tail, endIndex + 10)
      let directorySize = u32(tail, endIndex + 12)
      let directoryOffset = u32(tail, endIndex + 16)
      let commentLength = u16(tail, endIndex + 20)
      // These markers change the meaning of classic counts/offsets. Recognize them
      // before testing classic range/count assumptions or their resource ceilings.
      if let locator = try zip64Locator(
        before: endOffset, tail: tail, offset: tailOffset, reader: reader)
      {
        throw Failure.unsupported("zip64Locator", locator)
      }
      if diskCount == .max || count == .max || directorySize == .max || directoryOffset == .max {
        throw Failure.unsupported("zip64EndRecord", endOffset)
      }
      if disk != 0 || directoryDisk != 0 {
        throw Failure.unsupported("multipleDisks", endOffset)
      }
      guard diskCount == count else { throw Failure.malformed("entryCount", endOffset) }
      try check(.entryCount, UInt64(count))
      let start = UInt64(directoryOffset)
      let end = try adding(start, UInt64(directorySize), at: endOffset)
      guard end <= endOffset else { throw Failure.malformed("directoryRange", endOffset) }
      guard end == endOffset else { throw Failure.unsupported("directoryLayout", endOffset) }
      try check(.centralDirectoryBytes, UInt64(directorySize))
      guard UInt64(count) * 46 <= UInt64(directorySize) else {
        throw Failure.malformed("entryCount", endOffset)
      }
      var records: [Record] = []
      records.reserveCapacity(Int(count))
      var cursor = start
      var declaredTotal: UInt64 = 0
      for _ in 0..<count {
        let fixedEnd = try adding(cursor, 46, at: cursor)
        guard fixedEnd <= end else { throw Failure.malformed("centralHeader", cursor) }
        let header = try reader.read(offset: cursor, count: 46)
        guard u32(header, 0) == 0x0201_4b50 else {
          throw Failure.malformed("centralSignature", cursor)
        }
        let nameLength = UInt64(u16(header, 28))
        let extraLength = UInt64(u16(header, 30))
        let entryCommentLength = UInt64(u16(header, 32))
        let nameEnd = try adding(fixedEnd, nameLength, at: cursor)
        let extraEnd = try adding(nameEnd, extraLength, at: cursor)
        let recordEnd = try adding(extraEnd, entryCommentLength, at: cursor)
        // A bounded fixed header can prove truncation independently of unsupported
        // versions, flags, or ZIP64 sentinels in its other fields.
        guard recordEnd <= end else { throw Failure.malformed("centralFields", cursor) }
        try check(.entryNameBytes, nameLength)
        let name = try reader.read(offset: fixedEnd, count: Int(nameLength))
        let zip64Extra = try inspectExtras(reader: reader, start: nameEnd, end: extraEnd)
        let versionNeeded = u16(header, 6)
        let flags = u16(header, 8)
        let compressedSize = u32(header, 20)
        let uncompressedSize = u32(header, 24)
        let memberDisk = u16(header, 34)
        let localOffset = u32(header, 42)
        if zip64Extra || compressedSize == .max || uncompressedSize == .max
          || localOffset == .max || memberDisk == .max
        {
          throw Failure.unsupported("zip64Member", cursor)
        }
        if memberDisk != 0 { throw Failure.unsupported("multipleDisks", cursor) }
        if versionNeeded > 20 { throw Failure.unsupported("requiredVersion", cursor) }
        // Traditional encryption remains metadata-readable and is rejected by the
        // payload policy. Descriptors and all other interpretation flags stop mapping.
        if flags & ~UInt16(0x0801) != 0 {
          throw Failure.unsupported(flags & 8 != 0 ? "dataDescriptor" : "flags", cursor)
        }
        if flags & 0x0800 != 0 {
          guard String(data: name, encoding: .utf8) != nil else {
            throw Failure.invalidName(cursor)
          }
        } else if name.contains(where: { $0 > 0x7f }) {
          throw Failure.unsupported("nameEncoding", cursor)
        }
        guard UInt64(localOffset) < start else {
          throw Failure.malformed("localOffset", cursor)
        }
        // Count all declarations, including compressed members that later policy
        // rejects. No compressed size or ratio can exempt bytes from this envelope.
        try check(.entryBytes, UInt64(compressedSize))
        try check(.entryBytes, UInt64(uncompressedSize))
        declaredTotal = try adding(declaredTotal, UInt64(uncompressedSize), at: cursor)
        try check(.aggregateEntryBytes, declaredTotal)
        records.append(
          Record(
            nameBytes: name, versionMadeBy: u16(header, 4), versionNeeded: versionNeeded,
            flags: flags, method: u16(header, 10), modificationTime: u16(header, 12),
            modificationDate: u16(header, 14), crc32: u32(header, 16),
            compressedSize: UInt64(compressedSize), uncompressedSize: UInt64(uncompressedSize),
            diskNumber: memberDisk, internalAttributes: u16(header, 36),
            externalAttributes: u32(header, 38), localHeaderOffset: UInt64(localOffset),
            centralHeaderOffset: cursor))
        cursor = recordEnd
      }
      guard cursor == end else { throw Failure.malformed("directoryCount", cursor) }
      return ZIPDirectory(
        records: records, centralDirectoryRange: start..<end,
        endRecordOffset: endOffset, archiveCommentLength: commentLength)
    } catch let failure as Failure {
      let ruleID: String
      let reason: String
      let offset: UInt64?
      switch failure {
      case .malformed(let field, let position):
        (ruleID, reason, offset) = ("UVK-ARC-001", field, position)
      case .unsupported(let feature, let position):
        (ruleID, reason, offset) = ("UVK-LIM-001", feature, position)
      case .invalidName(let position):
        (ruleID, reason, offset) = ("UVK-PATH-001", "invalidUTF8", position)
      }
      recordFailure(diagnostics, ruleID: ruleID, reason: reason, offset: offset)
      return nil
    } catch let failure as InspectionFailure {
      switch failure {
      case .resourceLimit(let resource): diagnostics.limit(resource, location: nil)
      case .malformedRange, .shortRead:
        recordFailure(diagnostics, ruleID: "UVK-ARC-001", reason: "metadataRead", offset: nil)
      }
      return nil
    }
  }

  private enum Failure: Error {
    case malformed(String, UInt64?)
    case unsupported(String, UInt64)
    case invalidName(UInt64)
  }

  private static func check(_ resource: SafetyResource, _ value: UInt64) throws {
    guard value <= resource.limit else { throw InspectionFailure.resourceLimit(resource) }
  }

  private static func adding(_ left: UInt64, _ right: UInt64, at offset: UInt64) throws -> UInt64 {
    let (sum, overflow) = left.addingReportingOverflow(right)
    guard !overflow else { throw Failure.malformed("overflow", offset) }
    return sum
  }

  private static func endRecord(in tail: Data, offset: UInt64, reader: BoundedReader) throws -> Int?
  {
    var fallback: Int?
    for index in 0...(tail.count - 22) {
      guard u32(tail, index) == 0x0605_4b50,
        index + 22 + Int(u16(tail, index + 20)) == tail.count
      else { continue }
      if fallback == nil { fallback = index }
      let position = offset + UInt64(index)
      let count = u16(tail, index + 10)
      let size = u32(tail, index + 12)
      let start = u32(tail, index + 16)
      let sentinel = u16(tail, index + 8) == .max || count == .max || size == .max || start == .max
      let locator = try zip64Locator(before: position, tail: tail, offset: offset, reader: reader)
      let directoryEnd = locator ?? position
      let unsupported =
        sentinel || locator != nil || u16(tail, index + 4) != 0
        || u16(tail, index + 6) != 0
      // A marker in the search tail may belong to a member's bytes. Prefer it only
      // after directory placement is supported, including the locator's physical gap.
      let classicRange =
        start != .max && size != .max
        && UInt64(start) + UInt64(size) == directoryEnd
      let countFits = count == .max || UInt64(count) * 46 <= UInt64(size)
      let emptyAtStart = start == 0 && size == 0 && directoryEnd == 0
      if classicRange && countFits && (count != 0 || emptyAtStart)
        && (!unsupported || emptyAtStart)
      {
        // Range/count plausibility alone cannot distinguish an EOCD-shaped payload
        // from metadata. Keep malformed candidates as fallback for stable diagnostics.
        if emptyAtStart { return index }
        if try directoryFramingFits(
          reader: reader, start: UInt64(start), end: directoryEnd, count: count)
        {
          return index
        }
      }
      if unsupported {
        // A missing ZIP64 field is never a real classic offset/size. For candidate
        // identity only, derive the missing boundary from the other bounded field
        // and check central record framing without interpreting ZIP64 contents.
        let framingStart: UInt64?
        if start != .max {
          framingStart = UInt64(start)
        } else if size != .max && UInt64(size) <= directoryEnd {
          framingStart = directoryEnd - UInt64(size)
        } else {
          framingStart = nil
        }
        if let framingStart,
          try directoryFramingFits(
            reader: reader, start: framingStart, end: directoryEnd, count: count)
        {
          return index
        }
        // Failed placement leaves no evidence that the marker belongs to archive metadata.
      }
    }
    return fallback
  }

  private static func directoryFramingFits(
    reader: BoundedReader, start: UInt64, end: UInt64,
    count: UInt16
  ) throws -> Bool {
    // Framing establishes identity only by validating at least one actual central header.
    guard start < end, end - start <= SafetyResource.centralDirectoryBytes.limit,
      count == .max || UInt64(count) <= SafetyResource.entryCount.limit
    else { return false }
    var cursor = start
    var records: UInt64 = 0
    while cursor < end && records < SafetyResource.entryCount.limit {
      guard end - cursor >= 46 else { return false }
      let header = try reader.read(offset: cursor, count: 46)
      guard u32(header, 0) == 0x0201_4b50 else { return false }
      let length =
        UInt64(46) + UInt64(u16(header, 28)) + UInt64(u16(header, 30))
        + UInt64(u16(header, 32))
      guard length <= end - cursor else { return false }
      cursor += length
      records += 1
    }
    return cursor == end && (count == .max || records == UInt64(count))
  }

  private static func zip64Locator(
    before position: UInt64, tail: Data, offset: UInt64,
    reader: BoundedReader
  ) throws -> UInt64? {
    guard position >= 20 else { return nil }
    let locator = position - 20
    let signature: UInt32
    if locator >= offset {
      signature = u32(tail, Int(locator - offset))
    } else {
      signature = u32(try reader.read(offset: locator, count: 4), 0)
    }
    return signature == 0x0706_4b50 ? locator : nil
  }

  private static func inspectExtras(reader: BoundedReader, start: UInt64, end: UInt64) throws
    -> Bool
  {
    var cursor = start
    var zip64 = false
    while cursor < end {
      guard end - cursor >= 4 else { throw Failure.malformed("extraField", cursor) }
      let header = try reader.read(offset: cursor, count: 4)
      let next = try adding(cursor + 4, UInt64(u16(header, 2)), at: cursor)
      guard next <= end else { throw Failure.malformed("extraField", cursor) }
      if u16(header, 0) == 1 { zip64 = true }
      // Unknown vendor/padding bodies do not affect interpretation and need no read.
      cursor = next
    }
    return zip64
  }

  private static func recordFailure(
    _ diagnostics: NativeDiagnostics, ruleID: String,
    reason: String, offset: UInt64?
  ) {
    let location = offset.map { FindingLocation(archiveByteOffset: $0) }
    diagnostics.emit(
      ruleID: ruleID,
      message: ruleID == "UVK-LIM-001"
        ? "ZIP metadata uses an unsupported feature or layout."
        : "ZIP metadata is malformed or truncated.",
      evidence: ["reason": .string(reason)], location: location,
      key: FindingKey(
        ruleID: ruleID, entryNameBytes: nil, entryOffset: nil,
        contentOffset: offset, discriminator: reason))
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

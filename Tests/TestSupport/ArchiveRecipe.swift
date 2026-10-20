import Foundation

/// A test-only writer, independent of every product reader. Sizes describe metadata;
/// payload bytes are always written verbatim, including for deliberately invalid recipes.
public struct ArchiveRecipe: Sendable {
  public enum EntryType: UInt32, Sendable {
    case regular = 0o100644
    case directory = 0o040755
    case symbolicLink = 0o120777
    case characterDevice = 0o020600
    case blockDevice = 0o060600
    case fifo = 0o010600
    case socket = 0o140600
  }

  /// Offset is relative to the selected fixed header (30 local, 46 central, 22 end bytes)
  /// or to the payload for a content patch.
  public struct HeaderPatch: Sendable {
    public var offset: Int
    public var bytes: Data

    public init(offset: Int, bytes: Data) {
      self.offset = offset
      self.bytes = bytes
    }

    public static func uint16(at offset: Int, _ value: UInt16) -> Self {
      var bytes = Data()
      bytes.appendLittleEndian(value)
      return Self(offset: offset, bytes: bytes)
    }

    public static func uint32(at offset: Int, _ value: UInt32) -> Self {
      var bytes = Data()
      bytes.appendLittleEndian(value)
      return Self(offset: offset, bytes: bytes)
    }
  }

  public struct Entry: Sendable {
    public var nameBytes: Data
    public var payload: Data
    public var type: EntryType
    public var flags: UInt16
    public var method: UInt16
    public var declaredCompressedSize: UInt32?
    public var declaredUncompressedSize: UInt32?
    public var declaredCRC32: UInt32?
    public var localExtra: Data
    public var centralExtra: Data
    public var centralComment: Data
    public var localHeaderPatches: [HeaderPatch]
    public var centralHeaderPatches: [HeaderPatch]
    public var payloadPatches: [HeaderPatch]

    public init(
      nameBytes: Data, payload: Data, type: EntryType = .regular,
      flags: UInt16 = 0, method: UInt16 = 0,
      declaredCompressedSize: UInt32? = nil, declaredUncompressedSize: UInt32? = nil,
      declaredCRC32: UInt32? = nil, localExtra: Data = Data(), centralExtra: Data = Data(),
      localHeaderPatches: [HeaderPatch] = [], centralHeaderPatches: [HeaderPatch] = [],
      centralComment: Data = Data(), payloadPatches: [HeaderPatch] = []
    ) {
      self.nameBytes = nameBytes
      self.payload = payload
      self.type = type
      self.flags = flags
      self.method = method
      self.declaredCompressedSize = declaredCompressedSize
      self.declaredUncompressedSize = declaredUncompressedSize
      self.declaredCRC32 = declaredCRC32
      self.localExtra = localExtra
      self.centralExtra = centralExtra
      self.centralComment = centralComment
      self.localHeaderPatches = localHeaderPatches
      self.centralHeaderPatches = centralHeaderPatches
      self.payloadPatches = payloadPatches
    }
  }

  public struct EntryOffsets: Sendable {
    public let localHeader: Int
    public let name: Int
    public let payload: Int
    public let centralHeader: Int
  }

  public struct Encoding: Sendable {
    public var bytes: Data
    public let entries: [EntryOffsets]
    public let centralDirectory: Int
    public let endRecord: Int
  }

  public enum RecipeError: Error, Equatable {
    case invalidAlignment
    case fieldOverflow
    case patchOutOfBounds
  }

  public var entries: [Entry]
  public var alignment: Int
  public var archiveComment: Data
  public var endRecordPatches: [HeaderPatch]
  public var prefix: Data
  public var bytesBeforeDirectory: Data

  public init(
    entries: [Entry], alignment: Int = 64, archiveComment: Data = Data(),
    endRecordPatches: [HeaderPatch] = [], prefix: Data = Data(),
    bytesBeforeDirectory: Data = Data()
  ) {
    self.entries = entries
    self.alignment = alignment
    self.archiveComment = archiveComment
    self.endRecordPatches = endRecordPatches
    self.prefix = prefix
    self.bytesBeforeDirectory = bytesBeforeDirectory
  }

  public func encode() throws -> Data { try encodeWithLayout().bytes }

  public func encodeWithLayout() throws -> Encoding {
    guard alignment > 0, alignment <= 65_536 else { throw RecipeError.invalidAlignment }
    guard let count = UInt16(exactly: entries.count),
      let commentLength = UInt16(exactly: archiveComment.count)
    else { throw RecipeError.fieldOverflow }
    var bytes = prefix
    var locations: [(local: Int, name: Int, payload: Int)] = []
    for entry in entries {
      let metadata = try metadata(for: entry)
      let start = bytes.count
      var extra = entry.localExtra
      let unaligned = start + 30 + entry.nameBytes.count + extra.count
      var padding = (alignment - unaligned % alignment) % alignment
      // ZIP extra fields have a four-byte header. Never emit a partial field.
      if padding > 0 {
        while padding < 4 { padding += alignment }
        guard padding <= Int(UInt16.max) else { throw RecipeError.fieldOverflow }
        extra.appendLittleEndian(UInt16(0x1986))
        extra.appendLittleEndian(UInt16(padding - 4))
        extra.append(Data(repeating: 0, count: padding - 4))
      }
      guard let extraLength = UInt16(exactly: extra.count) else { throw RecipeError.fieldOverflow }
      var header = Data()
      header.appendLittleEndian(UInt32(0x0403_4b50))
      header.appendLittleEndian(UInt16(20))
      header.appendLittleEndian(entry.flags)
      header.appendLittleEndian(entry.method)
      header.appendLittleEndian(UInt16(0))
      header.appendLittleEndian(UInt16(0x0021))  // 1980-01-01, 00:00:00 DOS time.
      header.appendLittleEndian(metadata.crc)
      header.appendLittleEndian(metadata.compressed)
      header.appendLittleEndian(metadata.uncompressed)
      header.appendLittleEndian(metadata.nameLength)
      header.appendLittleEndian(extraLength)
      try Self.apply(entry.localHeaderPatches, to: &header)
      bytes.append(header)
      bytes.append(entry.nameBytes)
      bytes.append(extra)
      locations.append((start, start + 30, bytes.count))
      // Corrupt content after computing the independently recorded CRC and sizes.
      var payload = entry.payload
      try Self.apply(entry.payloadPatches, to: &payload)
      bytes.append(payload)
    }
    bytes.append(bytesBeforeDirectory)
    let centralDirectory = bytes.count
    var offsets: [EntryOffsets] = []
    for (index, entry) in entries.enumerated() {
      let metadata = try metadata(for: entry)
      guard let extraLength = UInt16(exactly: entry.centralExtra.count),
        let entryCommentLength = UInt16(exactly: entry.centralComment.count),
        let localOffset = UInt32(exactly: locations[index].local)
      else { throw RecipeError.fieldOverflow }
      let centralHeader = bytes.count
      var header = Data()
      header.appendLittleEndian(UInt32(0x0201_4b50))
      header.appendLittleEndian(UInt16(0x0314))  // Unix, ZIP 2.0.
      header.appendLittleEndian(UInt16(20))
      header.appendLittleEndian(entry.flags)
      header.appendLittleEndian(entry.method)
      header.appendLittleEndian(UInt16(0))
      header.appendLittleEndian(UInt16(0x0021))
      header.appendLittleEndian(metadata.crc)
      header.appendLittleEndian(metadata.compressed)
      header.appendLittleEndian(metadata.uncompressed)
      header.appendLittleEndian(metadata.nameLength)
      header.appendLittleEndian(extraLength)
      header.appendLittleEndian(entryCommentLength)
      header.appendLittleEndian(UInt16(0))  // Disk.
      header.appendLittleEndian(UInt16(0))  // Internal attributes.
      header.appendLittleEndian(entry.type.rawValue << 16 | (entry.type == .directory ? 0x10 : 0))
      header.appendLittleEndian(localOffset)
      try Self.apply(entry.centralHeaderPatches, to: &header)
      bytes.append(header)
      bytes.append(entry.nameBytes)
      bytes.append(entry.centralExtra)
      bytes.append(entry.centralComment)
      offsets.append(
        EntryOffsets(
          localHeader: locations[index].local, name: locations[index].name,
          payload: locations[index].payload, centralHeader: centralHeader))
    }
    let endRecord = bytes.count
    guard let directorySize = UInt32(exactly: endRecord - centralDirectory),
      let directoryOffset = UInt32(exactly: centralDirectory)
    else { throw RecipeError.fieldOverflow }
    var end = Data()
    end.appendLittleEndian(UInt32(0x0605_4b50))
    end.appendLittleEndian(UInt16(0))
    end.appendLittleEndian(UInt16(0))
    end.appendLittleEndian(count)
    end.appendLittleEndian(count)
    end.appendLittleEndian(directorySize)
    end.appendLittleEndian(directoryOffset)
    end.appendLittleEndian(commentLength)
    try Self.apply(endRecordPatches, to: &end)
    bytes.append(end)
    bytes.append(archiveComment)
    return Encoding(
      bytes: bytes, entries: offsets, centralDirectory: centralDirectory, endRecord: endRecord)
  }

  /// CRC-32/ISO-HDLC, computed directly from bytes without product code or ZIP libraries.
  public static func crc32(_ data: Data) -> UInt32 {
    var crc: UInt32 = 0xffff_ffff
    for byte in data {
      crc ^= UInt32(byte)
      for _ in 0..<8 {
        crc = (crc >> 1) ^ (crc & 1 == 1 ? 0xedb8_8320 : 0)
      }
    }
    return crc ^ 0xffff_ffff
  }

  /// Mutates bytes at an exposed record offset without parsing the generated archive.
  public static func overwrite(_ data: inout Data, at offset: Int, with bytes: Data) throws {
    guard offset >= 0, offset <= data.count, bytes.count <= data.count - offset else {
      throw RecipeError.patchOutOfBounds
    }
    data.replaceSubrange(offset..<(offset + bytes.count), with: bytes)
  }

  private static func apply(_ patches: [HeaderPatch], to header: inout Data) throws {
    for patch in patches { try overwrite(&header, at: patch.offset, with: patch.bytes) }
  }

  private func metadata(for entry: Entry) throws -> (
    crc: UInt32, compressed: UInt32, uncompressed: UInt32, nameLength: UInt16
  ) {
    guard let payloadSize = UInt32(exactly: entry.payload.count),
      let nameLength = UInt16(exactly: entry.nameBytes.count)
    else { throw RecipeError.fieldOverflow }
    return (
      entry.declaredCRC32 ?? Self.crc32(entry.payload),
      entry.declaredCompressedSize ?? payloadSize,
      entry.declaredUncompressedSize ?? payloadSize, nameLength
    )
  }
}

extension Data {
  fileprivate mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
    for shift in 0..<MemoryLayout<T>.size {
      append(UInt8(truncatingIfNeeded: value >> (shift * 8)))
    }
  }
}

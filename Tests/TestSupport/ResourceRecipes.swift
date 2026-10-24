import Foundation

/// Original MIT temporary resource fixtures. Payloads/comments are streamed in <=64 KiB
/// chunks; only bounded entry metadata is retained. No product reader or large fixture.
public enum ResourceRecipes {
  public enum Segment: Sendable {
    case bytes(Data)
    case repeated(Data, Int)
    case fill(UInt8, Int)

    var byteCount: Int {
      switch self {
      case .bytes(let bytes): bytes.count
      case .repeated(let bytes, let count): bytes.count * count
      case .fill(_, let count): count
      }
    }

    func stream(_ consume: (Data) throws -> Void) rethrows {
      let value: Data
      var units: Int
      switch self {
      case .bytes(let bytes):
        for offset in stride(from: 0, to: bytes.count, by: 65_536) {
          try consume(bytes.subdata(in: offset..<min(offset + 65_536, bytes.count)))
        }
        return
      case .repeated(let bytes, let count):
        precondition(!bytes.isEmpty && bytes.count <= 65_536 && count >= 0)
        value = bytes
        units = count
      case .fill(let byte, let count):
        precondition(count >= 0)
        value = Data([byte])
        units = count
      }
      guard units > 0 else { return }
      let unitsPerChunk = min(units, 65_536 / value.count)
      var block = Data()
      for _ in 0..<unitsPerChunk { block.append(value) }
      while units > 0 {
        let next = min(units, unitsPerChunk)
        try consume(next == unitsPerChunk ? block : Data(block.prefix(next * value.count)))
        units -= next
      }
    }
  }

  public struct Entry: Sendable {
    public var name: String
    public var segments: [Segment]
    /// Metadata-only boundary vectors deliberately need not fit their declared payload.
    public var declaredSize: UInt32?
    public var commentBytes: Int

    public init(
      _ name: String, _ segments: [Segment] = [], declaredSize: UInt32? = nil,
      commentBytes: Int = 0
    ) {
      self.name = name
      self.segments = segments
      self.declaredSize = declaredSize
      self.commentBytes = commentBytes
    }
  }

  public struct Layout: Sendable {
    public let payloadRanges: [Range<UInt64>]
    public let centralHeaders: [UInt64]
    public let directoryRange: Range<UInt64>
    public let endRecord: UInt64
    public let byteCount: UInt64
  }

  public static var nearArchiveLimit: [Entry] {
    [
      Entry("root.usda", [.bytes(Data("#usda 1.0\n".utf8))]),
      Entry("a.wav", [.fill(0x42, 268_435_456)]),
      Entry("b.wav", [.fill(0x42, 268_434_432)]),
    ]
  }

  public static func text(tokens: Int, tokenBytes: Int = 1, totalBytes: Int? = nil) -> [Segment] {
    let header = Data("#usda 1.0\n".utf8)
    let literal = Data([0x40]) + Data(repeating: 0x61, count: tokenBytes) + Data([0x40, 0x20])
    let used = header.count + literal.count * tokens
    if let totalBytes { precondition(totalBytes >= used) }
    return [.bytes(header), .repeated(literal, tokens), .fill(0x20, (totalBytes ?? used) - used)]
  }

  /// Move metadata beyond a streamed opaque body without retaining the large layer.
  /// This accepts an independent empty-value recipe, never arbitrary live value offsets.
  public static func binaryWithOpaqueBody(metadata: Data, paddingBytes: Int) throws -> [Segment] {
    precondition(metadata.count >= 88 && paddingBytes >= 0)
    func readWord(_ offset: Int) -> UInt64 {
      (0..<8).reduce(0) { $0 | (UInt64(metadata[offset + $1]) << ($1 * 8)) }
    }
    func word(_ value: UInt64) -> Data {
      Data((0..<8).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) })
    }
    let toc = Int(readWord(16))
    var relocated = try USDCMutationRecipe.patch(
      metadata, at: 16, bytes: word(UInt64(toc + paddingBytes)))
    let count = Int(readWord(toc))
    for row in 0..<count {
      let position = toc + 8 + row * 32 + 16
      relocated = try USDCMutationRecipe.patch(
        relocated, at: position, bytes: word(readWord(position) + UInt64(paddingBytes)))
    }
    return [
      .bytes(Data(relocated.prefix(88))), .fill(0x42, paddingBytes),
      .bytes(Data(relocated.dropFirst(88))),
    ]
  }

  /// Original JPEG header-only vector; establishes scan behavior, not image validity.
  public static func jpegHeader(paddingBytes: Int) -> [Segment] {
    var segments: [Segment] = [.bytes(Data([0xff, 0xd8]))]
    var remaining = paddingBytes
    while remaining > 0 {
      var count = min(remaining, 65_537)
      if remaining - count > 0 && remaining - count < 4 {
        count -= 4 - (remaining - count)
      }
      precondition(count >= 4)
      let length = count - 2
      segments.append(.bytes(Data([0xff, 0xe1, UInt8(length >> 8), UInt8(length & 0xff)])))
      segments.append(.fill(0x42, count - 4))
      remaining -= count
    }
    segments.append(
      .bytes(
        Data([
          0xff, 0xc0, 0, 17, 8, 0, 8, 0, 16, 3, 1, 0x11, 0, 2, 0x11, 0, 3, 0x11, 0,
        ])))
    return segments
  }

  /// Matches verify-resources.py's bytes, including extra fields and fixed timestamps.
  @discardableResult
  public static func write(
    _ entries: [Entry], to url: URL, archiveBytes: UInt64? = nil
  ) throws -> Layout {
    guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
      throw CocoaError(.fileWriteUnknown)
    }
    let file = try FileHandle(forWritingTo: url)
    defer { try? file.close() }
    var offset: UInt64 = 0
    func append(_ bytes: Data) throws {
      try file.write(contentsOf: bytes)
      offset += UInt64(bytes.count)
    }
    struct Record {
      let entry: Entry
      let name: Data
      let crc: UInt32
      let size: UInt32
      let local: UInt32
    }
    var records: [Record] = []
    var payloads: [Range<UInt64>] = []
    for entry in entries {
      let name = Data(entry.name.utf8)
      var crc = CRC32()
      for segment in entry.segments { segment.stream { crc.update($0) } }
      let actualSize = entry.segments.reduce(0) { $0 + $1.byteCount }
      let size = entry.declaredSize ?? UInt32(actualSize)
      let local = UInt32(offset)
      var padding = (64 - Int((offset + 30 + UInt64(name.count)) % 64)) % 64
      if padding > 0 && padding < 4 { padding += 64 }
      var extra = Data()
      if padding > 0 {
        extra.le(UInt16(0x1986))
        extra.le(UInt16(padding - 4))
        extra.append(Data(repeating: 0, count: padding - 4))
      }
      var header = Data()
      header.le(UInt32(0x0403_4b50))
      for value: UInt16 in [20, 0, 0, 0, 0x21] { header.le(value) }
      for value in [crc.value, size, size] { header.le(value) }
      header.le(UInt16(name.count))
      header.le(UInt16(extra.count))
      try append(header)
      try append(name)
      try append(extra)
      let start = offset
      for segment in entry.segments { try segment.stream(append) }
      payloads.append(start..<offset)
      records.append(Record(entry: entry, name: name, crc: crc.value, size: size, local: local))
    }
    let directory = offset
    var centralHeaders: [UInt64] = []
    for record in records {
      centralHeaders.append(offset)
      var header = Data()
      header.le(UInt32(0x0201_4b50))
      for value: UInt16 in [0x0314, 20, 0, 0, 0, 0x21] { header.le(value) }
      for value in [record.crc, record.size, record.size] { header.le(value) }
      for value in [UInt16(record.name.count), 0, UInt16(record.entry.commentBytes), 0, 0] {
        header.le(value)
      }
      header.le(UInt32(0x81a4_0000))
      header.le(record.local)
      try append(header)
      try append(record.name)
      try Segment.fill(0, record.entry.commentBytes).stream(append)
    }
    let end = offset
    let comment = archiveBytes.map { Int($0) - Int(end) - 22 } ?? 0
    precondition((0...65_535).contains(comment))
    var eocd = Data()
    eocd.le(UInt32(0x0605_4b50))
    for value in [UInt16(0), 0, UInt16(records.count), UInt16(records.count)] { eocd.le(value) }
    eocd.le(UInt32(end - directory))
    eocd.le(UInt32(directory))
    eocd.le(UInt16(comment))
    try append(eocd)
    try Segment.fill(0, comment).stream(append)
    try file.synchronize()
    return Layout(
      payloadRanges: payloads, centralHeaders: centralHeaders, directoryRange: directory..<end,
      endRecord: end, byteCount: offset)
  }

  private struct CRC32 {
    private var state: UInt32 = 0xffff_ffff
    private static let table: [UInt32] = (0..<256).map { byte in
      var value = UInt32(byte)
      for _ in 0..<8 { value = value >> 1 ^ (value & 1 == 1 ? 0xedb8_8320 : 0) }
      return value
    }
    mutating func update(_ bytes: Data) {
      for byte in bytes { state = state >> 8 ^ Self.table[Int((state ^ UInt32(byte)) & 0xff)] }
    }
    var value: UInt32 { state ^ 0xffff_ffff }
  }
}

extension Data {
  fileprivate mutating func le<T: FixedWidthInteger>(_ value: T) {
    for shift in 0..<MemoryLayout<T>.size {
      append(UInt8(truncatingIfNeeded: value >> (8 * shift)))
    }
  }
}

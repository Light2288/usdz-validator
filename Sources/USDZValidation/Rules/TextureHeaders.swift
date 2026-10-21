import Foundation

struct TextureDimensions: Equatable {
  let width: UInt32
  let height: UInt32
}

enum TextureHeaders {
  /// The caller requests dimensions only after safe stored-payload eligibility. Success
  /// leaves engine coverage pending; header recognition never certifies a complete image.
  static func inspect(
    entry: ZIPEntry, kind: MemberKind, reader: BoundedReader, diagnostics: NativeDiagnostics
  ) throws -> TextureDimensions? {
    var cursor = Cursor(entry: entry, reader: reader)
    do {
      guard kind == .png || kind == .jpeg else {
        throw HeaderFailure.unsupported("textureFormat")
      }
      try reader.ledger.check(resource: .entryBytes, value: entry.uncompressedSize)
      guard entry.payloadRange.upperBound <= reader.size,
        entry.payloadRange.upperBound - entry.payloadRange.lowerBound == entry.uncompressedSize,
        entry.compressedSize == entry.uncompressedSize
      else { throw InspectionFailure.malformedRange }
      return try kind == .png ? png(&cursor) : jpeg(&cursor)
    } catch let failure as HeaderFailure {
      let ruleID: String
      let reason: String
      switch failure {
      case .malformed(let field): (ruleID, reason) = ("UVK-BUD-007", field)
      case .unsupported(let field): (ruleID, reason) = ("UVK-LIM-005", field)
      }
      record(ruleID, reason: reason, cursor: cursor, diagnostics: diagnostics)
    } catch let failure as InspectionFailure {
      switch failure {
      case .resourceLimit(let resource):
        diagnostics.limit(resource, location: cursor.location)
      case .shortRead, .malformedRange:
        record("UVK-ARC-001", reason: "textureRead", cursor: cursor, diagnostics: diagnostics)
      }
    }
    return nil
  }

  private static func png(_ cursor: inout Cursor) throws -> TextureDimensions {
    let signature = try cursor.read(8)
    guard signature == Data([137, 80, 78, 71, 13, 10, 26, 10]) else {
      throw HeaderFailure.malformed("pngSignature")
    }
    let prefix = try cursor.read(8)
    guard u32(prefix, 0) == 13, prefix.suffix(4) == Data("IHDR".utf8) else {
      throw HeaderFailure.malformed("pngIHDR")
    }
    let fields = try cursor.read(17)
    let width = u32(fields, 0)
    let height = u32(fields, 4)
    guard width > 0, height > 0, width <= 0x7fff_ffff, height <= 0x7fff_ffff else {
      throw HeaderFailure.malformed("pngDimensions")
    }
    let depths: [UInt8]
    switch fields[9] {
    case 0: depths = [1, 2, 4, 8, 16]
    case 2, 4, 6: depths = [8, 16]
    case 3: depths = [1, 2, 4, 8]
    default: throw HeaderFailure.malformed("pngColorType")
    }
    guard depths.contains(fields[8]), fields[10] == 0, fields[11] == 0, fields[12] <= 1 else {
      throw HeaderFailure.malformed("pngIHDRFields")
    }
    // Only the fixed IHDR is checked. Neither IDAT nor any pixel payload is requested.
    var crc: UInt32 = 0xffff_ffff
    for byte in prefix.suffix(4) + fields.prefix(13) {
      crc ^= UInt32(byte)
      for _ in 0..<8 { crc = (crc >> 1) ^ (crc & 1 == 1 ? 0xedb8_8320 : 0) }
    }
    guard crc ^ 0xffff_ffff == u32(fields, 13) else {
      throw HeaderFailure.malformed("pngIHDRCRC")
    }
    return TextureDimensions(width: width, height: height)
  }

  private static func jpeg(_ cursor: inout Cursor) throws -> TextureDimensions {
    guard try cursor.read(2) == Data([0xff, 0xd8]) else {
      throw HeaderFailure.malformed("jpegSignature")
    }
    while true {
      guard try cursor.read(1)[0] == 0xff else {
        throw HeaderFailure.malformed("jpegMarkerPrefix")
      }
      var marker = try cursor.read(1)[0]
      while marker == 0xff { marker = try cursor.read(1)[0] }
      guard marker != 0, marker != 0xd8, marker != 0xd9,
        !(0xd0...0xd7).contains(marker), marker != 0xda
      else { throw HeaderFailure.malformed("jpegMarkerOrder") }
      let supportedFrame = [0xc0, 0xc1, 0xc2].contains(marker)
      let metadata =
        (0xe0...0xef).contains(marker)
        || [0xc4, 0xcc, 0xdb, 0xdd, 0xfe].contains(marker)
      // Other SOFs, TEM and reserved extensions require semantics outside v0.1.
      // Do not invent a length field for unknown syntax and call it malformed.
      guard supportedFrame || metadata else { throw HeaderFailure.unsupported("jpegVariant") }
      let lengthBytes = try cursor.read(2)
      let length = Int(u16(lengthBytes, 0))
      guard length >= 2 else { throw HeaderFailure.malformed("jpegMarkerLength") }
      if supportedFrame {
        return try jpegFrame(&cursor, marker: marker, length: length)
      }
      // Bounds include skipped segment bodies, so seeking cannot evade the prefix cap.
      try cursor.skip(length - 2)
    }
  }

  private static func jpegFrame(_ cursor: inout Cursor, marker: UInt8, length: Int) throws
    -> TextureDimensions
  {
    guard (8...773).contains(length), (length - 8) % 3 == 0 else {
      throw HeaderFailure.malformed("jpegFrameLength")
    }
    // Contradictions established by readable frame fields remain errors even when the
    // full declared record would cross the scan boundary. No out-of-bound field is read.
    _ = try cursor.checkedEnd(length - 2)
    let frame = try cursor.read(6)
    let precision = frame[0]
    let height = u16(frame, 1)
    let width = u16(frame, 3)
    let components = Int(frame[5])
    guard components > 0, marker != 0xc2 || components <= 4,
      length == 8 + 3 * components, width > 0,
      precision == 8 || (marker != 0xc0 && precision == 12)
    else { throw HeaderFailure.malformed("jpegFrameFields") }
    let fields = try cursor.read(3 * components)
    var identifiers: Set<UInt8> = []
    for index in stride(from: 0, to: fields.count, by: 3) {
      let horizontal = fields[index + 1] >> 4
      let vertical = fields[index + 1] & 0x0f
      guard identifiers.insert(fields[index]).inserted,
        (1...4).contains(horizontal), (1...4).contains(vertical), fields[index + 2] <= 3
      else { throw HeaderFailure.malformed("jpegComponents") }
    }
    // T.81 B.2.2 permits zero Y when a later DNL supplies the line count. Obtaining
    // that value would require leaving this frame-header boundary and inspecting scans.
    guard height > 0 else { throw HeaderFailure.unsupported("jpegDeferredHeight") }
    return TextureDimensions(width: UInt32(width), height: UInt32(height))
  }

  private enum HeaderFailure: Error {
    case malformed(String)
    case unsupported(String)
  }

  /// Demand reads avoid prefetching compressed pixels. No allocation is larger than a
  /// fixed PNG IHDR or a JPEG frame's bounded 255 component descriptors.
  private struct Cursor {
    let entry: ZIPEntry
    let reader: BoundedReader
    var offset: UInt64 = 0

    var location: FindingLocation {
      FindingLocation(
        entryName: String(data: entry.nameBytes, encoding: .utf8),
        archiveByteOffset: entry.payloadRange.lowerBound + offset, layerByteOffset: offset)
    }

    func checkedEnd(_ count: Int) throws -> UInt64 {
      guard let bytes = UInt64(exactly: count) else { throw InspectionFailure.malformedRange }
      let (end, overflow) = offset.addingReportingOverflow(bytes)
      guard !overflow, end <= entry.payloadRange.upperBound - entry.payloadRange.lowerBound else {
        throw HeaderFailure.malformed("truncatedHeader")
      }
      return end
    }

    func require(_ count: Int) throws {
      try reader.ledger.check(resource: .textureHeaderBytes, value: checkedEnd(count))
    }

    mutating func read(_ count: Int) throws -> Data {
      try require(count)
      var bytes = Data()
      while bytes.count < count {
        let chunkRemaining =
          SafetyResource.readChunkBytes.limit
          - offset % SafetyResource.readChunkBytes.limit
        let amount = min(count - bytes.count, Int(chunkRemaining))
        bytes.append(
          try reader.read(offset: entry.payloadRange.lowerBound + offset, count: amount))
        offset += UInt64(amount)
      }
      return bytes
    }

    mutating func skip(_ count: Int) throws {
      try require(count)
      offset += UInt64(count)
    }
  }

  private static func record(
    _ ruleID: String, reason: String, cursor: Cursor, diagnostics: NativeDiagnostics
  ) {
    diagnostics.emit(
      ruleID: ruleID,
      message: ruleID == "UVK-BUD-007"
        ? "The supported texture header is malformed."
        : ruleID == "UVK-LIM-005"
          ? "Texture dimensions require unsupported header interpretation."
          : "The texture payload range is malformed or truncated.",
      evidence: ["reason": .string(reason)], location: cursor.location,
      key: FindingKey(
        ruleID: ruleID, entryNameBytes: cursor.entry.nameBytes,
        entryOffset: cursor.entry.localHeaderOffset, contentOffset: cursor.offset,
        discriminator: reason))
    diagnostics.mark(
      area: .textureDimensions, state: .partial,
      reason: CoverageReason(ruleID: ruleID, reasonID: reason, location: cursor.location))
  }

  private static func u16(_ data: Data, _ offset: Int) -> UInt16 {
    UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
  }

  private static func u32(_ data: Data, _ offset: Int) -> UInt32 {
    UInt32(u16(data, offset)) << 16 | UInt32(u16(data, offset + 2))
  }
}

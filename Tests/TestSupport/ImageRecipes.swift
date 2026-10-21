import Foundation

/// Original MIT-licensed header recipes. JPEG frames are header-only test vectors, not
/// decodable-image or scene-validity oracles; arbitrary trailing bytes model unread pixels.
public enum ImageRecipes {
  public static func pngHeader(width: UInt32 = 16, height: UInt32 = 8) -> Data {
    var fields = Data("IHDR".utf8)
    append32(width, to: &fields)
    append32(height, to: &fields)
    fields.append(contentsOf: [8, 6, 0, 0, 0])
    var bytes = Data([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13])
    bytes.append(fields)
    append32(ArchiveRecipe.crc32(fields), to: &bytes)
    return bytes
  }

  public static func jpegHeader(
    marker: UInt8 = 0xc0, width: UInt16 = 16, height: UInt16 = 8,
    precision: UInt8 = 8, leadingSegments: Data = Data()
  ) -> Data {
    let fields = Data([
      precision, UInt8(truncatingIfNeeded: height >> 8), UInt8(truncatingIfNeeded: height),
      UInt8(truncatingIfNeeded: width >> 8), UInt8(truncatingIfNeeded: width),
      3, 1, 0x11, 0, 2, 0x11, 1, 3, 0x11, 1,
    ])
    return Data([0xff, 0xd8]) + leadingSegments + jpegSegment(marker: marker, fields: fields)
  }

  public static func jpegSegment(marker: UInt8, fields: Data) -> Data {
    precondition(fields.count <= 65_533)
    let length = fields.count + 2
    return Data([0xff, marker, UInt8(length >> 8), UInt8(length & 0xff)]) + fields
  }

  /// APP1 segments occupy exactly byteCount bytes, including marker and length fields.
  /// The split avoids a final 1–3 byte fragment, which cannot hold a length-bearing marker.
  public static func jpegPadding(byteCount: Int) -> Data {
    precondition(byteCount == 0 || byteCount >= 4)
    var bytes = Data()
    var remaining = byteCount
    while remaining > 0 {
      var count = min(65_537, remaining)
      let tail = remaining - count
      if (1...3).contains(tail) { count -= 4 - tail }
      bytes.append(jpegSegment(marker: 0xe1, fields: Data(repeating: 0x42, count: count - 4)))
      remaining -= count
    }
    return bytes
  }

  private static func append32(_ value: UInt32, to bytes: inout Data) {
    for shift in [24, 16, 8, 0] { bytes.append(UInt8(truncatingIfNeeded: value >> shift)) }
  }
}

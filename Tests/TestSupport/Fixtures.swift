import Foundation

public enum Fixtures {
  public static var root: URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent("Fixtures", isDirectory: true)
  }

  public static func validUSDA() throws -> Data {
    try ArchiveRecipe(entries: [
      .init(
        nameBytes: Data("root.usda".utf8),
        payload: Data(contentsOf: root.appendingPathComponent("Sources/root.usda"))),
      .init(
        nameBytes: Data("Sources/pixel.png".utf8),
        payload: Data(contentsOf: root.appendingPathComponent("Sources/pixel.png"))),
    ]).encode()
  }

  public static func validUSDC() throws -> Data {
    var entries: [ArchiveRecipe.Entry] = [
      .init(
        nameBytes: Data("root.usdc".utf8),
        payload: try Data(
          contentsOf: USDCFixtures.root.appendingPathComponent("baseline/containers.usdc")))
    ]
    for name in ["same.png", "selected.png", "unselected.png", "a.png", "b.png"] {
      entries.append(.init(nameBytes: Data(name.utf8), payload: pixelPNG()))
    }
    return try ArchiveRecipe(entries: entries).encode()
  }

  public static func write(_ bytes: Data, basename: String, in directory: URL) throws -> URL {
    guard !basename.isEmpty, basename != ".", basename != "..",
      !basename.contains("/"), !basename.contains("\\"), !basename.contains("\0")
    else { throw CocoaError(.fileWriteInvalidFileName) }
    let url = directory.appendingPathComponent(basename, isDirectory: false)
    try bytes.write(to: url, options: .atomic)
    return url
  }

  /// Original 1x1 RGBA blue pixel: PNG chunks and a zlib stored block, no codec dependency.
  public static func pixelPNG() -> Data {
    let scanline: [UInt8] = [0, 0x33, 0x99, 0xcc, 0xff]
    var adlerA: UInt32 = 1
    var adlerB: UInt32 = 0
    for byte in scanline {
      adlerA = (adlerA + UInt32(byte)) % 65_521
      adlerB = (adlerB + adlerA) % 65_521
    }
    var compressed = Data([0x78, 0x01, 0x01, 0x05, 0x00, 0xfa, 0xff] + scanline)
    appendBigEndian((adlerB << 16) | adlerA, to: &compressed)
    var png = Data([137, 80, 78, 71, 13, 10, 26, 10])
    png.append(chunk("IHDR", Data([0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0])))
    png.append(chunk("IDAT", compressed))
    png.append(chunk("IEND", Data()))
    return png
  }

  private static func chunk(_ type: String, _ payload: Data) -> Data {
    let content = Data(type.utf8) + payload
    var bytes = Data()
    appendBigEndian(UInt32(payload.count), to: &bytes)
    bytes.append(content)
    appendBigEndian(ArchiveRecipe.crc32(content), to: &bytes)
    return bytes
  }

  private static func appendBigEndian(_ value: UInt32, to bytes: inout Data) {
    for shift in [24, 16, 8, 0] { bytes.append(UInt8(truncatingIfNeeded: value >> shift)) }
  }
}

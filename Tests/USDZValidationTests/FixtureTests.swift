import CryptoKit
import Foundation
import ImageIO
import TestSupport
import XCTest

final class FixtureTests: XCTestCase {
  func testReproducibleOriginalPackage() throws {
    let recipe = ArchiveRecipe(entries: [
      .init(nameBytes: Data("a".utf8), payload: Data("123456789".utf8))
    ])
    let bytes = try recipe.encode()
    XCTAssertEqual(bytes, try recipe.encode())
    XCTAssertEqual(ArchiveRecipe.crc32(Data("123456789".utf8)), 0xcbf4_3926)
    XCTAssertEqual(ArchiveRecipe.crc32(Data()), 0)
    // A one-character name requires 33 extra bytes to put its payload at byte 64.
    XCTAssertEqual(bytes.count, 142)
    guard bytes.count == 142 else { return }
    XCTAssertEqual(u32(bytes, 0), 0x0403_4b50)
    XCTAssertEqual(u16(bytes, 28), 33)
    XCTAssertEqual(bytes.subdata(in: 64..<73), Data("123456789".utf8))
    XCTAssertEqual(u32(bytes, 14), 0xcbf4_3926)
    XCTAssertEqual(u32(bytes, 73), 0x0201_4b50)
    XCTAssertEqual(u32(bytes, 120), 0x0605_4b50)

    let committed = try Data(contentsOf: Fixtures.root.appendingPathComponent("valid-usda.usdz"))
    XCTAssertEqual(try Fixtures.validUSDA(), committed)
    var offset = 0
    var names: [String] = []
    while u32(committed, offset) == 0x0403_4b50 {
      let nameStart = offset + 30
      let nameEnd = nameStart + Int(u16(committed, offset + 26))
      let payload = nameEnd + Int(u16(committed, offset + 28))
      XCTAssertEqual(payload % 64, 0)
      names.append(String(decoding: committed[nameStart..<nameEnd], as: UTF8.self))
      offset = payload + Int(u32(committed, offset + 18))
    }
    XCTAssertEqual(names, ["root.usda", "Sources/pixel.png"])
    XCTAssertEqual(u32(committed, offset), 0x0201_4b50)
    let source = try String(
      contentsOf: Fixtures.root.appendingPathComponent("Sources/root.usda"), encoding: .utf8)
    XCTAssertTrue(source.hasPrefix("#usda 1.0\n"))
    XCTAssertTrue(source.contains("@Sources/pixel.png@"))
    let png = try Data(contentsOf: Fixtures.root.appendingPathComponent("Sources/pixel.png"))
    XCTAssertEqual(png, Fixtures.pixelPNG())
    let imageSource = try XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil))
    let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(imageSource, 0, nil))
    XCTAssertEqual(image.width, 1)
    XCTAssertEqual(image.height, 1)
  }

  func testOffsetsAndHeaderOverridesCreateAdversarialBytes() throws {
    let recipe = ArchiveRecipe(
      entries: [
        .init(
          nameBytes: Data([0xff, 0x2f]), payload: Data([7, 8, 9]), type: .symbolicLink,
          flags: 1, method: 8, declaredCompressedSize: 1,
          declaredUncompressedSize: .max, declaredCRC32: 0x1234_5678,
          localHeaderPatches: [.uint16(at: 26, 123)],
          centralHeaderPatches: [.uint32(at: 42, 100)]),
        .init(nameBytes: Data("dir/".utf8), payload: Data(), type: .directory),
      ], archiveComment: Data([42]), endRecordPatches: [.uint16(at: 8, 7)])
    var encoding = try recipe.encodeWithLayout()
    XCTAssertEqual(encoding.entries.count, 2)
    XCTAssertEqual(encoding.entries[0].localHeader, 0)
    XCTAssertEqual(encoding.entries[0].name, 30)
    XCTAssertEqual(encoding.entries[0].payload, 64)
    XCTAssertEqual(encoding.entries[1].localHeader, 67)
    XCTAssertEqual(encoding.entries[1].payload, 128)
    XCTAssertEqual(encoding.centralDirectory, 128)
    XCTAssertEqual(encoding.entries[0].centralHeader, 128)
    XCTAssertEqual(encoding.entries[1].centralHeader, 176)
    XCTAssertEqual(encoding.endRecord, 226)
    XCTAssertEqual(u16(encoding.bytes, 6), 1)
    XCTAssertEqual(u16(encoding.bytes, 8), 8)
    XCTAssertEqual(u32(encoding.bytes, 14), 0x1234_5678)
    XCTAssertEqual(u32(encoding.bytes, 18), 1)
    XCTAssertEqual(u32(encoding.bytes, 22), .max)
    XCTAssertEqual(u16(encoding.bytes, 26), 123)
    XCTAssertEqual(u32(encoding.bytes, 128 + 38), 0xa1ff_0000)
    XCTAssertEqual(u32(encoding.bytes, 128 + 42), 100)
    XCTAssertEqual(u32(encoding.bytes, 176 + 38), 0x41ed_0010)
    XCTAssertEqual(u16(encoding.bytes, 226 + 8), 7)
    XCTAssertEqual(encoding.bytes.last, 42)
    try ArchiveRecipe.overwrite(&encoding.bytes, at: encoding.entries[0].payload, with: Data([0]))
    XCTAssertEqual(encoding.bytes[64], 0)
    XCTAssertEqual(encoding.bytes[65], 8)
  }

  func testAlignmentExtraFieldsAndRecipeErrors() throws {
    let recipe = ArchiveRecipe(entries: [
      .init(nameBytes: Data(repeating: 0x61, count: 32), payload: Data())
    ])
    let bytes = try recipe.encodeWithLayout()
    XCTAssertEqual(bytes.entries[0].payload, 128)
    XCTAssertEqual(u16(bytes.bytes, 28), 66)
    XCTAssertEqual(u16(bytes.bytes, 62), 0x1986)
    XCTAssertEqual(u16(bytes.bytes, 64), 62)
    XCTAssertThrowsError(try ArchiveRecipe(entries: [], alignment: 0).encode())
    XCTAssertThrowsError(try ArchiveRecipe(entries: [], alignment: 65_537).encode())
    XCTAssertThrowsError(
      try ArchiveRecipe(entries: [
        .init(nameBytes: Data(repeating: 1, count: 65_536), payload: Data())
      ]).encode())
    XCTAssertThrowsError(
      try ArchiveRecipe(entries: [], endRecordPatches: [.uint32(at: 20, 0)]).encode())
    var oneByte = Data([1])
    XCTAssertThrowsError(try ArchiveRecipe.overwrite(&oneByte, at: -1, with: Data([0])))
    XCTAssertThrowsError(try ArchiveRecipe.overwrite(&oneByte, at: Int.max, with: Data([0])))
    XCTAssertEqual(oneByte, Data([1]))
    let unaligned = try ArchiveRecipe(
      entries: [.init(nameBytes: Data("a".utf8), payload: Data())], alignment: 1
    ).encodeWithLayout()
    XCTAssertEqual(unaligned.entries[0].payload, 31)
    let empty = try ArchiveRecipe(entries: []).encode()
    XCTAssertEqual(empty.count, 22)
    XCTAssertEqual(u32(empty, 0), 0x0605_4b50)
  }

  func testFixtureWritesOnlyRequestedBasename() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    addTeardownBlock { try FileManager.default.removeItem(at: directory) }
    let url = try Fixtures.write(Data([4, 2]), basename: "test.usdz", in: directory)
    XCTAssertEqual(url, directory.appendingPathComponent("test.usdz"))
    XCTAssertEqual(try Data(contentsOf: url), Data([4, 2]))
    for basename in ["", ".", "..", "../escape.usdz", "sub/file", "sub\\file", "a\0b"] {
      XCTAssertThrowsError(try Fixtures.write(Data(), basename: basename, in: directory))
    }
    XCTAssertThrowsError(
      try Fixtures.write(
        Data(), basename: "no.usdz", in: directory.appendingPathComponent("missing")))
  }

  func testManifestCoversCorpusAndGenerators() throws {
    let project = Fixtures.root.deletingLastPathComponent().deletingLastPathComponent()
    let manifestURL = Fixtures.root.appendingPathComponent("manifest.json")
    XCTAssertTrue(FileManager.default.fileExists(atPath: manifestURL.path))
    guard FileManager.default.fileExists(atPath: manifestURL.path) else { return }
    let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
    XCTAssertEqual(manifest.schemaVersion, 1)
    var files = Set<String>()
    for directory in ["Tests/Fixtures", "Tests/TestSupport"] {
      let enumerator = try XCTUnwrap(
        FileManager.default.enumerator(
          at: project.appendingPathComponent(directory),
          includingPropertiesForKeys: [.isRegularFileKey]
        ))
      for case let file as URL in enumerator {
        if try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true,
          file != manifestURL
        {
          files.insert(String(file.path.dropFirst(project.path.count + 1)))
        }
      }
    }
    XCTAssertFalse(files.isEmpty)
    XCTAssertEqual(Set(manifest.entries.map(\.path)), files)
    XCTAssertEqual(Set(manifest.entries.map(\.id)).count, manifest.entries.count)
    for entry in manifest.entries {
      XCTAssertFalse(entry.id.isEmpty)
      XCTAssertFalse(entry.purpose.isEmpty)
      XCTAssertEqual(entry.source, "project-authored")
      XCTAssertFalse(entry.author.isEmpty)
      XCTAssertEqual(entry.license, "MIT")
      XCTAssertEqual(entry.licenseText, "LICENSE")
      XCTAssertFalse(entry.obligations.isEmpty)
      XCTAssertFalse(entry.recipe.isEmpty)
      XCTAssertFalse(entry.history.isEmpty)
      let contents = try Data(contentsOf: project.appendingPathComponent(entry.path))
      let hash = SHA256.hash(data: contents).map { String(format: "%02x", $0) }.joined()
      XCTAssertEqual(entry.sha256, hash, entry.path)
      if contents.starts(with: Data("PXR-USDC".utf8)), contents.count < 88 {
        XCTAssertEqual(entry.kind, "synthetic-usdc")
        XCTAssertEqual(entry.conformance, "synthetic/nonconforming")
      } else if entry.kind == "synthetic-usdc" {
        XCTAssertEqual(entry.conformance, "synthetic/nonconforming")
      }
      if entry.kind == "generated-asset" {
        let generator = try XCTUnwrap(entry.generator)
        XCTAssertFalse(generator.name.isEmpty)
        XCTAssertFalse(generator.version.isEmpty)
        XCTAssertFalse(generator.arguments.isEmpty)
        XCTAssertEqual(generator.sourceLicense, "MIT")
      }
    }
    let license = try String(contentsOf: project.appendingPathComponent("LICENSE"), encoding: .utf8)
    XCTAssertTrue(license.contains("Copyright (c) 2026 USDZ Validation Kit contributors"))
  }

  private func u16(_ data: Data, _ offset: Int) -> UInt16 {
    UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
  }

  private func u32(_ data: Data, _ offset: Int) -> UInt32 {
    UInt32(u16(data, offset)) | UInt32(u16(data, offset + 2)) << 16
  }

  private struct Manifest: Decodable {
    let schemaVersion: Int
    let entries: [Entry]
    struct Entry: Decodable {
      let id: String
      let path: String
      let kind: String
      let purpose: String
      let source: String
      let author: String
      let license: String
      let licenseText: String
      let obligations: String
      let sha256: String
      let recipe: String
      let history: [String]
      let conformance: String?
      let generator: Generator?
    }
    struct Generator: Decodable {
      let name: String
      let version: String
      let arguments: String
      let sourceLicense: String
    }
  }
}

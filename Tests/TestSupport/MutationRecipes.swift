import Foundation

public struct MutationCase: Equatable, Sendable {
  public enum Surface: String, CaseIterable, Sendable { case zip, usda, png, jpeg }
  public enum Oracle: Equatable, Sendable {
    case invariants
    case malformed(ruleID: String)
    case unsupported(ruleID: String)
  }

  public let id: String
  public let recipe: String
  public let surface: Surface
  public let bytes: Data
  public let oracle: Oracle
}

/// Original MIT corpus. Fixed recipes and 16 seeded single-bit flips per surface keep
/// runtime and reproduction bounded. Header vectors establish no complete-scene oracle.
public enum MutationRecipes {
  public static func cases(seed: UInt64) -> [MutationCase] {
    do { return try makeCases(seed: seed) } catch {
      preconditionFailure("Invalid fixed mutation recipe: \(error)")
    }
  }

  private static func makeCases(seed: UInt64) throws -> [MutationCase] {
    var cases: [MutationCase] = []
    func add(
      _ id: String, _ surface: MutationCase.Surface, _ bytes: Data, _ recipe: String,
      _ oracle: MutationCase.Oracle = .invariants
    ) {
      cases.append(.init(id: id, recipe: recipe, surface: surface, bytes: bytes, oracle: oracle))
    }
    func entry(_ name: String, _ payload: Data) -> ArchiveRecipe.Entry {
      .init(nameBytes: Data(name.utf8), payload: payload)
    }
    let root = Data("#usda 1.0\n".utf8)
    func package(_ payload: Data, surface: MutationCase.Surface) throws -> Data {
      if surface == .usda {
        return try ArchiveRecipe(entries: [
          entry("root.usda", payload), entry("tex.png", Fixtures.pixelPNG()),
        ]).encode()
      }
      return try ArchiveRecipe(entries: [
        entry("root.usda", root), entry(surface == .png ? "tex.png" : "tex.jpg", payload),
      ]).encode()
    }
    let zip = try ArchiveRecipe(
      entries: [
        .init(
          nameBytes: Data("root.usda".utf8), payload: root,
          centralExtra: Data([0x86, 0x19, 0, 0]), centralComment: Data([0x42]))
      ], archiveComment: Data([0x43])
    ).encodeWithLayout()
    let member = zip.entries[0]
    let nameEnd = member.name + 9
    // Preserve the directory/end record while cutting local fields, so truncations
    // reach the index parser instead of all stopping at a missing end record.
    let localBoundaries = [
      0, 4, 6, 8, 10, 12, 14, 18, 22, 26, 28, 30, nameEnd,
      nameEnd + 2, nameEnd + 4, member.payload, zip.centralDirectory,
    ]
    for cut in cuts(localBoundaries, before: zip.centralDirectory) {
      var bytes = Data(zip.bytes.prefix(cut)) + zip.bytes[zip.centralDirectory...]
      try patch32(&bytes, cut + zip.endRecord - zip.centralDirectory + 16, UInt32(cut))
      add(
        "zip.local.cut.\(cut)", .zip, bytes,
        "Keep local prefix 0..<\(cut); retain CD/EOCD; rebase CD offset.")
    }
    let centralLength = zip.endRecord - zip.centralDirectory
    let centralBoundaries = [
      0, 4, 6, 8, 10, 12, 14, 16, 20, 24, 28, 30, 32, 34, 36, 38, 42, 46,
      55, 57, 59, centralLength,
    ]
    for cut in cuts(centralBoundaries, before: centralLength) {
      var bytes = Data(zip.bytes.prefix(zip.centralDirectory + cut)) + zip.bytes[zip.endRecord...]
      try patch32(&bytes, zip.centralDirectory + cut + 12, UInt32(cut))
      add(
        "zip.central.cut.\(cut)", .zip, bytes,
        "Keep CD prefix 0..<\(cut); retain EOCD; replace CD size.")
    }
    for cut in cuts([0, 4, 6, 8, 10, 12, 16, 20, 22, 23], before: 23) {
      add(
        "zip.end.cut.\(cut)", .zip, Data(zip.bytes.prefix(zip.endRecord + cut)),
        "Truncate EOCD/comment at relative byte \(cut).")
    }
    for (name, offset) in [("name", 26), ("extra", 28)] {
      var bytes = zip.bytes
      try patch16(&bytes, offset, .max)
      add(
        "zip.interaction.\(name)-crosses-directory", .zip, bytes,
        "Local \(name) length = 65535 crosses validated CD boundary; metadata remains readable.",
        .malformed(ruleID: "UVK-ARC-001"))
    }
    for (id, patches, oracle): (String, [ArchiveRecipe.HeaderPatch], MutationCase.Oracle) in [
      ("signature", [.uint32(at: 0, 0)], .malformed(ruleID: "UVK-ARC-001")),
      ("zip64", [.uint32(at: 20, .max)], .unsupported(ruleID: "UVK-LIM-001")),
      ("range", [.uint32(at: 42, 0xffff_fffe)], .malformed(ruleID: "UVK-ARC-001")),
    ] {
      var bytes = zip.bytes
      for patch in patches {
        let base = id == "signature" ? 0 : member.centralHeader
        try ArchiveRecipe.overwrite(&bytes, at: base + patch.offset, with: patch.bytes)
      }
      add("zip.target.\(id)", .zip, bytes, "Apply fixed \(id) field patch to original ZIP.", oracle)
    }
    for (id, flags, method, compressed, uncompressed, crc, oracle):
      (String, UInt16, UInt16, UInt32?, UInt32?, UInt32?, MutationCase.Oracle) in [
        ("descriptor", 8, 0, nil, nil, nil, .unsupported(ruleID: "UVK-LIM-001")),
        ("encrypted", 1, 0, nil, nil, nil, .malformed(ruleID: "UVK-ARC-005")),
        ("compressed", 0, 8, nil, nil, nil, .malformed(ruleID: "UVK-ARC-004")),
        ("zero-compressed", 0, 0, 0, 1, nil, .malformed(ruleID: "UVK-ARC-004")),
        ("ratio", 0, 8, nil, 268_435_456, nil, .malformed(ruleID: "UVK-ARC-004")),
        ("crc", 0, 0, nil, nil, 0, .malformed(ruleID: "UVK-ARC-003")),
      ]
    {
      let bytes = try ArchiveRecipe(entries: [
        .init(
          nameBytes: Data("root.usda".utf8),
          payload: id == "zero-compressed" ? Data() : root, flags: flags, method: method,
          declaredCompressedSize: compressed, declaredUncompressedSize: uncompressed,
          declaredCRC32: crc)
      ]).encode()
      add(
        "zip.target.\(id)", .zip, bytes,
        "Original ZIP with \(id) metadata in both headers; zero-compressed uses empty physical payload.",
        oracle
      )
    }
    for (index, name) in ["../root.usda", "/root.usda", "C:/root.usda", "a\\b.usda"].enumerated() {
      let bytes = try ArchiveRecipe(entries: [entry(name, root)]).encode()
      add(
        "zip.name.\(index)", .zip, bytes, "Verbatim unsafe member name \(name).",
        .malformed(ruleID: "UVK-PATH-001"))
    }
    let tokens = [
      "#usda 1.0", "\n", "# @ignored@", "\n", "def Scope ", "\"", "@quoted@", "\"",
      " { asset a = ", "@", "tex.png", "@", " asset b = ", "@@@", "tex.png", "@@@", " }\n",
    ]
    let usda = Data(tokens.joined().utf8)
    var ends = [0]
    var tokenEnd = 0
    for token in tokens {
      tokenEnd += token.utf8.count
      ends.append(tokenEnd)
    }
    for cut in cuts(ends, before: usda.count) {
      add(
        "usda.cut.\(cut)", .usda, try package(Data(usda.prefix(cut)), surface: .usda),
        "Truncate original USDA at lexical boundary byte \(cut); regenerate ZIP lengths/CRC.")
    }
    for (id, source, oracle): (String, Data, MutationCase.Oracle) in [
      ("unterminated", root + Data("@tex.png".utf8), .malformed(ruleID: "UVK-PATH-007")),
      ("triple-open", root + Data("@@@tex.png@@".utf8), .malformed(ruleID: "UVK-PATH-007")),
      ("template", root + Data("@tex.<UDIM>.png@".utf8), .unsupported(ruleID: "UVK-LIM-003")),
      ("bom", Data([0xef, 0xbb, 0xbf]) + root, .unsupported(ruleID: "UVK-LIM-004")),
      ("absolute", root + Data("@/outside.png@".utf8), .malformed(ruleID: "UVK-PATH-004")),
      ("escape", root + Data("@../outside.png@".utf8), .malformed(ruleID: "UVK-PATH-005")),
    ] {
      add(
        "usda.target.\(id)", .usda, try package(source, surface: .usda),
        "Original USDA \(id) token/encoding; regenerate ZIP CRC.", oracle)
    }
    let png = ImageRecipes.pngHeader()
    for cut in cuts([0, 8, 12, 16, 20, 24, 25, 26, 27, 28, 29, 33], before: png.count) {
      add(
        "png.cut.\(cut)", .png, try package(Data(png.prefix(cut)), surface: .png),
        "Cut PNG signature/IHDR field at byte \(cut); regenerate ZIP CRC.")
    }
    for (id, offset, value): (String, Int, UInt8) in [
      ("signature", 0, 0), ("length", 11, 255), ("zero-width", 19, 0),
      ("crc", 32, png[32] ^ 1),
    ] {
      var bytes = png
      bytes[offset] = value
      add(
        "png.target.\(id)", .png, try package(bytes, surface: .png),
        "PNG \(id) byte \(offset) = \(value); regenerate ZIP CRC.",
        .malformed(ruleID: "UVK-BUD-007"))
    }
    let jpeg = ImageRecipes.jpegHeader()
    for cut in cuts(
      [0, 2, 3, 4, 6, 7, 9, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21], before: jpeg.count)
    {
      add(
        "jpeg.cut.\(cut)", .jpeg, try package(Data(jpeg.prefix(cut)), surface: .jpeg),
        "Cut JPEG SOI/marker/length/SOF component field at byte \(cut); regenerate ZIP CRC.")
    }
    for (id, offset, value, oracle): (String, Int, UInt8, MutationCase.Oracle) in [
      ("unsupported-sof", 3, 0xc3, .unsupported(ruleID: "UVK-LIM-005")),
      ("unknown-marker", 3, 0x01, .unsupported(ruleID: "UVK-LIM-005")),
      ("short-length", 5, 1, .malformed(ruleID: "UVK-BUD-007")),
      ("range-length", 5, 255, .malformed(ruleID: "UVK-BUD-007")),
      ("deferred-height", 8, 0, .unsupported(ruleID: "UVK-LIM-005")),
      ("zero-width", 10, 0, .malformed(ruleID: "UVK-BUD-007")),
    ] {
      var bytes = jpeg
      bytes[offset] = value
      add(
        "jpeg.target.\(id)", .jpeg, try package(bytes, surface: .jpeg),
        "JPEG \(id) byte \(offset) = \(value); regenerate ZIP CRC.", oracle)
    }
    var state = seed
    for (surface, original): (MutationCase.Surface, Data) in [
      (.zip, zip.bytes), (.usda, usda), (.png, png), (.jpeg, jpeg),
    ] {
      for index in 0..<16 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let offset = Int((state >> 16) % UInt64(original.count))
        let mask = UInt8(1 << ((state >> 48) & 7))
        var bytes = original
        bytes[offset] ^= mask
        add(
          "\(surface.rawValue).bit.\(index)", surface,
          try surface == .zip ? bytes : package(bytes, surface: surface),
          "LCG64 seed \(seed), ordered ZIP/USDA/PNG/JPEG iteration \(index); XOR byte \(offset) mask \(mask); rebuild outer ZIP for content."
        )
      }
    }
    return cases
  }

  // Include immediately-before boundaries to expose partial fixed fields as well as
  // empty next fields. Sorting fixes discovery order and removes adjacent duplicates.
  private static func cuts(_ boundaries: [Int], before end: Int) -> [Int] {
    Set(boundaries.flatMap { [$0 - 1, $0] }).filter { $0 >= 0 && $0 < end }.sorted()
  }

  private static func patch16(_ bytes: inout Data, _ offset: Int, _ value: UInt16) throws {
    try ArchiveRecipe.overwrite(
      &bytes, at: offset, with: ArchiveRecipe.HeaderPatch.uint16(at: 0, value).bytes)
  }

  private static func patch32(_ bytes: inout Data, _ offset: Int, _ value: UInt32) throws {
    try ArchiveRecipe.overwrite(
      &bytes, at: offset, with: ArchiveRecipe.HeaderPatch.uint32(at: 0, value).bytes)
  }
}

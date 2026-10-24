import Foundation

/// Independent literal-only LZ4 encoding for hostile metadata recipes, not valid-scene evidence.
public enum USDCMutationRecipe {
  public enum RecipeError: Error { case patchOutOfRange, invalidChunkCount, chunkTooLarge }

  public static func patch(_ original: Data, at offset: Int, bytes: Data) throws -> Data {
    guard offset >= 0, offset <= original.count, bytes.count <= original.count - offset else {
      throw RecipeError.patchOutOfRange
    }
    var result = original
    let start = result.index(result.startIndex, offsetBy: offset)
    let end = result.index(start, offsetBy: bytes.count)
    result.replaceSubrange(start..<end, with: bytes)
    return result
  }

  public static func literalBlock(_ bytes: Data) -> Data {
    var result = Data([UInt8(min(bytes.count, 15) << 4)])
    if bytes.count >= 15 {
      var remaining = bytes.count - 15
      while remaining >= 255 {
        result.append(255)
        remaining -= 255
      }
      result.append(UInt8(remaining))
    }
    result.append(bytes)
    return result
  }

  /// Source-compatible TfFastCompression framing: one-byte count, signed four-byte chunk sizes.
  public static func literalFrame(_ chunks: [Data]) throws -> Data {
    guard !chunks.isEmpty, chunks.count <= 255 else { throw RecipeError.invalidChunkCount }
    if chunks.count == 1 { return Data([0]) + literalBlock(chunks[0]) }
    var result = Data([UInt8(chunks.count)])
    for chunk in chunks {
      let block = literalBlock(chunk)
      guard let length = Int32(exactly: block.count) else { throw RecipeError.chunkTooLarge }
      for shift in [0, 8, 16, 24] { result.append(UInt8(truncatingIfNeeded: length >> shift)) }
      result.append(block)
    }
    return result
  }
  /// Deliberately small independent hostile-value crate; never used as positive writer evidence.
  public static func valueCrate(
    reps: [UInt64], body: Data = Data(), tokens: [String] = ["/", "default", "a.png", ""],
    strings: [UInt32] = [2, 3], names: [UInt32]? = nil, version: [UInt8] = [0, 8, 0]
  ) throws -> Data {
    func word(_ n: UInt64, _ width: Int = 8) -> Data {
      Data((0..<width).map { UInt8(truncatingIfNeeded: n >> ($0 * 8)) })
    }
    func frame(_ data: Data) throws -> Data {
      let framed = try literalFrame([data])
      return word(UInt64(framed.count)) + framed
    }
    func ints(_ values: [UInt32]) throws -> Data {
      var raw = Data()
      if !values.isEmpty {
        raw = word(0, 4) + Data(repeating: 0xff, count: (values.count + 3) / 4)
        var prev: UInt32 = 0
        for value in values {
          raw += word(UInt64(value &- prev), 4)
          prev = value
        }
      }
      return try frame(raw)
    }
    let tokenData = tokens.reduce(into: Data()) {
      $0 += Data($1.utf8)
      $0.append(0)
    }
    let fieldNames = names ?? Array(repeating: UInt32(1), count: reps.count)
    let sections: [(String, Data)] = [
      (
        "TOKENS",
        word(UInt64(tokens.count)) + word(UInt64(tokenData.count)) + (try frame(tokenData))
      ),
      (
        "STRINGS",
        word(UInt64(strings.count)) + strings.reduce(into: Data()) { $0 += word(UInt64($1), 4) }
      ),
      (
        "FIELDS",
        word(UInt64(reps.count)) + (try ints(fieldNames))
          + (try frame(reps.reduce(into: Data()) { $0 += word($1) }))
      ),
      (
        "FIELDSETS",
        word(UInt64(reps.count + 1)) + (try ints((0..<reps.count).map(UInt32.init) + [.max]))
      ),
      ("PATHS", word(1) + word(1) + (try ints([0])) + (try ints([0])) + (try ints([0xffff_fffe]))),
      ("SPECS", word(1) + (try ints([0])) + (try ints([0])) + (try ints([7]))),
    ]
    var data = Data("PXR-USDC".utf8) + Data(version) + Data(repeating: 0, count: 77) + body
    var records = Data()
    for (name, bytes) in sections {
      records += Data(name.utf8) + Data(repeating: 0, count: 16 - name.utf8.count)
      records += word(UInt64(data.count)) + word(UInt64(bytes.count))
      data += bytes
    }
    data = try patch(data, at: 16, bytes: word(UInt64(data.count)))
    return data + word(UInt64(sections.count)) + records
  }

}

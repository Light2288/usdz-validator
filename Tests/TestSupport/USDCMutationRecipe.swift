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
}

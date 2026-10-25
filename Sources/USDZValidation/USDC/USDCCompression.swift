import CUSDCCompression

/// The pinned crate framing has one count byte and signed little-endian Int32 lengths.
/// Disputed encodings never trigger another interpretation or decoder attempt.
enum USDCCompression {
  static func decode(
    input: USDCInput, range: Range<UInt64>, decodedCapacity: UInt64
  ) throws -> USDCStorage {
    let payload = input.entry.payloadRange
    guard payload.upperBound <= input.reader.size,
      range.upperBound <= payload.upperBound - payload.lowerBound
    else { throw USDCFailure.malformed(.invalidRange) }
    let compressedCount = range.upperBound - range.lowerBound
    let ledger = input.reader.ledger
    try ledger.check(resource: .usdcMetadataBlockBytes, value: compressedCount)
    try ledger.check(resource: .usdcMetadataBlockBytes, value: decodedCapacity)
    try ledger.reserveUSDCDecode(decodedCapacity)
    guard compressedCount > 0 else { throw USDCFailure.malformed(.invalidCompression) }

    // Retained staging is a separate owner; scoped source Data never escapes its charged borrow.
    let compressed = try USDCStorage.allocate(byteCount: compressedCount, ledger: ledger)
    try compressed.withUnsafeMutableBytes { destination in
      var copied = 0
      while copied < destination.count {
        let count = min(Int(SafetyResource.readChunkBytes.limit), destination.count - copied)
        try input.withBytes(offset: range.lowerBound + UInt64(copied), count: count) { bytes in
          destination.baseAddress!.advanced(by: copied).copyMemory(
            from: bytes.baseAddress!, byteCount: count)
        }
        copied += count
      }
      return copied
    }

    let output = try USDCStorage.allocate(byteCount: decodedCapacity, ledger: ledger)
    try output.withUnsafeMutableBytes { destination in
      try compressed.withUnsafeBytes { source in
        try decodeFrame(source, into: destination, ledger: ledger)
      }
    }
    return output
  }

  private static func decodeFrame(
    _ source: UnsafeRawBufferPointer, into destination: UnsafeMutableRawBufferPointer,
    ledger: ResourceLedger
  ) throws -> Int {
    let count = Int(source[0])
    guard count <= 127 else { throw USDCFailure.unsupported(.unsupportedEncoding) }
    let chunks = count == 0 ? 1 : count
    var cursor = 1
    var initialized = 0
    // LZ4 still needs a valid destination pointer when capacity is zero.
    let scratch = try ledger.reserveUSDCStorage(destination.isEmpty ? 1 : 0)
    defer { scratch.release() }
    var emptyDestination: CChar = 0
    return try withUnsafeMutablePointer(to: &emptyDestination) { emptyPointer in
      let outputPointer =
        destination.baseAddress?.assumingMemoryBound(to: CChar.self) ?? emptyPointer
      for _ in 0..<chunks {
        try ledger.consumeUSDCWork(1)
        let compressedLength: Int
        if count == 0 {
          compressedLength = source.count - cursor
        } else {
          guard source.count - cursor >= 4 else {
            throw USDCFailure.malformed(.invalidCompression)
          }
          let bits =
            UInt32(source[cursor]) | (UInt32(source[cursor + 1]) << 8)
            | (UInt32(source[cursor + 2]) << 16) | (UInt32(source[cursor + 3]) << 24)
          let signedLength = Int32(bitPattern: bits)
          guard signedLength > 0 else { throw USDCFailure.malformed(.invalidCompression) }
          compressedLength = Int(signedLength)
          cursor += 4
        }
        guard compressedLength > 0, compressedLength <= source.count - cursor else {
          throw USDCFailure.malformed(.invalidCompression)
        }
        let remaining = destination.count - initialized
        guard let inputLength = Int32(exactly: compressedLength),
          let outputCapacity = Int32(exactly: remaining)
        else { throw USDCFailure.malformed(.invalidCompression) }
        let result = LZ4_decompress_safe(
          source.baseAddress!.advanced(by: cursor).assumingMemoryBound(to: CChar.self),
          outputPointer.advanced(by: initialized), inputLength, outputCapacity)
        guard result >= 0 else { throw USDCFailure.unsupported(.unsupportedEncoding) }
        let (total, overflow) = initialized.addingReportingOverflow(Int(result))
        guard !overflow, total <= destination.count else {
          throw USDCFailure.malformed(.invalidCompression)
        }
        initialized = total
        cursor += compressedLength
      }
      guard cursor == source.count else { throw USDCFailure.malformed(.invalidCompression) }
      return initialized
    }
  }
}

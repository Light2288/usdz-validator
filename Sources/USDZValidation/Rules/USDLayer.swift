import Foundation

/// The frozen v0.1 suffix catalogue. Classification folds ASCII suffix bytes only;
/// it never changes the original member name used for namespace identity.
enum MemberKind: Equatable {
  case usd, usda, usdc, usdz, png, jpeg, exr, avif, m4a, mp3, wav, unknown
}

enum MemberClassifier {
  static func kind(nameBytes: Data) -> MemberKind {
    guard let dot = nameBytes.lastIndex(of: 0x2e),
      !nameBytes[dot...].contains(0x2f), nameBytes.distance(from: dot, to: nameBytes.endIndex) <= 6
    else { return .unknown }
    let suffix = nameBytes[nameBytes.index(after: dot)...].map { byte in
      (0x41...0x5a).contains(byte) ? byte + 0x20 : byte
    }
    switch suffix {
    case Array("usd".utf8): return .usd
    case Array("usda".utf8): return .usda
    case Array("usdc".utf8): return .usdc
    case Array("usdz".utf8): return .usdz
    case Array("png".utf8): return .png
    case Array("jpg".utf8), Array("jpeg".utf8), Array("jpe".utf8), Array("jfif".utf8):
      return .jpeg
    case Array("exr".utf8): return .exr
    case Array("avif".utf8): return .avif
    case Array("m4a".utf8): return .m4a
    case Array("mp3".utf8): return .mp3
    case Array("wav".utf8): return .wav
    default: return .unknown
    }
  }
}

enum LayerKind: Equatable {
  case usda, usdc, unrecognized, unsupportedEncoding
}

enum USDLayer {
  /// Recognition only. The caller establishes safe namespace, stored mapping and CRC first.
  /// A successful header probe never certifies USDA grammar, crate version or scene validity.
  static func identify(entry: ZIPEntry, reader: BoundedReader, diagnostics: NativeDiagnostics)
    throws
    -> LayerKind
  {
    let suffix = MemberClassifier.kind(nameBytes: entry.nameBytes)
    if suffix == .usdz {
      gap(
        "UVK-LIM-006", reason: "nestedPackage", entry: entry, diagnostics: diagnostics,
        message: "Nested package content is not inspected.")
      return .unrecognized
    }
    guard suffix == .usd || suffix == .usda || suffix == .usdc else { return .unrecognized }
    do {
      if suffix == .usda {
        try reader.ledger.check(resource: .textLayerBytes, value: entry.uncompressedSize)
      }
      guard entry.payloadRange.upperBound <= reader.size,
        entry.payloadRange.upperBound - entry.payloadRange.lowerBound == entry.uncompressedSize
      else { throw InspectionFailure.malformedRange }
      let header = try reader.read(
        offset: entry.payloadRange.lowerBound,
        count: Int(min(48, entry.payloadRange.upperBound - entry.payloadRange.lowerBound)))
      let kind: LayerKind
      if header.starts(with: Data("PXR-USDC".utf8)) {
        kind = .usdc
      } else if hasTextHeader(header) {
        kind = .usda
      } else if hasUnsupportedTextHeader(header) {
        kind = .unsupportedEncoding
      } else {
        kind = .unrecognized
      }
      if kind == .usda || kind == .unsupportedEncoding {
        try reader.ledger.check(resource: .textLayerBytes, value: entry.uncompressedSize)
      }
      if (suffix == .usda && kind != .usda && kind != .unsupportedEncoding)
        || (suffix == .usdc && kind != .usdc)
      {
        emit(
          "UVK-ARC-007", reason: "suffixSignature", entry: entry, diagnostics: diagnostics,
          message: "The USD member suffix disagrees with its bounded signature.")
      }
      if kind == .unsupportedEncoding {
        gap(
          "UVK-LIM-004", reason: "textEncoding", entry: entry, diagnostics: diagnostics,
          message: "Recognized USD text uses an unsupported encoding or byte order mark.")
      }
      return kind
    } catch let failure as InspectionFailure {
      recordReadFailure(failure, entry: entry, diagnostics: diagnostics)
      return .unrecognized
    }
  }

  static func hasTextHeader(_ bytes: Data) -> Bool {
    let magic = Data("#usda 1.0".utf8)
    guard bytes.starts(with: magic) else { return false }
    guard bytes.count > magic.count else { return true }
    return [0x0a, 0x0d, 0x20, 0x09].contains(bytes[bytes.startIndex + magic.count])
  }

  static func hasUnsupportedTextHeader(_ bytes: Data) -> Bool {
    let bom = Data([0xef, 0xbb, 0xbf])
    if bytes.starts(with: bom), hasTextHeader(Data(bytes.dropFirst(3))) { return true }
    // Recognition of the same header in UTF-16/32 is deliberately not transcoding a layer.
    for encoding: String.Encoding in [
      .utf16LittleEndian, .utf16BigEndian, .utf32LittleEndian, .utf32BigEndian,
    ] {
      guard let magic = "#usda 1.0".data(using: encoding) else { continue }
      if bytes.starts(with: magic) { return true }
      for prefix in [
        Data([0xff, 0xfe]), Data([0xfe, 0xff]), Data([0xff, 0xfe, 0, 0]), Data([0, 0, 0xfe, 0xff]),
      ] {
        if bytes.starts(with: prefix + magic) { return true }
      }
    }
    return false
  }

  static func recordReadFailure(
    _ failure: InspectionFailure, entry: ZIPEntry, diagnostics: NativeDiagnostics,
    offset: UInt64 = 0, line: UInt64? = nil, column: UInt64? = nil
  ) {
    let location = location(entry, offset: offset, line: line, column: column)
    switch failure {
    case .resourceLimit(let resource): diagnostics.limit(resource, location: location)
    case .shortRead, .malformedRange:
      gap(
        "UVK-ARC-001", reason: "layerRead", entry: entry, diagnostics: diagnostics,
        message: "The USD layer payload range is malformed or truncated.",
        offset: offset, line: line, column: column)
    }
  }

  static func gap(
    _ ruleID: String, reason: String, entry: ZIPEntry, diagnostics: NativeDiagnostics,
    message: String, offset: UInt64 = 0, line: UInt64? = nil, column: UInt64? = nil
  ) {
    emit(
      ruleID, reason: reason, entry: entry, diagnostics: diagnostics, message: message,
      offset: offset, line: line, column: column)
    diagnostics.mark(
      area: .references, state: .partial,
      reason: CoverageReason(
        ruleID: ruleID, reasonID: reason,
        location: location(entry, offset: offset, line: line, column: column)))
  }

  private static func emit(
    _ ruleID: String, reason: String, entry: ZIPEntry, diagnostics: NativeDiagnostics,
    message: String, offset: UInt64 = 0, line: UInt64? = nil, column: UInt64? = nil
  ) {
    diagnostics.emit(
      ruleID: ruleID, message: message, evidence: ["reason": .string(reason)],
      location: location(entry, offset: offset, line: line, column: column),
      key: FindingKey(
        ruleID: ruleID, entryNameBytes: entry.nameBytes, entryOffset: entry.localHeaderOffset,
        contentOffset: offset, discriminator: reason))
  }

  private static func location(
    _ entry: ZIPEntry, offset: UInt64, line: UInt64?, column: UInt64?
  ) -> FindingLocation {
    FindingLocation(
      entryName: String(data: entry.nameBytes, encoding: .utf8),
      archiveByteOffset: entry.payloadRange.lowerBound + offset, layerByteOffset: offset,
      line: line.map { Int64($0) }, column: column.map { Int64($0) })
  }
}

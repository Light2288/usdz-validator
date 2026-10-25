import Foundation

struct AssetToken: Equatable {
  enum Delimiter: Equatable { case single, triple }
  typealias Classification = ReferenceClassification

  /// Exact authored interior, including any delimiter escape backslash. Never normalized.
  let rawValueBytes: Data
  /// Interior after only the pinned USD delimiter unescape: \@@@ -> @@@ in triple form.
  /// Reference lookup consumes these bytes while evidence retains rawValueBytes.
  let valueBytes: Data
  /// Location of the opening delimiter. Columns count Unicode scalars, with CRLF one newline.
  let layerByteOffset: UInt64
  let line: UInt64
  let column: UInt64
  let delimiter: Delimiter
  let classification: Classification
}

enum USDALexer {
  /// A bounded lexical scan, not a scene parser. Call after safe stored-payload eligibility.
  /// The callback consumes each token synchronously, before scanning the next token.
  static func scan(
    entry: ZIPEntry, reader: BoundedReader, diagnostics: NativeDiagnostics,
    onToken: (AssetToken) -> Void
  ) throws {
    var cursor = Cursor(entry: entry, reader: reader)
    do {
      try reader.ledger.check(resource: .textLayerBytes, value: entry.uncompressedSize)
      guard entry.payloadRange.upperBound <= reader.size,
        entry.payloadRange.upperBound - entry.payloadRange.lowerBound == entry.uncompressedSize
      else { throw InspectionFailure.malformedRange }
      if try cursor.matches([0xef, 0xbb, 0xbf]) || cursor.matches([0xff, 0xfe])
        || cursor.matches([0xfe, 0xff]) || cursor.matches([0, 0, 0xfe, 0xff])
        || cursor.matches([0x23, 0])
      {
        throw LexicalFailure.encoding
      }
      while let byte = try cursor.peek() {
        switch byte {
        case 0x23:
          try skipLine(&cursor)
        case 0x2f where try cursor.matches([0x2f, 0x2f]):
          try skipLine(&cursor)
        case 0x2f where try cursor.matches([0x2f, 0x2a]):
          try cursor.discard(2)
          while try !cursor.matches([0x2a, 0x2f]) {
            guard try cursor.take() != nil else { return }
          }
          try cursor.discard(2)
        case 0x27, 0x22:
          try skipString(&cursor, quote: byte)
        case 0x40:
          try reader.ledger.consumeTokens(1)
          let token = try asset(&cursor, ledger: reader.ledger)
          onToken(token)
        default:
          _ = try cursor.take()
        }
      }
      try cursor.validateEnd()
    } catch let failure as LexicalFailure {
      let ruleID: String
      let reason: String
      let position: Position
      switch failure {
      case .malformedAsset(let start):
        (ruleID, reason, position) = ("UVK-PATH-007", "malformedAssetLiteral", start)
      case .encoding:
        (ruleID, reason, position) = ("UVK-LIM-004", "textEncoding", cursor.position)
      }
      USDLayer.gap(
        ruleID, reason: reason, entry: entry, diagnostics: diagnostics,
        message: ruleID == "UVK-PATH-007"
          ? "A supported asset literal is unterminated or contains a forbidden control character."
          : "USD text could not be scanned in its supported encoding.",
        offset: position.offset, line: position.line, column: position.column)
    } catch let failure as InspectionFailure {
      USDLayer.recordReadFailure(
        failure, entry: entry, diagnostics: diagnostics, offset: cursor.position.offset,
        line: cursor.position.line, column: cursor.position.column)
    }
  }

  private static func skipLine(_ cursor: inout Cursor) throws {
    while let byte = try cursor.peek(), byte != 0x0a && byte != 0x0d {
      _ = try cursor.take()
    }
  }

  private static func skipString(_ cursor: inout Cursor, quote: UInt8) throws {
    let triple = try cursor.matches([quote, quote, quote])
    let delimiter = triple ? [quote, quote, quote] : [quote]
    try cursor.discard(delimiter.count)
    while let byte = try cursor.peek() {
      if try cursor.matches(delimiter) {
        try cursor.discard(delimiter.count)
        return
      }
      // OpenUSD treats only a doubled backslash or an escaped matching quote as
      // a two-byte string unit. Other escapes need no evaluation to skip the string.
      if byte == 0x5c, let next = try cursor.peek(1), next == 0x5c || next == quote {
        try cursor.discard(2)
      } else {
        _ = try cursor.take()
      }
    }
    // Ordinary string grammar is outside the asset-literal policy: at EOF the
    // contents remain ignored. Invalid UTF-8 still establishes an encoding gap.
    try cursor.validateEnd()
  }

  private static func asset(_ cursor: inout Cursor, ledger: ResourceLedger) throws -> AssetToken {
    let start = cursor.position
    let triple = try cursor.matches([0x40, 0x40, 0x40])
    try cursor.discard(triple ? 3 : 1)
    var raw = Data()
    while let byte = try cursor.peek() {
      // A control-looking byte cannot establish malformed supported syntax while
      // an invalid UTF-8 sequence is still waiting for its continuation.
      try cursor.validatePendingContinuation(byte)
      // SdfAssetPath rejects C0/C1 controls, including CR/LF, NUL and DEL.
      if byte < 0x20 || byte == 0x7f { throw LexicalFailure.malformedAsset(start) }
      if byte == 0xc2, let next = try cursor.peek(1), (0x80...0x9f).contains(next) {
        throw LexicalFailure.malformedAsset(start)
      }
      // OpenUSD v26.08 textFileFormatParser.h AssetRef / EscapeAtAtAt and
      // parserHelpers.cpp Sdf_EvalAssetPath: only triple delimiters have an escape.
      if try triple && byte == 0x5c && cursor.matches([0x5c, 0x40, 0x40, 0x40]) {
        try ledger.check(resource: .tokenBytes, value: UInt64(raw.count) + 4)
        raw.append(contentsOf: [0x5c, 0x40, 0x40, 0x40])
        try cursor.discard(4)
      } else if try byte == 0x40 && (!triple || cursor.matches([0x40, 0x40, 0x40])) {
        var closingCount = triple ? 3 : 1
        if triple {
          while closingCount < 5, try cursor.peek(closingCount) == 0x40 { closingCount += 1 }
          let extra = closingCount - 3
          try ledger.check(resource: .tokenBytes, value: UInt64(raw.count + extra))
          raw.append(contentsOf: repeatElement(UInt8(0x40), count: extra))
        }
        try cursor.discard(closingCount)
        let value = triple ? unescapeTriple(raw) : raw
        return AssetToken(
          rawValueBytes: raw, valueBytes: value, layerByteOffset: start.offset,
          line: start.line, column: start.column, delimiter: triple ? .triple : .single,
          classification: ReferenceClassifier.classify(value))
      } else {
        try ledger.check(resource: .tokenBytes, value: UInt64(raw.count) + 1)
        // Check before appending or advancing. Even a malformed token cannot grow past 4 KiB.
        raw.append(byte)
        _ = try cursor.take()
      }
    }
    try cursor.validateEnd()
    throw LexicalFailure.malformedAsset(start)
  }

  private static func unescapeTriple(_ raw: Data) -> Data {
    let bytes = Array(raw)
    var value = Data()
    var index = 0
    while index < bytes.count {
      if bytes[index] == 0x5c, index + 3 < bytes.count,
        bytes[index + 1] == 0x40, bytes[index + 2] == 0x40, bytes[index + 3] == 0x40
      {
        value.append(contentsOf: [0x40, 0x40, 0x40])
        index += 4
      } else {
        value.append(bytes[index])
        index += 1
      }
    }
    return value
  }

  private struct Position {
    var offset: UInt64 = 0
    var line: UInt64 = 1
    var column: UInt64 = 1
  }

  private enum LexicalFailure: Error {
    case malformedAsset(Position)
    case encoding
  }

  /// At most one 64 KiB chunk plus four lookahead bytes; no whole-layer allocation.
  private struct Cursor {
    let entry: ZIPEntry
    let reader: BoundedReader
    var position = Position()
    private var buffer: [UInt8] = []
    private var index = 0
    private var nextReadOffset: UInt64
    private var continuationBytes = 0
    private var minimumContinuation: UInt8 = 0x80
    private var maximumContinuation: UInt8 = 0xbf
    private var previousCR = false

    init(entry: ZIPEntry, reader: BoundedReader) {
      self.entry = entry
      self.reader = reader
      nextReadOffset = entry.payloadRange.lowerBound
    }

    mutating func peek(_ distance: Int = 0) throws -> UInt8? {
      if index + distance >= buffer.count, nextReadOffset < entry.payloadRange.upperBound {
        // Only a fixed lookahead suffix survives replacing the old chunk.
        buffer = Array(buffer[index...])
        index = 0
        let count = Int(
          min(SafetyResource.readChunkBytes.limit, entry.payloadRange.upperBound - nextReadOffset))
        buffer.append(contentsOf: try reader.read(offset: nextReadOffset, count: count))
        nextReadOffset += UInt64(count)
      }
      guard index + distance < buffer.count else { return nil }
      return buffer[index + distance]
    }

    mutating func matches(_ bytes: [UInt8]) throws -> Bool {
      for (offset, byte) in bytes.enumerated() {
        if try peek(offset) != byte { return false }
      }
      return true
    }

    mutating func discard(_ count: Int) throws {
      for _ in 0..<count { _ = try take() }
    }

    mutating func take() throws -> UInt8? {
      guard let byte = try peek() else {
        try validateEnd()
        return nil
      }
      let continuation = continuationBytes > 0
      try validatePendingContinuation(byte)
      if continuation {
        continuationBytes -= 1
        minimumContinuation = 0x80
        maximumContinuation = 0xbf
      } else {
        switch byte {
        case 0x00...0x7f: break
        case 0xc2...0xdf: continuationBytes = 1
        case 0xe0:
          continuationBytes = 2
          minimumContinuation = 0xa0
        case 0xe1...0xec, 0xee...0xef: continuationBytes = 2
        case 0xed:
          continuationBytes = 2
          maximumContinuation = 0x9f
        case 0xf0:
          continuationBytes = 3
          minimumContinuation = 0x90
        case 0xf1...0xf3: continuationBytes = 3
        case 0xf4:
          continuationBytes = 3
          maximumContinuation = 0x8f
        default: throw LexicalFailure.encoding
        }
      }
      index += 1
      position.offset += 1
      if byte == 0x0d {
        position.line += 1
        position.column = 1
        previousCR = true
      } else if byte == 0x0a {
        if !previousCR { position.line += 1 }
        position.column = 1
        previousCR = false
      } else {
        if !continuation { position.column += 1 }
        previousCR = false
      }
      return byte
    }

    func validatePendingContinuation(_ byte: UInt8) throws {
      if continuationBytes > 0, byte < minimumContinuation || byte > maximumContinuation {
        throw LexicalFailure.encoding
      }
    }

    func validateEnd() throws {
      if continuationBytes != 0 { throw LexicalFailure.encoding }
    }
  }
}

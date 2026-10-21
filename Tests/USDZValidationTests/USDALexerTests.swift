import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

final class USDALexerTests: XCTestCase {
  func testLiteralStatesAcrossChunks() throws {
    let text =
      "#usda 1.0 @comment@\r\n  @Sources/pixel.png@ 'a \\' @decoy@' \"@decoy@\" '''@decoy@\n''' \"\"\"@decoy@\n\"\"\" // @decoy@\n/* @decoy@ */"
    let result = try scan(Data(text.utf8))
    XCTAssertEqual(result.tokens.map(\.rawValueBytes), [Data("Sources/pixel.png".utf8)])
    XCTAssertEqual(result.tokens.first?.line, 2)
    XCTAssertEqual(result.tokens.first?.column, 3)
    XCTAssertEqual(result.tokens.first?.layerByteOffset, 23)
    XCTAssertTrue(result.findings.isEmpty)
    XCTAssertEqual(result.coverage.areas[.references]?.state, .notRun)

    // Every multi-byte lexical transition crosses the fixed 64 KiB read boundary.
    for fragment in [
      "@@@a\\@@@b@@@@@", "'\\' @decoy@' @a@", "\"\\\" @decoy@\" @a@", "'''@decoy@''' @a@",
      "\"\"\"@decoy@\"\"\" @a@", "// @decoy@\r\n@a@", "/* @decoy@ */ @a@", "# @decoy@\n@a@",
    ] {
      for split in 1..<fragment.utf8.count {
        var bytes = Data(repeating: 0x20, count: 65_536 - split)
        bytes.append(Data(fragment.utf8))
        let result = try scan(bytes)
        XCTAssertEqual(result.tokens.count, 1, fragment + " split " + String(split))
        XCTAssertTrue(result.findings.isEmpty, fragment)
        if fragment.hasPrefix("@@@") {
          XCTAssertEqual(result.tokens.first?.rawValueBytes, Data("a\\@@@b@@".utf8))
          XCTAssertEqual(result.tokens.first?.valueBytes, Data("a@@@b@@".utf8))
          XCTAssertEqual(result.tokens.first?.layerByteOffset, UInt64(65_536 - split))
        } else {
          XCTAssertEqual(result.tokens.first?.valueBytes, Data("a".utf8))
        }
        XCTAssertTrue(result.reads.allSatisfy { $0.count <= 65_536 })
      }
    }
  }

  func testPinnedOpenUSDEscapeVectors() throws {
    // Characterized from PixarAnimationStudios/OpenUSD tag v26.08:
    // pxr/usd/sdf/textFileFormatParser.h:362–380 (EscapeAtAtAt, AssetRef),
    // pxr/usd/sdf/parserHelpers.cpp:725–735 (Sdf_EvalAssetPath).
    // Single @ has NO backslash escaping. Triple @ recognizes ONLY \@@@;
    // closing runs have 3–5 @, with the first 0–2 retained inside the value.
    // Both asset delimiters prohibit CR/LF, unlike triple quoted ordinary strings.
    for (source, raw, value, delimiter): (String, String, String, AssetToken.Delimiter) in [
      ("@@", "", "", .single),
      ("@@@@@@", "", "", .triple),
      ("@a\\@", "a\\", "a\\", .single),
      ("@a\\nb@", "a\\nb", "a\\nb", .single),
      ("@@@a@b@@c@@@", "a@b@@c", "a@b@@c", .triple),
      ("@@@a\\@@@b@@@", "a\\@@@b", "a@@@b", .triple),
      ("@@@a\\\\@@@b@@@", "a\\\\@@@b", "a\\@@@b", .triple),
      ("@@@a\\nb@@@", "a\\nb", "a\\nb", .triple),
      ("@@@a@@@@", "a@", "a@", .triple),
      ("@@@a@@@@@", "a@@", "a@@", .triple),
    ] {
      let result = try scan(Data(source.utf8))
      XCTAssertEqual(result.tokens.map(\.rawValueBytes), [Data(raw.utf8)], source)
      XCTAssertEqual(result.tokens.first?.valueBytes, Data(value.utf8), source)
      XCTAssertEqual(result.tokens.first?.delimiter, delimiter)
      XCTAssertTrue(result.findings.isEmpty)
    }
  }

  func testLocationsUseAuthoredBytesAndOneBasedUnicodeColumns() throws {
    let result = try scan(Data("#usda 1.0\r\nα @é.png@\r@b@\n@@@c@@@".utf8))
    XCTAssertEqual(result.tokens.map(\.layerByteOffset), [14, 23, 27])
    XCTAssertEqual(result.tokens.map(\.line), [2, 3, 4])
    XCTAssertEqual(result.tokens.map(\.column), [3, 1, 1])
    XCTAssertEqual(
      result.tokens.map(\.rawValueBytes), [Data("é.png".utf8), Data("b".utf8), Data("c".utf8)])
    for (prefix, column): (String, UInt64) in [("e\u{301} ", 4), ("é ", 3)] {
      let result = try scan(Data((prefix + "@x@").utf8))
      XCTAssertEqual(result.tokens.first?.layerByteOffset, UInt64(prefix.utf8.count))
      XCTAssertEqual(result.tokens.first?.column, column)
    }
  }

  func testMalformedSupportedLiteralsAndUnfinishedUnrelatedContexts() throws {
    for source in [
      "@unterminated", "@@@unterminated", "@a\nb@", "@@@a\rb@@@", "@a\tb@", "@a\0b@", "@a\u{7f}b@",
      "@a\u{85}b@",
    ] {
      let result = try scan(Data(source.utf8))
      XCTAssertTrue(result.tokens.isEmpty)
      XCTAssertEqual(result.findings.map(\.ruleID), ["UVK-PATH-007"])
      XCTAssertEqual(result.findings.first?.location?.layerByteOffset, 0)
      XCTAssertEqual(result.findings.first?.location?.line, 1)
      XCTAssertEqual(result.findings.first?.location?.column, 1)
      XCTAssertEqual(result.coverage.areas[.references]?.state, .partial)
    }
    for source in [
      "'unterminated @decoy@", "\"bad\n@decoy@", "'''unterminated @decoy@", "/* @decoy@",
    ] {
      let result = try scan(Data(source.utf8))
      XCTAssertTrue(result.tokens.isEmpty)
      XCTAssertEqual(result.findings.map(\.ruleID), [])
      XCTAssertEqual(result.coverage.areas[.references]?.state, .notRun)
    }
  }

  func testUnsupportedEncodingAcrossChunksStopsWithoutReplacement() throws {
    for bytes in [
      Data([0xff]), Data([0xc0, 0xaf]), Data([0xed, 0xa0, 0x80]), Data([0xf4, 0x90, 0x80, 0x80]),
      Data([0xe2, 0x82]), Data([0x80]), Data([0xef, 0xbb, 0xbf]) + Data("@a@".utf8),
      Data([0x23, 0, 0x75, 0]),
    ] {
      let result = try scan(bytes)
      XCTAssertTrue(result.tokens.isEmpty)
      XCTAssertEqual(result.findings.map(\.ruleID), ["UVK-LIM-004"])
      XCTAssertEqual(result.coverage.areas[.references]?.state, .partial)
    }
    // An invalid UTF-8 continuation wins over a control-looking C1 scalar or newline.
    for bytes in [Data([0x40, 0xe2, 0xc2, 0x85, 0x40]), Data([0x40, 0xe2, 0x0a, 0x40])] {
      let result = try scan(bytes)
      XCTAssertTrue(result.tokens.isEmpty)
      XCTAssertEqual(result.findings.map(\.ruleID), ["UVK-LIM-004"])
      XCTAssertEqual(result.coverage.areas[.references]?.state, .partial)
      XCTAssertEqual(result.findings.first?.location?.layerByteOffset, 2)
    }
    var valid = Data(repeating: 0x20, count: 65_535)
    valid.append(Data("é @a@".utf8))
    XCTAssertEqual(try scan(valid).tokens.first?.column, 65_538)
    var invalid = Data(repeating: 0x20, count: 65_535)
    invalid.append(contentsOf: [0xe2, 0x28, 0xa1])
    let result = try scan(invalid)
    XCTAssertEqual(result.findings.map(\.ruleID), ["UVK-LIM-004"])
    XCTAssertEqual(result.findings.first?.location?.layerByteOffset, 65_536)
  }

  func testValidUTF8OutsideAssetSubsetDoesNotBecomeEncodingFinding() throws {
    // U+0000 is valid UTF-8. In an asset it is a conclusive control-character error;
    // elsewhere USDA grammar validity is outside this lexical policy.
    let result = try scan(Data("#usda 1.0\n\0 @a@".utf8))
    XCTAssertEqual(result.tokens.map(\.rawValueBytes), [Data("a".utf8)])
    XCTAssertTrue(result.findings.isEmpty)
  }

  func testExpressionClassificationWithoutEvaluation() throws {
    let sources = [
      "`\"${ROOT}/a.png\"`", "${ROOT}/a.png", "tex.<UDIM>.png", "tex.####.png", "${name}",
      "package.usdz[root.usda]", "resolver:thing", "https://example/a", "tex.%04d.png",
      "tex.<UVTILE>.png",
    ]
    for source in sources {
      let result = try scan(Data(("@" + source + "@").utf8))
      XCTAssertEqual(result.tokens.first?.classification, .unsupportedExpression, source)
      XCTAssertEqual(result.tokens.first?.rawValueBytes, Data(source.utf8))
      // Task 10 checks unsafe literal prefixes before emitting the unevaluated-reference gap.
      XCTAssertTrue(result.findings.isEmpty)
    }
    for source in [
      "pixel.png", "./a.png", "../a.png", "", "Case/é.png", "C:/a.png", "a\\b.png", "100%.png",
      "money$.png", "x#y.png", "x<y.png",
    ] {
      let result = try scan(Data(("@" + source + "@").utf8))
      XCTAssertEqual(result.tokens.first?.classification, .literal, source)
    }
  }

  func testTokenLengthBoundaryChecksRawAuthoredBytes() throws {
    for count in [4_096, 4_097] {
      let result = try scan(
        ArchiveRecipe.repeatedUSDALiterals(
          valueBytes: Data(repeating: 0x61, count: count), count: 1))
      XCTAssertEqual(result.tokens.count, count == 4_096 ? 1 : 0)
      XCTAssertEqual(result.findings.map(\.ruleID), count == 4_096 ? [] : ["UVK-RES-001"])
      if count == 4_096 { XCTAssertEqual(result.tokens.first?.valueBytes.count, 4_096) }
    }
    // Unescaping must not allow an overlong authored token to fit the envelope.
    let raw = String(repeating: "a", count: 4_093) + "\\@@@"
    let result = try scan(Data(("@@@" + raw + "@@@").utf8))
    XCTAssertTrue(result.tokens.isEmpty)
    XCTAssertEqual(result.findings.first?.evidence["resource"], .string("tokenBytes"))
  }

  func testLayerLengthBoundaryStopsBeforeAnyExcessRead() throws {
    let exact = ArchiveRecipe.repeatedUSDALiterals(
      valueBytes: Data("a".utf8), count: 1, paddingBytes: 16_777_202)
    XCTAssertEqual(exact.count, 16_777_216)
    let result = try scan(exact)
    XCTAssertEqual(result.tokens.count, 1)
    XCTAssertTrue(result.findings.isEmpty)
    XCTAssertEqual(result.chargedBytes, 16_777_216)
    XCTAssertEqual(result.reads.count, 256)
    let exceeded = try scan(exact + Data([0x20]))
    XCTAssertTrue(exceeded.tokens.isEmpty)
    XCTAssertTrue(exceeded.reads.isEmpty)
    XCTAssertEqual(exceeded.findings.map(\.ruleID), ["UVK-RES-001"])
  }

  func testTokenCountBoundaryAndSharedLedger() throws {
    let exact = ArchiveRecipe.repeatedUSDALiterals(valueBytes: Data("a".utf8), count: 100_000)
    var callbacks = 0
    let ledger = ResourceLedger()
    let first = try scan(
      exact, ledger: ledger, retainingTokens: false, onToken: { _ in callbacks += 1 })
    XCTAssertEqual(callbacks, 100_000)
    XCTAssertTrue(first.findings.isEmpty)
    let second = try scan(Data("@a@".utf8), ledger: ledger)
    XCTAssertTrue(second.tokens.isEmpty)
    XCTAssertEqual(second.findings.first?.evidence["resource"], .string("tokenCount"))
    callbacks = 0
    let exceeded = try scan(
      exact + Data("@a@".utf8), retainingTokens: false, onToken: { _ in callbacks += 1 })
    XCTAssertEqual(callbacks, 100_000)
    XCTAssertEqual(exceeded.findings.first?.evidence["resource"], .string("tokenCount"))
  }

  func testCallbackConsumesSynchronouslyBeforeFurtherIO() throws {
    var bytes = Data("@a@".utf8)
    bytes.append(Data(repeating: 0x20, count: 65_533))
    bytes.append(Data("@b@".utf8))
    var seenFirst = false
    let result = try scan(
      bytes,
      beforeRead: { offset in
        if offset >= 65_600 { XCTAssertTrue(seenFirst) }
      },
      onToken: { token in
        if token.valueBytes == Data("a".utf8) { seenFirst = true }
      })
    XCTAssertEqual(result.tokens.count, 2)
    XCTAssertTrue(seenFirst)
  }

  func testCumulativeReadCeilingAndOperationalFailures() throws {
    let ledger = ResourceLedger()
    try ledger.consumeRead(1_207_959_552 - 65_536)
    let result = try scan(Data(repeating: 0x20, count: 65_537), ledger: ledger)
    XCTAssertEqual(result.reads, [64..<65_600])
    XCTAssertEqual(result.findings.first?.evidence["resource"], .string("totalReadBytes"))
    for failure in [InspectionFailure.shortRead, .malformedRange] {
      let diagnostics = NativeDiagnostics()
      let reader = BoundedReader(size: 67, ledger: ResourceLedger()) { _, _ in throw failure }
      try USDALexer.scan(entry: entry(size: 3), reader: reader, diagnostics: diagnostics) { _ in
        XCTFail("No fabricated tokens")
      }
      XCTAssertEqual(diagnostics.finish().0.map(\.ruleID), ["UVK-ARC-001"])
    }
    let reader = BoundedReader(size: 67, ledger: ResourceLedger()) { _, _ in
      throw ValidationError.operational(.inputReadFailed)
    }
    XCTAssertThrowsError(
      try USDALexer.scan(entry: entry(size: 3), reader: reader, diagnostics: NativeDiagnostics()) {
        _ in
      })
  }

  func testKnownPartialCoverageIsStickyAcrossSuccess() throws {
    let diagnostics = NativeDiagnostics()
    diagnostics.mark(
      area: .references, state: .partial,
      reason: CoverageReason(ruleID: "UVK-LIM-002", reasonID: "binary"))
    _ = try scan(Data("@a@".utf8), diagnostics: diagnostics)
    XCTAssertEqual(diagnostics.finish().1.areas[.references]?.state, .partial)
  }

  private func entry(size: UInt64) -> ZIPEntry {
    let record = ZIPDirectory.Record(
      nameBytes: Data("sub/root.usda".utf8), versionMadeBy: 0x0314, versionNeeded: 20, flags: 0,
      method: 0, modificationTime: 0, modificationDate: 0x21, crc32: 0, compressedSize: size,
      uncompressedSize: size, diskNumber: 0, internalAttributes: 0, externalAttributes: 0x81a4_0000,
      localHeaderOffset: 0, centralHeaderOffset: 64 + size)
    return ZIPEntry(
      record: record, recordRange: 0..<(64 + size), headerRange: 0..<64,
      payloadRange: 64..<(64 + size))
  }

  private func scan(
    _ bytes: Data, ledger: ResourceLedger = ResourceLedger(),
    diagnostics: NativeDiagnostics = NativeDiagnostics(), retainingTokens: Bool = true,
    beforeRead: @escaping (UInt64) -> Void = { _ in }, onToken: (AssetToken) -> Void = { _ in }
  ) throws -> (
    tokens: [AssetToken], findings: [Finding], coverage: Coverage, reads: [Range<UInt64>],
    chargedBytes: UInt64
  ) {
    var reads: [Range<UInt64>] = []
    var tokens: [AssetToken] = []
    let previous = ledger.totalReadBytes
    let reader = BoundedReader(size: 64 + UInt64(bytes.count), ledger: ledger) { offset, count in
      beforeRead(offset)
      XCTAssertGreaterThanOrEqual(offset, 64)
      XCTAssertLessThanOrEqual(offset + UInt64(count), 64 + UInt64(bytes.count))
      reads.append(offset..<(offset + UInt64(count)))
      return bytes[(Int(offset) - 64)..<(Int(offset) - 64 + count)]
    }
    try USDALexer.scan(
      entry: entry(size: UInt64(bytes.count)), reader: reader, diagnostics: diagnostics
    ) { token in
      if retainingTokens { tokens.append(token) }
      onToken(token)
    }
    let result = diagnostics.finish()
    return (tokens, result.0, result.1, reads, ledger.totalReadBytes - previous)
  }
}

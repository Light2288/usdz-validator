import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

final class ReferenceResolverTests: XCTestCase {
  func testUSDAAdapterPreservesKeysAndUnescaping() throws {
    let namespace = try package([member("root.usda"), member("a@@@b.png")])
    let author = try XCTUnwrap(namespace.defaultEntry)
    let value = Data("missing.png".utf8)
    let token = AssetToken(
      rawValueBytes: value, valueBytes: value, layerByteOffset: 17, line: 3, column: 5,
      delimiter: .single, classification: .literal)
    let adapter = NativeDiagnostics()
    ReferenceResolver.check(
      token: token, author: author, namespace: namespace, diagnostics: adapter)
    let direct = NativeDiagnostics()
    ReferenceResolver.check(
      occurrence: ReferenceOccurrence(
        valueBytes: value, classification: .literal, site: .usda(offset: 17, line: 3, column: 5)),
      author: author, namespace: namespace, diagnostics: direct)
    XCTAssertEqual(adapter.finish().0, direct.finish().0)
    XCTAssertEqual(
      adapter.finish().0.first?.occurrenceID,
      "389f990e973f1429aa75625ed4fbadd3f646014d68c712ec5c359169915caac6")
    let source = ArchiveRecipe.repeatedUSDALiterals(
      valueBytes: Data("a\\@@@b.png".utf8), count: 1, tripleDelimited: true)
    XCTAssertTrue(
      try scanPackage([member("root.usda", payload: source), member("a@@@b.png")]).findings.isEmpty)
    let binary = NativeDiagnostics()
    ReferenceResolver.check(
      occurrence: ReferenceOccurrence(
        valueBytes: Data("a\\@@@b.png".utf8), classification: .literal,
        site: .usdc(try USDCReferenceLocator(specIndex: 0, fieldOrdinal: 0))),
      author: author, namespace: namespace, diagnostics: binary)
    // A serialized backslash remains unsafe rather than being unescaped into a valid target.
    XCTAssertEqual(binary.finish().0.map(\.ruleID), ["UVK-PATH-004"])
  }

  func testBinaryResolverReusesLiteralAnchorsAndExpressionSafePrefixes() throws {
    let namespace = try package([
      member("stage/root.usda"), member("stage/sub/author.usdc"), member("stage/fallback.png"),
      member("stage/sub/local.png"), member("stage/sub/dir/", directory: true),
    ])
    let author = try XCTUnwrap(
      namespace.regularEntry(namedUTF8: Data("stage/sub/author.usdc".utf8)))
    let cases: [(String, [String])] = [
      ("local.png", []), ("fallback.png", []), ("./fallback.png", ["UVK-PATH-006"]),
      ("dir/", ["UVK-PATH-006"]), ("", []), ("../../../escape", ["UVK-PATH-005"]),
      ("../../../${ROOT}/asset", ["UVK-PATH-005", "UVK-LIM-003"]),
      ("${ROOT}/../../asset", ["UVK-LIM-003"]),
      ("https://privacy-sentinel.invalid/key", ["UVK-PATH-004", "UVK-LIM-003"]),
    ]
    for (value, rules) in cases {
      let diagnostics = NativeDiagnostics()
      let bytes = Data(value.utf8)
      ReferenceResolver.check(
        occurrence: ReferenceOccurrence(
          valueBytes: bytes, classification: ReferenceClassifier.classify(bytes),
          site: .usdc(try USDCReferenceLocator(specIndex: 2, fieldOrdinal: 4))),
        author: author, namespace: namespace, diagnostics: diagnostics)
      XCTAssertEqual(diagnostics.finish().0.map(\.ruleID), rules, value)
      XCTAssertFalse(String(describing: diagnostics.finish()).contains("privacy-sentinel"))
    }
  }

  func testAuthorAndDefaultAnchors() throws {
    let namespace = try package([
      member("stage/root.usda"), member("stage/sub/author.usda"),
      member("stage/sub/local.png"), member("stage/fallback.png"),
      member("stage/parent.png"), member("root.png"),
      member("stage/sub/directory", directory: true),
      member("stage/sub/implicit/child.png"),
      member("stage/sub/collision", directory: true), member("stage/collision"),
    ])
    let author = try XCTUnwrap(
      namespace.regularEntry(namedUTF8: Data("stage/sub/author.usda".utf8)))
    for value in ["local.png", "./local.png", "fallback.png", "../parent.png", "../../root.png"] {
      XCTAssertTrue(check(value, author: author, namespace: namespace).0.isEmpty, value)
    }
    for value in ["./fallback.png", "missing.png", "directory", "implicit", "collision"] {
      XCTAssertEqual(
        check(value, author: author, namespace: namespace).0.map(\.ruleID), ["UVK-PATH-006"], value)
    }
    let safeParentFindings = check("../parent.png", author: author, namespace: namespace).0
    XCTAssertEqual(safeParentFindings.count, 0)
    let rootEscapeFindings = check("../../../escape.png", author: author, namespace: namespace).0
    XCTAssertEqual(rootEscapeFindings.map(\.ruleID), ["UVK-PATH-005"])

    // Author-first selection must not inspect a fallback that would itself escape.
    let deeper = try package([
      member("root.usda"), member("sub/deep/author.usda"), member("sub/target.png"),
    ])
    let deepAuthor = try XCTUnwrap(
      deeper.regularEntry(namedUTF8: Data("sub/deep/author.usda".utf8)))
    XCTAssertTrue(check("a/../../target.png", author: deepAuthor, namespace: deeper).0.isEmpty)
    XCTAssertEqual(
      check("a/../../absent.png", author: deepAuthor, namespace: deeper).0.map(\.ruleID),
      ["UVK-PATH-005"])
  }

  func testUnsafeAndUnsupportedPaths() throws {
    let namespace = try package([member("root.usda"), member("a.png")])
    let author = try XCTUnwrap(namespace.defaultEntry)
    for value in [
      "/a.png", "//host/share", "C:/a.png", "c:a.png", "\\\\host\\a", "a\\b", "a\0b", "a\u{7f}b",
      "a\u{85}b",
    ] {
      let result = check(value, author: author, namespace: namespace)
      XCTAssertEqual(result.0.map(\.ruleID), ["UVK-PATH-004"], value)
      XCTAssertEqual(result.1.areas[.references]?.state, .partial)
    }
    for value in [
      "https://example/a", "https:relative", "data:image/png,abc", "resolver:thing",
      "custom+v1.2-x:value",
    ] {
      let result = check(
        value, classification: .unsupportedExpression, author: author, namespace: namespace)
      XCTAssertEqual(result.0.map(\.ruleID), ["UVK-PATH-004", "UVK-LIM-003"], value)
      XCTAssertFalse(result.0.contains { $0.ruleID == "UVK-PATH-006" })
    }
    for value in [
      "${ROOT}/a.png", "`\"a.png\"`", "a.<UDIM>.png", "a.<UVTILE>.png", "a.####.png", "a.%04d.png",
      "package.usdz[root.usda]", "9resolver:thing", "${ROOT}/../../a.png",
    ] {
      let expressionFindings = check(
        value, classification: .unsupportedExpression, author: author, namespace: namespace
      ).0
      XCTAssertEqual(expressionFindings.map(\.ruleID), ["UVK-LIM-003"], value)
      XCTAssertFalse(expressionFindings.contains { $0.ruleID == "UVK-PATH-006" })
    }
    for (value, unsafeRule) in [
      ("/${ROOT}/a", "UVK-PATH-004"), ("../${ROOT}/a", "UVK-PATH-005"),
      ("../package.usdz[root.usda]", "UVK-PATH-005"),
    ] {
      XCTAssertEqual(
        check(value, classification: .unsupportedExpression, author: author, namespace: namespace).0
          .map(\.ruleID), [unsafeRule, "UVK-LIM-003"], value)
    }
    XCTAssertTrue(check("", author: author, namespace: namespace).0.isEmpty)

    let subpackage = try package([member("root.usda"), member("sub/author.usda")])
    let subauthor = try XCTUnwrap(subpackage.regularEntry(namedUTF8: Data("sub/author.usda".utf8)))
    // The final '..' is only a prefix of an unknown expression-bearing component.
    // Only the first, slash-terminated '..' can be treated as a parent traversal.
    XCTAssertEqual(
      check(
        "../..${ROOT}/a.png", classification: .unsupportedExpression,
        author: subauthor, namespace: subpackage
      ).0.map(\.ruleID), ["UVK-LIM-003"])
  }

  func testExactIdentityAndNoHostFallback() throws {
    let namespace = try package([
      member("root.usda"), member("Case.png"), member("caf\u{e9}.png"),
      member("a b.png"), member("encoded%20only.png"), member("~literal.png"),
      member("$LITERAL.png"),
    ])
    let author = try XCTUnwrap(namespace.defaultEntry)
    for value in [
      "Case.png", "caf\u{e9}.png", "a b.png", "encoded%20only.png", "~literal.png", "$LITERAL.png",
    ] {
      XCTAssertTrue(check(value, author: author, namespace: namespace).0.isEmpty, value)
    }
    for value in ["case.png", "cafe\u{301}.png", "a%20b.png", "encoded only.png", "%43ase.png"] {
      XCTAssertEqual(
        check(value, author: author, namespace: namespace).0.map(\.ruleID), ["UVK-PATH-006"], value)
    }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    addTeardownBlock { try FileManager.default.removeItem(at: directory) }
    let host = directory.appendingPathComponent("outside.png")
    try Data([1, 2, 3]).write(to: host)
    XCTAssertEqual(
      check(host.lastPathComponent, author: author, namespace: namespace).0.map(\.ruleID),
      ["UVK-PATH-006"])
    XCTAssertEqual(
      check(host.path, author: author, namespace: namespace).0.map(\.ruleID), ["UVK-PATH-004"])
    XCTAssertEqual(try Data(contentsOf: host), Data([1, 2, 3]))
  }

  func testNormalizationIsPackageBytesOnlyAndDirectoryTargetsFail() throws {
    let namespace = try package([
      member("root.usda"), member("sub/author.usda"), member("sub/a.png"),
      member("dir/", directory: true),
    ])
    let author = try XCTUnwrap(namespace.regularEntry(namedUTF8: Data("sub/author.usda".utf8)))
    for value in ["./a.png", "x/../a.png", "././a.png", "x//../a.png"] {
      XCTAssertTrue(check(value, author: author, namespace: namespace).0.isEmpty, value)
    }
    for value in ["a.png/", "a.png/.", ".", "..", "../dir/"] {
      XCTAssertEqual(
        check(value, author: author, namespace: namespace).0.map(\.ruleID), ["UVK-PATH-006"], value)
    }
    XCTAssertEqual(
      check("%2e%2e/a.png", author: author, namespace: namespace).0.map(\.ruleID), ["UVK-PATH-006"])
  }

  func testAuthoredLocationsAndSafeEvidence() throws {
    let namespace = try package([member("sub/root.usda")])
    let author = try XCTUnwrap(namespace.defaultEntry)
    let raw = Data("/private/sensitive.png".utf8)
    let token = AssetToken(
      rawValueBytes: raw, valueBytes: raw, layerByteOffset: 17, line: 3, column: 5,
      delimiter: .single, classification: .literal)
    let diagnostics = NativeDiagnostics()
    ReferenceResolver.check(
      token: token, author: author, namespace: namespace, diagnostics: diagnostics)
    let (findings, coverage) = diagnostics.finish()
    let finding = try XCTUnwrap(findings.first)
    XCTAssertEqual(finding.ruleID, "UVK-PATH-004")
    XCTAssertEqual(finding.location?.entryName, "sub/root.usda")
    XCTAssertEqual(finding.location?.archiveByteOffset, author.payloadRange.lowerBound + 17)
    XCTAssertEqual(finding.location?.layerByteOffset, 17)
    XCTAssertEqual(finding.location?.line, 3)
    XCTAssertEqual(finding.location?.column, 5)
    XCTAssertEqual(finding.evidence, ["reason": .string("unsafeReference")])
    XCTAssertFalse(finding.message.contains("private"))
    XCTAssertEqual(coverage.areas[.references]?.reasons.first?.location, finding.location)
    XCTAssertEqual(token.rawValueBytes, raw)
  }

  func testPinnedTripleUnescapeIsTheLookupValue() throws {
    let source = ArchiveRecipe.repeatedUSDALiterals(
      valueBytes: Data("a\\@@@b.png".utf8), count: 1, tripleDelimited: true)
    let result = try scanPackage([
      member("root.usda", payload: source), member("a@@@b.png"),
    ])
    XCTAssertEqual(result.tokens.map(\.rawValueBytes), [Data("a\\@@@b.png".utf8)])
    XCTAssertEqual(result.tokens.map(\.valueBytes), [Data("a@@@b.png".utf8)])
    XCTAssertTrue(result.findings.isEmpty)
    XCTAssertEqual(result.coverage.areas[.references]?.state, .notRun)
  }

  func testCyclicLayersScanOnceAndInactiveMetadataStaysLexical() throws {
    let result = try scanPackage([
      member("root.usda", payload: Data("#usda 1.0\n@sub/child.usda@".utf8)),
      member("sub/child.usda", payload: Data("#usda 1.0\n@../root.usda@".utf8)),
      member(
        "unreferenced.usda",
        payload: Data("#usda 1.0\n( customData = { asset inactive = @missing.png@ } )".utf8)),
    ])
    XCTAssertEqual(
      result.scannedNames,
      [Data("root.usda".utf8), Data("sub/child.usda".utf8), Data("unreferenced.usda".utf8)])
    XCTAssertEqual(result.tokens.count, 3)
    XCTAssertEqual(result.findings.map(\.ruleID), ["UVK-PATH-006"])
    XCTAssertEqual(result.findings.first?.location?.entryName, "unreferenced.usda")
    // Ten header bytes plus the 34-byte metadata prefix precede the opening @.
    XCTAssertEqual(result.findings.first?.location?.layerByteOffset, 44)
  }

  func testUnsafeNamespaceNeverProducesDependentLookups() throws {
    let diagnostics = NativeDiagnostics()
    let bytes = try ArchiveRecipe(entries: [
      member("../bad.usda", payload: Data("#usda 1.0\n@missing.png@".utf8))
    ]).encode()
    let reader = BoundedReader(size: UInt64(bytes.count), ledger: ResourceLedger()) {
      offset, count in bytes[Int(offset)..<(Int(offset) + count)]
    }
    let directory = try XCTUnwrap(ZIPDirectory.read(from: reader, diagnostics: diagnostics))
    let index = try XCTUnwrap(
      ZIPIndex.build(directory: directory, reader: reader, diagnostics: diagnostics))
    XCTAssertNil(PackageNamespace.build(index: index, diagnostics: diagnostics))
    let result = diagnostics.finish()
    XCTAssertEqual(result.0.map(\.ruleID), ["UVK-PATH-001"])
    XCTAssertEqual(result.1.areas[.references]?.state, .notRun)
  }

  func testSuccessfulLookupLeavesCoveragePendingAndEarlierGapSticky() throws {
    let namespace = try package([member("root.usda"), member("a.png")])
    let author = try XCTUnwrap(namespace.defaultEntry)
    XCTAssertEqual(
      check("a.png", author: author, namespace: namespace).1.areas[.references]?.state, .notRun)
    let diagnostics = NativeDiagnostics()
    let reason = CoverageReason(ruleID: "UVK-LIM-002", reasonID: "binaryReferences")
    diagnostics.mark(area: .references, state: .partial, reason: reason)
    _ = check("a.png", author: author, namespace: namespace, diagnostics: diagnostics)
    XCTAssertEqual(diagnostics.finish().1.areas[.references]?.state, .partial)
    XCTAssertEqual(diagnostics.finish().1.areas[.references]?.reasons, [reason])
  }

  private func member(
    _ name: String, payload: Data = Data("#usda 1.0\n".utf8), directory: Bool = false
  ) -> ArchiveRecipe.Entry {
    .init(
      nameBytes: Data(name.utf8), payload: directory ? Data() : payload,
      type: directory ? .directory : .regular, flags: 0x0800)
  }

  private func package(_ members: [ArchiveRecipe.Entry]) throws -> PackageNamespace {
    let bytes = try ArchiveRecipe(entries: members).encode()
    let diagnostics = NativeDiagnostics()
    let reader = BoundedReader(size: UInt64(bytes.count), ledger: ResourceLedger()) {
      offset, count in bytes[Int(offset)..<(Int(offset) + count)]
    }
    let directory = try XCTUnwrap(ZIPDirectory.read(from: reader, diagnostics: diagnostics))
    let index = try XCTUnwrap(
      ZIPIndex.build(directory: directory, reader: reader, diagnostics: diagnostics))
    let namespace = try XCTUnwrap(PackageNamespace.build(index: index, diagnostics: diagnostics))
    XCTAssertTrue(diagnostics.finish().0.isEmpty)
    return namespace
  }

  private func check(
    _ value: String, classification: AssetToken.Classification = .literal, author: ZIPEntry,
    namespace: PackageNamespace, diagnostics: NativeDiagnostics = NativeDiagnostics()
  ) -> ([Finding], Coverage) {
    let bytes = Data(value.utf8)
    let token = AssetToken(
      rawValueBytes: bytes, valueBytes: bytes, layerByteOffset: 0, line: 1, column: 1,
      delimiter: .single, classification: classification)
    ReferenceResolver.check(
      token: token, author: author, namespace: namespace, diagnostics: diagnostics)
    return diagnostics.finish()
  }

  private func scanPackage(_ members: [ArchiveRecipe.Entry]) throws -> (
    tokens: [AssetToken], scannedNames: [Data], findings: [Finding], coverage: Coverage
  ) {
    let bytes = try ArchiveRecipe(entries: members).encode()
    let namespace = try package(members)
    let diagnostics = NativeDiagnostics()
    var reads = 0
    let reader = BoundedReader(size: UInt64(bytes.count), ledger: ResourceLedger()) {
      offset, count in
      reads += 1
      return bytes[Int(offset)..<(Int(offset) + count)]
    }
    var tokens: [AssetToken] = []
    var scannedNames: [Data] = []
    for entry in namespace.entries where MemberClassifier.kind(nameBytes: entry.nameBytes) == .usda
    {
      XCTAssertEqual(
        try USDLayer.identify(entry: entry, reader: reader, diagnostics: diagnostics), .usda)
      scannedNames.append(entry.nameBytes)
      try USDALexer.scan(entry: entry, reader: reader, diagnostics: diagnostics) { token in
        tokens.append(token)
        let previousReads = reads
        ReferenceResolver.check(
          token: token, author: entry, namespace: namespace, diagnostics: diagnostics)
        XCTAssertEqual(reads, previousReads)
      }
    }
    let result = diagnostics.finish()
    return (tokens, scannedNames, result.0, result.1)
  }
}

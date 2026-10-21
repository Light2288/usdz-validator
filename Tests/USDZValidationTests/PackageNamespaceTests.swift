import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

final class PackageNamespaceTests: XCTestCase {
  func testUnsafeNamesAndConstructs() throws {
    for name in [
      "", "\0", "a\u{1f}b", "a\u{7f}b", "a\u{85}b", "/", "/root.usda",
      "C:/root.usda", "z:relative", "//host/share", "\\\\host\\share", "a\\b",
      "a//b", "./a", "a/./b", "../a", "a/../b", "a/", "a//",
    ] {
      let result = try inspect([.init(nameBytes: Data(name.utf8), payload: Data(), flags: 0x0800)])
      XCTAssertTrue(result.namespace == nil, name.debugDescription)
      XCTAssertEqual(result.findings.map(\.ruleID), ["UVK-PATH-001"], name.debugDescription)
      XCTAssertEqual(result.coverage.areas[.entrySafety]?.state, .partial)
      XCTAssertEqual(result.coverage.areas[.references]?.state, .notRun)
      XCTAssertFalse(result.coverage.areas[.references]?.reasons.isEmpty ?? true)
    }
    let invalid = build([entry(Data([0xc3, 0x28]), flags: 0x0800)])
    XCTAssertTrue(invalid.namespace == nil)
    XCTAssertEqual(invalid.findings.map(\.ruleID), ["UVK-PATH-001"])
    for type: ArchiveRecipe.EntryType in [
      .symbolicLink, .characterDevice, .blockDevice, .fifo, .socket,
    ] {
      let result = try inspect([.init(nameBytes: Data("member".utf8), payload: Data(), type: type)])
      XCTAssertTrue(result.namespace == nil)
      XCTAssertEqual(result.findings.map(\.ruleID), ["UVK-PATH-003"])
    }
    for sizes: (UInt64, UInt64) in [(1, 0), (0, 1), (1, 1)] {
      let result = build([
        entry(Data("dir/".utf8), attributes: 0x41ed_0010, sizes: sizes)
      ])
      XCTAssertTrue(result.namespace == nil)
      XCTAssertEqual(result.findings.map(\.ruleID), ["UVK-PATH-003"])
    }
  }

  func testExactNamespaceConflicts() throws {
    let cases: [[(String, ArchiveRecipe.EntryType)]] = [
      [("a", .regular), ("a", .regular)],
      [("a/", .directory), ("a/", .directory)],
      [("a", .directory), ("a/", .directory)],
      [("a", .regular), ("a/", .directory)],
      [("a/", .directory), ("a", .regular)],
      [("a", .regular), ("a/b", .regular)],
      [("a/b/c", .regular), ("a", .regular)],
      [("a", .regular), ("a-elsewhere", .regular), ("a/b", .regular)],
      [("a/b", .regular), ("a/b/c/", .directory)],
    ]
    for names in cases {
      let result = try inspect(
        names.map {
          .init(nameBytes: Data($0.0.utf8), payload: Data(), type: $0.1)
        })
      XCTAssertTrue(result.namespace == nil, String(describing: names))
      XCTAssertEqual(result.findings.map(\.ruleID), ["UVK-PATH-002"])
    }
    let repeated = try inspect(
      (0..<3).map { _ in
        .init(nameBytes: Data("same".utf8), payload: Data())
      })
    XCTAssertTrue(repeated.namespace == nil)
    XCTAssertEqual(repeated.findings.count, 2)
    XCTAssertEqual(Set(repeated.findings.map(\.occurrenceID)).count, 2)
    XCTAssertEqual(repeated.findings.map { $0.location?.archiveByteOffset }, [64, 128])
  }

  func testCaseAndUnicodeNormalizationRemainExactBytes() throws {
    let names = ["A.usda", "caf\u{e9}.usda", "cafe\u{301}.usda", "a%20b.usda", "a b.usda"]
    let result = try inspect(
      names.map {
        .init(nameBytes: Data($0.utf8), payload: Data(), flags: 0x0800)
      })
    let namespace = try XCTUnwrap(result.namespace)
    XCTAssertTrue(result.findings.isEmpty)
    XCTAssertNotNil(namespace.regularEntry(namedUTF8: Data("A.usda".utf8)))
    XCTAssertNil(namespace.regularEntry(namedUTF8: Data("a.usda".utf8)))
    XCTAssertNil(namespace.regularEntry(namedUTF8: Data("caf\u{e9}.USDA".utf8)))
    let precomposed = try XCTUnwrap(namespace.regularEntry(namedUTF8: Data("caf\u{e9}.usda".utf8)))
    let decomposed = try XCTUnwrap(namespace.regularEntry(namedUTF8: Data("cafe\u{301}.usda".utf8)))
    XCTAssertEqual(precomposed.localHeaderOffset, 64)
    XCTAssertEqual(decomposed.localHeaderOffset, 128)
    XCTAssertNotEqual(precomposed.nameBytes, decomposed.nameBytes)
    XCTAssertNotEqual(
      namespace.regularEntry(namedUTF8: Data("a%20b.usda".utf8))?.localHeaderOffset,
      namespace.regularEntry(namedUTF8: Data("a b.usda".utf8))?.localHeaderOffset)
  }

  func testExplicitAndImplicitDirectoriesUseExactBytes() throws {
    let result = try inspect([
      .init(nameBytes: Data("dir/".utf8), payload: Data(), type: .directory),
      .init(nameBytes: Data("dir/a/b.usda".utf8), payload: Data()),
      .init(nameBytes: Data("caf\u{e9}/a".utf8), payload: Data(), flags: 0x0800),
      .init(nameBytes: Data("empty".utf8), payload: Data(), type: .directory),
    ])
    let namespace = try XCTUnwrap(result.namespace)
    XCTAssertTrue(result.findings.isEmpty)
    for name in ["dir", "dir/", "dir/a", "caf\u{e9}", "empty", "empty/"] {
      XCTAssertTrue(namespace.directoryExists(namedUTF8: Data(name.utf8)), name)
      XCTAssertNil(namespace.regularEntry(namedUTF8: Data(name.utf8)), name)
    }
    for name in ["Dir", "dir/aa", "dir/a/b.usda", "cafe\u{301}", "missing", "dir//"] {
      XCTAssertFalse(namespace.directoryExists(namedUTF8: Data(name.utf8)), name)
    }
  }

  func testUnknownEncodingAndTypeSemanticsRemainLimitations() throws {
    for member in [
      entry(Data([0xe9])),
      entry(Data("a".utf8), host: 0x6314),
      entry(Data("a".utf8), attributes: 0x31a4_0000),
    ] {
      let result = build([member])
      XCTAssertTrue(result.namespace == nil)
      XCTAssertEqual(result.findings.map(\.ruleID), ["UVK-LIM-001"])
      XCTAssertEqual(result.findings.first?.category, .validatorLimitation)
      XCTAssertEqual(result.coverage.areas[.references]?.state, .notRun)
    }
  }

  func testSupportedUnixAndDOSInterpretations() throws {
    for host: UInt16 in [0x0014, 0x0314] {
      let result = build([
        entry(Data("file".utf8), host: host, attributes: 0x20),
        entry(Data("dir/".utf8), offset: 64, host: host, attributes: 0x10),
      ])
      let namespace = try XCTUnwrap(result.namespace)
      XCTAssertNotNil(namespace.regularEntry(namedUTF8: Data("file".utf8)))
      XCTAssertTrue(namespace.directoryExists(namedUTF8: Data("dir".utf8)))
      XCTAssertNil(namespace.regularEntry(namedUTF8: Data("dir/".utf8)))
      XCTAssertTrue(result.findings.isEmpty)
      let volume = build([entry(Data("label".utf8), host: host, attributes: 0x08)])
      XCTAssertTrue(volume.namespace == nil)
      XCTAssertEqual(volume.findings.map(\.ruleID), ["UVK-PATH-003"])
    }
  }

  func testDefaultIsFirstRegularPhysicalEntryOnly() throws {
    let result = try inspect([
      .init(nameBytes: Data("dir/".utf8), payload: Data(), type: .directory),
      .init(nameBytes: Data("image.png".utf8), payload: Data([1, 2, 3])),
      .init(nameBytes: Data("later.usda".utf8), payload: Data("#usda 1.0\n".utf8)),
    ])
    let namespace = try XCTUnwrap(result.namespace)
    XCTAssertEqual(
      namespace.entries.map(\.nameBytes),
      [
        Data("dir/".utf8), Data("image.png".utf8), Data("later.usda".utf8),
      ])
    XCTAssertEqual(namespace.defaultEntry?.nameBytes, Data("image.png".utf8))
    XCTAssertEqual(namespace.defaultEntry?.recordRange, 64..<131)
    XCTAssertEqual(namespace.defaultEntry?.payloadRange, 128..<131)
    XCTAssertEqual(namespace.defaultEntry?.versionMadeBy, 0x0314)
    let directories = try inspect([
      .init(nameBytes: Data("dir/".utf8), payload: Data(), type: .directory)
    ])
    XCTAssertNil(try XCTUnwrap(directories.namespace).defaultEntry)
    XCTAssertNil(try XCTUnwrap(build([]).namespace).defaultEntry)
  }

  func testFailurePreservesIndependentKnownDiagnosticsAndOriginalLocations() throws {
    let result = build([
      entry(Data("../bad".utf8), attributes: 0xa1ff_0000),
      entry(Data("later".utf8), offset: 64, host: 0x6314),
      entry(Data("same/".utf8), offset: 128, attributes: 0x41ed_0010),
      entry(Data("same/".utf8), offset: 192, attributes: 0x41ed_0010),
    ])
    XCTAssertTrue(result.namespace == nil)
    XCTAssertEqual(
      result.findings.map(\.ruleID),
      [
        "UVK-PATH-001", "UVK-PATH-002", "UVK-PATH-003", "UVK-LIM-001",
      ])
    let conflict = result.findings.first { $0.ruleID == "UVK-PATH-002" }
    XCTAssertEqual(conflict?.location?.archiveByteOffset, 192)
    XCTAssertNil(result.findings.first?.location?.entryName)
    XCTAssertEqual(Set(result.findings.map(\.occurrenceID)).count, 4)
  }

  func testFixedNameAndEntryCountBoundaries() throws {
    let name = Data(repeating: 0x61, count: 4096)
    let exactName = build([entry(name)])
    XCTAssertNotNil(exactName.namespace?.regularEntry(namedUTF8: name))
    XCTAssertTrue(exactName.findings.isEmpty)
    let oversizedName = build([entry(name + Data([0x61]))])
    XCTAssertTrue(oversizedName.namespace == nil)
    XCTAssertEqual(oversizedName.findings.map(\.ruleID), ["UVK-RES-001"])
    var members = (0..<10_000).map { entry(Data("f\($0)".utf8), offset: UInt64($0 * 64)) }
    let exactCount = build(members)
    XCTAssertEqual(exactCount.namespace?.entries.count, 10_000)
    XCTAssertTrue(exactCount.findings.isEmpty)
    members.append(entry(Data("over".utf8), offset: 640_000))
    let oversizedCount = build(members)
    XCTAssertTrue(oversizedCount.namespace == nil)
    XCTAssertEqual(oversizedCount.findings.map(\.ruleID), ["UVK-RES-001"])
  }

  func testSuccessLeavesCoveragePendingAndDoesNotEraseEarlierGaps() throws {
    let diagnostics = NativeDiagnostics()
    let reason = CoverageReason(ruleID: "UVK-LIM-002", reasonID: "earlier")
    diagnostics.mark(area: .references, state: .partial, reason: reason)
    let namespace = PackageNamespace.build(
      index: ZIPIndex(entries: [entry(Data("a".utf8))]), diagnostics: diagnostics)
    XCTAssertNotNil(namespace)
    let (_, coverage) = diagnostics.finish()
    XCTAssertEqual(coverage.areas[.references]?.state, .partial)
    XCTAssertEqual(coverage.areas[.references]?.reasons, [reason])
    for area in CoverageArea.allCases where area != .references {
      XCTAssertEqual(coverage.areas[area]?.state, .notRun)
    }
  }

  private func entry(
    _ name: Data, offset: UInt64 = 0, flags: UInt16 = 0, host: UInt16 = 0x0314,
    attributes: UInt32 = 0x81a4_0000, sizes: (UInt64, UInt64) = (0, 0)
  ) -> ZIPEntry {
    let record = ZIPDirectory.Record(
      nameBytes: name, versionMadeBy: host, versionNeeded: 20, flags: flags, method: 0,
      modificationTime: 0, modificationDate: 0x0021, crc32: 0,
      compressedSize: sizes.0, uncompressedSize: sizes.1, diskNumber: 0,
      internalAttributes: 0, externalAttributes: attributes, localHeaderOffset: offset,
      centralHeaderOffset: 1_000_000 + offset)
    return ZIPEntry(
      record: record, recordRange: offset..<(offset + 64 + sizes.0),
      headerRange: offset..<(offset + 64),
      payloadRange: (offset + 64)..<(offset + 64 + sizes.0))
  }

  private func build(_ entries: [ZIPEntry]) -> (
    namespace: PackageNamespace?, findings: [Finding], coverage: Coverage
  ) {
    let diagnostics = NativeDiagnostics()
    let namespace = PackageNamespace.build(
      index: ZIPIndex(entries: entries), diagnostics: diagnostics)
    let (findings, coverage) = diagnostics.finish()
    return (namespace, findings, coverage)
  }

  private func inspect(_ entries: [ArchiveRecipe.Entry]) throws -> (
    namespace: PackageNamespace?, findings: [Finding], coverage: Coverage
  ) {
    let bytes = try ArchiveRecipe(entries: entries).encode()
    var reads = 0
    let reader = BoundedReader(size: UInt64(bytes.count), ledger: ResourceLedger()) {
      offset, count in
      reads += 1
      return bytes[Int(offset)..<(Int(offset) + count)]
    }
    let directory = try XCTUnwrap(
      ZIPDirectory.read(from: reader, diagnostics: NativeDiagnostics()))
    let index = try XCTUnwrap(
      ZIPIndex.build(directory: directory, reader: reader, diagnostics: NativeDiagnostics()))
    let previousReads = reads
    let result = build(index.entries)
    XCTAssertEqual(reads, previousReads)
    return result
  }
}

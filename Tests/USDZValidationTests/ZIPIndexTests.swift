import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

final class ZIPIndexTests: XCTestCase {
  func testHeaderAgreementAndOwnership() throws {
    // Omitting any corresponding-field comparison would accept one of these contradictions.
    let patches: [ArchiveRecipe.HeaderPatch] = [
      .uint16(at: 4, 10), .uint16(at: 6, 1), .uint16(at: 8, 8),
      .uint16(at: 10, 1), .uint16(at: 12, 0x0022), .uint32(at: 14, 0),
      .uint32(at: 18, 4), .uint32(at: 22, 4), .uint16(at: 26, 8),
    ]
    for patch in patches {
      var member = entry()
      member.localHeaderPatches = [patch]
      try assertRejected(try ArchiveRecipe(entries: [member]).encode(), rule: "UVK-ARC-002")
    }
    var differentName = try ArchiveRecipe(entries: [entry()]).encodeWithLayout()
    differentName.bytes[differentName.entries[0].name] = 0x52
    try assertRejected(differentName.bytes, rule: "UVK-ARC-002")

    var duplicate = entry()
    duplicate.centralHeaderPatches = [.uint32(at: 42, 0)]
    try assertRejected(
      try ArchiveRecipe(entries: [entry(), duplicate]).encode(), rule: "UVK-ARC-002")

    let pair = try ArchiveRecipe(entries: [entry(), entry()]).encodeWithLayout()
    var overlap = pair.bytes
    // First payload claims one byte of the second local header.
    try setSize(&overlap, layout: pair, entry: 0, size: 6)
    try assertRejected(overlap, rule: "UVK-ARC-002")
    let single = try ArchiveRecipe(entries: [entry()]).encodeWithLayout()
    for end in [single.centralDirectory + 1, single.endRecord + 1, single.bytes.count] {
      var bytes = single.bytes
      try setSize(&bytes, layout: single, entry: 0, size: UInt32(end - 64))
      try assertRejected(bytes, rule: "UVK-ARC-002")
    }

    for offset in [26, 28] {
      var member = entry()
      member.localHeaderPatches = [.uint16(at: offset, .max)]
      try assertRejected(try ArchiveRecipe(entries: [member]).encode(), rule: "UVK-ARC-001")
    }
    var badSignature = entry()
    badSignature.localHeaderPatches = [.uint32(at: 0, 0)]
    try assertRejected(try ArchiveRecipe(entries: [badSignature]).encode(), rule: "UVK-ARC-001")
    var badExtra = entry()
    badExtra.localExtra = Data([0x86, 0x19, 10, 0])
    try assertRejected(
      try ArchiveRecipe(entries: [badExtra], alignment: 1).encode(), rule: "UVK-ARC-001")
  }

  func testRecordMappingBoundary() throws {
    let bytes = try ArchiveRecipe(entries: [
      .init(nameBytes: Data("dir/".utf8), payload: Data(), type: .directory), entry(),
    ]).encode()
    let result = try inspect(bytes)
    let index = try XCTUnwrap(result.index)
    XCTAssertEqual(index.entries.count, 2)
    XCTAssertEqual(index.entries.first?.recordRange, 0..<64)
    XCTAssertEqual(index.entries.first?.payloadRange, 64..<64)
    XCTAssertEqual(index.entries.last?.headerRange, 64..<128)
    XCTAssertEqual(index.entries.last?.payloadRange, 128..<133)
    XCTAssertEqual(index.entries.first?.record.externalAttributes, 0x41ed_0010)
    XCTAssertEqual(index.entries.last?.record.nameBytes, Data("root.usda".utf8))
    XCTAssertTrue(result.findings.isEmpty)
    XCTAssertEqual(result.coverage.areas[.containerStructure]?.state, .notRun)

    // Directory order cannot choose the physical order or default member.
    let directory = try directory(for: bytes)
    let reversed = ZIPDirectory(
      records: directory.records.reversed(), centralDirectoryRange: directory.centralDirectoryRange,
      endRecordOffset: directory.endRecordOffset,
      archiveCommentLength: directory.archiveCommentLength)
    let reordered = try inspect(bytes, directory: reversed)
    XCTAssertEqual(reordered.index?.entries.map { $0.record.localHeaderOffset }, [0, 64])

    let hidden = try ArchiveRecipe(entries: [entry()]).encodeWithLayout()
    let hiddenLocal = Data(hidden.bytes[..<hidden.centralDirectory])
    for recipe in [
      ArchiveRecipe(entries: [entry()], prefix: hiddenLocal),
      ArchiveRecipe(entries: [entry()], bytesBeforeDirectory: hiddenLocal),
      ArchiveRecipe(entries: [], bytesBeforeDirectory: hiddenLocal),
    ] {
      try assertRejected(try recipe.encode(), rule: "UVK-ARC-002")
    }
    for recipe in [
      ArchiveRecipe(entries: [entry()], prefix: Data("MZ executable prefix".utf8)),
      ArchiveRecipe(entries: [entry()], bytesBeforeDirectory: Data([0, 0, 0, 0])),
      ArchiveRecipe(entries: [], bytesBeforeDirectory: Data([1, 2, 3])),
    ] {
      try assertRejected(try recipe.encode(), rule: "UVK-LIM-001")
    }
    // A complete local record, CD, and EOCD inside a known payload are inert bytes.
    let signatures = try ArchiveRecipe(entries: [entry()]).encode()
    let embedded = try inspect(
      try ArchiveRecipe(entries: [.init(nameBytes: Data("root.usda".utf8), payload: signatures)])
        .encode())
    XCTAssertNotNil(embedded.index)
    XCTAssertTrue(embedded.findings.isEmpty)
    let payload = try XCTUnwrap(embedded.index?.entries.first?.payloadRange)
    XCTAssertFalse(embedded.reads.contains { $0.overlaps(payload) })
    XCTAssertNotNil(try inspect(try ArchiveRecipe(entries: []).encode()).index)
  }

  func testLocalUnsupportedExtrasAndBoundedFailures() throws {
    var zip64 = entry()
    zip64.localExtra = Data([1, 0, 0, 0])
    try assertRejected(try ArchiveRecipe(entries: [zip64]).encode(), rule: "UVK-LIM-001")

    let bytes = try ArchiveRecipe(entries: [entry()]).encode()
    let directory = try directory(for: bytes)
    for failure in [InspectionFailure.shortRead, .resourceLimit(.totalReadBytes)] {
      let reader = BoundedReader(size: UInt64(bytes.count), ledger: ResourceLedger()) { _, _ in
        throw failure
      }
      let diagnostics = NativeDiagnostics()
      XCTAssertNil(
        try ZIPIndex.build(directory: directory, reader: reader, diagnostics: diagnostics))
      XCTAssertEqual(
        diagnostics.finish().0.map(\.ruleID),
        [failure == .shortRead ? "UVK-ARC-001" : "UVK-RES-001"])
    }
    let reader = BoundedReader(size: UInt64(bytes.count), ledger: ResourceLedger()) { _, _ in
      throw ValidationError.operational(.inputUnavailable)
    }
    XCTAssertThrowsError(
      try ZIPIndex.build(directory: directory, reader: reader, diagnostics: NativeDiagnostics()))
  }

  func testUnsupportedUnindexedFeaturesDoNotUseClassicSizeAssumptions() throws {
    // A ZIP64 sentinel or descriptor makes a hidden record's payload extent unknown.
    for patches: [ArchiveRecipe.HeaderPatch] in [
      [.uint32(at: 18, .max)],
      [.uint16(at: 6, 8), .uint32(at: 18, .max)],
      [.uint16(at: 4, 45), .uint32(at: 18, .max)],
    ] {
      var hidden = entry()
      hidden.localHeaderPatches = patches
      let encoding = try ArchiveRecipe(entries: [hidden]).encodeWithLayout()
      try assertRejected(
        try ArchiveRecipe(
          entries: [entry()],
          bytesBeforeDirectory: Data(encoding.bytes[..<encoding.centralDirectory])
        ).encode(), rule: "UVK-LIM-001")
    }
  }

  private func entry() -> ArchiveRecipe.Entry {
    .init(nameBytes: Data("root.usda".utf8), payload: Data("hello".utf8))
  }

  private func directory(for bytes: Data) throws -> ZIPDirectory {
    let reader = BoundedReader(size: UInt64(bytes.count), ledger: ResourceLedger()) {
      offset, count in
      bytes.subdata(in: Int(offset)..<(Int(offset) + count))
    }
    return try XCTUnwrap(ZIPDirectory.read(from: reader, diagnostics: NativeDiagnostics()))
  }

  private func inspect(_ bytes: Data, directory: ZIPDirectory? = nil) throws -> (
    index: ZIPIndex?, findings: [Finding], coverage: Coverage, reads: [Range<UInt64>]
  ) {
    let directory = try directory ?? self.directory(for: bytes)
    var reads: [Range<UInt64>] = []
    let reader = BoundedReader(size: UInt64(bytes.count), ledger: ResourceLedger()) {
      offset, count in
      reads.append(offset..<(offset + UInt64(count)))
      return bytes.subdata(in: Int(offset)..<(Int(offset) + count))
    }
    let diagnostics = NativeDiagnostics()
    let index = try ZIPIndex.build(directory: directory, reader: reader, diagnostics: diagnostics)
    let (findings, coverage) = diagnostics.finish()
    return (index, findings, coverage, reads)
  }

  private func assertRejected(
    _ bytes: Data, rule: String, file: StaticString = #filePath, line: UInt = #line
  ) throws {
    let result = try inspect(bytes)
    XCTAssertNil(result.index, file: file, line: line)
    XCTAssertEqual(result.findings.map(\.ruleID), [rule], file: file, line: line)
    XCTAssertEqual(
      result.coverage.areas[.containerStructure]?.state, .partial, file: file, line: line)
    XCTAssertEqual(result.coverage.areas[.references]?.state, .notRun, file: file, line: line)
    XCTAssertFalse(result.coverage.isComplete, file: file, line: line)
  }

  private func setSize(
    _ bytes: inout Data, layout: ArchiveRecipe.Encoding, entry: Int, size: UInt32
  ) throws {
    for offset in [
      layout.entries[entry].localHeader + 18, layout.entries[entry].localHeader + 22,
      layout.entries[entry].centralHeader + 20, layout.entries[entry].centralHeader + 24,
    ] {
      try ArchiveRecipe.overwrite(
        &bytes, at: offset, with: ArchiveRecipe.HeaderPatch.uint32(at: 0, size).bytes)
    }
  }
}

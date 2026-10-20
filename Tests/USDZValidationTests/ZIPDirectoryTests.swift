import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

final class ZIPDirectoryTests: XCTestCase {
  func testEOCDAndDirectorySafety() throws {
    let encoding = try recipe().encodeWithLayout()
    let valid = try inspect(encoding.bytes)
    let directory = try XCTUnwrap(valid.directory)
    XCTAssertEqual(directory.records.count, 1)
    let record = directory.records[0]
    XCTAssertEqual(record.nameBytes, Data("root.usda".utf8))
    XCTAssertEqual(record.versionMadeBy, 0x0314)
    XCTAssertEqual(record.versionNeeded, 20)
    XCTAssertEqual(record.flags, 0)
    XCTAssertEqual(record.method, 0)
    XCTAssertEqual(record.modificationDate, 0x0021)
    XCTAssertEqual(record.modificationTime, 0)
    XCTAssertEqual(record.crc32, 0x3610_a686)
    XCTAssertEqual(record.compressedSize, 5)
    XCTAssertEqual(record.uncompressedSize, 5)
    XCTAssertEqual(record.diskNumber, 0)
    XCTAssertEqual(record.internalAttributes, 0)
    XCTAssertEqual(record.externalAttributes, 0x81a4_0000)
    XCTAssertEqual(record.localHeaderOffset, 0)
    XCTAssertEqual(record.centralHeaderOffset, UInt64(encoding.centralDirectory))
    XCTAssertEqual(
      directory.centralDirectoryRange,
      UInt64(encoding.centralDirectory)..<UInt64(encoding.endRecord))
    XCTAssertEqual(directory.endRecordOffset, UInt64(encoding.endRecord))
    XCTAssertTrue(valid.findings.isEmpty)
    // Directory discovery does not claim that later local/header/content checks ran.
    XCTAssertEqual(valid.coverage.areas[.containerStructure]?.state, .notRun)
    XCTAssertEqual(valid.coverage.areas[.references]?.state, .notRun)

    for bytes in [Data(), Data("not a ZIP file".utf8)] {
      try assertRejected(bytes, rules: ["UVK-ARC-001"])
    }
    for length in 0..<22 {
      try assertRejected(
        Data(encoding.bytes.prefix(encoding.endRecord + length)), rules: ["UVK-ARC-001"])
    }
    // Keep the EOCD while truncating each byte of the central fixed header.
    for length in 0..<46 {
      var bytes = Data(encoding.bytes.prefix(encoding.centralDirectory + length))
      var end = Data(encoding.bytes[encoding.endRecord...])
      try patch(&end, at: 12, value: UInt32(length))
      bytes.append(end)
      try assertRejected(bytes, rules: ["UVK-ARC-001"])
    }
    for patches: [ArchiveRecipe.HeaderPatch] in [
      [.uint16(at: 8, 2), .uint16(at: 10, 2)],
      [.uint16(at: 8, 0), .uint16(at: 10, 0)],
      [.uint16(at: 8, 0)],
      [.uint32(at: 16, 0xffff_fffe)],
      [.uint32(at: 12, 0xffff_fffe)],
      [.uint32(at: 12, UInt32(encoding.endRecord - encoding.centralDirectory + 1))],
    ] {
      try assertRejected(try recipe(endPatches: patches).encode(), rules: ["UVK-ARC-001"])
    }
    for extra in [Data([42]), Data([42, 0, 3, 0, 1, 2])] {
      try assertRejected(try recipe(extra: extra).encode(), rules: ["UVK-ARC-001"])
    }
    try assertRejected(
      try recipe(centralPatches: [.uint32(at: 42, UInt32(encoding.centralDirectory))]).encode(),
      rules: ["UVK-ARC-001"])
    // Unknown noninterpreting extra fields and bounded comments are legal metadata.
    let padded = try inspect(try recipe(extra: Data([0x86, 0x19, 3, 0, 7, 8, 9])).encode())
    XCTAssertNotNil(padded.directory)
    XCTAssertTrue(padded.findings.isEmpty)
    let empty = try inspect(try ArchiveRecipe(entries: []).encode())
    XCTAssertEqual(empty.directory?.records.count, 0)
  }

  func testCommentSignatureAndMaximumTailStayBounded() throws {
    var comment = Data(repeating: 0x41, count: 65_535)
    // An apparent EOCD at the very end of a real comment must not hide the real one.
    let fake = try ArchiveRecipe(entries: []).encode()
    comment.replaceSubrange((comment.count - fake.count)..<comment.count, with: fake)
    let encoding = try recipe(comment: comment).encodeWithLayout()
    let result = try inspect(encoding.bytes)
    XCTAssertEqual(result.directory?.records.count, 1)
    XCTAssertEqual(result.directory?.archiveCommentLength, 65_535)
    XCTAssertEqual(result.directory?.endRecordOffset, UInt64(encoding.endRecord))
    XCTAssertTrue(result.findings.isEmpty)
    XCTAssertGreaterThan(result.reads.count, 1)
    XCTAssertLessThanOrEqual(result.reads.map(\.count).max() ?? 0, 65_536)
    let tailStart = max(0, encoding.bytes.count - 65_557)
    for read in result.reads {
      let isTail = read.offset >= UInt64(tailStart)
      let isDirectory =
        read.offset >= UInt64(encoding.centralDirectory)
        && read.offset + UInt64(read.count) <= UInt64(encoding.endRecord)
      XCTAssertTrue(isTail || isDirectory)
    }
    var truncated = encoding.bytes
    truncated.removeLast()
    try assertRejected(truncated, rules: ["UVK-ARC-001"])
  }

  func testUnsupportedFeaturesAreLimitations() throws {
    for patches: [ArchiveRecipe.HeaderPatch] in [
      [.uint16(at: 4, 1)], [.uint16(at: 6, 1)],
      [.uint16(at: 8, .max), .uint16(at: 10, .max)],
      [.uint32(at: 12, .max)], [.uint32(at: 16, .max)],
      // Disk-local entry counts are not interpreted using single-disk assumptions.
      [.uint16(at: 4, 1), .uint16(at: 8, 0)],
    ] {
      try assertRejected(try recipe(endPatches: patches).encode(), rules: ["UVK-LIM-001"])
    }
    for patches: [ArchiveRecipe.HeaderPatch] in [
      [.uint16(at: 6, 45)], [.uint16(at: 8, 8)], [.uint16(at: 8, 0x10)],
      [.uint16(at: 34, 1)], [.uint16(at: 34, .max)],
      [.uint32(at: 20, .max)], [.uint32(at: 24, .max)], [.uint32(at: 42, .max)],
    ] {
      try assertRejected(try recipe(centralPatches: patches).encode(), rules: ["UVK-LIM-001"])
    }
    try assertRejected(try recipe(extra: Data([1, 0, 0, 0])).encode(), rules: ["UVK-LIM-001"])
    try assertRejected(try recipe(name: Data([0xe9])).encode(), rules: ["UVK-LIM-001"])
    let utf8 = try inspect(try recipe(name: Data("é.usda".utf8), flags: 0x0800).encode())
    XCTAssertNotNil(utf8.directory)
    // Invalid declared UTF-8 is a name error, rather than unsupported encoding.
    try assertRejected(
      try recipe(name: Data([0xff]), flags: 0x0800).encode(), rules: ["UVK-PATH-001"])

    var locatorArchive = try recipe().encodeWithLayout()
    locatorArchive.bytes.insert(
      contentsOf: Data([0x50, 0x4b, 0x06, 0x07]) + Data(repeating: 0, count: 16),
      at: locatorArchive.endRecord)
    try assertRejected(locatorArchive.bytes, rules: ["UVK-LIM-001"])
    // An established variable-field truncation survives an unsupported version marker.
    try assertRejected(
      try recipe(centralPatches: [.uint16(at: 6, 45), .uint16(at: 28, 100)]).encode(),
      rules: ["UVK-ARC-001"])
    // An unrecognized bounded gap is outside this supported layout, not invalid ZIP.
    var gap = try recipe().encodeWithLayout()
    gap.bytes.insert(0, at: gap.endRecord)
    try assertRejected(gap.bytes, rules: ["UVK-LIM-001"])
  }

  func testSafetyCeilingsBeforeAllocationOrPayloadReads() throws {
    for (length, rejected) in [(4_096, false), (4_097, true)] {
      let result = try inspect(try recipe(name: Data(repeating: 0x61, count: length)).encode())
      XCTAssertEqual(result.directory == nil, rejected)
      XCTAssertEqual(result.findings.map(\.ruleID), rejected ? ["UVK-RES-001"] : [])
    }
    for (count, rejected) in [(10_000, false), (10_001, true)] {
      let result = try inspect(
        try ArchiveRecipe(entries: Array(repeating: entry(), count: count)).encode())
      XCTAssertEqual(result.directory?.records.count, rejected ? nil : count)
      XCTAssertEqual(result.findings.map(\.ruleID), rejected ? ["UVK-RES-001"] : [])
    }
    for (bytes, rejected) in [(UInt32(268_435_456), false), (268_435_457, true)] {
      let member = ArchiveRecipe.Entry(
        nameBytes: Data("a".utf8), payload: Data(), method: 8,
        declaredCompressedSize: 1, declaredUncompressedSize: bytes)
      let result = try inspect(try ArchiveRecipe(entries: [member]).encode())
      XCTAssertEqual(result.directory == nil, rejected)
      XCTAssertEqual(result.findings.map(\.ruleID), rejected ? ["UVK-RES-001"] : [])
    }
    // Rejected compressed members still contribute their declared expansion to the sum.
    let full = ArchiveRecipe.Entry(
      nameBytes: Data("a".utf8), payload: Data(), method: 8,
      declaredCompressedSize: 1, declaredUncompressedSize: 268_435_456)
    for (lastSize, rejected) in [(UInt32(0), false), (1, true)] {
      let last = ArchiveRecipe.Entry(
        nameBytes: Data("b".utf8), payload: Data(), method: 8,
        declaredCompressedSize: 0, declaredUncompressedSize: lastSize)
      let result = try inspect(try ArchiveRecipe(entries: [full, full, last]).encode())
      XCTAssertEqual(result.directory == nil, rejected)
      XCTAssertEqual(result.findings.map(\.ruleID), rejected ? ["UVK-RES-001"] : [])
    }
    for (size, rejected) in [(16_777_216, false), (16_777_217, true)] {
      // 256 independent directory records; comments fill the directory without payload allocation.
      var entries: [ArchiveRecipe.Entry] = []
      var remaining = size
      for index in 0..<256 {
        let commentCount = min(65_535, remaining - (256 - index) * 47)
        var member = entry(name: Data([0x61]))
        member.centralComment = Data(repeating: 0, count: commentCount)
        entries.append(member)
        remaining -= 47 + commentCount
      }
      XCTAssertEqual(remaining, 0)
      let result = try inspect(try ArchiveRecipe(entries: entries).encode())
      XCTAssertEqual(result.directory == nil, rejected)
      XCTAssertEqual(result.findings.map(\.ruleID), rejected ? ["UVK-RES-001"] : [])
    }
    var sourceCalls = 0
    let tooLarge = BoundedReader(size: 536_870_913, ledger: ResourceLedger()) { _, _ in
      sourceCalls += 1
      return Data()
    }
    let diagnostics = NativeDiagnostics()
    XCTAssertNil(try ZIPDirectory.read(from: tooLarge, diagnostics: diagnostics))
    XCTAssertEqual(sourceCalls, 0)
    XCTAssertEqual(diagnostics.finish().0.map(\.ruleID), ["UVK-RES-001"])
  }

  func testCompressedDeclarationCeilingAndUnsupportedCommentCandidate() throws {
    let oversized = ArchiveRecipe.Entry(
      nameBytes: Data("a".utf8), payload: Data(),
      method: 8, declaredCompressedSize: 268_435_457, declaredUncompressedSize: 1)
    let result = try inspect(try ArchiveRecipe(entries: [oversized]).encode())
    XCTAssertNil(result.directory)
    XCTAssertEqual(result.findings.map(\.ruleID), ["UVK-RES-001"])

    // A forged classic candidate in a comment cannot erase a preceding ZIP64 EOCD.
    var fakeEnd = try ArchiveRecipe(
      entries: [],
      endRecordPatches: [
        .uint16(at: 8, 1), .uint16(at: 10, 1), .uint32(at: 12, 46),
      ]
    ).encode()
    let endOffset = try recipe().encodeWithLayout().endRecord
    try patch(&fakeEnd, at: 16, value: UInt32(endOffset + 22))
    let comment = Data(repeating: 0, count: 46) + fakeEnd
    try assertRejected(
      try recipe(comment: comment, endPatches: [.uint32(at: 16, .max)]).encode(),
      rules: ["UVK-LIM-001"])
  }

  func testPayloadUnsupportedEOCDCandidateDoesNotDisplaceRealEndRecord() throws {
    var payload = Data(repeating: 0x41, count: 100)
    let baseline = try ArchiveRecipe(entries: [
      .init(nameBytes: Data("root.usda".utf8), payload: payload)
    ]).encodeWithLayout()
    XCTAssertEqual(baseline.entries[0].payload, 64)
    XCTAssertEqual(baseline.endRecord, 219)
    XCTAssertEqual(baseline.bytes.count, 241)
    let fakeEnd = try ArchiveRecipe(
      entries: [],
      endRecordPatches: [
        .uint16(at: 4, 1), .uint16(at: 20, 155),
      ]
    ).encode()
    payload.replaceSubrange(0..<22, with: fakeEnd)
    // Re-encoding independently updates both CRC declarations for the valid payload.
    let encoding = try ArchiveRecipe(entries: [
      .init(nameBytes: Data("root.usda".utf8), payload: payload)
    ]).encodeWithLayout()
    let result = try inspect(encoding.bytes)
    XCTAssertNotNil(result.directory)
    XCTAssertEqual(result.directory?.endRecordOffset, 219)
    XCTAssertEqual(result.directory?.records.count, 1)
    XCTAssertTrue(result.findings.isEmpty)
  }

  func testPayloadZIP64SentinelWithoutPlacementDoesNotDisplaceRealEndRecord() throws {
    var payload = Data(repeating: 0x41, count: 100)
    let baseline = try ArchiveRecipe(entries: [
      .init(nameBytes: Data("root.usda".utf8), payload: payload)
    ]).encodeWithLayout()
    let original = try inspect(baseline.bytes)
    XCTAssertNotNil(original.directory)
    XCTAssertTrue(original.findings.isEmpty)
    XCTAssertEqual(baseline.entries[0].payload, 64)
    XCTAssertEqual(baseline.endRecord, 219)
    XCTAssertEqual(baseline.bytes.count, 241)
    let fakeEnd = try ArchiveRecipe(
      entries: [],
      endRecordPatches: [
        .uint16(at: 8, .max), .uint16(at: 20, 155),
      ]
    ).encode()
    payload.replaceSubrange(0..<22, with: fakeEnd)
    // The only sentinel is in content; independent re-encoding updates both CRCs.
    let encoding = try ArchiveRecipe(entries: [
      .init(nameBytes: Data("root.usda".utf8), payload: payload)
    ]).encodeWithLayout()
    let result = try inspect(encoding.bytes)
    XCTAssertNotNil(result.directory)
    XCTAssertEqual(result.directory?.endRecordOffset, 219)
    XCTAssertEqual(result.directory?.records.count, 1)
    XCTAssertTrue(result.findings.isEmpty)
  }

  func testPayloadMarkersWithoutCentralFramingDoNotEstablishEndRecordIdentity() throws {
    for patches: [ArchiveRecipe.HeaderPatch] in [
      [.uint32(at: 16, .max)],
      [.uint32(at: 12, .max), .uint32(at: 16, 64)],
      [.uint16(at: 10, .max), .uint32(at: 16, 64)],
      [.uint16(at: 10, .max), .uint32(at: 12, 46), .uint32(at: 16, 18)],
      [
        .uint16(at: 4, 1), .uint16(at: 8, 1), .uint16(at: 10, 1),
        .uint32(at: 12, 46), .uint32(at: 16, 18),
      ],
    ] {
      let fakeEnd = try ArchiveRecipe(
        entries: [],
        endRecordPatches: patches + [.uint16(at: 20, 155)]
      ).encode()
      var payload = Data(repeating: 0x41, count: 100)
      payload.replaceSubrange(0..<22, with: fakeEnd)
      let encoding = try ArchiveRecipe(entries: [
        .init(nameBytes: Data("root.usda".utf8), payload: payload)
      ]).encodeWithLayout()
      let result = try inspect(encoding.bytes)
      XCTAssertNotNil(result.directory)
      XCTAssertEqual(result.directory?.endRecordOffset, 219)
      XCTAssertTrue(result.findings.isEmpty)
    }
  }

  func testZIP64LocatorCannotBeHiddenByCopiedDirectoryAndCommentEOCD() throws {
    let original = try recipe().encodeWithLayout()
    let copiedDirectory = original.bytes.subdata(in: original.centralDirectory..<original.endRecord)
    XCTAssertEqual(copiedDirectory.count, 55)
    let fakeEnd = try ArchiveRecipe(
      entries: [],
      endRecordPatches: [
        .uint16(at: 8, 1), .uint16(at: 10, 1),
        .uint32(at: 12, 55), .uint32(at: 16, 166),
      ]
    ).encode()
    var encoding = try recipe(comment: copiedDirectory + fakeEnd).encodeWithLayout()
    encoding.bytes.insert(
      contentsOf: Data([0x50, 0x4b, 0x06, 0x07]) + Data(repeating: 0, count: 16),
      at: encoding.endRecord)
    // Actual end record 144; copied comment directory 166..<221; forged end 221.
    try assertRejected(encoding.bytes, rules: ["UVK-LIM-001"])
    let result = try inspect(encoding.bytes)
    XCTAssertEqual(result.findings.first?.evidence["reason"], .string("zip64Locator"))
  }

  func testOperationalErrorsEscapeAndSharedReadBudgetIsEnforced() throws {
    let bytes = try recipe().encode()
    let failed = BoundedReader(size: UInt64(bytes.count), ledger: ResourceLedger()) { _, _ in
      throw ValidationError.operational(.inputReadFailed)
    }
    XCTAssertThrowsError(try ZIPDirectory.read(from: failed, diagnostics: NativeDiagnostics())) {
      error in
      XCTAssertEqual(error as? ValidationError, .operational(.inputReadFailed))
    }
    let ledger = ResourceLedger()
    try ledger.consumeRead(1_207_959_552)
    var calls = 0
    let exhausted = BoundedReader(size: UInt64(bytes.count), ledger: ledger) { _, count in
      calls += 1
      return Data(repeating: 0, count: count)
    }
    let diagnostics = NativeDiagnostics()
    XCTAssertNil(try ZIPDirectory.read(from: exhausted, diagnostics: diagnostics))
    XCTAssertEqual(calls, 0)
    XCTAssertEqual(diagnostics.finish().0.map(\.ruleID), ["UVK-RES-001"])
  }

  func testReaderMayReturnDataSlices() throws {
    let bytes = try recipe().encode()
    let reader = BoundedReader(size: UInt64(bytes.count), ledger: ResourceLedger()) {
      offset, count in
      bytes[Int(offset)..<(Int(offset) + count)]
    }
    let directory = try ZIPDirectory.read(from: reader, diagnostics: NativeDiagnostics())
    XCTAssertEqual(directory?.records.first?.nameBytes, Data("root.usda".utf8))
  }

  private struct Read {
    let offset: UInt64
    let count: Int
  }

  private func inspect(_ bytes: Data) throws -> (
    directory: ZIPDirectory?, findings: [Finding], coverage: Coverage, reads: [Read]
  ) {
    var reads: [Read] = []
    let reader = BoundedReader(size: UInt64(bytes.count), ledger: ResourceLedger()) {
      offset, count in
      XCTAssertLessThanOrEqual(count, 65_536)
      XCTAssertLessThanOrEqual(offset + UInt64(count), UInt64(bytes.count))
      reads.append(Read(offset: offset, count: count))
      return bytes.subdata(in: Int(offset)..<(Int(offset) + count))
    }
    let diagnostics = NativeDiagnostics()
    let directory = try ZIPDirectory.read(from: reader, diagnostics: diagnostics)
    let (findings, coverage) = diagnostics.finish()
    return (directory, findings, coverage, reads)
  }

  private func assertRejected(
    _ bytes: Data, rules: [String], file: StaticString = #filePath, line: UInt = #line
  ) throws {
    let result = try inspect(bytes)
    XCTAssertNil(result.directory, file: file, line: line)
    XCTAssertEqual(result.findings.map(\.ruleID), rules, file: file, line: line)
    XCTAssertEqual(
      result.coverage.areas[.containerStructure]?.state, .partial, file: file, line: line)
    XCTAssertEqual(result.coverage.areas[.references]?.state, .notRun, file: file, line: line)
    XCTAssertFalse(result.coverage.isComplete, file: file, line: line)
    XCTAssertFalse(
      result.coverage.areas[.containerStructure]?.reasons.isEmpty ?? true, file: file, line: line)
  }

  private func entry(name: Data = Data("root.usda".utf8)) -> ArchiveRecipe.Entry {
    .init(nameBytes: name, payload: Data("hello".utf8))
  }

  private func recipe(
    name: Data = Data("root.usda".utf8), flags: UInt16 = 0,
    extra: Data = Data(), comment: Data = Data(), centralPatches: [ArchiveRecipe.HeaderPatch] = [],
    endPatches: [ArchiveRecipe.HeaderPatch] = []
  ) -> ArchiveRecipe {
    ArchiveRecipe(
      entries: [
        .init(
          nameBytes: name, payload: Data("hello".utf8), flags: flags,
          centralExtra: extra, centralHeaderPatches: centralPatches)
      ], archiveComment: comment,
      endRecordPatches: endPatches)
  }

  private func patch(_ bytes: inout Data, at offset: Int, value: UInt32) throws {
    try ArchiveRecipe.overwrite(
      &bytes, at: offset,
      with: ArchiveRecipe.HeaderPatch.uint32(at: 0, value).bytes)
  }
}

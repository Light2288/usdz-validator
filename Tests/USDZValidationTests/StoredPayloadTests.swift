import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

final class StoredPayloadTests: XCTestCase {
  func testSeparateIntegrityRules() throws {
    // A payload mutation preserves both original CRC declarations, so this tests content.
    let corrupt = ArchiveRecipe.Entry(
      nameBytes: Data("root.usda".utf8), payload: Data("hello".utf8),
      payloadPatches: [.init(offset: 0, bytes: Data("j".utf8))])
    let crc = try inspect(corrupt)
    XCTAssertFalse(crc.eligible)
    XCTAssertEqual(crc.findings.map(\.ruleID), ["UVK-ARC-003"])
    XCTAssertEqual(crc.reads, [64..<69])

    for member in [
      ArchiveRecipe.Entry(nameBytes: Data("a".utf8), payload: Data([1]), method: 8),
      ArchiveRecipe.Entry(
        nameBytes: Data("a".utf8), payload: Data([1]), declaredUncompressedSize: 2),
      ArchiveRecipe.Entry(nameBytes: Data("a".utf8), payload: Data([1]), flags: 1),
    ] {
      let result = try inspect(member)
      XCTAssertFalse(result.eligible)
      XCTAssertTrue(result.reads.isEmpty)
      XCTAssertEqual(
        result.findings.map(\.ruleID), [member.flags == 1 ? "UVK-ARC-005" : "UVK-ARC-004"])
    }
    let alignment = try inspect(
      .init(nameBytes: Data("a".utf8), payload: Data("hello".utf8)), alignment: 1)
    XCTAssertFalse(alignment.eligible)
    XCTAssertEqual(alignment.findings.map(\.ruleID), ["UVK-ARC-006"])
    XCTAssertEqual(alignment.findings.first?.location?.archiveByteOffset, 31)

    let combined = try inspect(
      .init(nameBytes: Data("a".utf8), payload: Data([1]), flags: 1, method: 8), alignment: 1)
    XCTAssertEqual(
      combined.findings.map(\.ruleID), ["UVK-ARC-004", "UVK-ARC-005", "UVK-ARC-006"])
    XCTAssertTrue(combined.reads.isEmpty)
  }

  func testBombMetadataNeverInterpreted() throws {
    // Removing any eligibility check must reach the counting payload source and fail.
    for (method, compressed, expanded, expected): (UInt16, UInt64, UInt64, [String]) in [
      (8, 1, 1, ["UVK-ARC-004"]),
      (8, 1, 268_435_456, ["UVK-ARC-004"]),
      (0, 0, 1, ["UVK-ARC-004"]),
      (0, 1, 0, ["UVK-ARC-004"]),
      (0, 268_435_457, 268_435_457, ["UVK-RES-001"]),
      (0, UInt64.max, UInt64.max, ["UVK-RES-001"]),
      (8, 1, 268_435_457, ["UVK-ARC-004", "UVK-RES-001"]),
    ] {
      let diagnostics = NativeDiagnostics()
      var payloadReadCount = 0
      let reader = BoundedReader(size: 536_870_912, ledger: ResourceLedger()) { _, count in
        payloadReadCount += 1
        return Data(repeating: 0, count: count)
      }
      XCTAssertFalse(
        try StoredPayload.check(
          entry: entry(method: method, compressed: compressed, expanded: expanded),
          reader: reader, diagnostics: diagnostics))
      XCTAssertEqual(payloadReadCount, 0)
      XCTAssertEqual(diagnostics.finish().0.map(\.ruleID), expected)
    }

    // Aggregate declarations are accounted for by the directory, before a payload exists.
    for (lastSize, rejected) in [(UInt32(0), false), (1, true)] {
      let full = ArchiveRecipe.Entry(
        nameBytes: Data("a".utf8), payload: Data(), method: 8,
        declaredCompressedSize: 0, declaredUncompressedSize: 268_435_456)
      let last = ArchiveRecipe.Entry(
        nameBytes: Data("b".utf8), payload: Data(), method: 8,
        declaredCompressedSize: 0, declaredUncompressedSize: lastSize)
      let bytes = try ArchiveRecipe(entries: [full, full, last]).encode()
      let diagnostics = NativeDiagnostics()
      let reader = BoundedReader(size: UInt64(bytes.count), ledger: ResourceLedger()) {
        offset, count in
        bytes.subdata(in: Int(offset)..<(Int(offset) + count))
      }
      let directory = try ZIPDirectory.read(from: reader, diagnostics: diagnostics)
      XCTAssertEqual(directory == nil, rejected)
      XCTAssertEqual(diagnostics.finish().0.map(\.ruleID), rejected ? ["UVK-RES-001"] : [])
    }
    // The shared cumulative counter must reject arithmetic overflow without wrapping.
    let ledger = ResourceLedger()
    try ledger.consumeRead(1)
    XCTAssertThrowsError(try ledger.consumeRead(UInt64.max)) { error in
      XCTAssertEqual(error as? InspectionFailure, .resourceLimit(.totalReadBytes))
    }
  }

  func testKnownCRCVectorsAndStreamingChunks() throws {
    // Literal ISO-HDLC check vectors avoid deriving expected CRCs with product code.
    for (payload, expected): (Data, UInt32) in [
      (Data(), 0), (Data("123456789".utf8), 0xcbf4_3926),
      (Data("hello".utf8), 0x3610_a686),
      (Data(repeating: 0, count: 65_536), 0xd797_8eeb),
      (Data(repeating: 0, count: 65_537), 0xe50d_43f3),
      (Data(repeating: 0, count: 131_073), 0x37a9_b94d),
    ] {
      let result = try inspect(
        .init(nameBytes: Data("root.usda".utf8), payload: payload, declaredCRC32: expected))
      XCTAssertTrue(result.eligible)
      XCTAssertTrue(result.findings.isEmpty)
      XCTAssertEqual(result.reads.reduce(0) { $0 + $1.count }, payload.count)
      XCTAssertTrue(result.reads.allSatisfy { $0.count > 0 && $0.count <= 65_536 })
      XCTAssertEqual(result.chargedBytes, UInt64(payload.count))
      if payload.count == 131_073 {
        XCTAssertEqual(result.reads, [64..<65_600, 65_600..<131_136, 131_136..<131_137])
      }
      XCTAssertEqual(result.coverage.areas[.containerStructure]?.state, .notRun)
    }
    let emptyBadCRC = try inspect(
      .init(nameBytes: Data("empty".utf8), payload: Data(), declaredCRC32: 1))
    XCTAssertFalse(emptyBadCRC.eligible)
    XCTAssertTrue(emptyBadCRC.reads.isEmpty)
    XCTAssertEqual(emptyBadCRC.findings.map(\.ruleID), ["UVK-ARC-003"])
  }

  func testSharedReadBudgetStopsBeforeExcessIO() throws {
    let payload = Data(repeating: 0, count: 65_537)
    for (remaining, reads, eligible, rules): (UInt64, [Range<UInt64>], Bool, [String]) in [
      (65_537, [64..<65_600, 65_600..<65_601], true, []),
      (65_536, [64..<65_600], false, ["UVK-RES-001"]),
      (0, [], false, ["UVK-RES-001"]),
    ] {
      let ledger = ResourceLedger()
      try ledger.consumeRead(1_207_959_552 - remaining)
      let result = try inspect(
        .init(nameBytes: Data("root.usda".utf8), payload: payload), ledger: ledger)
      XCTAssertEqual(result.eligible, eligible)
      XCTAssertEqual(result.reads, reads)
      XCTAssertEqual(result.findings.map(\.ruleID), rules)
      XCTAssertEqual(ledger.totalReadBytes, 1_207_959_552)
      if !eligible {
        XCTAssertEqual(result.coverage.areas[.containerStructure]?.state, .partial)
      }
    }
  }

  func testRangeAndArchiveBoundsBeforeIO() throws {
    for (member, size, rule): (ZIPEntry, UInt64, String) in [
      (entry(compressed: 1, expanded: 1, payload: 64..<64), 128, "UVK-ARC-001"),
      (entry(compressed: 1, expanded: 1, payload: 64..<65), 64, "UVK-ARC-001"),
      (entry(compressed: 0, expanded: 0), 536_870_913, "UVK-RES-001"),
    ] {
      var calls = 0
      let reader = BoundedReader(size: size, ledger: ResourceLedger()) { _, count in
        calls += 1
        return Data(repeating: 0, count: count)
      }
      let diagnostics = NativeDiagnostics()
      XCTAssertFalse(
        try StoredPayload.check(entry: member, reader: reader, diagnostics: diagnostics))
      XCTAssertEqual(calls, 0)
      XCTAssertEqual(diagnostics.finish().0.map(\.ruleID), [rule])
    }
    // Exactly 256 MiB may reach the bounded source; one byte above never does.
    var calls = 0
    let reader = BoundedReader(size: 268_435_520, ledger: ResourceLedger()) { _, _ in
      calls += 1
      throw ValidationError.operational(.inputReadFailed)
    }
    XCTAssertThrowsError(
      try StoredPayload.check(
        entry: entry(compressed: 268_435_456, expanded: 268_435_456, payload: 64..<268_435_520),
        reader: reader, diagnostics: NativeDiagnostics()))
    XCTAssertEqual(calls, 1)
  }

  func testCRCAndAlignmentApplyOnlyToKnownRegularEntries() throws {
    let directory = try inspect(
      .init(
        nameBytes: Data("dir/".utf8), payload: Data(), type: .directory, declaredCRC32: 1),
      alignment: 1)
    XCTAssertFalse(directory.eligible)
    XCTAssertTrue(directory.findings.isEmpty)
    XCTAssertTrue(directory.reads.isEmpty)
    for (host, attributes): (UInt16, UInt32) in [
      (0x0314, 0xa1ff_0000), (0x6314, 0),
    ] {
      let diagnostics = NativeDiagnostics()
      var calls = 0
      let reader = BoundedReader(size: 128, ledger: ResourceLedger()) { _, count in
        calls += 1
        return Data(repeating: 0, count: count)
      }
      XCTAssertFalse(
        try StoredPayload.check(
          entry: entry(
            compressed: 1, expanded: 1, payload: 64..<65, host: host, attributes: attributes),
          reader: reader, diagnostics: diagnostics))
      XCTAssertEqual(calls, 0)
      XCTAssertTrue(diagnostics.finish().0.isEmpty)
    }
    // DOS/Unix entries without Unix type bits follow their supported DOS interpretation.
    for host: UInt16 in [0x0014, 0x0314] {
      let diagnostics = NativeDiagnostics()
      let reader = BoundedReader(size: 128, ledger: ResourceLedger()) { _, count in
        Data(repeating: 0, count: count)
      }
      XCTAssertTrue(
        try StoredPayload.check(
          entry: entry(compressed: 0, expanded: 0, host: host, attributes: 0),
          reader: reader, diagnostics: diagnostics))
    }
  }

  func testReadFailuresDoNotFabricateCRCFindings() throws {
    let member = entry(compressed: 1, expanded: 1, payload: 64..<65)
    for failure in [InspectionFailure.shortRead, .malformedRange] {
      let diagnostics = NativeDiagnostics()
      let reader = BoundedReader(size: 128, ledger: ResourceLedger()) { _, _ in throw failure }
      XCTAssertFalse(
        try StoredPayload.check(entry: member, reader: reader, diagnostics: diagnostics))
      XCTAssertEqual(diagnostics.finish().0.map(\.ruleID), ["UVK-ARC-001"])
    }
    let reader = BoundedReader(size: 128, ledger: ResourceLedger()) { _, _ in
      throw ValidationError.operational(.inputReadFailed)
    }
    XCTAssertThrowsError(
      try StoredPayload.check(entry: member, reader: reader, diagnostics: NativeDiagnostics())
    ) { error in
      XCTAssertEqual(error as? ValidationError, .operational(.inputReadFailed))
    }
  }

  func testUnsupportedMetadataNeverReadsPayload() throws {
    for member in [
      entry(compressed: 1, expanded: 1, payload: 64..<65, flags: 8),
      entry(compressed: 1, expanded: 1, payload: 64..<65, flags: 0x10),
      entry(compressed: 1, expanded: 1, payload: 64..<65, flags: 0x40),
      entry(compressed: 1, expanded: 1, payload: 64..<65, version: 45),
      entry(compressed: 1, expanded: 1, payload: 64..<65, disk: 1),
    ] {
      var calls = 0
      let diagnostics = NativeDiagnostics()
      let reader = BoundedReader(size: 128, ledger: ResourceLedger()) { _, count in
        calls += 1
        return Data(repeating: 0, count: count)
      }
      XCTAssertFalse(
        try StoredPayload.check(entry: member, reader: reader, diagnostics: diagnostics))
      XCTAssertEqual(calls, 0)
      XCTAssertEqual(diagnostics.finish().0.map(\.ruleID), ["UVK-LIM-001"])
    }
  }

  private func entry(
    method: UInt16 = 0, compressed: UInt64, expanded: UInt64,
    payload: Range<UInt64> = 64..<64, host: UInt16 = 0x0314, attributes: UInt32 = 0x81a4_0000,
    flags: UInt16 = 0, version: UInt16 = 20, disk: UInt16 = 0
  ) -> ZIPEntry {
    let record = ZIPDirectory.Record(
      nameBytes: Data("a".utf8), versionMadeBy: host, versionNeeded: version, flags: flags,
      method: method,
      modificationTime: 0, modificationDate: 0x0021, crc32: 0,
      compressedSize: compressed, uncompressedSize: expanded, diskNumber: disk,
      internalAttributes: 0, externalAttributes: attributes, localHeaderOffset: 0,
      centralHeaderOffset: payload.upperBound)
    return ZIPEntry(
      record: record, recordRange: 0..<payload.upperBound, headerRange: 0..<payload.lowerBound,
      payloadRange: payload)
  }

  private func inspect(
    _ member: ArchiveRecipe.Entry, alignment: Int = 64, ledger: ResourceLedger = ResourceLedger()
  ) throws -> (
    eligible: Bool, findings: [Finding], coverage: Coverage, reads: [Range<UInt64>],
    chargedBytes: UInt64
  ) {
    let bytes = try ArchiveRecipe(entries: [member], alignment: alignment).encode()
    let metadataReader = BoundedReader(size: UInt64(bytes.count), ledger: ResourceLedger()) {
      offset, count in
      bytes.subdata(in: Int(offset)..<(Int(offset) + count))
    }
    let directory = try XCTUnwrap(
      ZIPDirectory.read(from: metadataReader, diagnostics: NativeDiagnostics()))
    let index = try XCTUnwrap(
      ZIPIndex.build(directory: directory, reader: metadataReader, diagnostics: NativeDiagnostics())
    )
    let member = try XCTUnwrap(index.entries.first)
    var reads: [Range<UInt64>] = []
    let reader = BoundedReader(size: UInt64(bytes.count), ledger: ledger) { offset, count in
      let range = offset..<(offset + UInt64(count))
      XCTAssertGreaterThanOrEqual(range.lowerBound, member.payloadRange.lowerBound)
      XCTAssertLessThanOrEqual(range.upperBound, member.payloadRange.upperBound)
      reads.append(range)
      // Return a nonzero-based slice to exercise the streaming CRC byte iteration.
      return bytes[Int(offset)..<(Int(offset) + count)]
    }
    let diagnostics = NativeDiagnostics()
    let previousReadBytes = ledger.totalReadBytes
    let eligible = try StoredPayload.check(entry: member, reader: reader, diagnostics: diagnostics)
    let (findings, coverage) = diagnostics.finish()
    return (eligible, findings, coverage, reads, ledger.totalReadBytes - previousReadBytes)
  }
}

import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

final class ResourceBoundaryTests: XCTestCase {
  func testMaximumEnvelopeMeasurements() throws {
    try requireRealSizes()
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    let output = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: output) }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [
      "python3", root.appendingPathComponent("Scripts/verify-resources.py").path,
      "--executable", root.appendingPathComponent(".build/release/usdz-validator").path,
      "--output", output.path,
    ]
    try process.run()
    process.waitUntilExit()
    XCTAssertEqual(
      process.terminationStatus, 0,
      "Every independently measured native case must meet the resource contract")
    XCTAssertTrue(
      FileManager.default.fileExists(atPath: output.path),
      "The measurement workflow must record decisive evidence")
  }

  private func requireRealSizes() throws {
    guard ProcessInfo.processInfo.environment["UVK_RUN_RESOURCE_TESTS"] == "1" else {
      throw XCTSkip("Set UVK_RUN_RESOURCE_TESTS=1 for streamed real-size resource cases")
    }
  }
}

extension ResourceBoundaryTests {
  /// Removing any preflight, charging reads after I/O, or permitting one more retained
  /// item must fail these assertions. Impossible combined maxima use independent ledgers.
  func testEverySafetyCeilingAtAndAbove() throws {
    let boundaries: [(SafetyResource, UInt64)] = [
      (.archiveBytes, 536_870_912), (.entryCount, 10_000),
      (.centralDirectoryBytes, 16_777_216), (.entryBytes, 268_435_456),
      (.aggregateEntryBytes, 536_870_912), (.textLayerBytes, 16_777_216),
      (.entryNameBytes, 4_096), (.tokenBytes, 4_096), (.tokenCount, 100_000),
      (.readChunkBytes, 65_536), (.textureHeaderBytes, 1_048_576),
      (.totalReadBytes, 1_207_959_552), (.findings, 10_000),
      (.messageBytes, 1_024), (.evidenceStringBytes, 4_096),
      (.configurationBytes, 65_536), (.reportBytes, 33_554_432),
    ]
    let ledger = ResourceLedger()
    XCTAssertEqual(boundaries.count, SafetyResource.allCases.count)
    for (resource, maximum) in boundaries {
      XCTAssertNoThrow(try ledger.check(resource: resource, value: maximum), resource.rawValue)
      XCTAssertThrowsError(try ledger.check(resource: resource, value: maximum + 1)) {
        XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(resource))
      }
    }
    var reads = 0
    let reader = BoundedReader(size: 536_870_912, ledger: ledger) { _, count in
      reads += 1
      return Data(repeating: 0, count: count)
    }
    XCTAssertEqual(try reader.read(offset: 536_870_911, count: 1).count, 1)
    XCTAssertEqual(try reader.read(offset: 0, count: 65_536).count, 65_536)
    let before = reads
    XCTAssertThrowsError(try reader.read(offset: 0, count: 65_537))
    XCTAssertThrowsError(try reader.read(offset: 536_870_912, count: 1))
    XCTAssertEqual(reads, before, "Rejected chunks/ranges must never reach the source")
    try ledger.consumeRead(1_207_959_552 - ledger.totalReadBytes - 1)
    _ = try reader.read(offset: 0, count: 1)
    let readsBeforeRejectedRange = reads
    XCTAssertThrowsError(try reader.read(offset: 0, count: 1))
    XCTAssertEqual(reads, readsBeforeRejectedRange)
    XCTAssertEqual(ledger.totalReadBytes, 1_207_959_552)
    let oversized = BoundedReader(size: 536_870_913, ledger: ResourceLedger()) { _, count in
      reads += 1
      return Data(repeating: 0, count: count)
    }
    XCTAssertThrowsError(try oversized.read(offset: 0, count: 1))
    XCTAssertEqual(reads, readsBeforeRejectedRange)

    let config = Data("{\"schemaVersion\":1,\"budgets\":{}}".utf8)
    let exactConfig = config + Data(repeating: 0x20, count: 65_536 - config.count)
    XCTAssertNoThrow(try BudgetConfiguration.decode(exactConfig))
    XCTAssertThrowsError(try BudgetConfiguration.decode(exactConfig + Data([0x20]))) {
      XCTAssertEqual($0 as? ValidationError, .configuration(.sizeLimitExceeded))
    }
    var buffer = CappedBuffer()
    let chunk = Data(repeating: 0x20, count: 65_536)
    for _ in 0..<512 { try buffer.append(chunk) }
    XCTAssertEqual(buffer.finish().count, 33_554_432)
    XCTAssertThrowsError(try buffer.append(Data([0x20]))) {
      XCTAssertEqual($0 as? ValidationError, .operational(.reportLimitExceeded))
    }
    XCTAssertEqual(buffer.finish().count, 33_554_432, "No append beyond the cap")

    let diagnostics = NativeDiagnostics()
    for index in 0..<10_000 {
      diagnostics.emit(
        ruleID: "UVK-PATH-006", message: String(repeating: "m", count: 1_024 + index % 2),
        evidence: ["value": .string(String(repeating: "e", count: 4_096 + index % 2))],
        location: nil, key: findingKey(index))
    }
    let exact = diagnostics.finish().0
    XCTAssertEqual(exact.count, 10_000)
    XCTAssertFalse(diagnostics.processingTruncated)
    XCTAssertEqual(exact[0].message.utf8.count, 1_024)
    XCTAssertFalse(exact[0].message.hasSuffix("[truncated]"))
    XCTAssertEqual(exact[1].message.utf8.count, 1_024)
    XCTAssertTrue(exact[1].message.hasSuffix("[truncated]"))
    for index in [0, 1] {
      guard case .string(let value) = exact[index].evidence["value"] else {
        return XCTFail("Missing bounded evidence")
      }
      XCTAssertEqual(value.utf8.count, 4_096)
      XCTAssertEqual(value.hasSuffix("[truncated]"), index == 1)
    }
    diagnostics.emit(
      ruleID: "UVK-PATH-006", message: "One more", evidence: [:], location: nil,
      key: findingKey(10_000))
    let truncated = diagnostics.finish().0
    XCTAssertTrue(diagnostics.processingTruncated)
    XCTAssertEqual(truncated.count, 10_000)
    XCTAssertEqual(truncated.filter { $0.ruleID == "UVK-RES-001" }.count, 1)
    XCTAssertEqual(
      Set(truncated.filter { $0.ruleID != "UVK-RES-001" }.map(\.occurrenceID)),
      Set(exact.prefix(9_999).map(\.occurrenceID)))
  }

  func testMetadataBoundariesStopBeforeForbiddenRead() throws {
    for length in [4_096, 4_097] {
      try withFixture([.init(String(repeating: "a", count: length))]) { url, layout in
        let source = try Source(url)
        let diagnostics = NativeDiagnostics()
        let directory = try ZIPDirectory.read(from: source.reader, diagnostics: diagnostics)
        XCTAssertEqual(directory?.records.count, length == 4_096 ? 1 : nil)
        if length > 4_096 {
          assertLimit(diagnostics, .entryNameBytes)
          XCTAssertFalse(source.reads.contains { $0.lowerBound == layout.centralHeaders[0] + 46 })
        }
      }
    }
    for count in [10_000, 10_001] {
      try withFixture((0..<count).map { .init("f\($0).wav") }) { url, layout in
        let source = try Source(url)
        let diagnostics = NativeDiagnostics()
        let directory = try ZIPDirectory.read(from: source.reader, diagnostics: diagnostics)
        XCTAssertEqual(directory?.records.count, count == 10_000 ? count : nil)
        if count > 10_000 {
          assertLimit(diagnostics, .entryCount)
          XCTAssertFalse(source.reads.contains { $0.lowerBound == layout.centralHeaders[0] })
        }
      }
    }
    for declared in [UInt32(268_435_456), 268_435_457] {
      try withFixture([.init("a.wav", [.fill(0x42, 1)], declaredSize: declared)]) { url, layout in
        let source = try Source(url)
        let diagnostics = NativeDiagnostics()
        let directory = try ZIPDirectory.read(from: source.reader, diagnostics: diagnostics)
        XCTAssertEqual(
          directory?.records.first?.uncompressedSize,
          declared == 268_435_456 ? UInt64(declared) : nil)
        XCTAssertFalse(
          source.reads.contains { $0.lowerBound == layout.payloadRanges[0].lowerBound })
        if declared > 268_435_456 { assertLimit(diagnostics, .entryBytes) }
      }
    }
    // Actual stored payloads totaling 512 MiB cannot also fit ZIP overhead. Test the
    // declaration accumulator independently rather than inventing an accepted archive.
    for finalSize: UInt32 in [0, 1] {
      try withFixture([
        .init("a.wav", declaredSize: 268_435_456),
        .init("b.wav", declaredSize: 268_435_456), .init("c.wav", declaredSize: finalSize),
      ]) { url, _ in
        let source = try Source(url)
        let diagnostics = NativeDiagnostics()
        let directory = try ZIPDirectory.read(from: source.reader, diagnostics: diagnostics)
        XCTAssertEqual(directory?.records.count, finalSize == 0 ? 3 : nil)
        if finalSize == 1 { assertLimit(diagnostics, .aggregateEntryBytes) }
      }
    }
  }

  func testTokenBoundariesConsumeNoForbiddenTokenOrRead() throws {
    for length in [4_096, 4_097] {
      try withFixture([.init("root.usda", ResourceRecipes.text(tokens: 1, tokenBytes: length))]) {
        url, _ in
        let source = try Source(url)
        let entry = try indexedEntries(source)[0]
        let diagnostics = NativeDiagnostics()
        var tokens = 0
        try USDALexer.scan(entry: entry, reader: source.reader, diagnostics: diagnostics) { token in
          tokens += 1
          XCTAssertEqual(token.rawValueBytes.count, 4_096)
        }
        XCTAssertEqual(tokens, length == 4_096 ? 1 : 0)
        if length > 4_096 { assertLimit(diagnostics, .tokenBytes) }
      }
    }
    for count in [100_000, 100_001] {
      try withFixture([.init("root.usda", ResourceRecipes.text(tokens: count))]) { url, _ in
        let source = try Source(url)
        let entry = try indexedEntries(source)[0]
        let diagnostics = NativeDiagnostics()
        var tokens = 0
        try USDALexer.scan(entry: entry, reader: source.reader, diagnostics: diagnostics) { _ in
          tokens += 1
        }
        XCTAssertEqual(tokens, 100_000)
        if count > 100_000 { assertLimit(diagnostics, .tokenCount) }
      }
    }
    // Arrange the forbidden token's body in the next chunk: consumeTokens must stop
    // before that read or any AssetToken allocation/callback, despite bounded lookahead.
    var bytes = Data(repeating: 0x20, count: 65_535)
    bytes.append(0x40)
    bytes.append(Data(repeating: 0x61, count: 4_096))
    bytes.append(0x40)
    try withFixture([.init("root.usda", [.bytes(bytes)])]) { url, _ in
      let source = try Source(url)
      let entry = try indexedEntries(source)[0]
      try source.ledger.consumeTokens(100_000)
      let diagnostics = NativeDiagnostics()
      let priorReads = source.reads.count
      try USDALexer.scan(entry: entry, reader: source.reader, diagnostics: diagnostics) { _ in
        XCTFail("Forbidden token")
      }
      assertLimit(diagnostics, .tokenCount)
      XCTAssertEqual(source.reads.count, priorReads + 1)
      XCTAssertEqual(
        source.reads.last, entry.payloadRange.lowerBound..<(entry.payloadRange.lowerBound + 65_536))
    }
  }

  func testRealSizeArchiveLayerDirectoryAndHeaderBoundaries() throws {
    try requireRealSizes()
    try withFixture(ResourceRecipes.nearArchiveLimit, archiveBytes: 536_870_912) { url, layout in
      XCTAssertEqual(layout.byteCount, 536_870_912)
      let source = try Source(url)
      let entries = try indexedEntries(source)
      XCTAssertEqual(entries[1].uncompressedSize, 268_435_456)
      XCTAssertTrue(
        try StoredPayload.check(
          entry: entries[1], reader: source.reader, diagnostics: NativeDiagnostics()))
      XCTAssertLessThanOrEqual(source.ledger.totalReadBytes, 1_207_959_552)
      let handle = try FileHandle(forWritingTo: url)
      try handle.seekToEnd()
      try handle.write(contentsOf: Data([0]))
      try handle.close()
      let exceeded = try Source(url)
      let diagnostics = NativeDiagnostics()
      XCTAssertNil(try ZIPDirectory.read(from: exceeded.reader, diagnostics: diagnostics))
      assertLimit(diagnostics, .archiveBytes)
      XCTAssertTrue(exceeded.reads.isEmpty)
    }
    for size in [16_777_216, 16_777_217] {
      try withFixture([.init("root.usda", ResourceRecipes.text(tokens: 100_000, totalBytes: size))])
      { url, _ in
        let source = try Source(url)
        let entry = try indexedEntries(source)[0]
        let diagnostics = NativeDiagnostics()
        let before = source.reads.count
        var tokens = 0
        try USDALexer.scan(entry: entry, reader: source.reader, diagnostics: diagnostics) { _ in
          tokens += 1
        }
        XCTAssertEqual(tokens, size == 16_777_216 ? 100_000 : 0)
        if size > 16_777_216 {
          assertLimit(diagnostics, .textLayerBytes)
          XCTAssertEqual(source.reads.count, before)
        } else {
          XCTAssertEqual(source.reads.count - before, 256)
        }
      }
    }
    for extra in [0, 1] {
      let count = 257
      var entries = (0..<count).map { ResourceRecipes.Entry(String(format: "f%03d.wav", $0)) }
      var remaining = 16_777_216 + extra - count * (46 + 8)
      for index in entries.indices {
        entries[index].commentBytes = min(65_535, remaining)
        remaining -= entries[index].commentBytes
      }
      XCTAssertEqual(remaining, 0)
      try withFixture(entries) { url, layout in
        XCTAssertEqual(layout.directoryRange.count, 16_777_216 + extra)
        let source = try Source(url)
        let diagnostics = NativeDiagnostics()
        let directory = try ZIPDirectory.read(from: source.reader, diagnostics: diagnostics)
        XCTAssertEqual(directory?.records.count, extra == 0 ? count : nil)
        if extra == 1 {
          assertLimit(diagnostics, .centralDirectoryBytes)
          XCTAssertFalse(
            source.reads.contains { $0.lowerBound == layout.directoryRange.lowerBound })
        }
      }
      let header = ResourceRecipes.jpegHeader(paddingBytes: 1_048_576 - 21 + extra)
      try withFixture([.init("image.jpg", header)]) { url, _ in
        let source = try Source(url)
        let entry = try indexedEntries(source)[0]
        let diagnostics = NativeDiagnostics()
        let before = source.reads.count
        let dimensions = try TextureHeaders.inspect(
          entry: entry, kind: .jpeg, reader: source.reader, diagnostics: diagnostics)
        XCTAssertEqual(dimensions?.width, extra == 0 ? 16 : nil)
        XCTAssertTrue(
          source.reads.dropFirst(before).allSatisfy {
            $0.upperBound <= entry.payloadRange.lowerBound + 1_048_576
          })
        if extra == 1 {
          XCTAssertEqual(diagnostics.finish().0.first?.ruleID, "UVK-LIM-005")
          XCTAssertEqual(
            diagnostics.finish().0.first?.evidence["resource"], .string("textureHeaderBytes"))
        }
      }
    }
  }

  func testRealReferenceReportCapIsOperational() throws {
    try requireRealSizes()
    let name = String(repeating: "a", count: 4_091) + ".usda"
    try withFixture([
      .init(name, [.bytes(Data("#usda 1.0\n".utf8)), .repeated(Data("@missing@ ".utf8), 9_990)])
    ]) { url, _ in
      let report = try Validator().validate(fileAt: url, configuration: ValidationConfiguration())
      XCTAssertEqual(report.nativeFindings.count, 9_990)
      XCTAssertTrue(report.nativeFindings.allSatisfy { $0.ruleID == "UVK-PATH-006" })
      XCTAssertEqual(report.coverage.areas[.references]?.reasons.count, 9_990)
      for format: ReportFormat in [.json, .sarif] {
        XCTAssertThrowsError(try ReportEncoder.encode(report, format: format)) {
          XCTAssertEqual($0 as? ValidationError, .operational(.reportLimitExceeded))
        }
      }
    }
  }

  private final class Source {
    let file: FileHandle
    let size: UInt64
    let ledger = ResourceLedger()
    var reads: [Range<UInt64>] = []
    lazy var reader = BoundedReader(size: size, ledger: ledger) { [unowned self] offset, count in
      XCTAssertLessThanOrEqual(count, 65_536)
      XCTAssertLessThanOrEqual(offset + UInt64(count), self.size)
      self.reads.append(offset..<(offset + UInt64(count)))
      try self.file.seek(toOffset: offset)
      return try self.file.read(upToCount: count) ?? Data()
    }
    init(_ url: URL) throws {
      file = try FileHandle(forReadingFrom: url)
      size = try file.seekToEnd()
    }
    deinit { try? file.close() }
  }

  private func withFixture(
    _ entries: [ResourceRecipes.Entry], archiveBytes: UInt64? = nil,
    _ body: (URL, ResourceRecipes.Layout) throws -> Void
  ) throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("input.usdz")
    let layout = try ResourceRecipes.write(entries, to: url, archiveBytes: archiveBytes)
    try body(url, layout)
  }

  private func indexedEntries(_ source: Source) throws -> [ZIPEntry] {
    let diagnostics = NativeDiagnostics()
    let directory = try XCTUnwrap(ZIPDirectory.read(from: source.reader, diagnostics: diagnostics))
    return try XCTUnwrap(
      ZIPIndex.build(directory: directory, reader: source.reader, diagnostics: diagnostics)
    ).entries
  }

  private func findingKey(_ index: Int) -> FindingKey {
    FindingKey(
      ruleID: "UVK-PATH-006", entryNameBytes: nil, entryOffset: 0, contentOffset: UInt64(index),
      discriminator: "missing")
  }

  private func assertLimit(_ diagnostics: NativeDiagnostics, _ resource: SafetyResource) {
    XCTAssertTrue(
      diagnostics.finish().0.contains {
        $0.ruleID == "UVK-RES-001" && $0.evidence["resource"] == .string(resource.rawValue)
      })
  }
}

extension ResourceBoundaryTests {
  func testReportCapStopsBeforeProjectingNextRetainedItem() throws {
    var projected: [Int] = []
    let value = JSONValue.array([
      .deferred {
        projected.append(1)
        return .string("123456789")
      },
      .deferred {
        projected.append(2)
        return .string("must not be projected")
      },
    ])
    var buffer = CappedBuffer(limit: 10)
    XCTAssertThrowsError(try CanonicalJSON.encode(value, into: &buffer)) {
      XCTAssertEqual($0 as? ValidationError, .operational(.reportLimitExceeded))
    }
    XCTAssertEqual(projected, [1], "A capped report must not allocate the next projected finding")
    XCTAssertLessThanOrEqual(buffer.finish().count, 10)
  }
}

extension ResourceBoundaryTests {
  func testStreamedRecipeMatchesIndependentSmallArchive() throws {
    let payload = Data("123456789".utf8)
    try withFixture([.init("a", [.bytes(payload)])]) { url, layout in
      // The existing writer uses independent bitwise CRC and a full buffer only for
      // this 142-byte vector. Real resource fixtures are always streamed to disk.
      let expected = try ArchiveRecipe(entries: [.init(nameBytes: Data("a".utf8), payload: payload)]
      ).encode()
      XCTAssertEqual(try Data(contentsOf: url), expected)
      XCTAssertEqual(layout.payloadRanges, [64..<73])
      XCTAssertEqual(layout.byteCount, 142)
    }
  }
}

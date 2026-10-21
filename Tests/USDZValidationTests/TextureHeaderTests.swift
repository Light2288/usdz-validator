import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

final class TextureHeaderTests: XCTestCase {
  func testPNGAndJPEGWithoutDecode() throws {
    let pixel = try inspect(Fixtures.pixelPNG(), kind: .png)
    XCTAssertEqual(pixel.dimensions, TextureDimensions(width: 1, height: 1))
    XCTAssertEqual(pixel.ranges.last?.upperBound, 33)
    for kind: MemberKind in [.png, .jpeg] {
      for marker: UInt8 in (kind == .jpeg ? [0xc0, 0xc1, 0xc2] : [0]) {
        let header =
          kind == .png ? ImageRecipes.pngHeader() : ImageRecipes.jpegHeader(marker: marker)
        let result = try inspect(header + Data(repeating: 0xab, count: 131_072), kind: kind)
        XCTAssertEqual(result.dimensions?.width, 16)
        XCTAssertEqual(result.dimensions?.height, 8)
        XCTAssertTrue(result.findings.isEmpty)
        XCTAssertEqual(result.ranges.last?.upperBound, UInt64(header.count))
        XCTAssertEqual(result.coverage.areas[.textureDimensions]?.state, .notRun)
        XCTAssertEqual(result.coverage.areas[.byteBudgets]?.state, .complete)
      }
    }
    for marker: UInt8 in [0xc1, 0xc2] {
      let result = try inspect(ImageRecipes.jpegHeader(marker: marker, precision: 12), kind: .jpeg)
      XCTAssertEqual(result.dimensions, TextureDimensions(width: 16, height: 8))
    }
    let maximum = try inspect(
      ImageRecipes.pngHeader(width: 2_147_483_647, height: 2_147_483_647), kind: .png)
    XCTAssertEqual(maximum.dimensions?.width, 2_147_483_647)
  }

  func testMalformedPNG() throws {
    let header = ImageRecipes.pngHeader()
    for count in 0..<33 {
      try assertMalformed(Data(header.prefix(count)), kind: .png)
    }
    for (offset, value): (Int, UInt8) in [
      (0, 0), (11, 12), (12, 0), (24, 3), (25, 1), (26, 1), (27, 1), (28, 2), (32, 0),
    ] {
      var bytes = header
      bytes[offset] = value
      if (24...28).contains(offset) {
        // Keep CRC valid so this vector specifically exercises IHDR field validation.
        let crc = ArchiveRecipe.crc32(Data(bytes[12..<29]))
        for index in 0..<4 {
          bytes[29 + index] = UInt8(truncatingIfNeeded: crc >> (24 - 8 * index))
        }
      }
      try assertMalformed(bytes, kind: .png)
    }
    for bytes in [
      ImageRecipes.pngHeader(width: 0), ImageRecipes.pngHeader(height: 0),
      ImageRecipes.pngHeader(width: .max),
    ] {
      try assertMalformed(bytes, kind: .png)
    }
    var overflow = header
    overflow.replaceSubrange(8..<12, with: [0xff, 0xff, 0xff, 0xff])
    try assertMalformed(overflow, kind: .png)
  }

  func testMalformedSupportedJPEG() throws {
    let header = ImageRecipes.jpegHeader()
    for count in 0..<header.count {
      try assertMalformed(Data(header.prefix(count)), kind: .jpeg)
    }
    for bytes in [
      Data([0, 0xd8]), Data([0xff, 0xd8, 0xff, 0xd9]),
      Data([0xff, 0xd8, 0xff, 0xda, 0, 2]), Data([0xff, 0xd8, 0xff, 0]),
      Data([0xff, 0xd8, 0x42, 0x42]), Data([0xff, 0xd8, 0xff, 0xd8]),
      Data([0xff, 0xd8, 0xff, 0xd0]), Data([0xff, 0xd8, 0xff, 0xe1, 0, 0]),
      Data([0xff, 0xd8, 0xff, 0xe1, 0, 1]), Data([0xff, 0xd8, 0xff, 0xe1, 0xff, 0xff]),
      ImageRecipes.jpegHeader(width: 0), ImageRecipes.jpegHeader(precision: 12),
      ImageRecipes.jpegHeader(marker: 0xc2, precision: 16),
    ] {
      try assertMalformed(bytes, kind: .jpeg)
    }
    var progressive = ImageRecipes.jpegHeader(marker: 0xc2)
    progressive[5] = 23
    progressive[11] = 5
    progressive.append(contentsOf: [4, 0x11, 0, 5, 0x11, 0])
    try assertMalformed(progressive, kind: .jpeg)
    for (offset, value): (Int, UInt8) in [
      (5, 16), (5, 18), (11, 0), (11, 4), (13, 0), (13, 0x51), (14, 4), (15, 1),
    ] {
      var bytes = header
      bytes[offset] = value
      try assertMalformed(bytes, kind: .jpeg)
    }
  }

  func testUnsupportedAndScanCap() throws {
    for marker: UInt8 in [0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf, 0xc8] {
      try assertUnsupported(ImageRecipes.jpegHeader(marker: marker), kind: .jpeg)
    }
    for marker: UInt8 in [0x01, 0x02, 0xc8, 0xf7] {
      // Unsupported marker syntax cannot establish a malformed supported record.
      try assertUnsupported(Data([0xff, 0xd8, 0xff, marker]), kind: .jpeg)
    }
    try assertUnsupported(ImageRecipes.jpegHeader(height: 0), kind: .jpeg)
    for kind: MemberKind in [.exr, .avif, .unknown] {
      let result = try inspect(Data(repeating: 0, count: 100), kind: kind)
      assertGap(result, rule: "UVK-LIM-005")
      XCTAssertTrue(result.ranges.isEmpty)
    }
    let exact = ImageRecipes.jpegHeader(
      leadingSegments: ImageRecipes.jpegPadding(byteCount: 1_048_576 - 21))
    XCTAssertEqual(exact.count, 1_048_576)
    let result = try inspect(exact + Data(repeating: 0xab, count: 1_024), kind: .jpeg)
    XCTAssertEqual(result.dimensions, TextureDimensions(width: 16, height: 8))
    XCTAssertEqual(result.ranges.last?.upperBound, 1_048_576)
    XCTAssertLessThanOrEqual(result.headerBytesRead, 1_048_576)

    // Logical position, including un-read APP bodies, cannot exceed the prefix boundary.
    for padding in [1_048_576 - 20, 1_048_576 - 2, 1_048_576 + 65_537] {
      let bytes = ImageRecipes.jpegHeader(
        leadingSegments: ImageRecipes.jpegPadding(byteCount: padding))
      let capped = try inspect(bytes, kind: .jpeg)
      assertGap(capped, rule: "UVK-LIM-005")
      XCTAssertLessThanOrEqual(capped.ranges.map(\.upperBound).max() ?? 0, 1_048_576)
      XCTAssertLessThanOrEqual(capped.headerBytesRead, 1_048_576)
      XCTAssertEqual(capped.findings.first?.evidence["resource"], .string("textureHeaderBytes"))
    }
  }

  func testConclusiveMalformedFrameFieldsTakePrecedenceOverScanCap() throws {
    let padding = ImageRecipes.jpegPadding(byteCount: 1_048_576 - 20)
    try assertMalformed(ImageRecipes.jpegHeader(width: 0, leadingSegments: padding), kind: .jpeg)
    var length = ImageRecipes.jpegHeader(leadingSegments: padding)
    length[2 + padding.count + 2] = 0xff
    length[2 + padding.count + 3] = 0xff
    length.append(Data(repeating: 0, count: 65_535))
    try assertMalformed(length, kind: .jpeg)
    let shortFrame =
      Data([0xff, 0xd8])
      + ImageRecipes.jpegPadding(byteCount: 1_048_576 - 6)
      + Data([0xff, 0xc0, 0, 3, 0])
    try assertMalformed(shortFrame, kind: .jpeg)
  }

  func testMarkerAndLengthFieldsAcrossChunkBoundaries() throws {
    for padding in [65_533, 65_531] {
      let header = ImageRecipes.jpegHeader(
        leadingSegments: ImageRecipes.jpegPadding(byteCount: padding))
      let result = try inspect(header + Data(repeating: 0xab, count: 65_536), kind: .jpeg)
      XCTAssertEqual(result.dimensions, TextureDimensions(width: 16, height: 8))
      XCTAssertEqual(result.ranges.last?.upperBound, UInt64(header.count))
      XCTAssertTrue(result.ranges.contains { $0.upperBound == 65_536 })
      XCTAssertTrue(result.ranges.contains { $0.lowerBound == 65_536 })
    }
    let segments =
      ImageRecipes.jpegSegment(marker: 0xdb, fields: Data([0]))
      + ImageRecipes.jpegSegment(marker: 0xfe, fields: Data([0xff, 0xc0, 0, 0]))
      + Data([0xff])
    let result = try inspect(ImageRecipes.jpegHeader(leadingSegments: segments), kind: .jpeg)
    XCTAssertEqual(result.dimensions, TextureDimensions(width: 16, height: 8))
  }

  func testTextureScanLimitDiagnosticsPreserveOtherCompletedAreasAndDeduplicate() {
    let diagnostics = NativeDiagnostics(profile: .applePortableV1)
    for area in CoverageArea.allCases {
      diagnostics.mark(
        area: area, state: .complete, reason: CoverageReason(ruleID: "", reasonID: "completed"))
    }
    let before = diagnostics.finish().1
    let location = FindingLocation(entryName: "image.jpg", archiveByteOffset: 64)
    diagnostics.limit(.textureHeaderBytes, location: location)
    let first = diagnostics.finish()
    diagnostics.limit(.textureHeaderBytes, location: location)
    let repeated = diagnostics.finish()
    XCTAssertEqual(first.0.map(\.ruleID), ["UVK-LIM-005"])
    XCTAssertEqual(first.0.first?.severity, .warning)
    XCTAssertEqual(first.0.first?.category, .validatorLimitation)
    XCTAssertFalse(first.0.contains { $0.ruleID == "UVK-RES-001" })
    XCTAssertEqual(first.1.areas[.textureDimensions]?.state, .partial)
    XCTAssertEqual(first.1.areas[.textureDimensions]?.reasons.last?.ruleID, "UVK-LIM-005")
    for area in CoverageArea.allCases where area != .textureDimensions {
      XCTAssertEqual(first.1.areas[area], before.areas[area])
    }
    XCTAssertEqual(repeated.0, first.0)
    XCTAssertEqual(repeated.1, first.1)
  }

  func testReadFailuresAndOperationalErrors() throws {
    for failure in [InspectionFailure.shortRead, .malformedRange, .resourceLimit(.totalReadBytes)] {
      let diagnostics = NativeDiagnostics()
      let reader = BoundedReader(size: 100, ledger: ResourceLedger()) { _, _ in throw failure }
      XCTAssertNil(
        try TextureHeaders.inspect(
          entry: entry(size: 36), kind: .png, reader: reader, diagnostics: diagnostics))
      let output = diagnostics.finish()
      XCTAssertEqual(
        output.0.map(\.ruleID),
        [failure == .resourceLimit(.totalReadBytes) ? "UVK-RES-001" : "UVK-ARC-001"])
      XCTAssertEqual(output.1.areas[.textureDimensions]?.state, .partial)
    }
    let reader = BoundedReader(size: 100, ledger: ResourceLedger()) { _, _ in
      throw ValidationError.operational(.inputReadFailed)
    }
    XCTAssertThrowsError(
      try TextureHeaders.inspect(
        entry: entry(size: 36), kind: .jpeg, reader: reader, diagnostics: NativeDiagnostics()))
    var reads = 0
    let outOfRange = BoundedReader(size: 63, ledger: ResourceLedger()) { _, _ in
      reads += 1
      return Data()
    }
    let diagnostics = NativeDiagnostics()
    XCTAssertNil(
      try TextureHeaders.inspect(
        entry: entry(size: 36), kind: .png, reader: outOfRange, diagnostics: diagnostics))
    XCTAssertEqual(reads, 0)
    XCTAssertEqual(diagnostics.finish().0.map(\.ruleID), ["UVK-ARC-001"])
  }

  private struct Result {
    let dimensions: TextureDimensions?
    let findings: [Finding]
    let coverage: Coverage
    let ranges: [Range<UInt64>]
    let headerBytesRead: UInt64
  }

  private func inspect(_ bytes: Data, kind: MemberKind) throws -> Result {
    var ranges: [Range<UInt64>] = []
    let ledger = ResourceLedger()
    let reader = BoundedReader(size: 64 + UInt64(bytes.count), ledger: ledger) { offset, count in
      XCTAssertGreaterThanOrEqual(offset, 64)
      XCTAssertLessThanOrEqual(offset + UInt64(count), 64 + UInt64(bytes.count))
      XCTAssertLessThanOrEqual(count, 65_536)
      let start = offset - 64
      ranges.append(start..<(start + UInt64(count)))
      return bytes.subdata(in: Int(start)..<(Int(start) + count))
    }
    let diagnostics = NativeDiagnostics()
    diagnostics.mark(
      area: .byteBudgets, state: .complete,
      reason: CoverageReason(ruleID: "", reasonID: "encodedBytesChecked"))
    let dimensions = try TextureHeaders.inspect(
      entry: entry(size: UInt64(bytes.count)), kind: kind, reader: reader, diagnostics: diagnostics)
    let (findings, coverage) = diagnostics.finish()
    return Result(
      dimensions: dimensions, findings: findings, coverage: coverage, ranges: ranges,
      headerBytesRead: ledger.totalReadBytes)
  }

  private func assertMalformed(
    _ bytes: Data, kind: MemberKind, file: StaticString = #filePath, line: UInt = #line
  ) throws {
    assertGap(try inspect(bytes, kind: kind), rule: "UVK-BUD-007", file: file, line: line)
  }

  private func assertUnsupported(
    _ bytes: Data, kind: MemberKind, file: StaticString = #filePath, line: UInt = #line
  ) throws {
    assertGap(try inspect(bytes, kind: kind), rule: "UVK-LIM-005", file: file, line: line)
  }

  private func assertGap(
    _ result: Result, rule: String, file: StaticString = #filePath, line: UInt = #line
  ) {
    XCTAssertNil(result.dimensions, file: file, line: line)
    XCTAssertEqual(result.findings.map(\.ruleID), [rule], file: file, line: line)
    XCTAssertEqual(
      result.coverage.areas[.textureDimensions]?.state, .partial, file: file, line: line)
    XCTAssertEqual(
      result.coverage.areas[.textureDimensions]?.reasons.last?.ruleID, rule, file: file, line: line)
    XCTAssertEqual(result.coverage.areas[.byteBudgets]?.state, .complete, file: file, line: line)
  }

  private func entry(size: UInt64) -> ZIPEntry {
    let record = ZIPDirectory.Record(
      nameBytes: Data("image".utf8), versionMadeBy: 0x0314, versionNeeded: 20, flags: 0,
      method: 0, modificationTime: 0, modificationDate: 0x21, crc32: 0,
      compressedSize: size, uncompressedSize: size, diskNumber: 0, internalAttributes: 0,
      externalAttributes: 0x81a4_0000, localHeaderOffset: 0, centralHeaderOffset: 64 + size)
    return ZIPEntry(
      record: record, recordRange: 0..<(64 + size), headerRange: 0..<64,
      payloadRange: 64..<(64 + size))
  }
}

import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

final class USDLayerTests: XCTestCase {
  func testMagicAndSuffixBoundary() throws {
    for (name, payload, kind, rules): (String, String, LayerKind, [String]) in [
      ("root.usda", "#usda 1.0\n", .usda, []),
      ("root.USDA", "#usda 1.0\r\n", .usda, []),
      ("root.usdc", "PXR-USDC", .usdc, ["UVK-LIM-002"]),
      ("root.usd", "#usda 1.0", .usda, []),
      ("root.usd", "PXR-USDC", .usdc, ["UVK-LIM-002"]),
      ("root.usda", "PXR-USDC", .usdc, ["UVK-ARC-007", "UVK-LIM-002"]),
      ("root.usdc", "#usda 1.0\n", .usda, ["UVK-ARC-007"]),
      ("root.usda", "#usda 1.00\n", .unrecognized, ["UVK-ARC-007"]),
      ("root.usda", "#usda 1.0garbage", .unrecognized, ["UVK-ARC-007"]),
      ("root.usdc", "PXR-USD", .unrecognized, ["UVK-ARC-007"]),
      ("root.usd", "garbage", .unrecognized, []),
      ("nested.usdz", "PK", .unrecognized, ["UVK-LIM-006"]),
      ("pixel.png", "#usda 1.0", .unrecognized, []),
    ] {
      let result = try identify(name, Data(payload.utf8))
      XCTAssertEqual(result.kind, kind, name + ": " + payload)
      XCTAssertEqual(result.findings.map(\.ruleID), rules)
      if rules.contains("UVK-LIM-002") || rules.contains("UVK-LIM-006") {
        XCTAssertEqual(result.coverage.areas[.references]?.state, .partial)
      }
      if rules.isEmpty { XCTAssertEqual(result.coverage.areas[.references]?.state, .notRun) }
      if name == "nested.usdz" || name == "pixel.png" { XCTAssertEqual(result.reads, 0) }
    }
    // This 8-byte synthetic prefix establishes recognition, never a valid crate/scene.
    let binary = try identify("synthetic.usdc", Data("PXR-USDC".utf8))
    XCTAssertEqual(binary.findings.first?.location?.entryName, "synthetic.usdc")
    XCTAssertEqual(binary.findings.first?.location?.layerByteOffset, 0)
  }

  func testCaseInsensitiveSuffixCatalogueUsesBytesAndFinalComponent() {
    for (suffix, expected): (String, MemberKind) in [
      ("usd", .usd), ("usda", .usda), ("usdc", .usdc), ("usdz", .usdz),
      ("png", .png), ("jpg", .jpeg), ("jpeg", .jpeg), ("jpe", .jpeg), ("jfif", .jpeg),
      ("exr", .exr), ("avif", .avif), ("m4a", .m4a), ("mp3", .mp3), ("wav", .wav),
    ] {
      XCTAssertEqual(
        MemberClassifier.kind(nameBytes: Data(("folder/f." + suffix.uppercased()).utf8)), expected)
    }
    for name in ["png", "root.usda.backup", "root.usda/", "root.usda/child", "x.ｕｓｄａ", "x.usdä"] {
      XCTAssertEqual(MemberClassifier.kind(nameBytes: Data(name.utf8)), .unknown)
    }
    XCTAssertEqual(MemberClassifier.kind(nameBytes: Data([0xff, 0x2e, 0x55, 0x53, 0x44])), .usd)
  }

  func testRecognizedUnsupportedTextEncoding() throws {
    let header = "#usda 1.0\n"
    var cases = [Data([0xef, 0xbb, 0xbf]) + Data(header.utf8)]
    for encoding: String.Encoding in [
      .utf16LittleEndian, .utf16BigEndian, .utf32LittleEndian, .utf32BigEndian,
    ] {
      cases.append(try XCTUnwrap(header.data(using: encoding)))
    }
    cases.append(Data([0xff, 0xfe]) + cases[1])
    cases.append(Data([0xfe, 0xff]) + cases[2])
    for bytes in cases {
      let result = try identify("root.usda", bytes)
      XCTAssertEqual(result.kind, .unsupportedEncoding)
      XCTAssertEqual(result.findings.map(\.ruleID), ["UVK-LIM-004"])
      XCTAssertEqual(result.coverage.areas[.references]?.state, .partial)
    }
  }

  func testLayerCeilingBeforeRecognitionReads() throws {
    var reads = 0
    let reader = BoundedReader(size: 16_777_281, ledger: ResourceLedger()) { _, _ in
      reads += 1
      return Data()
    }
    let diagnostics = NativeDiagnostics()
    XCTAssertEqual(
      try USDLayer.identify(
        entry: entry(name: "x.usda", size: 16_777_217), reader: reader, diagnostics: diagnostics),
      .unrecognized)
    XCTAssertEqual(reads, 0)
    XCTAssertEqual(diagnostics.finish().0.map(\.ruleID), ["UVK-RES-001"])
  }

  func testIdentificationErrorsAndReadBudget() throws {
    let member = entry(name: "root.usda", size: 10)
    for failure in [InspectionFailure.shortRead, .malformedRange, .resourceLimit(.totalReadBytes)] {
      let diagnostics = NativeDiagnostics()
      let reader = BoundedReader(size: 74, ledger: ResourceLedger()) { _, _ in throw failure }
      XCTAssertEqual(
        try USDLayer.identify(entry: member, reader: reader, diagnostics: diagnostics),
        .unrecognized)
      XCTAssertEqual(
        diagnostics.finish().0.map(\.ruleID),
        [failure == .resourceLimit(.totalReadBytes) ? "UVK-RES-001" : "UVK-ARC-001"])
    }
    let reader = BoundedReader(size: 74, ledger: ResourceLedger()) { _, _ in
      throw ValidationError.operational(.inputReadFailed)
    }
    XCTAssertThrowsError(
      try USDLayer.identify(entry: member, reader: reader, diagnostics: NativeDiagnostics()))
  }

  private func entry(name: String, size: UInt64) -> ZIPEntry {
    let record = ZIPDirectory.Record(
      nameBytes: Data(name.utf8), versionMadeBy: 0x0314, versionNeeded: 20, flags: 0,
      method: 0, modificationTime: 0, modificationDate: 0x21, crc32: 0,
      compressedSize: size, uncompressedSize: size, diskNumber: 0, internalAttributes: 0,
      externalAttributes: 0x81a4_0000, localHeaderOffset: 0, centralHeaderOffset: 64 + size)
    return ZIPEntry(
      record: record, recordRange: 0..<(64 + size), headerRange: 0..<64,
      payloadRange: 64..<(64 + size))
  }

  private func identify(_ name: String, _ bytes: Data) throws -> (
    kind: LayerKind, findings: [Finding], coverage: Coverage, reads: Int
  ) {
    let member = entry(name: name, size: UInt64(bytes.count))
    var reads = 0
    let reader = BoundedReader(size: 64 + UInt64(bytes.count), ledger: ResourceLedger()) {
      offset, count in
      reads += 1
      XCTAssertGreaterThanOrEqual(offset, 64)
      XCTAssertLessThanOrEqual(offset + UInt64(count), 64 + UInt64(bytes.count))
      return bytes[(Int(offset) - 64)..<(Int(offset) - 64 + count)]
    }
    let diagnostics = NativeDiagnostics()
    let kind = try USDLayer.identify(entry: member, reader: reader, diagnostics: diagnostics)
    let result = diagnostics.finish()
    return (kind, result.0, result.1, reads)
  }
}

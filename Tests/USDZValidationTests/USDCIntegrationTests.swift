import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

final class USDCIntegrationTests: XCTestCase {
  // Omitting .usd, unreferenced members, or an admitted version loses real authored findings.
  func testEveryEligibleBinaryLayerIsInspected() throws {
    let entries = try [
      binary("root.usdc", "baseline/containers.usdc"),
      binary("unreferenced.usd", "baseline/containers.usdc"),
      binary("clock.usdc", "versions/tc09-scalars-openusd.usdc"),
      binary("patterns.usdc", "versions/pe10-mixed-openusd.usdc"),
    ]
    let result = try inspect(ArchiveRecipe(entries: entries).encode())
    XCTAssertEqual(result.findings.filter { $0.ruleID == "UVK-PATH-006" }.count, 19)
    XCTAssertEqual(
      Set(
        result.findings.filter { $0.ruleID == "UVK-PATH-006" }.compactMap { $0.location?.entryName }
      ),
      ["root.usdc", "unreferenced.usd", "clock.usdc", "patterns.usdc"])
    XCTAssertFalse(result.findings.contains { $0.ruleID == "UVK-LIM-002" })
    XCTAssertEqual(result.coverage.areas[.references]?.state, .partial)
  }

  // Successful inventory must not certify unresolved targets or later independent gaps.
  func testEarlierFindingSurvivesLaterStop() throws {
    for later in [
      try USDCFixtures.unsupportedVersion(),
      Data("PXR-USDC".utf8),
      try USDCMutationRecipe.valueCrate(reps: [0x003f_0000_0000_0000]),
    ] {
      let result = try inspect(
        ArchiveRecipe(entries: [
          binary("root.usdc", "baseline/containers.usdc"),
          .init(nameBytes: Data("later.usdc".utf8), payload: later),
          binary("last.usdc", "baseline/empty.usdc"),
        ]).encode())
      XCTAssertEqual(result.findings.filter { $0.ruleID == "UVK-PATH-006" }.count, 7)
      XCTAssertTrue(
        result.findings.contains { $0.ruleID == "UVK-LIM-002" || $0.ruleID == "UVK-LIM-007" })
      XCTAssertEqual(result.coverage.areas[.references]?.state, .partial)
    }
  }

  // Empty live fields and recovered package-local values are both complete inventories.
  func testCompleteBinaryPackagesAndMixedTextNeedNoSwitch() throws {
    for bytes in [
      try Fixtures.validUSDC(),
      try ArchiveRecipe(entries: [binary("root.usdc", "baseline/empty.usdc")]).encode(),
      try ArchiveRecipe(entries: [
        .init(nameBytes: Data("root.usda".utf8), payload: Data("#usda 1.0\n@binary.usd@".utf8)),
        binary("binary.usd", "versions/pe10-empty-openusd.usdc"),
      ]).encode(),
    ] {
      let result = try inspect(bytes)
      XCTAssertTrue(result.findings.isEmpty)
      XCTAssertTrue(result.coverage.isComplete)
      XCTAssertEqual(result.coverage.areas[.references]?.state, .complete)
      XCTAssertTrue(result.containerSafeForExternal)
    }
  }

  // A recognized prefix is not a crate; intact unknown versions are limitations, not corruption.
  func testUninspectedAndPartialOutcomesRetainSpecificCauses() throws {
    for (crate, rules): (Data, [String]) in [
      (Data("PXR-USDC".utf8), ["UVK-LIM-002", "UVK-USD-001"]),
      (try USDCFixtures.unsupportedVersion(), ["UVK-LIM-002"]),
      (try USDCMutationRecipe.valueCrate(reps: [0x003f_0000_0000_0000]), ["UVK-LIM-007"]),
    ] {
      let result = try inspect(
        ArchiveRecipe(entries: [
          .init(nameBytes: Data("root.usdc".utf8), payload: crate)
        ]).encode())
      XCTAssertEqual(Set(result.findings.map(\.ruleID)), Set(rules))
      if rules == ["UVK-LIM-002"] {
        XCTAssertFalse(result.findings.contains { $0.ruleID == "UVK-LIM-007" })
        XCTAssertEqual(result.findings.first?.evidence["reason"], .string("unsupportedVersion"))
      }
      XCTAssertEqual(result.coverage.areas[.references]?.state, .partial)
      for finding in result.findings {
        XCTAssertEqual(finding.location?.entryName, "root.usdc")
        XCTAssertNil(finding.location?.layerByteOffset)
        XCTAssertNil(finding.location?.line)
      }
    }
  }

  // LIM003 is a resolver gap even when the binary scanner inventories every live field.
  func testCompleteScannerDoesNotEraseExpressionGap() throws {
    let result = try inspect(
      ArchiveRecipe(entries: [
        binary("root.usdc", "versions/pe10-asset-expression-openusd.usdc")
      ]).encode())
    XCTAssertTrue(result.findings.contains { $0.ruleID == "UVK-LIM-003" })
    XCTAssertFalse(
      result.findings.contains { $0.ruleID == "UVK-LIM-002" || $0.ruleID == "UVK-LIM-007" })
    XCTAssertEqual(result.coverage.areas[.references]?.state, .partial)
  }

  // A clip-template string must use the reference limitation without guessed targets or prefixes.
  func testClipTemplateReportsUnsupportedReferenceWithoutSpeculativeFindings() throws {
    for value in [
      "clips.###.usd", "/private/template-sentinel.usd", "missing-template-sentinel.usd",
    ] {
      let crate = try USDCMutationRecipe.valueCrate(
        reps: [0x400a_0000_0000_0000], tokens: ["/", "templateAssetPath", value], strings: [2])
      let result = try inspect(
        ArchiveRecipe(entries: [.init(nameBytes: Data("root.usdc".utf8), payload: crate)]).encode())
      XCTAssertEqual(Set(result.findings.map(\.ruleID)), ["UVK-LIM-003", "UVK-LIM-007"])
      let cause = try XCTUnwrap(result.findings.first { $0.ruleID == "UVK-LIM-003" })
      XCTAssertEqual(cause.evidence, ["reason": .string("unsupportedReference")])
      XCTAssertEqual(cause.category, .validatorLimitation)
      XCTAssertEqual(cause.severity, .warning)
      XCTAssertEqual(result.coverage.areas[.references]?.state, .partial)
      XCTAssertTrue(
        result.coverage.areas[.references]?.reasons.contains {
          $0.ruleID == "UVK-LIM-003" && $0.reasonID == "unsupportedReference"
        } == true)
      let report = ValidationReport(
        input: ReportInput(displayName: "input.usdz", byteSize: nil),
        configuration: try ValidationConfiguration(), coverage: result.coverage,
        nativeFindings: result.findings)
      XCTAssertEqual(report.exitCode, 2)
      for format: ReportFormat in [.json, .sarif] {
        let bytes = try ReportEncoder.encode(report, format: format)
        let text = String(decoding: bytes, as: UTF8.self)
        XCTAssertTrue(text.contains("UVK-LIM-003"))
        XCTAssertTrue(text.contains("unsupportedReference"))
        XCTAssertFalse(text.contains(value))
        XCTAssertFalse(text.contains("templateAssetPath"))
      }
    }
  }

  // Short components need resolver arrays even when their serialized bytes fit the old charge.
  func testResolverComponentScratchStopsBeforeResolutionAndReleasesStorage() throws {
    let cases = [
      (String(repeating: "a/", count: 2047) + "a", "root.usdc", "root.usdc"),
      ("missing.png", "root.usdc", String(repeating: "a/", count: 2000) + "author.usdc"),
      ("missing.png", String(repeating: "d/", count: 2000) + "root.usdc", "author.usdc"),
    ]
    for (value, defaultName, authorName) in cases {
      let crate = try USDCMutationRecipe.valueCrate(
        reps: [0x400c_0000_0000_0002], tokens: ["/", "default", value, ""])
      var entries: [ArchiveRecipe.Entry] = []
      if defaultName != authorName {
        entries.append(try binary(defaultName, "baseline/empty.usdc"))
      }
      entries.append(.init(nameBytes: Data(authorName.utf8), payload: crate))
      let bytes = try ArchiveRecipe(entries: entries).encode()
      let normalLedger = ResourceLedger()
      let normal = try inspect(bytes, ledger: normalLedger)
      XCTAssertEqual(normal.findings.map(\.ruleID), ["UVK-PATH-006"])
      XCTAssertEqual(normalLedger.usdcLiveBytes, 0)

      let ledger = ResourceLedger()
      let heldBytes = SafetyResource.usdcWorkingBytes.limit - 65_536
      let held = try ledger.reserveUSDCStorage(heldBytes)
      defer { held.release() }
      let limited = try inspect(bytes, ledger: ledger)
      XCTAssertTrue(
        limited.findings.contains {
          $0.ruleID == "UVK-RES-001" && $0.evidence["resource"] == .string("usdcWorkingBytes")
        })
      XCTAssertFalse(limited.findings.contains { $0.ruleID == "UVK-PATH-006" })
      XCTAssertEqual(ledger.usdcLiveBytes, heldBytes)
      held.release()
      XCTAssertEqual(ledger.usdcLiveBytes, 0)
    }
  }

  // Namespace, stored mapping, integrity, alignment and default gates must precede crate tables.
  func testPrerequisiteFailureForbidsBinaryReads() throws {
    let crate = try binary("root.usdc", "baseline/containers.usdc")
    var compressed = crate
    compressed.method = 8
    var badCRC = crate
    badCRC.declaredCRC32 = 1
    let recipes = [
      ArchiveRecipe(entries: [crate, .init(nameBytes: Data("../unsafe".utf8), payload: Data())]),
      ArchiveRecipe(entries: [compressed]),
      ArchiveRecipe(entries: [badCRC]),
      ArchiveRecipe(entries: [crate], alignment: 1),
      ArchiveRecipe(entries: [
        .init(nameBytes: Data("first.png".utf8), payload: Fixtures.pixelPNG()), crate,
      ]),
      ArchiveRecipe(entries: [
        .init(
          nameBytes: Data("first.usda".utf8), payload: Data("#usda 1.0\n".utf8), declaredCRC32: 1),
        crate,
      ]),
    ]
    for recipe in recipes {
      let layout = try recipe.encodeWithLayout()
      let payloads = Set(layout.entries.map { UInt64($0.payload) })
      var binaryTableReads = 0
      let result = try NativeEngine.inspect(
        size: UInt64(layout.bytes.count), configuration: ValidationConfiguration(),
        ledger: ResourceLedger()
      ) { offset, count in
        if payloads.contains(offset), count == 24 { binaryTableReads += 1 }
        return layout.bytes.subdata(in: Int(offset)..<(Int(offset) + count))
      }
      XCTAssertEqual(binaryTableReads, 0)
      XCTAssertFalse(
        result.findings.contains { $0.ruleID == "UVK-PATH-006" || $0.ruleID == "UVK-USD-001" })
      XCTAssertEqual(result.coverage.areas[.references]?.state, .notRun)
      XCTAssertFalse(result.coverage.isComplete)
    }
  }

  // A later successful binary must not erase a prerequisite failure on another member.
  func testCompleteBinaryRetainsOtherMemberPrerequisiteGap() throws {
    var damaged = try binary("damaged.usdc", "baseline/containers.usdc")
    damaged.declaredCRC32 = 1
    let result = try inspect(
      ArchiveRecipe(entries: [
        binary("root.usdc", "baseline/empty.usdc"), damaged,
        binary("last.usd", "versions/tc09-empty-openusd.usdc"),
      ]).encode())
    XCTAssertEqual(result.coverage.areas[.references]?.state, .partial)
    XCTAssertTrue(
      result.coverage.areas[.references]?.reasons.contains { $0.ruleID == "UVK-ARC-003" } == true)
  }

  // USDA and USDC must debit one occurrence budget, with recovered findings surviving the stop.
  func testMixedScannersShareOccurrenceBudgetAndReleaseOnPartialStop() throws {
    let ledger = ResourceLedger()
    try ledger.consumeTokens(99_998)
    let crate = try USDCMutationRecipe.valueCrate(reps: [
      0x400c_0000_0000_0002, 0x400c_0000_0000_0002,
    ])
    let result = try inspect(
      ArchiveRecipe(entries: [
        .init(nameBytes: Data("root.usda".utf8), payload: Data("#usda 1.0\n@@".utf8)),
        .init(nameBytes: Data("binary.usdc".utf8), payload: crate),
      ]).encode(), ledger: ledger)
    XCTAssertEqual(result.findings.filter { $0.ruleID == "UVK-PATH-006" }.count, 1)
    XCTAssertTrue(
      result.findings.contains {
        $0.ruleID == "UVK-RES-001" && $0.evidence["resource"] == .string("tokenCount")
      })
    XCTAssertTrue(result.findings.contains { $0.ruleID == "UVK-LIM-007" })
    XCTAssertFalse(result.findings.contains { $0.ruleID == "UVK-LIM-002" })
    XCTAssertEqual(result.coverage.areas[.references]?.state, .partial)
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
  }

  // Sequential layers must release all prior scratch and retain charged cumulative counters.
  func testSequentialBinaryLayersShareReaderAndReleaseStorage() throws {
    let crate = try USDCMutationRecipe.valueCrate(reps: [0x400c_0000_0000_0002])
    let layout = try ArchiveRecipe(entries: [
      .init(nameBytes: Data("first.usdc".utf8), payload: crate),
      .init(nameBytes: Data("second.usd".utf8), payload: crate),
    ]).encodeWithLayout()
    let payloads = layout.entries.map { UInt64($0.payload) }
    let ledger = ResourceLedger()
    try ledger.consumeTokens(99_999)
    var inspected: [UInt64] = []
    var readBytes: UInt64 = 0
    let result = try NativeEngine.inspect(
      size: UInt64(layout.bytes.count), configuration: ValidationConfiguration(), ledger: ledger
    ) { offset, count in
      readBytes += UInt64(count)
      if payloads.contains(offset), count == 24 {
        inspected.append(offset)
        // Only the current 24-byte bootstrap staging charge (2*n + 256) is live.
        XCTAssertEqual(ledger.usdcLiveBytes, 304)
      }
      return layout.bytes.subdata(in: Int(offset)..<(Int(offset) + count))
    }
    XCTAssertEqual(inspected, payloads)
    XCTAssertEqual(ledger.totalReadBytes, readBytes)
    XCTAssertGreaterThan(ledger.usdcDecodeBytes, 0)
    XCTAssertGreaterThan(ledger.usdcWorkUnits, 0)
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
    XCTAssertEqual(result.findings.filter { $0.ruleID == "UVK-PATH-006" }.count, 1)
    XCTAssertTrue(
      result.findings.contains {
        $0.ruleID == "UVK-LIM-002" && $0.location?.entryName == "second.usd"
      })
    XCTAssertTrue(result.findings.contains { $0.ruleID == "UVK-RES-001" })
    XCTAssertEqual(result.coverage.areas[.references]?.state, .partial)
  }

  // Snapshot errors must escape without becoming content diagnostics, after storage release.
  func testBinaryOperationalErrorsEscapeAndReleaseStorage() throws {
    let layout = try ArchiveRecipe(entries: [binary("root.usdc", "baseline/empty.usdc")])
      .encodeWithLayout()
    let ledger = ResourceLedger()
    XCTAssertThrowsError(
      try NativeEngine.inspect(
        size: UInt64(layout.bytes.count), configuration: ValidationConfiguration(), ledger: ledger
      ) { offset, count in
        if offset == UInt64(layout.entries[0].payload), count == 24 {
          throw ValidationError.operational(.inputChanged)
        }
        return layout.bytes.subdata(in: Int(offset)..<(Int(offset) + count))
      }
    ) { XCTAssertEqual($0 as? ValidationError, .operational(.inputChanged)) }
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
  }

  // A hard stop before any recovered reference inventory cannot certify a partial inventory.
  func testResourceStopBeforeInventoryIsUninspected() throws {
    let ledger = ResourceLedger()
    try ledger.reserveUSDCDecode(33_554_432)
    let result = try inspect(
      ArchiveRecipe(entries: [binary("root.usdc", "baseline/empty.usdc")]).encode(), ledger: ledger)
    XCTAssertEqual(Set(result.findings.map(\.ruleID)), ["UVK-RES-001", "UVK-LIM-002"])
    XCTAssertEqual(result.coverage.areas[.references]?.state, .partial)
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
  }

  // An earlier recovered value remains reported when another value is conclusively corrupt.
  func testEarlierValueSurvivesLaterCorruptionInSameLayer() throws {
    let crate = try USDCMutationRecipe.valueCrate(reps: [
      0x400c_0000_0000_0002, 0x400c_0000_ffff_ffff,
    ])
    let result = try inspect(
      ArchiveRecipe(entries: [.init(nameBytes: Data("root.usdc".utf8), payload: crate)]).encode())
    XCTAssertEqual(
      Set(result.findings.map(\.ruleID)), ["UVK-PATH-006", "UVK-USD-001", "UVK-LIM-007"])
    XCTAssertEqual(result.coverage.areas[.references]?.state, .partial)
  }

  private func inspect(_ bytes: Data, ledger: ResourceLedger) throws -> NativeResult {
    try NativeEngine.inspect(
      size: UInt64(bytes.count), configuration: ValidationConfiguration(), ledger: ledger
    ) { offset, count in
      bytes.subdata(in: Int(offset)..<(Int(offset) + count))
    }
  }

  private func binary(_ name: String, _ path: String) throws -> ArchiveRecipe.Entry {
    .init(
      nameBytes: Data(name.utf8),
      payload: try Data(contentsOf: USDCFixtures.root.appendingPathComponent(path)))
  }

  private func inspect(_ bytes: Data) throws -> NativeResult {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = try Fixtures.write(bytes, basename: "input.usdz", in: directory)
    let snapshot = try FileSnapshot.open(url)
    defer { try? snapshot.close() }
    return try NativeEngine.inspect(snapshot: snapshot, configuration: ValidationConfiguration())
  }
}

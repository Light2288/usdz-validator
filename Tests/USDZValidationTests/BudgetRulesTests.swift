import Foundation
import XCTest

@testable import USDZValidation

final class BudgetRulesTests: XCTestCase {
  // A >= comparison, a wrong budget mapping, or a changed effective default breaks these rows.
  func testEveryThreshold() throws {
    let defaults: [(String, String, UInt64)] = [
      ("archiveBytes", "UVK-BUD-001", 104_857_600),
      ("fileBytes", "UVK-BUD-002", 26_214_400),
      ("fileCount", "UVK-BUD-003", 1_000),
      ("textureBytes", "UVK-BUD-004", 20_971_520),
      ("totalTextureBytes", "UVK-BUD-005", 83_886_080),
      ("textureMaxDimension", "UVK-BUD-006", 4_096),
    ]
    let custom: [UInt64] = [7, 11, 3, 13, 17, 19]
    for (index, row) in defaults.enumerated() {
      for (threshold, budgets) in [
        (row.2, WarningBudgets.defaults),
        (custom[index], try only(row.0, threshold: custom[index])),
      ] {
        for delta: Int64 in [-1, 0, 1] {
          let observed = UInt64(Int64(threshold) + delta)
          let sample = scenario(key: row.0, observed: observed)
          let result = try evaluate(sample, budgets: budgets)
          XCTAssertEqual(result.0.map(\.ruleID), delta == 1 ? [row.1] : [], "\(row.0): \(observed)")
          XCTAssertTrue(result.0.allSatisfy { $0.category == .policy && $0.severity == .warning })
          if let finding = result.0.first {
            XCTAssertEqual(finding.evidence["budget"], .string(row.0))
            XCTAssertEqual(finding.evidence["threshold"], .integer(Int64(threshold)))
            XCTAssertEqual(finding.evidence["observed"], .integer(Int64(observed)))
          }
        }
      }
    }
  }

  // Disabled checks must not suppress any other independently enabled warning.
  func testNullDisablesOnlyItsBudget() throws {
    let sample = Scenario(
      archiveBytes: 104_857_601,
      entries: [entry("large.PNG", size: 83_886_081)]
        + (1...1_000).map { entry("\($0).usd", offset: UInt64($0) * 64) },
      dimensions: [0: TextureDimensions(width: 4_097, height: 1)])
    let rules = [
      "UVK-BUD-001", "UVK-BUD-002", "UVK-BUD-003", "UVK-BUD-004", "UVK-BUD-005", "UVK-BUD-006",
    ]
    XCTAssertEqual(Set(try evaluate(sample).0.map(\.ruleID)), Set(rules))
    let keys = [
      "archiveBytes", "fileBytes", "fileCount", "textureBytes", "totalTextureBytes",
      "textureMaxDimension",
    ]
    for (key, rule) in zip(keys, rules) {
      let budgets = try BudgetConfiguration.decode(
        Data("{\"schemaVersion\":1,\"budgets\":{\"\(key)\":null}}".utf8))
      let result = try evaluate(sample, budgets: budgets)
      XCTAssertEqual(Set(result.0.map(\.ruleID)), Set(rules.filter { $0 != rule }))
    }
    let disabled = try evaluate(sample, budgets: only("archiveBytes", threshold: nil))
    XCTAssertTrue(disabled.0.isEmpty)
  }

  // Classification, rather than references, controls delivery byte counts; directory metadata does not.
  func testRegularTexturesCountOnceIncludingUnreferencedAndUnavailableDimensions() throws {
    let entries = [
      entry("root.usda"), entry("one.PNG", offset: 64, size: 3),
      entry("two.jFiF", offset: 128, size: 5), entry("three.EXR", offset: 192, size: 7),
      entry("four.AvIf", offset: 256, size: 11),
      entry("folder.png", offset: 320, size: 999, attributes: 0x41ed_0000),
      entry("folder.jpg/", offset: 384, size: 999, host: 0, attributes: 0x10),
    ]
    let sample = Scenario(entries: entries)
    let exact = try evaluate(sample, budgets: only("totalTextureBytes", threshold: 26))
    XCTAssertTrue(exact.0.isEmpty)
    let excess = try evaluate(sample, budgets: only("totalTextureBytes", threshold: 25))
    XCTAssertEqual(excess.0.map(\.ruleID), ["UVK-BUD-005"])
    XCTAssertEqual(excess.0.first?.evidence["observed"], .integer(26))
    let count = try evaluate(sample, budgets: only("fileCount", threshold: 5))
    XCTAssertTrue(count.0.isEmpty)
    let perFile = try evaluate(sample, budgets: only("fileBytes", threshold: 11))
    XCTAssertTrue(perFile.0.isEmpty)
    let perTexture = try evaluate(sample, budgets: only("textureBytes", threshold: 6))
    XCTAssertEqual(perTexture.0.map(\.ruleID), ["UVK-BUD-004", "UVK-BUD-004"])
    XCTAssertEqual(perTexture.0.compactMap { $0.location?.archiveByteOffset }, [256, 192])
    XCTAssertFalse(excess.0.contains { $0.ruleID == "UVK-LIM-005" })
  }

  func testDimensionsUsePhysicalKeysAndEitherAxisOnlyForSupportedTextures() throws {
    let entries = [
      entry("a.png", offset: 64), entry("b.jpg", offset: 128),
      entry("c.exr", offset: 192), entry("d.usda", offset: 256),
      entry("folder.jpeg", offset: 320, attributes: 0x41ed_0000),
    ]
    let sample = Scenario(
      entries: entries,
      dimensions: [
        64: TextureDimensions(width: 19, height: 20),
        128: TextureDimensions(width: 20, height: 19),
        192: TextureDimensions(width: 500, height: 500),
        256: TextureDimensions(width: 500, height: 500),
        320: TextureDimensions(width: 500, height: 500),
        999: TextureDimensions(width: 500, height: 500),
      ])
    let findings = try evaluate(sample, budgets: only("textureMaxDimension", threshold: 19)).0
    XCTAssertEqual(findings.map(\.ruleID), ["UVK-BUD-006", "UVK-BUD-006"])
    XCTAssertEqual(findings.compactMap { $0.location?.archiveByteOffset }, [64, 128])
    XCTAssertEqual(findings.map { $0.evidence["observed"] }, [.integer(20), .integer(20)])
  }

  func testFixedBudgetIdentitySurvivesThresholdAndObservedChanges() throws {
    let sample = Scenario(
      archiveBytes: 50, entries: [entry("a.png", size: 50)],
      dimensions: [0: TextureDimensions(width: 50, height: 1)])
    let a = try evaluate(sample, budgets: all(10)).0
    let b = try evaluate(sample, budgets: all(20)).0
    XCTAssertEqual(a.map(\.occurrenceID), b.map(\.occurrenceID))
    XCTAssertNotEqual(a.map(\.evidence), b.map(\.evidence))
    let c = try evaluate(
      Scenario(
        archiveBytes: 60, entries: [entry("a.png", size: 60)],
        dimensions: [0: TextureDimensions(width: 60, height: 1)]), budgets: all(20)
    ).0
    XCTAssertEqual(a.map(\.occurrenceID), c.map(\.occurrenceID))
    for finding in a {
      let key = try XCTUnwrap(finding.evidence["budget"])
      guard case .string(let discriminator) = key else {
        return XCTFail("Missing fixed budget key")
      }
      let perEntry = ["fileBytes", "textureBytes", "textureMaxDimension"].contains(discriminator)
      XCTAssertEqual(
        finding.occurrenceID,
        FindingIdentity.native(
          FindingKey(
            ruleID: finding.ruleID, entryNameBytes: perEntry ? Data("a.png".utf8) : nil,
            entryOffset: perEntry ? 0 : nil, contentOffset: nil, discriminator: discriminator)))
    }
  }

  // Synthetic values outside the ZIP/safety envelope still must not wrap or trap in the pure evaluator.
  func testCheckedTextureTotalAndUnsignedEvidenceCannotOverflow() throws {
    let maximum = UInt64(Int64.max)
    let exact = try evaluate(
      Scenario(entries: [entry("a.png", size: maximum)]),
      budgets: only("totalTextureBytes", threshold: maximum)
    ).0
    XCTAssertTrue(exact.isEmpty)
    let excess = try evaluate(
      Scenario(entries: [entry("a.png", size: maximum), entry("b.exr", offset: 64, size: 1)]),
      budgets: only("totalTextureBytes", threshold: maximum)
    ).0
    XCTAssertEqual(excess.map(\.ruleID), ["UVK-BUD-005"])
    XCTAssertEqual(excess.first?.evidence["observed"], .string("9223372036854775808"))
    let overflow = try evaluate(
      Scenario(entries: [entry("a.png", size: .max), entry("b.avif", offset: 64, size: 1)]),
      budgets: only("totalTextureBytes", threshold: 1))
    XCTAssertEqual(overflow.0.map(\.ruleID), ["UVK-RES-001"])
    XCTAssertEqual(overflow.0.first?.evidence["resource"], .string("aggregateEntryBytes"))
    XCTAssertEqual(overflow.1.areas[.byteBudgets]?.state, .partial)
  }

  func testUnknownAndProhibitedTypesAreNotAssumedRegular() throws {
    let entries = [
      entry("unknown.png", size: 50, host: 0x0b14),
      entry("link.png", offset: 64, size: 50, attributes: 0xa1ff_0000),
      entry("volume.png", offset: 128, size: 50, host: 0, attributes: 0x08),
      entry("regular.PNG", offset: 192, size: 1, host: 0, attributes: 0),
      entry("unix.jpg", offset: 256, size: 1, attributes: 0),
    ]
    XCTAssertTrue(try evaluate(Scenario(entries: entries), budgets: all(2)).0.isEmpty)
  }

  func testDimensionDisablingRemovesOnlyItsRequestedCoverageAndNoStageClaimsCompletion() throws {
    let enabled = try evaluate(Scenario(entries: [entry("image.exr", size: 3)]), budgets: all(2))
    let disabled = try evaluate(
      Scenario(entries: [entry("image.exr", size: 3)]), budgets: only("textureBytes", threshold: 2))
    XCTAssertEqual(enabled.1.areas[.textureDimensions]?.requested, true)
    XCTAssertEqual(disabled.1.areas[.textureDimensions]?.requested, false)
    XCTAssertEqual(disabled.0.map(\.ruleID), ["UVK-BUD-004"])
    XCTAssertEqual(disabled.1.areas[.byteBudgets]?.requested, true)
    XCTAssertTrue(disabled.1.areas.values.allSatisfy { $0.state == .notRun })
    XCTAssertFalse(disabled.1.isComplete)
  }

  private struct Scenario {
    var archiveBytes: UInt64 = 0
    var entries: [ZIPEntry] = []
    var dimensions: [UInt64: TextureDimensions] = [:]
  }

  private func scenario(key: String, observed: UInt64) -> Scenario {
    switch key {
    case "archiveBytes": return Scenario(archiveBytes: observed)
    case "fileBytes": return Scenario(entries: [entry("root.usd", size: observed)])
    case "fileCount":
      return Scenario(entries: (0..<observed).map { entry("\($0).usd", offset: $0 * 64) })
    case "textureBytes": return Scenario(entries: [entry("a.png", size: observed)])
    case "totalTextureBytes":
      return Scenario(
        entries: (0..<8).map {
          entry(
            "\($0).png", offset: UInt64($0) * 64,
            size: observed / 8 + (UInt64($0) < observed % 8 ? 1 : 0))
        })
    default:
      return Scenario(
        entries: [entry("a.png")],
        dimensions: [0: TextureDimensions(width: UInt32(observed), height: 1)])
    }
  }

  private func evaluate(_ sample: Scenario, budgets: WarningBudgets = .defaults) throws -> (
    [Finding], Coverage
  ) {
    let configuration = try ValidationConfiguration(budgets: budgets)
    let diagnostics = NativeDiagnostics(
      textureDimensionsRequested: budgets.textureMaxDimension != nil)
    BudgetRules.evaluate(
      archiveBytes: sample.archiveBytes, entries: sample.entries, dimensions: sample.dimensions,
      configuration: configuration, diagnostics: diagnostics)
    return diagnostics.finish()
  }

  private func only(_ key: String, threshold: UInt64?) throws -> WarningBudgets {
    let value = threshold.map(String.init) ?? "null"
    let keys = [
      "archiveBytes", "fileBytes", "fileCount", "textureBytes", "totalTextureBytes",
      "textureMaxDimension",
    ]
    let fields = keys.map { "\"\($0)\":\($0 == key ? value : "null")" }.joined(separator: ",")
    return try BudgetConfiguration.decode(
      Data("{\"schemaVersion\":1,\"budgets\":{\(fields)}}".utf8))
  }

  private func all(_ threshold: Int64) -> WarningBudgets {
    WarningBudgets(
      archiveBytes: threshold, fileBytes: threshold, fileCount: threshold, textureBytes: threshold,
      totalTextureBytes: threshold, textureMaxDimension: threshold)
  }

  private func entry(
    _ name: String, offset: UInt64 = 0, size: UInt64 = 0, host: UInt16 = 0x0314,
    attributes: UInt32 = 0x81a4_0000
  ) -> ZIPEntry {
    let record = ZIPDirectory.Record(
      nameBytes: Data(name.utf8), versionMadeBy: host, versionNeeded: 20, flags: 0, method: 0,
      modificationTime: 0, modificationDate: 0, crc32: 0, compressedSize: size,
      uncompressedSize: size, diskNumber: 0, internalAttributes: 0, externalAttributes: attributes,
      localHeaderOffset: offset, centralHeaderOffset: 0)
    return ZIPEntry(
      record: record, recordRange: offset..<offset, headerRange: offset..<offset,
      payloadRange: offset..<offset)
  }
}

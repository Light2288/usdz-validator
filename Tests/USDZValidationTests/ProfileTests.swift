import Foundation
import XCTest

@testable import USDZValidation

final class ProfileTests: XCTestCase {
  // Advice follows the selected frozen profile and established member/layer identity.
  func testFrozenAppleAdvice() {
    let entries = [
      entry("root.usd", offset: 64), entry("binary.usdc", offset: 128),
      entry("photo.PNG", offset: 192), entry("photo.JPEG", offset: 256),
      entry("lighting.EXR", offset: 320), entry("image.AvIf", offset: 384),
      entry("text.usda", offset: 448),
    ]
    let kinds: [UInt64: LayerKind] = [64: .usda, 128: .usdc, 448: .usda]
    let general = evaluate(entries, kinds: kinds, profile: .generalV1)
    XCTAssertTrue(general.0.isEmpty)
    XCTAssertEqual(general.1.areas[.appleAdvice]?.requested, false)
    let apple = evaluate(entries, kinds: kinds)
    XCTAssertEqual(
      apple.0.map(\.ruleID), ["UVK-APL-001", "UVK-APL-001", "UVK-APL-002", "UVK-APL-002"])
    XCTAssertTrue(
      apple.0.allSatisfy { $0.severity == .warning && $0.category == .appleCompatibility })
    XCTAssertEqual(
      apple.0.filter { $0.ruleID == "UVK-APL-001" }.compactMap { $0.location?.archiveByteOffset },
      [64, 448])
    XCTAssertEqual(
      apple.0.filter { $0.ruleID == "UVK-APL-002" }.compactMap { $0.location?.archiveByteOffset },
      [384, 320])
    XCTAssertEqual(apple.1.areas[.appleAdvice]?.requested, true)
    XCTAssertTrue(apple.1.areas.values.allSatisfy { $0.state == .notRun })
    let binaryAndBaseline = evaluate(
      [
        entry("root.usdc"), entry("a.png", offset: 64), entry("b.jpg", offset: 128),
      ], kinds: [0: .usdc])
    XCTAssertTrue(binaryAndBaseline.0.isEmpty)
  }

  func testStandaloneUsesFirstPhysicalRegularWithoutSubstitutingLaterLayer() {
    let directory = entry("assets", offset: 0, attributes: 0x41ed_0000)
    let first = entry("first.png", offset: 64)
    let later = entry("later.usda", offset: 128)
    let result = evaluate([later, first, directory], kinds: [128: .usda], profile: .generalV1)
    XCTAssertEqual(result.0.map(\.ruleID), ["UVK-POL-001"])
    XCTAssertEqual(result.0.first?.location?.archiveByteOffset, 64)
    XCTAssertEqual(result.0.first?.severity, .error)
    XCTAssertTrue(evaluate([directory, later], kinds: [128: .usda], profile: .generalV1).0.isEmpty)
    XCTAssertTrue(evaluate([entry("root.usd")], kinds: [0: .usdc], profile: .generalV1).0.isEmpty)
  }

  func testConclusiveUnrecognizedFailsButUnavailableRecognitionDoesNotGuess() {
    let root = entry("root.usd")
    XCTAssertEqual(
      evaluate([root], kinds: [0: .unrecognized], profile: .generalV1).0.map(\.ruleID),
      ["UVK-POL-001"])
    XCTAssertTrue(evaluate([root], kinds: [:], profile: .generalV1).0.isEmpty)
    let encoded = evaluate([root], kinds: [0: .unsupportedEncoding])
    XCTAssertEqual(encoded.0.map(\.ruleID), ["UVK-APL-001"])
    XCTAssertTrue(encoded.1.areas.values.allSatisfy { $0.state == .notRun })
    let missing = evaluate([entry("missing.usda")], kinds: [:])
    XCTAssertTrue(missing.0.isEmpty)
    let notLayer = evaluate([entry("root.png")], kinds: [0: .usda], profile: .generalV1)
    XCTAssertEqual(notLayer.0.map(\.ruleID), ["UVK-POL-001"])
  }

  func testSuffixPolicyUsesFrozenCaseInsensitiveCatalogueAndExcludesDirectories() {
    let suffixes = [
      "USD", "UsDa", "UsDc", "USDZ", "PNG", "JPG", "JPEG", "JPE", "JFIF", "EXR", "AVIF", "M4A",
      "MP3", "WAV",
    ]
    let entries = suffixes.enumerated().map {
      entry("member.\($0.element)", offset: UInt64($0.offset) * 64)
    }
    let accepted = evaluate(entries, kinds: [0: .usda], profile: .generalV1)
    XCTAssertTrue(accepted.0.isEmpty)
    let extras = [
      entry("unknown.txt", offset: 1_000), entry("extensionless", offset: 1_064),
      entry("textures", offset: 1_128, attributes: 0x41ed_0000),
      entry("regular", offset: 1_192, host: 0, attributes: 0),
    ]
    let rejected = evaluate([entries[0]] + extras, kinds: [0: .usdc], profile: .generalV1)
    XCTAssertEqual(rejected.0.map(\.ruleID), ["UVK-POL-002", "UVK-POL-002", "UVK-POL-002"])
    XCTAssertEqual(
      Set(rejected.0.compactMap { $0.location?.archiveByteOffset }), [1_000, 1_064, 1_192])
    XCTAssertTrue(rejected.0.allSatisfy { $0.category == .policy && $0.severity == .error })
  }

  func testNestedPackageIsRecognizedSuffixButNotStandaloneAndDoesNotDuplicateLimitation() {
    let root = entry("root.usda")
    let nested = entry("nested.USDZ", offset: 64)
    XCTAssertTrue(evaluate([root, nested], kinds: [0: .usda], profile: .generalV1).0.isEmpty)
    let firstNested = evaluate(
      [nested, entry("later.usda", offset: 128)], kinds: [128: .usda], profile: .generalV1)
    XCTAssertEqual(firstNested.0.map(\.ruleID), ["UVK-POL-001"])
    XCTAssertFalse(firstNested.0.contains { $0.category == .validatorLimitation })
  }

  func testUnknownOrProhibitedTypeCannotSelectLaterDefaultOrProduceAdvice() {
    for (host, attributes): (UInt16, UInt32) in [
      (0x0b14, 0), (0x0314, 0xa1ff_0000), (0x0314, 0o030000 << 16), (0, 0x08),
    ] {
      let unknown = entry("unknown.exr", offset: 0, host: host, attributes: attributes)
      let later = entry("later.png", offset: 64)
      let result = evaluate([unknown, later], kinds: [:])
      XCTAssertTrue(result.0.isEmpty)
    }
    let directory = entry("directory.exr", attributes: 0x41ed_0000)
    let root = entry("root.usdc", offset: 64)
    XCTAssertTrue(evaluate([directory, root], kinds: [64: .usdc]).0.isEmpty)
  }

  func testEmptyOrDirectoriesOnlyFailsEstablishedDefaultRequirement() {
    let empty = evaluate([], kinds: [:], profile: .generalV1)
    XCTAssertEqual(empty.0.map(\.ruleID), ["UVK-POL-001"])
    XCTAssertNil(empty.0.first?.location)
    let directories = evaluate(
      [entry("dir", attributes: 0x41ed_0000)], kinds: [:], profile: .generalV1)
    XCTAssertEqual(directories.0.map(\.ruleID), ["UVK-POL-001"])
  }

  func testPolicyAndAdviceKeysAreStableAndIdempotent() {
    let entries = [
      entry("root.usda"), entry("a.exr", offset: 64), entry("unknown.txt", offset: 128),
    ]
    let diagnostics = NativeDiagnostics(profile: .applePortableV1)
    for _ in 0..<2 {
      ProfileRules.evaluate(
        entries: entries, layerKinds: [0: .usda], profile: .applePortableV1,
        diagnostics: diagnostics)
    }
    let result = diagnostics.finish().0
    XCTAssertEqual(result.map(\.ruleID), ["UVK-APL-001", "UVK-APL-002", "UVK-POL-002"])
    XCTAssertEqual(Set(result.map(\.occurrenceID)).count, 3)
    XCTAssertTrue(result.allSatisfy { $0.location?.entryName == nil })
  }

  private func evaluate(
    _ entries: [ZIPEntry], kinds: [UInt64: LayerKind], profile: Profile = .applePortableV1
  ) -> ([Finding], Coverage) {
    let diagnostics = NativeDiagnostics(profile: profile)
    ProfileRules.evaluate(
      entries: entries, layerKinds: kinds, profile: profile, diagnostics: diagnostics)
    return diagnostics.finish()
  }

  private func entry(
    _ name: String, offset: UInt64 = 0, host: UInt16 = 0x0314, attributes: UInt32 = 0x81a4_0000
  ) -> ZIPEntry {
    let record = ZIPDirectory.Record(
      nameBytes: Data(name.utf8), versionMadeBy: host, versionNeeded: 20, flags: 0, method: 0,
      modificationTime: 0, modificationDate: 0, crc32: 0, compressedSize: 0, uncompressedSize: 0,
      diskNumber: 0, internalAttributes: 0, externalAttributes: attributes,
      localHeaderOffset: offset, centralHeaderOffset: 0)
    return ZIPEntry(
      record: record, recordRange: offset..<offset, headerRange: offset..<offset,
      payloadRange: offset..<offset)
  }
}

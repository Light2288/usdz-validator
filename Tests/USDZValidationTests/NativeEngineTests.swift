import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

final class NativeEngineTests: XCTestCase {
  func testRegularFileCountSurvivesUnavailableStorageAndUnsafeNamespace() throws {
    let configuration = try ValidationConfiguration(
      budgets: WarningBudgets(
        archiveBytes: nil, fileBytes: nil, fileCount: 1, textureBytes: nil,
        totalTextureBytes: nil, textureMaxDimension: nil))
    for (flags, method): (UInt16, UInt16) in [(0, 8), (1, 0)] {
      for unsafeNamespace in [false, true] {
        let result = try inspect(
          ArchiveRecipe(entries: [
            layer("root.usda", "#usda 1.0\n"),
            .init(
              nameBytes: Data((unsafeNamespace ? "../sound.wav" : "sound.wav").utf8),
              payload: Data("bytes".utf8), flags: flags, method: method),
          ]).encode(), configuration: configuration)
        let count = result.findings.first { $0.ruleID == "UVK-BUD-003" }
        XCTAssertNotNil(count)
        XCTAssertEqual(count?.evidence["observed"], .integer(2))
        XCTAssertEqual(count?.evidence["threshold"], .integer(1))
        XCTAssertEqual(result.coverage.areas[.byteBudgets]?.state, .complete)
        XCTAssertTrue(
          result.findings.contains { $0.ruleID == (method == 8 ? "UVK-ARC-004" : "UVK-ARC-005") })
        XCTAssertEqual(result.coverage.areas[.containerStructure]?.state, .partial)
        XCTAssertFalse(result.containerSafeForExternal)
      }
    }
    let unknown = try inspect(
      ArchiveRecipe(entries: [
        layer("root.usda", "#usda 1.0\n"),
        .init(
          nameBytes: Data("sound.wav".utf8), payload: Data("bytes".utf8),
          centralHeaderPatches: [.uint16(at: 4, 0x0b14)]),
      ]).encode(), configuration: configuration)
    XCTAssertFalse(unknown.findings.contains { $0.ruleID == "UVK-BUD-003" })
    XCTAssertEqual(unknown.coverage.areas[.byteBudgets]?.state, .partial)
  }

  func testByteCoverageDependsOnEnabledApplicableInputs() throws {
    let archiveOnly = try ValidationConfiguration(
      budgets: WarningBudgets(
        archiveBytes: 1, fileBytes: nil, fileCount: nil, textureBytes: nil,
        totalTextureBytes: nil, textureMaxDimension: nil))
    let textureOnly = try ValidationConfiguration(
      budgets: WarningBudgets(
        archiveBytes: nil, fileBytes: nil, fileCount: nil, textureBytes: 1,
        totalTextureBytes: 1, textureMaxDimension: nil))
    let fileOnly = try ValidationConfiguration(
      budgets: WarningBudgets(
        archiveBytes: nil, fileBytes: 1, fileCount: nil, textureBytes: nil,
        totalTextureBytes: nil, textureMaxDimension: nil))
    for (flags, method, unknown): (UInt16, UInt16, Bool) in [
      (0, 8, false), (1, 0, false), (0, 0, true),
    ] {
      let unavailable = ArchiveRecipe.Entry(
        nameBytes: Data("sound.wav".utf8), payload: Data("bytes".utf8),
        flags: flags, method: method, centralHeaderPatches: unknown ? [.uint16(at: 4, 0x0b14)] : [])
      let bytes = try ArchiveRecipe(entries: [
        layer("root.usda", "#usda 1.0\n"), unavailable,
        .init(nameBytes: Data("good.png".utf8), payload: Fixtures.pixelPNG()),
      ]).encode()
      let archive = try inspect(bytes, configuration: archiveOnly)
      XCTAssertEqual(archive.coverage.areas[.byteBudgets]?.state, .complete)
      XCTAssertTrue(archive.findings.contains { $0.ruleID == "UVK-BUD-001" })
      let texture = try inspect(bytes, configuration: textureOnly)
      XCTAssertEqual(texture.coverage.areas[.byteBudgets]?.state, .complete)
      XCTAssertEqual(texture.findings.filter { $0.ruleID == "UVK-BUD-004" }.count, 1)
      XCTAssertEqual(texture.findings.filter { $0.ruleID == "UVK-BUD-005" }.count, 1)
      let file = try inspect(bytes, configuration: fileOnly)
      XCTAssertEqual(file.coverage.areas[.byteBudgets]?.state, .partial)
      XCTAssertEqual(file.findings.filter { $0.ruleID == "UVK-BUD-002" }.count, 2)
      XCTAssertFalse(archive.containerSafeForExternal)
      XCTAssertFalse(texture.containerSafeForExternal)
      XCTAssertFalse(file.containerSafeForExternal)

      var unavailableTexture = unavailable
      unavailableTexture.nameBytes = Data("bad.png".utf8)
      let applicable = try inspect(
        ArchiveRecipe(entries: [
          layer("root.usda", "#usda 1.0\n"),
          unavailableTexture,
        ]).encode(), configuration: textureOnly)
      XCTAssertEqual(applicable.coverage.areas[.byteBudgets]?.state, .partial)
      XCTAssertFalse(
        applicable.findings.contains { $0.ruleID == "UVK-BUD-004" || $0.ruleID == "UVK-BUD-005" })
    }
    let directory = try inspect(
      ArchiveRecipe(entries: [
        layer("root.usda", "#usda 1.0\n"),
        .init(nameBytes: Data("directory.png".utf8), payload: Data(), type: .directory),
      ]).encode(), configuration: textureOnly)
    XCTAssertEqual(directory.coverage.areas[.byteBudgets]?.state, .complete)
    XCTAssertTrue(directory.findings.isEmpty)
  }

  func testCompleteOriginalPackage() throws {
    let bytes = try Data(contentsOf: Fixtures.root.appendingPathComponent("valid-usda.usdz"))
    let result = try inspect(bytes)
    XCTAssertTrue(result.findings.isEmpty)
    XCTAssertTrue(result.containerSafeForExternal)
    XCTAssertEqual(result.inputByteSize, UInt64(bytes.count))
    XCTAssertTrue(result.coverage.isComplete)
    for area: CoverageArea in [
      .containerStructure, .entrySafety, .references, .byteBudgets, .textureDimensions,
    ] {
      XCTAssertEqual(result.coverage.areas[area]?.state, .complete)
      XCTAssertEqual(result.coverage.areas[area]?.reasons, [])
    }
    XCTAssertEqual(result.coverage.areas[.appleAdvice]?.requested, false)
    // Requesting a checker is inert in the native engine, including all diagnostics.
    let requested = try inspect(
      bytes, configuration: ValidationConfiguration(externalCheck: .usdchecker))
    XCTAssertEqual(result.findings, requested.findings)
    XCTAssertEqual(result.coverage, requested.coverage)
  }

  func testPrerequisitesAndIndependentResults() throws {
    let root = layer("root.usda", "#usda 1.0\n@absent.png@")
    let unsafe = try inspect(
      ArchiveRecipe(entries: [root, layer("../bad.png", "bad")]).encode(),
      configuration: lowBudgets())
    XCTAssertTrue(unsafe.findings.contains { $0.ruleID == "UVK-PATH-001" })
    XCTAssertFalse(unsafe.findings.contains { $0.ruleID == "UVK-PATH-006" })
    XCTAssertTrue(unsafe.findings.contains { $0.ruleID == "UVK-BUD-004" })
    XCTAssertEqual(unsafe.coverage.areas[.byteBudgets]?.state, .complete)
    XCTAssertEqual(unsafe.coverage.areas[.references]?.state, .notRun)
    XCTAssertFalse(unsafe.containerSafeForExternal)

    let brokenIndex = try inspect(
      ArchiveRecipe(
        entries: [root],
        endRecordPatches: [.uint32(at: 16, 1)]
      ).encode())
    XCTAssertFalse(brokenIndex.containerSafeForExternal)
    XCTAssertFalse(brokenIndex.findings.contains { $0.ruleID == "UVK-PATH-006" })
    XCTAssertEqual(brokenIndex.coverage.areas[.references]?.state, .notRun)

    var corrupt = root
    corrupt.declaredCRC32 = 1
    let crc = try inspect(ArchiveRecipe(entries: [corrupt]).encode())
    XCTAssertTrue(crc.findings.contains { $0.ruleID == "UVK-ARC-003" })
    XCTAssertFalse(crc.findings.contains { $0.ruleID == "UVK-PATH-006" })
    XCTAssertFalse(crc.containerSafeForExternal)

    let malformed = try inspect(
      ArchiveRecipe(entries: [layer("root.usda", "#usda 1.0\n"), layer("bad.png", "bad")]).encode(),
      configuration: lowBudgets())
    XCTAssertTrue(malformed.findings.contains { $0.ruleID == "UVK-BUD-007" })
    XCTAssertTrue(malformed.findings.contains { $0.ruleID == "UVK-BUD-004" })
    XCTAssertEqual(malformed.coverage.areas[.byteBudgets]?.state, .complete)
    XCTAssertEqual(malformed.coverage.areas[.textureDimensions]?.state, .partial)

    let bytes = try ArchiveRecipe(entries: [layer("root.usdc", "PXR-USDCsynthetic")]).encode()
    let binary = try inspect(bytes)
    let accepted = try inspect(
      bytes, configuration: ValidationConfiguration(gatePolicy: GatePolicy(allowIncomplete: true)))
    XCTAssertEqual(binary.findings.map(\.ruleID), ["UVK-LIM-002"])
    XCTAssertEqual(binary.coverage.areas[.references]?.state, .partial)
    XCTAssertEqual(binary.coverage.areas[.containerStructure]?.state, .complete)
    XCTAssertEqual(binary.coverage.areas[.byteBudgets]?.state, .complete)
    XCTAssertTrue(binary.containerSafeForExternal)
    XCTAssertEqual(binary.coverage, accepted.coverage)
    XCTAssertEqual(binary.findings, accepted.findings)
  }

  func testInvalidFirstRegularNeverSkipped() throws {
    let result = try inspect(
      ArchiveRecipe(entries: [
        .init(nameBytes: Data("first.png".utf8), payload: Fixtures.pixelPNG()),
        layer("later.usda", "#usda 1.0\n@absent.png@"),
      ]).encode())
    XCTAssertEqual(result.findings.map(\.ruleID), ["UVK-POL-001"])
    XCTAssertEqual(result.findings.first?.location?.archiveByteOffset, 0)
    XCTAssertEqual(result.coverage.areas[.references]?.state, .notRun)
    XCTAssertTrue(
      result.coverage.areas[.references]?.reasons.contains { $0.ruleID == "UVK-POL-001" } == true)
    XCTAssertEqual(result.coverage.areas[.textureDimensions]?.state, .complete)
  }

  func testFixedDiscoveryAndChanges() throws {
    let bytes = try ArchiveRecipe(entries: [
      layer("root.usda", "#usda 1.0\n@missing.png@ @https://host/asset@"),
      layer("unreferenced.usda", "#usda 1.0\n@missing.wav@"),
      layer("nested.usdz", "not inspected"),
    ]).encode()
    let first = try inspect(bytes)
    let relocated = try inspect(bytes, basename: "relocated.usdz")
    XCTAssertEqual(first.findings, relocated.findings)
    XCTAssertEqual(first.coverage, relocated.coverage)
    XCTAssertEqual(first.findings.filter { $0.ruleID == "UVK-PATH-006" }.count, 2)
    XCTAssertEqual(first.findings.filter { $0.ruleID == "UVK-LIM-006" }.count, 1)

    // The archive ceiling returns without a content read: only final verification can
    // detect that this already-open descriptor's metadata changed on this path.
    let directory = try temporaryDirectory()
    let url = directory.appendingPathComponent("large.usdz")
    XCTAssertTrue(FileManager.default.createFile(atPath: url.path, contents: nil))
    let handle = try FileHandle(forWritingTo: url)
    try handle.truncate(atOffset: 536_870_913)
    let snapshot = try FileSnapshot.open(url)
    defer { try? snapshot.close() }
    try handle.truncate(atOffset: 536_870_914)
    try handle.close()
    XCTAssertThrowsError(
      try NativeEngine.inspect(snapshot: snapshot, configuration: ValidationConfiguration())
    ) {
      XCTAssertEqual($0 as? ValidationError, .operational(.inputChanged))
    }
  }

  func testUnsupportedTextureDimensionsAndDisabledChecks() throws {
    let bytes = try ArchiveRecipe(entries: [
      layer("root.usda", "#usda 1.0\n"),
      layer("lighting.EXR", "bytes"), layer("image.AVIF", "bytes"),
    ]).encode()
    let requested = try inspect(bytes, configuration: lowBudgets())
    XCTAssertEqual(requested.findings.filter { $0.ruleID == "UVK-LIM-005" }.count, 2)
    XCTAssertEqual(requested.findings.filter { $0.ruleID == "UVK-BUD-004" }.count, 2)
    XCTAssertEqual(requested.coverage.areas[.textureDimensions]?.state, .partial)
    XCTAssertEqual(requested.coverage.areas[.byteBudgets]?.state, .complete)
    let disabled = try inspect(bytes, configuration: lowBudgets(dimensions: nil))
    XCTAssertFalse(disabled.findings.contains { $0.ruleID == "UVK-LIM-005" })
    XCTAssertEqual(disabled.findings.filter { $0.ruleID == "UVK-BUD-004" }.count, 2)
    XCTAssertEqual(disabled.coverage.areas[.textureDimensions]?.requested, false)
    XCTAssertEqual(disabled.coverage.areas[.textureDimensions]?.state, .notRun)
    XCTAssertTrue(disabled.coverage.isComplete)
    let allDisabled = try inspect(
      bytes,
      configuration: ValidationConfiguration(
        budgets: WarningBudgets(
          archiveBytes: nil, fileBytes: nil, fileCount: nil, textureBytes: nil,
          totalTextureBytes: nil, textureMaxDimension: nil)))
    XCTAssertEqual(allDisabled.coverage.areas[.byteBudgets]?.requested, false)
    XCTAssertEqual(allDisabled.coverage.areas[.byteBudgets]?.state, .notRun)
    XCTAssertTrue(allDisabled.findings.isEmpty)
  }

  func testOriginalPhysicalDefaultDirectoryAndEveryLayer() throws {
    // Author-relative lookup misses; only the original first physical default's
    // directory contains the fallback target, including for an unreferenced layer.
    let bytes = try ArchiveRecipe(entries: [
      .init(nameBytes: Data("directory".utf8), payload: Data(), type: .directory),
      layer("scenes/root.usda", "#usda 1.0\n"),
      layer("other/unreferenced.usda", "#usda 1.0\n@target.wav@"),
      layer("scenes/target.wav", "wave"),
    ]).encode()
    let result = try inspect(bytes)
    XCTAssertTrue(result.findings.isEmpty)
    XCTAssertTrue(result.coverage.isComplete)
  }

  func testUnrecognizedAndUnavailableDefaultHaveNoReferenceCascades() throws {
    for first in [
      layer("first.usda", "not USD"),
      ArchiveRecipe.Entry(
        nameBytes: Data("first.usda".utf8), payload: Data("#usda 1.0\n".utf8), declaredCRC32: 1),
    ] {
      let result = try inspect(
        ArchiveRecipe(entries: [first, layer("later.usda", "#usda 1.0\n@missing.png@")]).encode())
      XCTAssertFalse(result.findings.contains { $0.ruleID == "UVK-PATH-006" })
      XCTAssertEqual(
        result.findings.contains { $0.ruleID == "UVK-POL-001" }, first.declaredCRC32 == nil)
      XCTAssertEqual(result.coverage.areas[.references]?.state, .notRun)
    }
  }

  func testCoverageCompletionNeverErasesGaps() {
    let diagnostics = NativeDiagnostics(textureDimensionsRequested: false)
    let reason = CoverageReason(ruleID: "UVK-LIM-001", reasonID: "prerequisite")
    diagnostics.mark(area: .references, state: .notRun, reason: reason)
    diagnostics.mark(area: .entrySafety, state: .partial, reason: reason)
    for area in CoverageArea.allCases { diagnostics.complete(area: area) }
    let coverage = diagnostics.finish().1
    XCTAssertEqual(coverage.areas[.references]?.state, .notRun)
    XCTAssertEqual(coverage.areas[.references]?.reasons, [reason])
    XCTAssertEqual(coverage.areas[.entrySafety]?.state, .partial)
    XCTAssertEqual(coverage.areas[.entrySafety]?.reasons, [reason])
    XCTAssertEqual(coverage.areas[.textureDimensions]?.state, .notRun)
    XCTAssertEqual(coverage.areas[.appleAdvice]?.state, .notRun)
    XCTAssertEqual(coverage.areas[.containerStructure]?.state, .complete)
    XCTAssertEqual(coverage.areas[.containerStructure]?.reasons, [])
  }

  func testLargeTextStopsBeforeIntegrityButBinaryAndUnknownDoNotUseTextCap() throws {
    // Deliberately wrong CRC distinguishes a prohibited full-payload scan from a
    // permitted bounded discrimination read; no timing or read-count guess is needed.
    for (name, header, capped) in [
      ("root.usda", Data("#usda 1.0\n".utf8), true),
      ("root.usd", Data("#usda 1.0\n".utf8), true),
      ("root.usd", Data([0xef, 0xbb, 0xbf]) + Data("#usda 1.0\n".utf8), true),
      ("root.usd", Data([0xff, 0xfe]) + "#usda 1.0\n".data(using: .utf16LittleEndian)!, true),
      ("root.usd", Data("PXR-USDCsynthetic".utf8), false),
      ("root.usd", Data("unknown".utf8), false),
    ] {
      var payload = header
      payload.append(Data(repeating: 0, count: 16_777_217 - header.count))
      let bytes = try ArchiveRecipe(entries: [
        .init(
          nameBytes: Data(name.utf8),
          payload: payload, declaredCRC32: 1)
      ]).encode()
      let result = try inspect(bytes)
      XCTAssertEqual(
        result.findings.contains {
          $0.ruleID == "UVK-RES-001" && $0.evidence["resource"] == .string("textLayerBytes")
        }, capped)
      XCTAssertEqual(result.findings.contains { $0.ruleID == "UVK-ARC-003" }, !capped)
      XCTAssertFalse(result.findings.contains { $0.ruleID == "UVK-POL-001" })
      XCTAssertFalse(result.containerSafeForExternal)
      XCTAssertFalse(result.coverage.isComplete)
      XCTAssertEqual(result.coverage.areas[.byteBudgets]?.state, .complete)
      XCTAssertEqual(
        result.coverage.areas[.containerStructure]?.state, capped ? .partial : .complete)
    }
  }

  func testUnavailableWorkDoesNotEraseIndependentNonApplicableAreas() throws {
    let result = try inspect(
      ArchiveRecipe(entries: [
        layer("root.usda", "#usda 1.0\n"),
        .init(nameBytes: Data("sound.wav".utf8), payload: Data("compressed".utf8), method: 8),
      ]).encode())
    XCTAssertTrue(result.findings.contains { $0.ruleID == "UVK-ARC-004" })
    XCTAssertEqual(result.coverage.areas[.containerStructure]?.state, .partial)
    XCTAssertTrue(
      result.coverage.areas[.byteBudgets]?.reasons.contains {
        $0.ruleID == "UVK-ARC-004" && $0.reasonID == "storage"
      } == true)
    XCTAssertEqual(result.coverage.areas[.references]?.state, .complete)
    XCTAssertEqual(result.coverage.areas[.textureDimensions]?.state, .complete)
    XCTAssertFalse(result.containerSafeForExternal)
    let empty = try inspect(ArchiveRecipe(entries: []).encode())
    XCTAssertEqual(empty.findings.map(\.ruleID), ["UVK-POL-001"])
    XCTAssertEqual(empty.coverage.areas[.references]?.state, .notRun)
  }

  func testSafeMetadataNamesAreAvailableWithoutChangingIdentityOrUnsafeDisclosure() throws {
    let configuration = try ValidationConfiguration(
      profile: .applePortableV1,
      budgets: WarningBudgets(fileBytes: 1, textureBytes: 1))
    let safe = try inspect(
      ArchiveRecipe(entries: [
        layer("root.usda", "#usda 1.0\n"),
        layer("lighting.exr", "bytes"),
      ]).encode(), configuration: configuration)
    XCTAssertEqual(
      safe.findings.first { $0.ruleID == "UVK-BUD-004" }?.location?.entryName, "lighting.exr")
    XCTAssertEqual(
      safe.findings.first { $0.ruleID == "UVK-APL-001" }?.location?.entryName, "root.usda")
    let unsafe = try inspect(
      ArchiveRecipe(entries: [
        layer("root.usda", "#usda 1.0\n"),
        layer("../lighting.exr", "bytes"),
      ]).encode(), configuration: configuration)
    XCTAssertTrue(unsafe.findings.allSatisfy { $0.location?.entryName == nil })
    XCTAssertTrue(
      unsafe.coverage.areas.values.flatMap(\.reasons).allSatisfy { $0.location?.entryName == nil })
  }

  func testSafeIntegrityNamesAndReasonsNeverEnrichUnsafeNamespace() throws {
    for entry in [
      ArchiveRecipe.Entry(
        nameBytes: Data("root.usda".utf8), payload: Data("#usda 1.0\n".utf8), declaredCRC32: 1),
      ArchiveRecipe.Entry(
        nameBytes: Data("root.usda".utf8), payload: Data("#usda 1.0\n".utf8), flags: 1),
    ] {
      let result = try inspect(ArchiveRecipe(entries: [entry]).encode())
      let rule = entry.flags == 1 ? "UVK-ARC-005" : "UVK-ARC-003"
      XCTAssertEqual(result.findings.first { $0.ruleID == rule }?.location?.entryName, "root.usda")
      XCTAssertEqual(
        result.coverage.areas[.references]?.reasons.first { $0.ruleID == rule }?.location?
          .entryName, "root.usda")
      var unsafeEntry = entry
      unsafeEntry.nameBytes = Data("../root.usda".utf8)
      let unsafe = try inspect(ArchiveRecipe(entries: [unsafeEntry]).encode())
      XCTAssertTrue(unsafe.findings.allSatisfy { $0.location?.entryName == nil })
      XCTAssertTrue(
        unsafe.coverage.areas.values.flatMap(\.reasons).allSatisfy { $0.location?.entryName == nil }
      )
    }
  }

  func testTruncatedIntegrityNeverInventsDefaultRecognitionFailure() throws {
    let rootSource = Data("#usda 1.0\n".utf8)
    var entries: [ArchiveRecipe.Entry] = [
      .init(
        nameBytes: Data("root.usda".utf8),
        payload: rootSource, localExtra: paddingExtra(25))
    ]
    var cursor = 64 + rootSource.count
    for index in 0..<3_334 {
      let name = Data("sound\(index).wav".utf8)
      let fixedEnd = cursor + 30 + name.count
      var padding = (1 - fixedEnd % 64 + 64) % 64
      if padding < 4 { padding += 64 }
      entries.append(
        .init(
          nameBytes: name, payload: Data(), flags: 1, method: 8,
          localExtra: paddingExtra(padding)))
      cursor = fixedEnd + padding
    }
    let result = try inspect(ArchiveRecipe(entries: entries, alignment: 1).encode())
    XCTAssertEqual(result.findings.count, 10_000)
    XCTAssertFalse(
      result.coverage.areas.values.flatMap(\.reasons).contains { $0.ruleID == "UVK-POL-001" })
    XCTAssertFalse(result.containerSafeForExternal)
  }

  func testExternalEligibilitySeparatesUnsafeContentFromIndependentPolicy() throws {
    for source in ["#usda 1.0\n@missing.wav@", "#usda 1.0\n@broken", "#usda 1.0\n@<UDIM>.png@"] {
      let result = try inspect(ArchiveRecipe(entries: [layer("root.usda", source)]).encode())
      XCTAssertFalse(result.findings.isEmpty)
      XCTAssertTrue(result.containerSafeForExternal)
    }
    let nested = try inspect(
      ArchiveRecipe(entries: [
        layer("root.usda", "#usda 1.0\n"),
        layer("nested.usdz", "bounded nested data"),
      ]).encode())
    XCTAssertTrue(nested.containerSafeForExternal)
    for source in ["#usda 1.0\n@https://host/a@", "#usda 1.0\n@../../escape.png@"] {
      let result = try inspect(ArchiveRecipe(entries: [layer("root.usda", source)]).encode())
      XCTAssertFalse(result.containerSafeForExternal)
    }
  }

  func testDirectoryStorageMetadataAndUnknownTypesAreNotSkipped() throws {
    let compressedDirectory = try inspect(
      ArchiveRecipe(entries: [
        .init(nameBytes: Data("dir/".utf8), payload: Data(), type: .directory, method: 8),
        layer("root.usda", "#usda 1.0\n"),
      ]).encode())
    XCTAssertTrue(compressedDirectory.findings.contains { $0.ruleID == "UVK-ARC-004" })
    XCTAssertFalse(compressedDirectory.containerSafeForExternal)
    let unknown = try inspect(
      ArchiveRecipe(entries: [
        .init(
          nameBytes: Data("unknown.exr".utf8), payload: Data("bytes".utf8),
          centralHeaderPatches: [.uint16(at: 4, 0x0b14)]),
        layer("later.usda", "#usda 1.0\n@missing.png@"),
      ]).encode(), configuration: lowBudgets())
    XCTAssertFalse(
      unknown.findings.contains {
        $0.ruleID == "UVK-POL-001" || $0.ruleID == "UVK-PATH-006" || $0.ruleID == "UVK-BUD-004"
      })
    XCTAssertFalse(unknown.containerSafeForExternal)
    XCTAssertEqual(unknown.coverage.areas[.byteBudgets]?.state, .partial)
  }

  func testOversizedTextRetainsAlignmentWithoutReadingCRC() throws {
    let bytes = try ArchiveRecipe(
      entries: [
        .init(
          nameBytes: Data("root.usda".utf8),
          payload: Data(repeating: 0, count: 16_777_217), declaredCRC32: 1)
      ], alignment: 1
    ).encode()
    let result = try inspect(bytes)
    XCTAssertTrue(result.findings.contains { $0.ruleID == "UVK-ARC-006" })
    XCTAssertTrue(result.findings.contains { $0.ruleID == "UVK-RES-001" })
    XCTAssertFalse(result.findings.contains { $0.ruleID == "UVK-ARC-003" })
    XCTAssertFalse(result.containerSafeForExternal)
  }

  func testUnsafeNamespaceRetainsEstablishedStorageMetadataWithoutContentScans() throws {
    let bytes = try ArchiveRecipe(
      entries: [
        .init(
          nameBytes: Data("root.usda".utf8), payload: Data("#usda 1.0\n@missing.png@".utf8),
          method: 8),
        layer("../unsafe.png", "not a PNG"),
      ], alignment: 1
    ).encode()
    let result = try inspect(bytes)
    XCTAssertTrue(result.findings.contains { $0.ruleID == "UVK-ARC-004" })
    XCTAssertTrue(result.findings.contains { $0.ruleID == "UVK-ARC-006" })
    XCTAssertTrue(result.findings.contains { $0.ruleID == "UVK-PATH-001" })
    XCTAssertFalse(
      result.findings.contains { $0.ruleID == "UVK-PATH-006" || $0.ruleID == "UVK-BUD-007" })
    XCTAssertTrue(result.findings.allSatisfy { $0.location?.entryName == nil })
  }

  func testFindingCapStopsFurtherReadsAndLaterContent() throws {
    // 9,998 conclusive alignment errors use no reference reasons. Three unsafe
    // literals hit the findings ceiling inside the first lexer chunk. The invalid
    // UTF-8 byte in the next lexer chunk and malformed later lexical scan must
    // remain unavailable after the cap; integrity/header reads occurred earlier.
    var source = Data("#usda 1.0\n@/x@ @/x@ @/x@ ".utf8)
    source.append(Data(repeating: 0x20, count: 65_536 - source.count))
    source.append(0xff)
    var entries: [ArchiveRecipe.Entry] = [
      .init(
        nameBytes: Data("root.usda".utf8),
        payload: source, localExtra: paddingExtra(25))
    ]
    var cursor = 64 + source.count
    for index in 0..<9_998 {
      let name = Data("sound\(index).wav".utf8)
      let fixedEnd = cursor + 30 + name.count
      var padding = (1 - fixedEnd % 64 + 64) % 64
      if padding < 4 { padding += 64 }
      entries.append(.init(nameBytes: name, payload: Data(), localExtra: paddingExtra(padding)))
      cursor = fixedEnd + padding
    }
    let laterName = Data("later.usda".utf8)
    let laterFixedEnd = cursor + 30 + laterName.count
    var laterPadding = (64 - laterFixedEnd % 64) % 64
    if laterPadding < 4 { laterPadding += 64 }
    entries.append(
      .init(
        nameBytes: laterName, payload: Data("#usda 1.0\n@broken".utf8),
        localExtra: paddingExtra(laterPadding)))
    let bytes = try ArchiveRecipe(entries: entries, alignment: 1).encode()
    let result = try inspect(bytes)
    let repeated = try inspect(bytes)
    XCTAssertEqual(result.findings.count, 10_000)
    XCTAssertEqual(result.findings.filter { $0.ruleID == "UVK-RES-001" }.count, 1)
    XCTAssertEqual(
      result.findings.first { $0.ruleID == "UVK-RES-001" }?.evidence["resource"],
      .string("findings"))
    let reasons = result.coverage.areas.values.flatMap(\.reasons)
    XCTAssertFalse(
      reasons.contains { $0.reasonID == "textEncoding" || $0.reasonID == "malformedAssetLiteral" })
    XCTAssertTrue(reasons.contains { $0.reasonID == "findings" })
    XCTAssertEqual(result.findings, repeated.findings)
    XCTAssertEqual(result.coverage, repeated.coverage)
    XCTAssertFalse(result.containerSafeForExternal)
  }

  private func paddingExtra(_ length: Int) -> Data {
    Data([0x86, 0x19, UInt8(length - 4), 0]) + Data(repeating: 0, count: length - 4)
  }

  private func layer(_ name: String, _ source: String) -> ArchiveRecipe.Entry {
    .init(nameBytes: Data(name.utf8), payload: Data(source.utf8))
  }

  private func lowBudgets(dimensions: Int64? = 4096) throws -> ValidationConfiguration {
    try ValidationConfiguration(
      budgets: WarningBudgets(
        archiveBytes: 1, fileBytes: 1, fileCount: 1,
        textureBytes: 1, totalTextureBytes: 1, textureMaxDimension: dimensions))
  }

  private func inspect(
    _ bytes: Data, basename: String = "input.usdz",
    configuration: ValidationConfiguration? = nil
  ) throws -> NativeResult {
    let directory = try temporaryDirectory()
    let url = try Fixtures.write(bytes, basename: basename, in: directory)
    let snapshot = try FileSnapshot.open(url)
    defer { try? snapshot.close() }
    return try NativeEngine.inspect(
      snapshot: snapshot, configuration: configuration ?? ValidationConfiguration())
  }

  private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    addTeardownBlock { try FileManager.default.removeItem(at: url) }
    return url
  }
}

import Foundation
import XCTest

@testable import USDZValidation

final class ResourceLedgerTests: XCTestCase {
  func testEveryCounterBoundary() throws {
    let boundaries: [(SafetyResource, UInt64)] = [
      (.archiveBytes, 536_870_912), (.aggregateEntryBytes, 536_870_912),
      (.entryBytes, 268_435_456), (.centralDirectoryBytes, 16_777_216),
      (.textLayerBytes, 16_777_216), (.entryCount, 10_000),
      (.entryNameBytes, 4_096), (.tokenBytes, 4_096), (.tokenCount, 100_000),
      (.readChunkBytes, 65_536), (.textureHeaderBytes, 1_048_576),
      (.totalReadBytes, 1_207_959_552), (.findings, 10_000),
      (.messageBytes, 1_024), (.evidenceStringBytes, 4_096),
      (.configurationBytes, 65_536), (.reportBytes, 33_554_432),
    ]
    let ledger = ResourceLedger()
    XCTAssertEqual(boundaries.count, SafetyResource.allCases.count)
    for (resource, boundary) in boundaries {
      XCTAssertNoThrow(try ledger.check(resource: resource, value: boundary), "\(resource)")
      XCTAssertThrowsError(try ledger.check(resource: resource, value: boundary + 1)) { error in
        XCTAssertEqual(error as? InspectionFailure, .resourceLimit(resource))
      }
      XCTAssertThrowsError(try ledger.check(resource: resource, value: .max))
    }
    try ledger.consumeTokens(99_999)
    try ledger.consumeTokens(1)
    XCTAssertThrowsError(try ledger.consumeTokens(1)) { error in
      XCTAssertEqual(error as? InspectionFailure, .resourceLimit(.tokenCount))
    }
    XCTAssertThrowsError(try ledger.consumeTokens(.max))
    XCTAssertNoThrow(try ledger.consumeTokens(0))
    try ledger.consumeRead(1_207_959_552)
    XCTAssertThrowsError(try ledger.consumeRead(.max)) { error in
      XCTAssertEqual(error as? InspectionFailure, .resourceLimit(.totalReadBytes))
    }
    XCTAssertEqual(ledger.totalReadBytes, 1_207_959_552)
  }

  func testFindingCap() {
    let diagnostics = NativeDiagnostics()
    let first = key(0)
    for _ in 0..<10_001 {
      diagnostics.emit(
        ruleID: first.ruleID, message: "Repeated", evidence: [:], location: nil, key: first)
    }
    XCTAssertEqual(diagnostics.finish().0.count, 1)
    for offset in 1..<10_000 {
      emit(UInt64(offset), to: diagnostics)
    }
    let atBoundary = diagnostics.finish().0
    XCTAssertEqual(atBoundary.count, 10_000)
    XCTAssertFalse(atBoundary.contains { $0.ruleID == "UVK-RES-001" })
    emit(10_000, to: diagnostics)
    let (findings, coverage) = diagnostics.finish()
    XCTAssertEqual(findings.count, 10_000)
    XCTAssertEqual(findings.filter { $0.ruleID == "UVK-RES-001" }.count, 1)
    let retained = Set(findings.filter { $0.ruleID != "UVK-RES-001" }.map(\.occurrenceID))
    XCTAssertEqual(retained, Set(atBoundary.prefix(9_999).map(\.occurrenceID)))
    XCTAssertEqual(findings.first?.occurrenceID, atBoundary.first?.occurrenceID)
    XCTAssertFalse(coverage.isComplete)
    for area in CoverageArea.allCases where area != .appleAdvice {
      XCTAssertEqual(coverage.areas[area]?.state, .partial)
      XCTAssertTrue(coverage.areas[area]?.reasons.contains { $0.ruleID == "UVK-RES-001" } == true)
    }
    for offset in 10_001..<10_101 { emit(UInt64(offset), to: diagnostics) }
    XCTAssertEqual(diagnostics.finish().0, findings)
  }

  func testExactIdentitiesAndRawOrdering() {
    let diagnostics = NativeDiagnostics()
    let rawNames = [Data("\u{00e9}".utf8), Data("e\u{0301}".utf8)]
    for name in rawNames {
      for entry: UInt64 in [20, 10] {
        for token: UInt64 in [2, 1] {
          let identity = FindingKey(
            ruleID: "UVK-PATH-006", entryNameBytes: name, entryOffset: entry,
            contentOffset: token, discriminator: "asset")
          for message in ["First", "Different display"] {
            diagnostics.emit(
              ruleID: identity.ruleID, message: message, evidence: [:],
              location: FindingLocation(entryName: "[redacted]"), key: identity)
          }
        }
      }
    }
    let findings = diagnostics.finish().0
    XCTAssertEqual(findings.count, 8)
    let orderedNames = [rawNames[1], rawNames[0]]
    let expected = orderedNames.flatMap { name in
      [UInt64(10), 20].flatMap { entry in
        [UInt64(1), 2].map { token in
          FindingIdentity.native(
            FindingKey(
              ruleID: "UVK-PATH-006", entryNameBytes: name,
              entryOffset: entry, contentOffset: token, discriminator: "asset"))
        }
      }
    }
    XCTAssertEqual(findings.map(\.occurrenceID), expected)
    XCTAssertTrue(findings.allSatisfy { $0.message == "First" })
    for discriminator in ["e\u{0301}", "\u{00e9}"] {
      let identity = FindingKey(
        ruleID: "UVK-PATH-006", entryNameBytes: nil, entryOffset: nil,
        contentOffset: nil, discriminator: discriminator)
      diagnostics.emit(
        ruleID: identity.ruleID, message: "Distinct discriminator", evidence: [:],
        location: nil, key: identity)
    }
    XCTAssertEqual(diagnostics.finish().0.count, 10)
  }

  func testCoverageReasonsAreBoundedAndDeduplicated() {
    let diagnostics = NativeDiagnostics()
    for area in CoverageArea.allCases where area != .appleAdvice {
      diagnostics.mark(
        area: area, state: .complete,
        reason: CoverageReason(ruleID: "UVK-LIM-003", reasonID: "initial"))
    }
    XCTAssertTrue(diagnostics.finish().1.isComplete)
    let reason = CoverageReason(ruleID: "UVK-LIM-003", reasonID: "expression")
    for _ in 0..<10_001 { diagnostics.mark(area: .references, state: .partial, reason: reason) }
    XCTAssertEqual(diagnostics.finish().1.areas[.references]?.reasons.count, 2)
    for offset in 0..<10_001 {
      diagnostics.mark(
        area: .references, state: .partial,
        reason: CoverageReason(
          ruleID: "UVK-LIM-003", reasonID: "expression",
          location: FindingLocation(layerByteOffset: UInt64(offset))))
    }
    let (findings, coverage) = diagnostics.finish()
    XCTAssertLessThanOrEqual(coverage.areas.values.reduce(0) { $0 + $1.reasons.count }, 10_000)
    XCTAssertTrue(findings.contains { $0.ruleID == "UVK-RES-001" })
    XCTAssertFalse(coverage.isComplete)
    diagnostics.mark(area: .references, state: .complete, reason: reason)
    XCTAssertEqual(diagnostics.finish().1.areas[.references]?.state, .partial)
  }

  func testResourceCoverageAndSelection() {
    let diagnostics = NativeDiagnostics(
      profile: .generalV1, byteBudgetsRequested: false,
      textureDimensionsRequested: false)
    for area in [CoverageArea.containerStructure, .entrySafety, .references] {
      diagnostics.mark(
        area: area, state: .complete,
        reason: CoverageReason(ruleID: "UVK-ARC-001", reasonID: "checked"))
    }
    XCTAssertTrue(diagnostics.finish().1.isComplete)
    diagnostics.limit(.tokenCount, location: FindingLocation(layerByteOffset: 11))
    diagnostics.limit(.tokenCount, location: FindingLocation(layerByteOffset: 11))
    let (findings, coverage) = diagnostics.finish()
    XCTAssertEqual(findings.count, 1)
    XCTAssertEqual(findings.first?.ruleID, "UVK-RES-001")
    XCTAssertEqual(findings.first?.severity, .error)
    XCTAssertEqual(coverage.areas[.references]?.state, .partial)
    XCTAssertEqual(coverage.areas[.containerStructure]?.state, .complete)
    for area in [CoverageArea.byteBudgets, .textureDimensions, .appleAdvice] {
      XCTAssertEqual(coverage.areas[area]?.requested, false)
      XCTAssertEqual(coverage.areas[area]?.state, .notRun)
    }
    XCTAssertEqual(
      NativeDiagnostics(profile: .applePortableV1).finish().1.areas[.appleAdvice]?.requested, true)
  }

  func testRetainedTextIsBoundedWithoutSplittingUnicode() {
    let diagnostics = NativeDiagnostics()
    let oversized = String(repeating: "🦊", count: 2_000)
    diagnostics.emit(
      ruleID: "UVK-PATH-006", message: oversized,
      evidence: ["path": .string(oversized), "count": .integer(2)],
      location: FindingLocation(entryName: oversized), key: key(1))
    let finding = diagnostics.finish().0.first
    XCTAssertNotNil(finding)
    XCTAssertLessThanOrEqual(finding?.message.utf8.count ?? Int.max, 1_024)
    XCTAssertTrue(finding?.message.hasSuffix("[truncated]") == true)
    if case .string(let value) = finding?.evidence["path"] {
      XCTAssertLessThanOrEqual(value.utf8.count, 4_096)
      XCTAssertTrue(value.hasSuffix("[truncated]"))
    } else {
      XCTFail("Missing bounded evidence")
    }
    XCTAssertLessThanOrEqual(finding?.location?.entryName?.utf8.count ?? Int.max, 4_096)
    XCTAssertEqual(finding?.evidence["count"], .integer(2))
  }

  private func key(_ offset: UInt64) -> FindingKey {
    FindingKey(
      ruleID: "UVK-PATH-006", entryNameBytes: Data("root.usda".utf8), entryOffset: 0,
      contentOffset: offset, discriminator: "asset")
  }

  private func emit(_ offset: UInt64, to diagnostics: NativeDiagnostics) {
    let identity = key(offset)
    diagnostics.emit(
      ruleID: identity.ruleID, message: "Missing", evidence: [:], location: nil, key: identity)
  }
}

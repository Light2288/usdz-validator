import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

final class USDCResourceTests: XCTestCase {
  // A released working allocation must not refund cumulative decode, work or occurrence costs.
  func testLiveReservationsReleaseWithoutRefundingCumulativeCounters() throws {
    let ledger = ResourceLedger()
    try ledger.reserveUSDCDecode(16_777_216)
    try ledger.reserveUSDCDecode(16_777_216)
    try ledger.consumeUSDCWork(1_999_999)
    try ledger.consumeUSDCWork(1)
    try ledger.consumeTokens(100_000)
    var reservation: USDCStorageReservation? = try ledger.reserveUSDCStorage(67_108_864)
    XCTAssertEqual(ledger.usdcLiveBytes, 67_108_864)
    XCTAssertThrowsError(try ledger.reserveUSDCStorage(1)) {
      XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcWorkingBytes))
    }
    XCTAssertThrowsError(try ledger.reserveUSDCStorage(.max)) {
      XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcWorkingBytes))
    }
    XCTAssertEqual(ledger.usdcLiveBytes, 67_108_864)
    reservation?.release()
    reservation?.release()
    reservation = nil
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
    XCTAssertEqual(ledger.usdcDecodeBytes, 33_554_432)
    XCTAssertEqual(ledger.usdcWorkUnits, 2_000_000)
    for amount: UInt64 in [1, .max] {
      XCTAssertThrowsError(try ledger.reserveUSDCDecode(amount)) {
        XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcDecodeBytes))
      }
      XCTAssertThrowsError(try ledger.consumeUSDCWork(amount)) {
        XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcWork))
      }
      XCTAssertThrowsError(try ledger.consumeTokens(amount)) {
        XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.tokenCount))
      }
    }
    XCTAssertEqual(ledger.usdcDecodeBytes, 33_554_432)
    XCTAssertEqual(ledger.usdcWorkUnits, 2_000_000)
    XCTAssertNoThrow(try ledger.reserveUSDCDecode(0))
    XCTAssertNoThrow(try ledger.consumeUSDCWork(0))
    do {
      let live = try ledger.reserveUSDCStorage(17)
      XCTAssertEqual(ledger.usdcLiveBytes, 17)
      withExtendedLifetime(live) {}
    }
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
  }

  // Untrusted sizes must be rejected before reaching the allocator, including overflow.
  func testReservationsPrecedeAllocationAndReleaseOnThrow() throws {
    let ledger = ResourceLedger()
    var allocationCalls = 0
    for bytes: UInt64 in [67_108_865, UInt64(Int.max) + 1, .max] {
      XCTAssertThrowsError(
        try USDCStorage.allocate(byteCount: bytes, ledger: ledger) { count in
          allocationCalls += 1
          return UnsafeMutableRawPointer.allocate(byteCount: count, alignment: 16)
        }
      ) {
        XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcWorkingBytes))
      }
    }
    XCTAssertEqual(allocationCalls, 0)
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
    enum Stop: Error { case sentinel }
    XCTAssertThrowsError(
      try USDCStorage.allocate(byteCount: 7, ledger: ledger) { _ in
        allocationCalls += 1
        XCTAssertEqual(ledger.usdcLiveBytes, 7)
        throw Stop.sentinel
      }
    ) { XCTAssertTrue($0 is Stop) }
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
    XCTAssertThrowsError(
      try {
        let storage = try USDCStorage.allocate(byteCount: 7, ledger: ledger)
        try storage.withUnsafeMutableBytes { _ in throw Stop.sentinel }
      }()
    ) { XCTAssertTrue($0 is Stop) }
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
  }

  // Capacity is not initialized content; invalid writes cannot expose uninitialized bytes.
  func testStorageBorrowsOnlyInitializedBytesAndReleasesOwnedCapacity() throws {
    let ledger = ResourceLedger()
    do {
      let storage = try USDCStorage.allocate(byteCount: 8, ledger: ledger)
      XCTAssertEqual(storage.capacity, 8)
      XCTAssertEqual(storage.count, 0)
      storage.withUnsafeBytes { XCTAssertEqual($0.count, 0) }
      try storage.withUnsafeMutableBytes { bytes in
        XCTAssertEqual(bytes.count, 8)
        bytes[0] = 0x41
        bytes[1] = 0x42
        return 2
      }
      XCTAssertEqual(storage.count, 2)
      storage.withUnsafeBytes { XCTAssertEqual(Array($0), [0x41, 0x42]) }
      for invalidCount in [-1, 9] {
        XCTAssertThrowsError(try storage.withUnsafeMutableBytes { _ in invalidCount }) {
          XCTAssertEqual($0 as? USDCFailure, .malformed(.invalidRange))
        }
        XCTAssertEqual(storage.count, 2)
      }
      XCTAssertEqual(ledger.usdcLiveBytes, 8)
    }
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
    let empty = try USDCStorage.allocate(byteCount: 0, ledger: ledger)
    XCTAssertEqual(empty.capacity, 0)
    try empty.withUnsafeMutableBytes {
      XCTAssertEqual($0.count, 0)
      return 0
    }
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
  }

  // Overflow and oversized tables must never wrap to a cheap allocation.
  func testCheckedTableByteCountsRejectOverflowAndItemExcess() throws {
    XCTAssertEqual(try USDCStorage.checkedByteCount(count: 250_000, stride: 16), 4_000_000)
    XCTAssertEqual(try USDCStorage.checkedByteCount(count: 1, stride: 67_108_864), 67_108_864)
    for (count, stride, resource): (UInt64, UInt64, SafetyResource) in [
      (250_001, 1, .usdcItems), (2, .max, .usdcWorkingBytes),
      (1, 67_108_865, .usdcWorkingBytes), (1, UInt64(Int.max) + 1, .usdcWorkingBytes),
    ] {
      XCTAssertThrowsError(try USDCStorage.checkedByteCount(count: count, stride: stride)) {
        XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(resource))
      }
    }
  }

  // USDC ceilings stop reference coverage without contaminating unrelated native areas.
  func testUSDCLimitsMarkOnlyReferenceCoveragePartial() {
    for resource: SafetyResource in [
      .usdcMetadataBlockBytes, .usdcDecodeBytes, .usdcWorkingBytes,
      .usdcItems, .usdcWork, .usdcDepth,
    ] {
      let diagnostics = NativeDiagnostics()
      for area in CoverageArea.allCases { diagnostics.complete(area: area) }
      diagnostics.limit(resource, location: nil)
      let (findings, coverage) = diagnostics.finish()
      XCTAssertEqual(findings.count, 1)
      XCTAssertEqual(findings[0].ruleID, "UVK-RES-001")
      XCTAssertEqual(coverage.areas[.references]?.state, .partial)
      XCTAssertEqual(coverage.areas[.containerStructure]?.state, .complete)
      XCTAssertEqual(coverage.areas[.entrySafety]?.state, .complete)
    }
  }
}

extension USDCResourceTests {
  // Resetting an invocation counter between layers, charging UTF-8 scalars instead of bytes,
  // or retaining scanner storage after a success/error must break this integration boundary.
  func testCrossLayerAndUTF8Boundaries() throws {
    let ledger = ResourceLedger()
    let retained = try ledger.reserveUSDCStorage(17)
    defer { retained.release() }
    let baselineLiveBytes: UInt64 = 17
    var forbiddenAllocations = 0
    for length in [4_096, 4_097] {
      let value = String(repeating: "é", count: length / 2) + (length % 2 == 1 ? "a" : "")
      let crate = try USDCMutationRecipe.valueCrate(
        reps: [0x400c_0000_0000_0002], tokens: ["/", "default", value, ""])
      let input = USDCReferenceTests.input(crate, ledger: ledger)
      var emitted = 0
      do {
        _ = try USDCReader.scan(
          entry: input.entry, reader: input.reader,
          onReference: {
            emitted += 1
            if $0.valueBytes.count > 4_096 { forbiddenAllocations += 1 }
          }, onIssue: { _ in XCTFail("valid structure") })
        XCTAssertEqual(length, 4_096)
      } catch {
        XCTAssertEqual(error as? InspectionFailure, .resourceLimit(.tokenBytes))
        XCTAssertEqual(length, 4_097)
      }
      XCTAssertEqual(emitted, length == 4_096 ? 1 : 0)
      XCTAssertEqual(forbiddenAllocations, 0)
      XCTAssertEqual(ledger.usdcLiveBytes, baselineLiveBytes)
    }
    XCTAssertGreaterThan(ledger.usdcDecodeBytes, 0)
    XCTAssertGreaterThan(ledger.usdcWorkUnits, 0)

    // The first text token and the following binary token share exactly 100,000 slots.
    let mixed = ResourceLedger()
    try mixed.consumeTokens(99_998)
    let text = USDCReferenceTests.input(Data("@a.png@".utf8), ledger: mixed)
    let diagnostics = NativeDiagnostics()
    var textCount = 0
    try USDALexer.scan(entry: text.entry, reader: text.reader, diagnostics: diagnostics) { _ in
      textCount += 1
    }
    XCTAssertEqual(textCount, 1)
    let binary = try USDCMutationRecipe.valueCrate(reps: [0x400c_0000_0000_0002])
    XCTAssertEqual(try USDCReferenceTests.scan(binary, ledger: mixed).references.count, 1)
    XCTAssertThrowsError(try USDCReferenceTests.scan(binary, ledger: mixed)) {
      XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.tokenCount))
    }
    XCTAssertEqual(mixed.usdcLiveBytes, 0)

    // Highly compressed token metadata is accepted per block but accumulates across layers.
    let expanded = try USDCMutationRecipe.expandedTokenCrate(capacity: 16_777_216)
    let aggregate = ResourceLedger()
    XCTAssertEqual(try USDCReferenceTests.scan(expanded, ledger: aggregate).state, .complete)
    XCTAssertEqual(aggregate.usdcLiveBytes, 0)
    XCTAssertThrowsError(try USDCReferenceTests.scan(expanded, ledger: aggregate)) {
      XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcDecodeBytes))
    }
    XCTAssertEqual(aggregate.usdcLiveBytes, 0)
    XCTAssertLessThanOrEqual(aggregate.usdcDecodeBytes, 33_554_432)
    let excessive = try USDCMutationRecipe.expandedTokenCrate(capacity: 16_777_217)
    XCTAssertThrowsError(try USDCReferenceTests.scan(excessive)) {
      XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcMetadataBlockBytes))
    }

    // Every repeated numeric array edge counts, even when the body is shared and skipped.
    let fanout = try USDCMutationRecipe.valueCrate(
      reps: Array(repeating: 0x8003_0000_0000_0058, count: 8),
      body: USDCReferenceTests.word(250_000))
    let work = ResourceLedger()
    XCTAssertThrowsError(try USDCReferenceTests.scan(fanout, ledger: work)) {
      XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcWork))
    }
    XCTAssertEqual(work.usdcLiveBytes, 0)
    for count in [250_000, 250_001] {
      let bytes = try USDCMutationRecipe.valueCrate(
        reps: [0x8003_0000_0000_0058], body: USDCReferenceTests.word(UInt64(count)))
      if count == 250_000 {
        XCTAssertEqual(try USDCReferenceTests.scan(bytes).state, .complete)
      } else {
        XCTAssertThrowsError(try USDCReferenceTests.scan(bytes)) {
          XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcItems))
        }
      }
    }
    // Keep both 32/33-depth and shared-body identity checks in the focused resource suite.
    for depth in [32, 33] {
      let bytes = try USDCMutationRecipe.deepAssetCrate(depth: depth, sharedFields: 2)
      if depth == 32 {
        let result = try USDCReferenceTests.scan(bytes)
        XCTAssertEqual(result.references.count, 2)
        XCTAssertNotEqual(result.references[0].site, result.references[1].site)
      } else {
        XCTAssertThrowsError(try USDCReferenceTests.scan(bytes)) {
          XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcDepth))
        }
      }
    }
  }

  // A failed copy reservation or source read must return to an existing owner's baseline.
  func testFailurePathCopiesReleaseAndRejectBeforeAllocation() throws {
    let ledger = ResourceLedger()
    let retained = try ledger.reserveUSDCStorage(67_108_864)
    defer { retained.release() }
    let baselineLiveBytes = ledger.usdcLiveBytes
    var forbiddenAllocations = 0
    XCTAssertThrowsError(
      try USDCStorage.allocate(byteCount: 1, ledger: ledger) { count in
        forbiddenAllocations += 1
        return UnsafeMutableRawPointer.allocate(byteCount: count, alignment: 16)
      }
    ) { XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcWorkingBytes)) }
    let bytes = try USDCMutationRecipe.valueCrate(reps: [0x400c_0000_0000_0002])
    XCTAssertThrowsError(try USDCReferenceTests.scan(bytes, ledger: ledger)) {
      XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcWorkingBytes))
    }
    XCTAssertEqual(forbiddenAllocations, 0)
    XCTAssertEqual(ledger.usdcLiveBytes, baselineLiveBytes)
    XCTAssertEqual(ledger.totalReadBytes, 0)
    XCTAssertEqual(ledger.usdcDecodeBytes, 0)
  }
}

extension USDCResourceTests {
  // Checking only decoded size would allow an over-limit compressed staging allocation.
  // Literal-frame lengths are independently hand-calculated: n+3+floor((n-15)/255).
  func testCompressedBlockAtLimitAndOneByteBeyondPreflight() throws {
    for literalBytes in [16_711_678, 16_711_679] {
      let frame = try USDCMutationRecipe.literalFrame([Data(repeating: 0x61, count: literalBytes)])
      let expectedFrameBytes = literalBytes == 16_711_678 ? 16_777_216 : 16_777_217
      XCTAssertEqual(frame.count, expectedFrameBytes)
      let ledger = ResourceLedger()
      let source = USDCReferenceTests.input(frame, ledger: ledger)
      if expectedFrameBytes == 16_777_216 {
        do {
          let decoded = try USDCCompression.decode(
            input: source, range: 0..<UInt64(frame.count), decodedCapacity: UInt64(literalBytes))
          XCTAssertEqual(decoded.count, 16_711_678)
          XCTAssertTrue(decoded.withUnsafeBytes { $0.allSatisfy { $0 == 0x61 } })
          XCTAssertEqual(ledger.usdcLiveBytes, 16_711_678)
        }
        XCTAssertEqual(ledger.usdcDecodeBytes, 16_711_678)
        XCTAssertEqual(ledger.totalReadBytes, 16_777_216)
      } else {
        XCTAssertThrowsError(
          try USDCCompression.decode(
            input: source, range: 0..<UInt64(frame.count), decodedCapacity: UInt64(literalBytes))
        ) {
          XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcMetadataBlockBytes))
        }
        XCTAssertEqual(ledger.usdcDecodeBytes, 0)
        XCTAssertEqual(ledger.totalReadBytes, 0)
      }
      XCTAssertEqual(ledger.usdcLiveBytes, 0)
    }
  }
}

extension USDCResourceTests {
  // Refunding work or starting a new work ledger at scanner entry must lose these
  // literal invocation totals even though every individual layer fits its allowance.
  func testCrossLayerWorkReachesExactLimitWithoutRefunding() throws {
    // Hand-counted one-field numeric-array recipe: TOC 33, tokens 9, strings 4,
    // fields 5, fieldsets 7, paths 45, specs 10, live traversal/scratch 134 = 247.
    // Array elements add their declared count. No expected total comes from a scan.
    let layers: [(items: UInt64, cumulativeWork: UInt64)] = [
      (250_000, 250_247), (250_000, 500_494), (250_000, 750_741),
      (250_000, 1_000_988), (250_000, 1_251_235), (250_000, 1_501_482),
      (250_000, 1_751_729), (248_024, 2_000_000),
    ]
    let ledger = ResourceLedger()
    let retained = try ledger.reserveUSDCStorage(17)
    defer { retained.release() }
    let baselineLiveBytes: UInt64 = 17
    for (index, layer) in layers.enumerated() {
      let bytes = try USDCMutationRecipe.valueCrate(
        reps: [0x8003_0000_0000_0058], body: USDCReferenceTests.word(layer.items))
      let input = USDCReferenceTests.input(bytes, ledger: ledger)
      let state = try USDCReader.scan(
        entry: input.entry, reader: input.reader,
        onReference: { _ in XCTFail("Numeric arrays contain no asset values") },
        onIssue: { _ in XCTFail("Supported numeric-array structure") })
      XCTAssertEqual(state, .complete)
      XCTAssertEqual(ledger.usdcWorkUnits, layer.cumulativeWork, "layer \(index)")
      XCTAssertEqual(ledger.usdcLiveBytes, baselineLiveBytes, "layer \(index)")
    }
    XCTAssertThrowsError(try ledger.consumeUSDCWork(1)) {
      XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcWork))
    }
    XCTAssertEqual(ledger.usdcWorkUnits, 2_000_000)
    let nextBytes = try USDCMutationRecipe.valueCrate(reps: [])
    let next = USDCReferenceTests.input(nextBytes, ledger: ledger)
    XCTAssertThrowsError(
      try USDCReader.scan(
        entry: next.entry, reader: next.reader,
        onReference: { _ in XCTFail("Exhausted invocation must not emit") },
        onIssue: { _ in XCTFail("Work stops must propagate as typed resource failures") })
    ) {
      XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcWork))
    }
    XCTAssertEqual(ledger.usdcWorkUnits, 2_000_000)
    XCTAssertEqual(ledger.usdcLiveBytes, baselineLiveBytes)
  }
}

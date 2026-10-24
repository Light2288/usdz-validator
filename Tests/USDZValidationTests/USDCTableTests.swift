import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

final class USDCTableTests: XCTestCase {
  // Dropping live spec joins, accepting a different version, or reversing path parents loses authored sites.
  func testGenuineVersionsAndAuthoredStructuralJoins() throws {
    let cases = try USDCFixtures.cases()
    XCTAssertEqual(cases.count, 23)
    let specCounts = [
      "minimal": 7, "empty": 4, "listops": 14, "containers": 10,
      "unsafe": 3, "reference-customdata": 2, "payload-explicit-list": 2,
      "unregistered": 2, "unregistered-raw": 2, "tc09-scalars": 6,
      "tc09-arrays": 8, "tc09-empty": 5, "pe10-mixed": 8,
      "pe10-containers": 10, "pe10-empty": 6, "pe10-asset-expression": 4,
    ]
    for fixture in cases {
      let ledger = ResourceLedger()
      do {
        let tables = try USDCTables.read(input: input(fixture.crate, ledger: ledger))
        XCTAssertEqual(
          tables.version,
          USDCVersion(
            major: fixture.version[0], minor: fixture.version[1], patch: fixture.version[2]),
          fixture.id)
        let key = fixture.id.split(separator: "/")[1]
        XCTAssertEqual(tables.specCount, specCounts[String(key)], fixture.id)
        var sites = Set<String>()
        var specs = Set<UInt32>()
        try tables.forEachLiveField { field in
          specs.insert(field.specIndex)
          let name = try tables.withTokenBytes(at: field.nameTokenIndex) {
            String(decoding: $0, as: UTF8.self)
          }
          var parts: [String] = []
          var path: UInt32? = field.pathIndex
          while let current = path {
            let element = try tables.pathElement(at: current)
            let value = try tables.withTokenBytes(at: element.tokenIndex) {
              String(decoding: $0, as: UTF8.self)
            }
            parts.append(element.parentIndex == nil ? "/" : (element.isProperty ? "." : "") + value)
            path = element.parentIndex
          }
          sites.insert(parts.reversed().joined(separator: "|") + ":" + name)
        }
        XCTAssertEqual(specs.count, tables.specCount, fixture.id)
        for site in fixture.metadata.expectedSites {
          XCTAssertTrue(
            sites.contains(site.pathElements.joined(separator: "|") + ":" + site.field),
            "\(fixture.id): \(site.pathElements) \(site.field)")
        }
      }
      XCTAssertEqual(ledger.usdcLiveBytes, 0, fixture.id)
    }
  }

  // A token or field table scan would report an unreachable asset-looking value as live.
  func testDeadFieldAndUnusedAssetLookingTokenAreNotLive() throws {
    let originalLiveFields = try liveFields(crate())
    let mutatedLiveFields = try liveFields(
      crate(
        tokens: Data("/\0default\0dead.png\0".utf8), tokenCount: 3,
        names: [1, 2], reps: [0x400b_0000_0000_0000, 0x400b_0000_0000_0002]))
    XCTAssertEqual(mutatedLiveFields, originalLiveFields)
    XCTAssertEqual(originalLiveFields.count, 1)
    XCTAssertEqual(originalLiveFields.first?.fieldOrdinal, 0)
  }

  // Version acceptance is exact, including patch; a future header cannot be positive evidence.
  func testPatchFutureAndMajorVersionsAreUnsupported() throws {
    for version: [UInt8] in [
      [0, 8, 1], [0, 9, 1], [0, 10, 1], [0, 11, 0], [1, 8, 0], [0, 7, 0],
    ] {
      let bytes = try USDCMutationRecipe.patch(crate(), at: 8, bytes: Data(version))
      try fails(bytes, .unsupported(.unsupportedVersion))
    }
    try fails(
      try USDCMutationRecipe.patch(crate(), at: 0, bytes: Data([0])), .malformed(.invalidHeader))
  }

  // Forged TOC extents/aliases must fail before following a section pointer or allocating a table.
  func testTOCCountsRangesDuplicatesAndRequiredSections() throws {
    let bytes = try crate()
    let toc = Int(read(bytes, 16, 8))
    try fails(
      try USDCMutationRecipe.patch(bytes, at: 16, bytes: word(.max)), .malformed(.invalidSection))
    try fails(
      try USDCMutationRecipe.patch(bytes, at: toc + 8 + 16, bytes: word(.max)),
      .malformed(.invalidSection))
    try fails(
      try USDCMutationRecipe.patch(bytes, at: toc + 8 + 24, bytes: word(.max)),
      .malformed(.invalidSection))
    try fails(
      try USDCMutationRecipe.patch(bytes, at: toc + 8 + 32, bytes: name("TOKENS")),
      .malformed(.invalidSection))
    try fails(
      try USDCMutationRecipe.patch(bytes, at: toc + 8, bytes: name("EXTRA")),
      .unsupported(.unsupportedSection))
    let ledger = ResourceLedger()
    let excessive = try USDCMutationRecipe.patch(bytes, at: toc, bytes: word(250_001))
    XCTAssertThrowsError(try USDCTables.read(input: input(excessive, ledger: ledger))) {
      XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcItems))
    }
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
    // Unrelated, correctly ranged sections need no semantic interpretation.
    XCTAssertEqual(try liveFields(crate(extraSection: true)).count, 1)
  }

  // Invalid UTF-8, unterminated token data, wrong counts, and truncated integer streams are proven malformed.
  func testTokenAndIntegerEncodingInvariants() throws {
    for invalidUTF8: [UInt8] in [
      [0xff], [0xc0, 0x80], [0xe0, 0x80, 0x80], [0xed, 0xa0, 0x80],
      [0xf0, 0x80, 0x80, 0x80], [0xf4, 0x90, 0x80, 0x80], [0xe2, 0x82],
    ] {
      try fails(
        crate(tokens: Data(invalidUTF8) + Data([0, 100, 0]), tokenCount: 2),
        .malformed(.invalidTable))
    }
    XCTAssertEqual(
      try liveFields(crate(tokens: Data("/\0default\0🪁\0".utf8), tokenCount: 3)).count, 1)
    try fails(crate(tokens: Data("/\0default".utf8)), .malformed(.invalidTable))
    try fails(crate(tokenCount: 3), .malformed(.invalidTable))
    try fails(crate(fieldNameEncoding: Data([0, 0, 0, 0])), .malformed(.invalidTable))
    try fails(crate(fieldNameEncoding: Data([0, 0, 0, 0, 3, 1])), .malformed(.invalidTable))
    try fails(crate(fieldNameEncoding: Data([0, 0, 0, 0, 0, 0])), .malformed(.invalidTable))
    try fails(crate(reps: []), .malformed(.invalidTable))
    let tables = try USDCTables.read(input: input(crate(), ledger: ResourceLedger()))
    XCTAssertThrowsError(try tables.withTokenBytes(at: 2) { _ in }) {
      XCTAssertEqual($0 as? USDCFailure, .malformed(.invalidIndex))
    }
    XCTAssertThrowsError(try tables.withStringBytes(at: 1) { _ in }) {
      XCTAssertEqual($0 as? USDCFailure, .malformed(.invalidIndex))
    }
    XCTAssertEqual(try tables.withStringBytes(at: 0) { Array($0) }, Array("default".utf8))
  }

  // Wrong signed extension, delta carry, width selection or count handling changes these literal values.
  func testPinnedIntegerWidthsSignedDeltasAndEmptyCount() throws {
    let vectors: [(Data, [UInt32])] = [
      // The seven-integer example documented in pinned integerCoding.cpp.
      (
        Data([1, 0, 0, 0, 0xc1, 0x11, 123, 0xa0, 0x86, 1, 0, 0, 0]),
        [123, 124, 125, 100125, 100125, 100126, 100126]
      ),
      (
        Data([0, 0, 0, 0, 0x1a, 0x90, 1, 0xe0, 0xfc, 1]),
        [400, 0xffff_fe70, 0xffff_fe71]
      ),
      (Data([0xff, 0xff, 0xff, 0xff, 0]), [0xffff_ffff]),
      (Data(), []),
    ]
    for (raw, expected) in vectors {
      let frame = try USDCMutationRecipe.literalFrame([raw])
      let bytes = word(UInt64(frame.count)) + frame
      let ledger = ResourceLedger()
      do {
        var cursor = USDCByteCursor(
          input: input(bytes, ledger: ledger), range: 0..<UInt64(bytes.count))
        let table = try USDCIntegers.read(cursor: &cursor, count: UInt64(expected.count))
        XCTAssertEqual((0..<table.count).map { UInt32(table.word($0)) }, expected)
        try cursor.requireEnd()
      }
      XCTAssertEqual(ledger.usdcLiveBytes, 0)
    }
  }

  // Shared fieldsets retain each spec occurrence in file order, and a consumer's stop is propagated.
  func testSharedFieldsetsPreserveSpecOrderAndConsumerErrors() throws {
    let tables = try USDCTables.read(
      input: input(
        crate(
          pathCount: 2, pathIndices: [0, 1],
          pathTokens: [0, 1], jumps: [-1, -2], specPaths: [1, 0], specSets: [0, 0],
          specTypes: [1, 7]),
        ledger: ResourceLedger()))
    var fields: [USDCLiveField] = []
    try tables.forEachLiveField { fields.append($0) }
    XCTAssertEqual(fields.map(\.specIndex), [0, 1])
    XCTAssertEqual(fields.map(\.pathIndex), [1, 0])
    XCTAssertEqual(fields.map(\.fieldIndex), [0, 0])
    XCTAssertEqual(fields.map(\.fieldOrdinal), [0, 0])
    enum ConsumerStop: Error { case stop }
    XCTAssertThrowsError(try tables.forEachLiveField { _ in throw ConsumerStop.stop }) {
      XCTAssertTrue($0 is ConsumerStop)
    }
    let empty = try crate(
      tokens: Data(), tokenCount: 0, strings: [], names: [], reps: [], fieldsets: [],
      pathCount: 0, pathIndices: [], pathTokens: [], jumps: [], specPaths: [], specSets: [],
      specTypes: [])
    XCTAssertTrue(try liveFields(empty).isEmpty)
  }

  // All indices, FIELDSETS start boundaries, final sentinels and duplicate spec paths must be checked.
  func testIndicesFieldsetBoundariesAndSpecJoins() throws {
    try fails(crate(names: [2]), .malformed(.invalidIndex))
    try fails(crate(strings: [2]), .malformed(.invalidIndex))
    try fails(crate(fieldsets: [1, .max]), .malformed(.invalidIndex))
    try fails(crate(fieldsets: [0]), .malformed(.invalidTable))
    try fails(crate(fieldsets: [0, 0, .max], specSets: [1]), .malformed(.invalidIndex))
    try fails(crate(specSets: [2]), .malformed(.invalidIndex))
    try fails(crate(specPaths: [1]), .malformed(.invalidIndex))
    try fails(crate(specTypes: [0]), .malformed(.invalidTable))
    try fails(
      crate(specPaths: [0, 0], specSets: [0, 0], specTypes: [7, 7]), .malformed(.invalidGraph))
    // Empty fieldsets are legal and do not fabricate live values.
    XCTAssertTrue(try liveFields(crate(fieldsets: [.max])).isEmpty)
  }

  // Duplicate/absent path indices, impossible edges, and revisiting nodes must stop traversal.
  func testPathTopologyIndicesAndCycles() throws {
    try fails(crate(pathIndices: [1]), .malformed(.invalidIndex))
    try fails(
      crate(pathCount: 2, pathIndices: [0, 0], pathTokens: [0, 1], jumps: [-1, -2]),
      .malformed(.invalidIndex))
    try fails(crate(pathTokens: [UInt32(bitPattern: Int32.min)]), .malformed(.invalidIndex))
    try fails(crate(jumps: [-1]), .malformed(.invalidPath))
    try fails(
      crate(pathCount: 3, pathIndices: [0, 1, 2], pathTokens: [0, 1, 1], jumps: [-1, 1, -2]),
      .malformed(.invalidGraph))
    try fails(
      crate(pathCount: 2, pathIndices: [0, 1], pathTokens: [0, 1], jumps: [-2, -2]),
      .malformed(.invalidGraph))
    let tables = try USDCTables.read(input: input(crate(pathCount: 2), ledger: ResourceLedger()))
    XCTAssertThrowsError(try tables.pathElement(at: 1)) {
      XCTAssertEqual($0 as? USDCFailure, .malformed(.invalidIndex))
    }
  }

  // Disputed one-count PATHS and unknown jump semantics are support gaps; no alternate layout retry.
  func testAmbiguousRepresentationIsNotCorruption() throws {
    try fails(crate(jumps: [-3]), .unsupported(.unsupportedEncoding))
    try fails(crate(onePathCount: true), .unsupported(.unsupportedEncoding))
    // Here the first compressed-size is <= the total, so a count-size heuristic cannot disambiguate.
    try fails(crate(pathCount: 32, onePathCount: true), .unsupported(.unsupportedEncoding))
    try fails(crate(fieldNameFrame: Data([0x80, 0])), .unsupported(.unsupportedEncoding))
  }

  // Work and depth checks must fire before unbounded joins, recursion, or hostile count expansion.
  func testWorkDepthAndOverflowStopsReleaseStorage() throws {
    let ledger = ResourceLedger()
    try ledger.consumeUSDCWork(2_000_000)
    XCTAssertThrowsError(try USDCTables.read(input: input(crate(), ledger: ledger))) {
      XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcWork))
    }
    XCTAssertEqual(ledger.usdcLiveBytes, 0)
    let depth = 33
    let deep = try crate(
      pathCount: UInt64(depth), pathIndices: (0..<depth).map(UInt32.init),
      pathTokens: Array(repeating: 1, count: depth),
      jumps: Array(repeating: -1, count: depth - 1) + [-2])
    let depthLedger = ResourceLedger()
    XCTAssertThrowsError(try USDCTables.read(input: input(deep, ledger: depthLedger))) {
      XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcDepth))
    }
    XCTAssertEqual(depthLedger.usdcLiveBytes, 0)
    let exhausted = ResourceLedger()
    let tables = try USDCTables.read(input: input(crate(), ledger: exhausted))
    try exhausted.consumeUSDCWork(2_000_000 - exhausted.usdcWorkUnits)
    XCTAssertThrowsError(
      try tables.forEachLiveField { _ in XCTFail("work stop must precede callback") }
    ) {
      XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcWork))
    }
    let huge = try crate(tokenCount: .max)
    XCTAssertThrowsError(try USDCTables.read(input: input(huge, ledger: ResourceLedger()))) {
      XCTAssertEqual($0 as? InspectionFailure, .resourceLimit(.usdcItems))
    }
  }

  private func fails(
    _ bytes: @autoclosure () throws -> Data, _ expected: USDCFailure,
    file: StaticString = #filePath, line: UInt = #line
  ) throws {
    let ledger = ResourceLedger()
    XCTAssertThrowsError(
      try USDCTables.read(input: input(bytes(), ledger: ledger)), file: file, line: line
    ) {
      XCTAssertEqual($0 as? USDCFailure, expected, file: file, line: line)
    }
    XCTAssertEqual(ledger.usdcLiveBytes, 0, file: file, line: line)
  }

  private func liveFields(_ bytes: @autoclosure () throws -> Data) throws -> [USDCLiveField] {
    let tables = try USDCTables.read(input: input(bytes(), ledger: ResourceLedger()))
    var fields: [USDCLiveField] = []
    try tables.forEachLiveField { fields.append($0) }
    return fields
  }

  // Literal hostile-metadata recipe, independently laid out from pinned source structures.
  private func crate(
    tokens: Data = Data("/\0default\0".utf8), tokenCount: UInt64 = 2,
    strings: [UInt32] = [1], names: [UInt32] = [1], reps: [UInt64] = [0x400b_0000_0000_0000],
    fieldsets: [UInt32] = [0, .max], pathCount: UInt64 = 1, pathIndices: [UInt32] = [0],
    pathTokens: [UInt32] = [0], jumps: [Int32] = [-2], specPaths: [UInt32] = [0],
    specSets: [UInt32] = [0], specTypes: [UInt32] = [7], fieldNameEncoding: Data? = nil,
    fieldNameFrame: Data? = nil, onePathCount: Bool = false, extraSection: Bool = false
  ) throws -> Data {
    func framed(_ bytes: Data) throws -> Data { try USDCMutationRecipe.literalFrame([bytes]) }
    func integers(_ values: [UInt32]) throws -> Data {
      var raw = Data()
      if !values.isEmpty {
        raw = word(0, 4) + Data(repeating: 0xff, count: (values.count + 3) / 4)
        var previous: UInt32 = 0
        for value in values {
          raw += word(UInt64(value &- previous), 4)
          previous = value
        }
      }
      let frame = try framed(raw)
      return word(UInt64(frame.count)) + frame
    }
    let tokenFrame = try framed(tokens)
    let nameFrame =
      try fieldNameFrame
      ?? framed(
        fieldNameEncoding
          ?? {
            var raw = word(0, 4) + Data(repeating: 0xff, count: (names.count + 3) / 4)
            var previous: UInt32 = 0
            for value in names {
              raw += word(UInt64(value &- previous), 4)
              previous = value
            }
            return names.isEmpty ? Data() : raw
          }())
    let repFrame = try framed(reps.reduce(into: Data()) { $0 += word($1) })
    var sections: [(String, Data)] = [
      (
        "TOKENS",
        word(tokenCount) + word(UInt64(tokens.count)) + word(UInt64(tokenFrame.count)) + tokenFrame
      ),
      (
        "STRINGS",
        word(UInt64(strings.count)) + strings.reduce(into: Data()) { $0 += word(UInt64($1), 4) }
      ),
      (
        "FIELDS",
        word(UInt64(names.count)) + word(UInt64(nameFrame.count)) + nameFrame
          + word(UInt64(repFrame.count)) + repFrame
      ),
      ("FIELDSETS", word(UInt64(fieldsets.count)) + (try integers(fieldsets))),
      (
        "PATHS",
        word(pathCount) + (onePathCount ? Data() : word(UInt64(pathIndices.count)))
          + (try integers(pathIndices)) + (try integers(pathTokens))
          + (try integers(jumps.map(UInt32.init(bitPattern:))))
      ),
      (
        "SPECS",
        word(UInt64(specPaths.count)) + (try integers(specPaths)) + (try integers(specSets))
          + (try integers(specTypes))
      ),
    ]
    if extraSection { sections.append(("UNRELATED", Data([0xab]))) }
    var bytes =
      Data("PXR-USDC".utf8) + Data([0, 8, 0, 0, 0, 0, 0, 0]) + Data(repeating: 0, count: 72)
    var records = Data()
    for (sectionName, body) in sections {
      records += name(sectionName) + word(UInt64(bytes.count)) + word(UInt64(body.count))
      bytes += body
    }
    bytes = try USDCMutationRecipe.patch(bytes, at: 16, bytes: word(UInt64(bytes.count)))
    bytes += word(UInt64(sections.count)) + records
    return bytes
  }

  private func word(_ value: UInt64, _ width: Int = 8) -> Data {
    Data((0..<width).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) })
  }
  private func name(_ value: String) -> Data {
    Data(value.utf8) + Data(repeating: 0, count: 16 - value.utf8.count)
  }
  private func read(_ bytes: Data, _ offset: Int, _ width: Int) -> UInt64 {
    (0..<width).reduce(0) { $0 | UInt64(bytes[offset + $1]) << ($1 * 8) }
  }
  private func input(_ bytes: Data, ledger: ResourceLedger) -> USDCInput {
    let size = UInt64(bytes.count)
    let reader = BoundedReader(size: size, ledger: ledger) { offset, count in
      bytes.subdata(in: Int(offset)..<(Int(offset) + count))
    }
    let record = ZIPDirectory.Record(
      nameBytes: Data("root.usdc".utf8), versionMadeBy: 0x0314, versionNeeded: 20, flags: 0,
      method: 0, modificationTime: 0, modificationDate: 0x21, crc32: 0, compressedSize: size,
      uncompressedSize: size,
      diskNumber: 0, internalAttributes: 0, externalAttributes: 0x81a4_0000, localHeaderOffset: 0,
      centralHeaderOffset: 0)
    return USDCInput(
      entry: ZIPEntry(
        record: record, recordRange: 0..<0, headerRange: 0..<0, payloadRange: 0..<size),
      reader: reader)
  }
}

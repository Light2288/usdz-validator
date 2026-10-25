import Foundation

struct USDCLiveField: Equatable {
  let specIndex: UInt32
  let pathIndex: UInt32
  let fieldOrdinal: UInt32
  let fieldIndex: UInt32
  let nameTokenIndex: UInt32
  let valueRep: UInt64
}

struct USDCPathElement {
  let parentIndex: UInt32?
  let tokenIndex: UInt32
  let isProperty: Bool
}

/// Owns only packed metadata. Borrowed token/string bytes are valid during their callback.
final class USDCTables {
  let version: USDCVersion
  let valueDataRange: Range<UInt64>
  var specCount: Int { specPaths.count }
  private let ledger: ResourceLedger
  private let tokenBytes: USDCStorage
  private let tokens: USDCPackedTable
  private let strings: USDCPackedTable
  private let fieldNames: USDCPackedTable
  private let fieldReps: USDCStorage
  private let fieldsets: USDCPackedTable
  // Each path row stores parent, signed token bits, depth and visited spec marker.
  private let paths: USDCPackedTable
  private let specPaths: USDCPackedTable
  private let specSets: USDCPackedTable

  private init(
    version: USDCVersion, valueDataRange: Range<UInt64>, ledger: ResourceLedger,
    tokenBytes: USDCStorage, tokens: USDCPackedTable, strings: USDCPackedTable,
    fieldNames: USDCPackedTable, fieldReps: USDCStorage, fieldsets: USDCPackedTable,
    paths: USDCPackedTable, specPaths: USDCPackedTable, specSets: USDCPackedTable
  ) {
    self.version = version
    self.valueDataRange = valueDataRange
    self.ledger = ledger
    self.tokenBytes = tokenBytes
    self.tokens = tokens
    self.strings = strings
    self.fieldNames = fieldNames
    self.fieldReps = fieldReps
    self.fieldsets = fieldsets
    self.paths = paths
    self.specPaths = specPaths
    self.specSets = specSets
  }

  static func read(input: USDCInput) throws -> USDCTables {
    let size = input.entry.payloadRange.upperBound - input.entry.payloadRange.lowerBound
    guard size >= 88 else { throw USDCFailure.malformed(.invalidHeader) }
    let header = try input.withBytes(offset: 0, count: 24) { bytes -> (USDCVersion, UInt64) in
      guard bytes.prefix(8).elementsEqual("PXR-USDC".utf8) else {
        throw USDCFailure.malformed(.invalidHeader)
      }
      return (
        USDCVersion(major: bytes[8], minor: bytes[9], patch: bytes[10]),
        USDCWords.read(bytes, at: 16, width: 8)
      )
    }
    guard header.0.isSupported else { throw USDCFailure.unsupported(.unsupportedVersion) }
    let sections = try Sections.read(input: input, toc: header.1, size: size)
    let ledger = input.reader.ledger

    var cursor = sections.cursor(.tokens, input: input)
    let tokenCount = try cursor.integer()
    let tokens = try USDCPackedTable(count: tokenCount, stride: 8, ledger: ledger)
    let tokenCapacity = try cursor.integer()
    let tokenBytes = try cursor.decodedBlock(capacity: tokenCapacity)
    guard tokenBytes.count == tokenCapacity else { throw USDCFailure.malformed(.invalidTable) }
    try cursor.requireEnd()
    try readTokens(bytes: tokenBytes, index: tokens, ledger: ledger)

    cursor = sections.cursor(.strings, input: input)
    let stringCount = try cursor.integer()
    let strings = try USDCPackedTable(count: stringCount, stride: 4, ledger: ledger)
    for i in 0..<strings.count {
      try ledger.consumeUSDCWork(1)
      let token = try cursor.integer(4)
      guard token < tokenCount else { throw USDCFailure.malformed(.invalidIndex) }
      try strings.set(token, at: i)
    }
    try cursor.requireEnd()

    cursor = sections.cursor(.fields, input: input)
    let fieldCount = try cursor.integer()
    let fieldNames = try USDCIntegers.read(cursor: &cursor, count: fieldCount)
    for i in 0..<fieldNames.count {
      try ledger.consumeUSDCWork(1)
      guard fieldNames.word(i) < tokenCount else { throw USDCFailure.malformed(.invalidIndex) }
    }
    let repCapacity = try USDCStorage.checkedByteCount(count: fieldCount, stride: 8)
    let fieldReps = try cursor.decodedBlock(capacity: repCapacity)
    guard fieldReps.count == repCapacity else { throw USDCFailure.malformed(.invalidTable) }
    try cursor.requireEnd()

    cursor = sections.cursor(.fieldsets, input: input)
    let setCount = try cursor.integer()
    let fieldsets = try USDCIntegers.read(cursor: &cursor, count: setCount)
    try cursor.requireEnd()
    for i in 0..<fieldsets.count {
      try ledger.consumeUSDCWork(1)
      let field = fieldsets.word(i)
      guard field == UInt32.max || field < fieldCount else {
        throw USDCFailure.malformed(.invalidIndex)
      }
    }
    guard fieldsets.count == 0 || fieldsets.word(fieldsets.count - 1) == UInt32.max else {
      throw USDCFailure.malformed(.invalidTable)
    }

    cursor = sections.cursor(.paths, input: input)
    let paths = try readPaths(cursor: &cursor, tokenCount: tokenCount, ledger: ledger)

    cursor = sections.cursor(.specs, input: input)
    let specCount = try cursor.integer()
    let specPaths = try USDCIntegers.read(cursor: &cursor, count: specCount)
    let specSets = try USDCIntegers.read(cursor: &cursor, count: specCount)
    let specTypes = try USDCIntegers.read(cursor: &cursor, count: specCount)
    try cursor.requireEnd()
    for i in 0..<specPaths.count {
      try ledger.consumeUSDCWork(1)
      let path = specPaths.word(i)
      let start = specSets.word(i)
      guard path < paths.count, paths.word(Int(path), offset: 8) != UInt32.max,
        start < setCount, start == 0 || fieldsets.word(Int(start) - 1) == UInt32.max
      else {
        throw USDCFailure.malformed(.invalidIndex)
      }
      guard paths.word(Int(path), offset: 12) == UInt32.max else {
        throw USDCFailure.malformed(.invalidGraph)
      }
      try paths.set(UInt64(i), at: Int(path), offset: 12)
      guard (1...11).contains(specTypes.word(i)) else { throw USDCFailure.malformed(.invalidTable) }
    }
    return USDCTables(
      version: header.0, valueDataRange: 88..<sections.minimumStart,
      ledger: ledger, tokenBytes: tokenBytes, tokens: tokens, strings: strings,
      fieldNames: fieldNames, fieldReps: fieldReps, fieldsets: fieldsets, paths: paths,
      specPaths: specPaths, specSets: specSets)
  }

  func forEachLiveField(_ body: (USDCLiveField) throws -> Void) throws {
    for spec in 0..<specPaths.count {
      try ledger.consumeUSDCWork(1)
      var index = Int(specSets.word(spec))
      var ordinal: UInt32 = 0
      while true {
        try ledger.consumeUSDCWork(1)
        guard index < fieldsets.count else { throw USDCFailure.malformed(.invalidIndex) }
        let field = fieldsets.word(index)
        if field == UInt32.max { break }
        // The fieldset edge and its ValueRep are separate processed work units.
        try ledger.consumeUSDCWork(1)
        let rep = fieldReps.withUnsafeBytes { USDCWords.read($0, at: Int(field) * 8, width: 8) }
        try body(
          USDCLiveField(
            specIndex: UInt32(spec), pathIndex: UInt32(specPaths.word(spec)),
            fieldOrdinal: ordinal, fieldIndex: UInt32(field),
            nameTokenIndex: UInt32(fieldNames.word(Int(field))), valueRep: rep))
        index += 1
        ordinal += 1
      }
    }
  }

  func withTokenBytes<Result>(at index: UInt32, _ body: (UnsafeRawBufferPointer) throws -> Result)
    throws -> Result
  {
    try ledger.consumeUSDCWork(1)
    guard index < tokens.count else { throw USDCFailure.malformed(.invalidIndex) }
    let start = Int(tokens.word(Int(index)))
    let length = Int(tokens.word(Int(index), offset: 4))
    return try tokenBytes.withUnsafeBytes {
      try body(UnsafeRawBufferPointer(rebasing: $0[start..<(start + length)]))
    }
  }

  func withStringBytes<Result>(at index: UInt32, _ body: (UnsafeRawBufferPointer) throws -> Result)
    throws -> Result
  {
    try ledger.consumeUSDCWork(1)
    guard index < strings.count else { throw USDCFailure.malformed(.invalidIndex) }
    return try withTokenBytes(at: UInt32(strings.word(Int(index))), body)
  }

  func pathElement(at index: UInt32) throws -> USDCPathElement {
    try ledger.consumeUSDCWork(1)
    guard index < paths.count, paths.word(Int(index), offset: 8) != UInt32.max else {
      throw USDCFailure.malformed(.invalidIndex)
    }
    let parent = UInt32(paths.word(Int(index)))
    let element = Int32(bitPattern: UInt32(paths.word(Int(index), offset: 4)))
    return USDCPathElement(
      parentIndex: parent == .max ? nil : parent,
      tokenIndex: UInt32(abs(Int64(element))), isProperty: element < 0)
  }

  private static func readTokens(bytes: USDCStorage, index: USDCPackedTable, ledger: ResourceLedger)
    throws
  {
    try bytes.withUnsafeBytes { raw in
      var start = 0
      var token = 0
      var remaining = 0
      var lower: UInt8 = 0x80
      var upper: UInt8 = 0xbf
      for i in 0..<raw.count {
        let byte = raw[i]
        if remaining > 0 {
          guard byte >= lower, byte <= upper else { throw USDCFailure.malformed(.invalidTable) }
          remaining -= 1
          lower = 0x80
          upper = 0xbf
        } else if byte >= 0x80 {
          switch byte {
          case 0xc2...0xdf: remaining = 1
          case 0xe0:
            remaining = 2
            lower = 0xa0
          case 0xe1...0xec, 0xee...0xef: remaining = 2
          case 0xed:
            remaining = 2
            upper = 0x9f
          case 0xf0:
            remaining = 3
            lower = 0x90
          case 0xf1...0xf3: remaining = 3
          case 0xf4:
            remaining = 3
            upper = 0x8f
          default: throw USDCFailure.malformed(.invalidTable)
          }
        } else if byte == 0 {
          try ledger.consumeUSDCWork(1)
          guard token < index.count else { throw USDCFailure.malformed(.invalidTable) }
          try index.set(UInt64(start), at: token)
          try index.set(UInt64(i - start), at: token, offset: 4)
          token += 1
          start = i + 1
        }
      }
      guard remaining == 0, start == raw.count, token == index.count else {
        throw USDCFailure.malformed(.invalidTable)
      }
    }
  }

  private static func readPaths(
    cursor: inout USDCByteCursor, tokenCount: UInt64,
    ledger: ResourceLedger
  ) throws -> USDCPackedTable {
    let paths: USDCPackedTable
    let indices: USDCPackedTable
    let elements: USDCPackedTable
    let jumps: USDCPackedTable
    do {
      let pathCount = try cursor.integer()
      paths = try USDCPackedTable(count: pathCount, stride: 16, ledger: ledger, fill: 0xff)
      let encodedCount = try cursor.integer()
      try ledger.check(resource: .usdcItems, value: encodedCount)
      guard encodedCount <= pathCount else { throw USDCFailure.unsupported(.unsupportedEncoding) }
      indices = try USDCIntegers.read(cursor: &cursor, count: encodedCount)
      elements = try USDCIntegers.read(cursor: &cursor, count: encodedCount)
      jumps = try USDCIntegers.read(cursor: &cursor, count: encodedCount)
      try cursor.requireEnd()
    } catch let failure as USDCFailure {
      // Published one-count PATHS conflicts with the pinned source's two-count layout.
      // Exact integer streams and enclosing spans must admit that layout before
      // decoded graph invariants can establish corruption. Never retry another parser.
      switch failure {
      case .malformed(.invalidRange), .malformed(.invalidCompression), .malformed(.invalidTable):
        throw USDCFailure.unsupported(.unsupportedEncoding)
      default: throw failure
      }
    }
    let visited = try USDCPackedTable(count: UInt64(indices.count), stride: 1, ledger: ledger)
    for i in 0..<indices.count {
      try ledger.consumeUSDCWork(1)
      let path = indices.word(i)
      let token = abs(Int64(Int32(bitPattern: UInt32(elements.word(i)))))
      guard path < paths.count, paths.word(Int(path), offset: 8) == UInt32.max,
        token < tokenCount
      else { throw USDCFailure.malformed(.invalidIndex) }
      // Temporary marker rejects duplicate logical indices before topology is followed.
      try paths.set(0, at: Int(path), offset: 8)
    }
    // Fixed pending-sibling storage replaces recursive frames and is charged before traversal.
    let stack = try USDCPackedTable(
      count: SafetyResource.usdcDepth.limit, stride: 16, ledger: ledger)
    var stackCount = 0
    var visitedCount = 0
    var current = 0
    var parent = UInt32.max
    var depth: UInt64 = 1
    while indices.count > 0 {
      try ledger.consumeUSDCWork(1)
      guard current < indices.count else { throw USDCFailure.malformed(.invalidPath) }
      guard visited.word(current, width: 1) == 0 else { throw USDCFailure.malformed(.invalidGraph) }
      try ledger.check(resource: .usdcDepth, value: depth)
      try visited.set(1, at: current, width: 1)
      visitedCount += 1
      let path = indices.word(current)
      try paths.set(UInt64(parent), at: Int(path))
      try paths.set(elements.word(current), at: Int(path), offset: 4)
      try paths.set(depth, at: Int(path), offset: 8)
      let jump = Int32(bitPattern: UInt32(jumps.word(current)))
      guard jump >= -2 else { throw USDCFailure.unsupported(.unsupportedEncoding) }
      if jump > 0 {
        guard parent != .max else { throw USDCFailure.unsupported(.unsupportedEncoding) }
        let sibling = current + Int(jump)
        guard sibling < indices.count else { throw USDCFailure.malformed(.invalidPath) }
        guard stackCount < stack.count else { throw InspectionFailure.resourceLimit(.usdcDepth) }
        try ledger.consumeUSDCWork(1)
        try stack.set(UInt64(sibling), at: stackCount)
        try stack.set(UInt64(parent), at: stackCount, offset: 4)
        try stack.set(depth, at: stackCount, offset: 8)
        stackCount += 1
        try ledger.consumeUSDCWork(1)
        current += 1
        parent = UInt32(path)
        depth += 1
      } else if jump == -1 {
        try ledger.consumeUSDCWork(1)
        current += 1
        parent = UInt32(path)
        depth += 1
      } else if jump == 0 {
        guard parent != .max else { throw USDCFailure.unsupported(.unsupportedEncoding) }
        try ledger.consumeUSDCWork(1)
        current += 1
      } else if stackCount > 0 {
        try ledger.consumeUSDCWork(1)
        stackCount -= 1
        current = Int(stack.word(stackCount))
        parent = UInt32(stack.word(stackCount, offset: 4))
        depth = stack.word(stackCount, offset: 8)
      } else {
        break
      }
    }
    guard visitedCount == indices.count else { throw USDCFailure.malformed(.invalidGraph) }
    return paths
  }

  private enum Section: Int {
    case tokens, strings, fields, fieldsets, paths, specs
    static func identify(_ bytes: UnsafeRawBufferPointer.SubSequence) -> Section? {
      if bytes.elementsEqual("TOKENS".utf8) { return .tokens }
      if bytes.elementsEqual("STRINGS".utf8) { return .strings }
      if bytes.elementsEqual("FIELDS".utf8) { return .fields }
      if bytes.elementsEqual("FIELDSETS".utf8) { return .fieldsets }
      if bytes.elementsEqual("PATHS".utf8) { return .paths }
      if bytes.elementsEqual("SPECS".utf8) { return .specs }
      return nil
    }
  }

  private struct Sections {
    let ranges: USDCPackedTable
    let minimumStart: UInt64

    func cursor(_ section: Section, input: USDCInput) -> USDCByteCursor {
      let start = ranges.word(section.rawValue, width: 8)
      let size = ranges.word(section.rawValue, offset: 8, width: 8)
      return USDCByteCursor(input: input, range: start..<(start + size))
    }

    static func read(input: USDCInput, toc: UInt64, size: UInt64) throws -> Sections {
      guard toc >= 88, toc <= size, size - toc >= 8 else {
        throw USDCFailure.malformed(.invalidSection)
      }
      let ledger = input.reader.ledger
      var cursor = USDCByteCursor(input: input, range: toc..<size)
      let count = try cursor.integer()
      let rows = try USDCPackedTable(count: count, stride: 16, ledger: ledger)
      guard count * 32 <= cursor.end - cursor.position else {
        throw USDCFailure.malformed(.invalidSection)
      }
      let required = try USDCPackedTable(count: 6, stride: 16, ledger: ledger)
      var seen: UInt8 = 0
      var minimum = toc
      for i in 0..<rows.count {
        try ledger.consumeUSDCWork(1)
        let record = try cursor.take(32)
        let info = try input.withBytes(offset: record.lowerBound, count: 32) {
          bytes -> (Section?, UInt64, UInt64) in
          guard let terminator = bytes.prefix(16).firstIndex(of: 0),
            bytes[..<terminator].allSatisfy({ $0 > 0 && $0 < 128 })
          else {
            throw USDCFailure.malformed(.invalidSection)
          }
          let section = Section.identify(bytes[..<terminator])
          return (
            section, USDCWords.read(bytes, at: 16, width: 8),
            USDCWords.read(bytes, at: 24, width: 8)
          )
        }
        let (section, start, length) = info
        guard start >= 88, start <= toc, length <= toc - start else {
          throw USDCFailure.malformed(.invalidSection)
        }
        for other in 0..<i {
          try ledger.consumeUSDCWork(1)
          let otherStart = rows.word(other, width: 8)
          let otherEnd = rows.word(other, offset: 8, width: 8)
          guard start + length <= otherStart || start >= otherEnd else {
            throw USDCFailure.malformed(.invalidSection)
          }
        }
        try rows.set(start, at: i, width: 8)
        try rows.set(start + length, at: i, offset: 8, width: 8)
        minimum = min(minimum, start)
        if let section {
          let bit: UInt8 = 1 << section.rawValue
          guard seen & bit == 0 else { throw USDCFailure.malformed(.invalidSection) }
          seen |= bit
          try required.set(start, at: section.rawValue, width: 8)
          try required.set(length, at: section.rawValue, offset: 8, width: 8)
        }
      }
      guard seen == 0x3f else { throw USDCFailure.unsupported(.unsupportedSection) }
      return Sections(ranges: required, minimumStart: minimum)
    }
  }
}

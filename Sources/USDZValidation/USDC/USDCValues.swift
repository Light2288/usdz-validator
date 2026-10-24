import Foundation

/// Selective, source-backed authored-value traversal; never composes a scene or resolves paths.
enum USDCValues {
  static func walk(
    field: USDCLiveField, tables: USDCTables, input: USDCInput,
    onReference: (ReferenceOccurrence) -> Void, onIssue: (USDCIssue) -> Void
  ) throws {
    let walker = try Walker(field: field, tables: tables, input: input)
    let template = try tables.withTokenBytes(at: field.nameTokenIndex) {
      $0.elementsEqual("templateAssetPath".utf8)
    }
    try walker.visit(
      field.valueRep, depth: 0, template: template, onReference: onReference, onIssue: onIssue)
  }

  private final class Walker {
    let field: USDCLiveField
    let tables: USDCTables
    let input: USDCInput
    let ledger: ResourceLedger
    let stack: USDCPackedTable
    let coordinates: USDCPackedTable
    var coordinateCount = 0

    init(field: USDCLiveField, tables: USDCTables, input: USDCInput) throws {
      self.field = field
      self.tables = tables
      self.input = input
      ledger = input.reader.ledger
      stack = try USDCPackedTable(count: 32, stride: 8, ledger: ledger)
      coordinates = try USDCPackedTable(count: 96, stride: 16, ledger: ledger)
    }

    func cursor(_ offset: UInt64) throws -> USDCByteCursor {
      guard input.entry.payloadRange.lowerBound <= input.reader.size,
        tables.valueDataRange.contains(offset)
      else { throw USDCFailure.malformed(.invalidRange) }
      return USDCByteCursor(input: input, range: offset..<tables.valueDataRange.upperBound)
    }

    /// Reader::_RecursiveRead: signed offset is relative to the pointer's own position.
    func relative(_ cursor: inout USDCByteCursor) throws {
      try ledger.consumeUSDCWork(1)
      let start = cursor.position
      let delta = Int64(bitPattern: try cursor.integer())
      let target: UInt64
      if delta >= 0 {
        let (sum, overflow) = start.addingReportingOverflow(UInt64(delta))
        guard !overflow else { throw USDCFailure.malformed(.invalidRange) }
        target = sum
      } else {
        let distance = UInt64(-(delta + 1)) + 1
        guard distance <= start else { throw USDCFailure.malformed(.invalidRange) }
        target = start - distance
      }
      cursor = try self.cursor(target)
    }

    func count(_ cursor: inout USDCByteCursor, stride: UInt64) throws -> UInt64 {
      let n = try cursor.integer()
      _ = try USDCStorage.checkedByteCount(count: n, stride: stride)
      try ledger.consumeUSDCWork(n)
      return n
    }

    func withStep<T>(_ kind: USDCReferenceLocator.Kind, _ index: UInt64, _ body: () throws -> T)
      throws -> T
    {
      try ledger.consumeUSDCWork(1)
      guard coordinateCount < coordinates.count else {
        throw InspectionFailure.resourceLimit(.usdcDepth)
      }
      try coordinates.set(UInt64(kind.rawValue), at: coordinateCount, width: 1)
      try coordinates.set(index, at: coordinateCount, offset: 8, width: 8)
      coordinateCount += 1
      defer { coordinateCount -= 1 }
      return try body()
    }

    func withLocator<T>(_ body: (USDCReferenceLocator) throws -> T) throws -> T {
      // Charge worst-case Array capacity/copy overhead before creating the callback's locator.
      let charge = UInt64(
        coordinateCount * MemoryLayout<USDCReferenceLocator.Step>.stride * 2 + 256)
      let reservation = try ledger.reserveUSDCStorage(charge)
      defer { reservation.release() }
      return try { () throws -> T in
        var steps: [USDCReferenceLocator.Step] = []
        steps.reserveCapacity(coordinateCount)
        for i in 0..<coordinateCount {
          guard let kind = USDCReferenceLocator.Kind(rawValue: UInt8(coordinates.word(i, width: 1)))
          else {
            throw USDCFailure.malformed(.invalidValue)
          }
          steps.append(.init(kind: kind, index: coordinates.word(i, offset: 8, width: 8)))
        }
        return try body(
          USDCReferenceLocator(
            specIndex: UInt64(field.specIndex), fieldOrdinal: UInt64(field.fieldOrdinal),
            steps: steps))
      }()
    }

    func asset(
      _ index: UInt64, token: Bool = false, omitEmpty: Bool = false,
      onReference: (ReferenceOccurrence) -> Void
    ) throws {
      guard let index = UInt32(exactly: index) else { throw USDCFailure.malformed(.invalidIndex) }
      func emit(_ bytes: UnsafeRawBufferPointer) throws {
        try ledger.check(resource: .tokenBytes, value: UInt64(bytes.count))
        try ledger.consumeTokens(1)
        try ledger.consumeUSDCWork(1)
        if omitEmpty && bytes.isEmpty { return }
        // Serialized Data, classifier's temporary Array, and bounded syntax-search scratch.
        let reservation = try ledger.reserveUSDCStorage(UInt64(bytes.count) * 4 + 1024)
        defer { reservation.release() }
        try { () throws -> Void in
          let data = Data(bytes)
          let classification = ReferenceClassifier.classify(data)
          try withLocator { locator in
            onReference(
              ReferenceOccurrence(
                valueBytes: data, classification: classification, site: .usdc(locator)))
          }
        }()
      }
      if token {
        try tables.withTokenBytes(at: index, emit)
      } else {
        try tables.withStringBytes(at: index, emit)
      }
    }

    func visit(
      _ rep: UInt64, depth: Int, template: Bool = false,
      onReference: (ReferenceOccurrence) -> Void, onIssue: (USDCIssue) -> Void
    ) throws {
      try ledger.consumeUSDCWork(1)
      guard depth < stack.count else { throw InspectionFailure.resourceLimit(.usdcDepth) }
      do {
        for i in 0..<depth where rep != 0 && stack.word(i, width: 8) == rep {
          throw USDCFailure.malformed(.invalidGraph)
        }
        try stack.set(rep, at: depth, width: 8)
        let tag = UInt8(truncatingIfNeeded: rep >> 48)
        let flags = UInt8(truncatingIfNeeded: rep >> 56)
        let payload = rep & USDCValueFormat.payloadMask
        try USDCValueFormat.admit(tag: tag, flags: flags, payload: payload, version: tables.version)
        switch tag {
        case 12:
          if flags == 0x40 {
            try asset(payload, token: true, onReference: onReference)
          } else if flags == 0x80 {
            if payload == 0 { return }
            var c = try cursor(payload)
            let n = try count(&c, stride: 4)
            for i in 0..<n {
              let index = try c.integer(4)
              try withStep(.array, i) { try asset(index, onReference: onReference) }
            }
          } else {
            var c = try cursor(payload)
            try asset(c.integer(4), onReference: onReference)
          }
        case 31:
          if flags == 0x40 { return }
          var c = try cursor(payload)
          try dictionary(&c, depth: depth, onReference: onReference, onIssue: onIssue)
        case 35, 54, 55:
          var c = try cursor(payload)
          let mask = try c.integer(1)
          guard mask & 0x80 == 0 else { throw USDCFailure.unsupported(.unsupportedEncoding) }
          // _ListOpHeader and Reader::_Read: wire order differs from bit order.
          for bucket: UInt64 in 0..<6 {
            // A switch avoids an uncharged temporary array of bucket pairs.
            let bit: UInt64 =
              switch bucket {
              case 0: 2
              case 1: 4
              case 2: 32
              case 3: 64
              case 4: 8
              default: 16
              }
            if mask & bit == 0 { continue }
            let n = try count(&c, stride: 8)
            try withStep(.listBucket, bucket) {
              for i in 0..<n {
                try withStep(.listItem, i) {
                  if tag == 54 {
                    try relative(&c)
                    let inner = try c.integer()
                    try withStep(.wrapper, 0) {
                      try unregistered(
                        inner, depth: depth + 1, onReference: onReference, onIssue: onIssue)
                    }
                  } else {
                    try reference(
                      &c, payload: tag == 55, depth: depth, onReference: onReference,
                      onIssue: onIssue)
                  }
                }
              }
            }
          }
        case 47:
          if payload == 0 { return }
          var c = try cursor(payload)
          try reference(&c, payload: true, depth: depth, onReference: onReference, onIssue: onIssue)
        case 52, 53:
          var c = try cursor(payload)
          try relative(&c)
          let inner = try c.integer()
          try withStep(.wrapper, 0) {
            if tag == 53 {
              try unregistered(inner, depth: depth + 1, onReference: onReference, onIssue: onIssue)
            } else {
              try visit(
                inner, depth: depth + 1, template: template, onReference: onReference,
                onIssue: onIssue)
            }
          }
        case 46:
          var c = try cursor(payload)
          try relative(&c)
          let times = try c.integer()
          try ledger.consumeUSDCWork(1)
          guard times >> 48 == 48 else { throw USDCFailure.unsupported(.unsupportedValue) }
          var t = try cursor(times & USDCValueFormat.payloadMask)
          let nt = try count(&t, stride: 8)
          _ = try t.take(nt * 8)
          try relative(&c)
          let n = try count(&c, stride: 8)
          guard n == nt else { throw USDCFailure.malformed(.invalidValue) }
          for i in 0..<n {
            let inner = try c.integer()
            try withStep(.sample, i) {
              try visit(inner, depth: depth + 1, onReference: onReference, onIssue: onIssue)
            }
          }
        case 50:
          let sublayers = try tables.withTokenBytes(at: field.nameTokenIndex) {
            $0.elementsEqual("subLayers".utf8)
          }
          if sublayers && depth == 0 {
            var c = try cursor(payload)
            let n = try count(&c, stride: 4)
            for i in 0..<n {
              let index = try c.integer(4)
              try withStep(.array, i) { try asset(index, onReference: onReference) }
            }
          } else {
            try skip(tag: tag, flags: flags, payload: payload)
          }
        case 10 where template:
          if flags != 0x40 { throw USDCFailure.unsupported(.unsupportedValue) }
          let nonempty = try tables.withStringBytes(at: UInt32(payload)) { !$0.isEmpty }
          if nonempty { throw USDCFailure.unsupported(.unsupportedValue) }
        case 56, 57:
          if flags == 0x80 && payload == 0 { return }
          var c = try cursor(payload)
          let n = flags == 0x80 ? try count(&c, stride: tag == 56 ? 8 : 4) : 1
          if tag == 56 {
            _ = try c.take(n * 8)
          } else {
            for _ in 0..<n {
              let index = try c.integer(4)
              try tables.withStringBytes(at: UInt32(index)) { _ in }
            }
          }
        default: try skip(tag: tag, flags: flags, payload: payload)
        }
      } catch let failure as USDCFailure {
        try withLocator { onIssue(USDCIssue(failure: failure, locator: $0)) }
      }
    }

    func unregistered(
      _ inner: UInt64, depth: Int, onReference: (ReferenceOccurrence) -> Void,
      onIssue: (USDCIssue) -> Void
    ) throws {
      // Reader::Read<SdfUnregisteredValue> permits string, dictionary or unregistered list op.
      let tag = UInt8(truncatingIfNeeded: inner >> 48)
      if tag != 31 && tag != 54 {
        try ledger.consumeUSDCWork(1)
        guard depth < stack.count else { throw InspectionFailure.resourceLimit(.usdcDepth) }
        try withLocator {
          onIssue(USDCIssue(failure: .unsupported(.unsupportedValue), locator: $0))
        }
        return
      }
      try visit(inner, depth: depth, onReference: onReference, onIssue: onIssue)
    }

    func dictionary(
      _ c: inout USDCByteCursor, depth: Int, onReference: (ReferenceOccurrence) -> Void,
      onIssue: (USDCIssue) -> Void
    ) throws {
      let n = try count(&c, stride: 12)
      for i in 0..<n {
        let key = try c.integer(4)
        // Normative ReadMap<string,VtValue> uses STRINGS; never retry TOKENS.
        let template = try tables.withStringBytes(at: UInt32(key)) {
          $0.elementsEqual("templateAssetPath".utf8)
        }
        try relative(&c)
        let inner = try c.integer()
        try withStep(.dictionary, i) {
          try visit(
            inner, depth: depth + 1, template: template, onReference: onReference, onIssue: onIssue)
        }
      }
    }

    func reference(
      _ c: inout USDCByteCursor, payload: Bool, depth: Int,
      onReference: (ReferenceOccurrence) -> Void, onIssue: (USDCIssue) -> Void
    ) throws {
      let assetIndex = try c.integer(4)
      let path = try c.integer(4)
      if path != UInt64(UInt32.max) { _ = try tables.pathElement(at: UInt32(path)) }
      _ = try c.take(16)
      try asset(assetIndex, omitEmpty: true, onReference: onReference)
      if !payload {
        guard depth + 1 < stack.count else { throw InspectionFailure.resourceLimit(.usdcDepth) }
        // This dictionary is stored inline in the reference, with no ValueRep.
        // Clear a prior sibling's slot before counting it as a container depth.
        try stack.set(0, at: depth + 1, width: 8)
        try withStep(.referenceCustomData, 0) {
          try dictionary(&c, depth: depth + 1, onReference: onReference, onIssue: onIssue)
        }
      }
    }

    func skip(tag: UInt8, flags: UInt8, payload: UInt64) throws {
      // Scalar geometry/metadata has no asset-bearing members. This is an inventory
      // proof from the matrix, not validation of the skipped value's geometry bytes.
      if flags == 0x40 {
        if tag == 10 { try tables.withStringBytes(at: UInt32(payload)) { _ in } }
        if tag == 11 { try tables.withTokenBytes(at: UInt32(payload)) { _ in } }
        return
      }
      if flags & 0x80 != 0 {
        if payload == 0 { return }
        var c = try cursor(payload)
        _ = try count(&c, stride: 1)
        return
      }
      // These bodies are source-proven non-asset containers. No body unpacking is
      // needed for reference coverage; compressed numeric geometry stays opaque.
      _ = try cursor(payload)
    }
  }
}

import Foundation

struct USDCVersion: Equatable {
  let major: UInt8
  let minor: UInt8
  let patch: UInt8

  var isSupported: Bool { major == 0 && (8...10).contains(minor) && patch == 0 }
}

/// A member-relative cursor never reads beyond the enclosing admitted region.
struct USDCByteCursor {
  let input: USDCInput
  var position: UInt64
  let end: UInt64

  init(input: USDCInput, range: Range<UInt64>) {
    self.input = input
    position = range.lowerBound
    end = range.upperBound
  }

  mutating func take(_ count: UInt64) throws -> Range<UInt64> {
    guard position <= end, count <= end - position else {
      throw USDCFailure.malformed(.invalidRange)
    }
    let start = position
    position += count
    return start..<position
  }

  mutating func integer(_ width: Int = 8) throws -> UInt64 {
    let range = try take(UInt64(width))
    return try input.withBytes(offset: range.lowerBound, count: width) {
      USDCWords.read($0, at: 0, width: width)
    }
  }

  func requireEnd() throws {
    guard position == end else { throw USDCFailure.malformed(.invalidTable) }
  }

  mutating func decodedBlock(capacity: UInt64) throws -> USDCStorage {
    let size = try integer()
    let range = try take(size)
    return try USDCCompression.decode(input: input, range: range, decodedCapacity: capacity)
  }
}

/// Bytewise access keeps the independent format reader alignment- and endian-neutral.
enum USDCWords {
  static func read(_ bytes: UnsafeRawBufferPointer, at offset: Int, width: Int) -> UInt64 {
    var value: UInt64 = 0
    for i in 0..<width { value |= UInt64(bytes[offset + i]) << (i * 8) }
    return value
  }

  static func write(
    _ value: UInt64, to bytes: UnsafeMutableRawBufferPointer, at offset: Int, width: Int
  ) {
    for i in 0..<width { bytes[offset + i] = UInt8(truncatingIfNeeded: value >> (i * 8)) }
  }
}

/// Packed payload capacity is charged before allocation; no per-record Foundation objects are retained.
struct USDCPackedTable {
  let storage: USDCStorage
  let count: Int
  let stride: Int

  init(count: UInt64, stride: Int, ledger: ResourceLedger, fill: UInt8 = 0) throws {
    let size = try USDCStorage.checkedByteCount(count: count, stride: UInt64(stride))
    try ledger.consumeUSDCWork(count)
    storage = try USDCStorage.allocate(byteCount: size, ledger: ledger)
    self.count = Int(count)
    self.stride = stride
    try storage.withUnsafeMutableBytes {
      $0.initializeMemory(as: UInt8.self, repeating: fill)
      return $0.count
    }
  }

  func word(_ index: Int, offset: Int = 0, width: Int = 4) -> UInt64 {
    storage.withUnsafeBytes { USDCWords.read($0, at: index * stride + offset, width: width) }
  }

  func set(_ value: UInt64, at index: Int, offset: Int = 0, width: Int = 4) throws {
    try storage.withUnsafeMutableBytes {
      USDCWords.write(value, to: $0, at: index * stride + offset, width: width)
      return $0.count
    }
  }
}

/// Pinned Sdf integer coding: common signed delta, two-bit widths, then signed deltas.
enum USDCIntegers {
  static func read(cursor: inout USDCByteCursor, count: UInt64) throws -> USDCPackedTable {
    let ledger = cursor.input.reader.ledger
    let output = try USDCPackedTable(count: count, stride: 4, ledger: ledger)
    // The item bound has already admitted all arithmetic below.
    let codes = (count + 3) / 4
    let maximum = count == 0 ? 0 : 4 + codes + count * 4
    let encoded = try cursor.decodedBlock(capacity: maximum)
    try encoded.withUnsafeBytes { bytes in
      if count == 0 {
        guard bytes.isEmpty else { throw USDCFailure.malformed(.invalidTable) }
        return
      }
      guard bytes.count >= 4 + Int(codes) else { throw USDCFailure.malformed(.invalidTable) }
      let common = UInt32(USDCWords.read(bytes, at: 0, width: 4))
      var position = 4 + Int(codes)
      var previous: UInt32 = 0
      for i in 0..<Int(count) {
        try ledger.consumeUSDCWork(1)
        let code = (bytes[4 + i / 4] >> ((i % 4) * 2)) & 3
        let width = code == 0 ? 0 : (code == 3 ? 4 : Int(code))
        guard width <= bytes.count - position else { throw USDCFailure.malformed(.invalidTable) }
        var delta = common
        if width > 0 {
          let bits = UInt32(USDCWords.read(bytes, at: position, width: width))
          if width == 1 {
            delta = UInt32(bitPattern: Int32(Int8(bitPattern: UInt8(bits))))
          } else if width == 2 {
            delta = UInt32(bitPattern: Int32(Int16(bitPattern: UInt16(bits))))
          } else {
            delta = bits
          }
          position += width
        }
        previous = previous &+ delta
        try output.set(UInt64(previous), at: i)
      }
      guard position == bytes.count else { throw USDCFailure.malformed(.invalidTable) }
    }
    return output
  }
}

/// Admitted representation matrix, pinned to OpenUSD 96c1989167d2aaab5bd34627f32a321a6b79866b.
/// Types: crateDataTypes.h. Scalar/array flags: crateFile.cpp _IsAlwaysInlined,
/// _ValueHandler::Pack/PackArray, _WritePossiblyCompressedArray; optional scalar
/// inlining: crateValueInliners.h _EncodeInline overloads. No geometry validity is claimed.
enum USDCValueFormat {
  static let payloadMask: UInt64 = 0x0000_ffff_ffff_ffff

  static func admit(tag: UInt8, flags: UInt8, payload: UInt64, version: USDCVersion) throws {
    guard tag > 0, tag <= 57 else { throw USDCFailure.unsupported(.unsupportedValue) }
    // crateFile.cpp Write(GfTimeCode) and Write(SdfPathExpression) request these floors.
    guard !(tag == 56 && version.minor < 9), !(tag == 57 && version.minor < 10) else {
      throw USDCFailure.unsupported(.unsupportedValue)
    }
    let admitted: Bool
    switch tag {
    case 1, 2: admitted = flags == 0x40 || flags == 0x80
    case 3, 4: admitted = flags == 0x40 || flags == 0x80 || flags == 0xa0
    case 5, 6: admitted = flags == 0 || flags == 0x40 || flags == 0x80 || flags == 0xa0
    case 7, 8: admitted = flags == 0x40 || flags == 0x80 || flags == 0xa0
    case 9: admitted = flags == 0 || flags == 0x40 || flags == 0x80 || flags == 0xa0
    case 10, 11: admitted = flags == 0x40 || flags == 0x80
    // Non-inline asset scalar is backed by Reader::Read<SdfAssetPath> (string index).
    case 12: admitted = flags == 0 || flags == 0x40 || flags == 0x80
    case 13, 14, 15, 19...30: admitted = flags == 0 || flags == 0x40 || flags == 0x80
    case 16...18: admitted = flags == 0 || flags == 0x80
    case 31: admitted = flags == 0 || (flags == 0x40 && payload == 0)
    // Reader::_Read(SdfListOp/vector), ReadMap and Write overloads are non-array bodies.
    case 32...41, 45...50, 52...55: admitted = flags == 0
    case 42...44, 51: admitted = flags == 0x40
    // Genuine authored fixtures demonstrate 0/0x80. No inferred inline/compressed forms.
    case 56, 57: admitted = flags == 0 || flags == 0x80
    default: admitted = false
    }
    guard admitted else { throw USDCFailure.unsupported(.unsupportedValue) }
    if flags == 0x40, payload > UInt64(UInt32.max) {
      throw USDCFailure.unsupported(.unsupportedValue)
    }
  }
}

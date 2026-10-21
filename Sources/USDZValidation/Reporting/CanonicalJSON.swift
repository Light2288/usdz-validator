import Foundation

/// Integer cases retain their checked Swift ranges; floating point has no v1 representation.
indirect enum JSONValue {
  case object([String: JSONValue])
  case array([JSONValue])
  case string(String)
  case integer(Int64)
  case unsignedInteger(UInt64)
  case bool(Bool)
  case null
}

enum CanonicalJSON {
  /// The document terminator participates in the same cap as every other encoded byte.
  static func encode(_ value: JSONValue, into buffer: inout CappedBuffer) throws {
    try write(value, into: &buffer)
    try buffer.append(Data([0x0a]))
  }

  private static func write(_ value: JSONValue, into buffer: inout CappedBuffer) throws {
    switch value {
    case .object(let fields):
      try buffer.append(Data([0x7b]))
      for (index, field) in fields.sorted(by: { $0.key.utf8.lexicographicallyPrecedes($1.key.utf8) }
      )
      .enumerated() {
        if index > 0 { try buffer.append(Data([0x2c])) }
        try string(field.key, into: &buffer)
        try buffer.append(Data([0x3a]))
        try write(field.value, into: &buffer)
      }
      try buffer.append(Data([0x7d]))
    case .array(let values):
      try buffer.append(Data([0x5b]))
      for (index, member) in values.enumerated() {
        if index > 0 { try buffer.append(Data([0x2c])) }
        try write(member, into: &buffer)
      }
      try buffer.append(Data([0x5d]))
    case .string(let value): try string(value, into: &buffer)
    case .integer(let value): try buffer.append(Data(String(value).utf8))
    case .unsignedInteger(let value): try buffer.append(Data(String(value).utf8))
    case .bool(let value): try buffer.append(Data((value ? "true" : "false").utf8))
    case .null: try buffer.append(Data("null".utf8))
    }
  }

  private static func string(_ value: String, into buffer: inout CappedBuffer) throws {
    try buffer.append(Data([0x22]))
    // Never allocate a complete escaped string; malicious control/quote expansion is streamed.
    let hex = Array("0123456789abcdef".utf8)
    var chunk = Data()
    for byte in value.utf8 {
      switch byte {
      case 0x22: chunk.append(contentsOf: [0x5c, 0x22])
      case 0x5c: chunk.append(contentsOf: [0x5c, 0x5c])
      case 0x08: chunk.append(contentsOf: [0x5c, 0x62])
      case 0x0c: chunk.append(contentsOf: [0x5c, 0x66])
      case 0x0a: chunk.append(contentsOf: [0x5c, 0x6e])
      case 0x0d: chunk.append(contentsOf: [0x5c, 0x72])
      case 0x09: chunk.append(contentsOf: [0x5c, 0x74])
      case 0...0x1f:
        chunk.append(contentsOf: [
          0x5c, 0x75, 0x30, 0x30, hex[Int(byte >> 4)], hex[Int(byte & 0xf)],
        ])
      default: chunk.append(byte)
      }
      if chunk.count >= 4_090 {
        try buffer.append(chunk)
        chunk.removeAll(keepingCapacity: true)
      }
    }
    try buffer.append(chunk)
    try buffer.append(Data([0x22]))
  }
}

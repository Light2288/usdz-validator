import Foundation

/// Strict version 1 warning budgets supplied as explicit UTF-8 JSON bytes.
public enum BudgetConfiguration {
  public static func decode(_ bytes: Data) throws -> WarningBudgets {
    // Check the caller's buffer before copying, decoding strings, or tokenizing it.
    guard bytes.count <= Int(SafetyResource.configurationBytes.limit) else {
      throw ValidationError.configuration(.sizeLimitExceeded)
    }
    guard String(data: bytes, encoding: .utf8) != nil else {
      throw ValidationError.configuration(.invalidEncoding)
    }
    var parser = BudgetParser(bytes: Array(bytes))
    let budgets = try parser.decode()
    // Native and JSON callers share the effective positive-value boundary.
    return try ValidationConfiguration(budgets: budgets).budgets
  }
}

/// Only the two fixed objects are parsed; unknown fields never trigger recursive value parsing.
private struct BudgetParser {
  let bytes: [UInt8]
  var index = 0

  mutating func decode() throws -> WarningBudgets {
    try expect(0x7B)
    var keys = Set<String>()
    var hasVersion = false
    var budgets: WarningBudgets?
    skipWhitespace()
    if !consume(0x7D) {
      while true {
        let key = try uniqueKey(in: &keys)
        try expect(0x3A)
        switch key {
        case "schemaVersion":
          guard try integer() == 1 else {
            throw ValidationError.configuration(.invalidSchemaVersion)
          }
          hasVersion = true
        case "budgets":
          budgets = try budgetObject()
        default:
          throw ValidationError.configuration(.unknownKey)
        }
        skipWhitespace()
        if consume(0x7D) { break }
        try expect(0x2C)
      }
    }
    guard hasVersion, let budgets else {
      throw ValidationError.configuration(.invalidValue)
    }
    skipWhitespace()
    guard index == bytes.count else { throw ValidationError.configuration(.trailingData) }
    return budgets
  }

  private mutating func budgetObject() throws -> WarningBudgets {
    try expect(0x7B)
    var keys = Set<String>()
    var values: [String: Int64?] = [:]
    skipWhitespace()
    if !consume(0x7D) {
      while true {
        let key = try uniqueKey(in: &keys)
        switch key {
        case "archiveBytes", "fileBytes", "fileCount", "textureBytes", "totalTextureBytes",
          "textureMaxDimension":
          break
        default: throw ValidationError.configuration(.unknownKey)
        }
        try expect(0x3A)
        skipWhitespace()
        let value: Int64?
        if consume(0x6E) {
          guard consume(0x75), consume(0x6C), consume(0x6C) else {
            throw ValidationError.configuration(.invalidValue)
          }
          value = nil
        } else {
          value = try integer()
        }
        // updateValue preserves explicit null as a present optional dictionary value.
        values.updateValue(value, forKey: key)
        skipWhitespace()
        if consume(0x7D) { break }
        try expect(0x2C)
      }
    }
    let defaults = WarningBudgets.defaults
    return WarningBudgets(
      archiveBytes: values["archiveBytes"] ?? defaults.archiveBytes,
      fileBytes: values["fileBytes"] ?? defaults.fileBytes,
      fileCount: values["fileCount"] ?? defaults.fileCount,
      textureBytes: values["textureBytes"] ?? defaults.textureBytes,
      totalTextureBytes: values["totalTextureBytes"] ?? defaults.totalTextureBytes,
      textureMaxDimension: values["textureMaxDimension"] ?? defaults.textureMaxDimension
    )
  }

  private mutating func uniqueKey(in seen: inout Set<String>) throws -> String {
    let key = try string()
    guard seen.insert(key).inserted else { throw ValidationError.configuration(.duplicateKey) }
    return key
  }

  private mutating func integer() throws -> Int64 {
    skipWhitespace()
    let negative = consume(0x2D)
    guard index < bytes.count, (0x30...0x39).contains(bytes[index]) else {
      throw ValidationError.configuration(.invalidValue)
    }
    let leadingZero = bytes[index] == 0x30
    let start = index
    // Accumulate negatively so Int64.min is representable without a wider integer or lexeme copy.
    var value: Int64 = 0
    while index < bytes.count, (0x30...0x39).contains(bytes[index]) {
      guard !leadingZero || index == start else {
        throw ValidationError.configuration(.invalidValue)
      }
      let (scaled, multiplyOverflow) = value.multipliedReportingOverflow(by: 10)
      let (next, subtractOverflow) = scaled.subtractingReportingOverflow(Int64(bytes[index] - 0x30))
      guard !multiplyOverflow, !subtractOverflow else {
        throw ValidationError.configuration(.invalidValue)
      }
      value = next
      index += 1
    }
    if index < bytes.count {
      guard isWhitespace(bytes[index]) || bytes[index] == 0x2C || bytes[index] == 0x7D else {
        throw ValidationError.configuration(.invalidValue)
      }
    }
    if negative { return value }
    guard value != Int64.min else { throw ValidationError.configuration(.invalidValue) }
    return -value
  }

  private mutating func string() throws -> String {
    try expect(0x22)
    var decoded: [UInt8] = []
    while index < bytes.count {
      let byte = bytes[index]
      index += 1
      if byte == 0x22 {
        guard let key = String(bytes: decoded, encoding: .utf8) else {
          throw ValidationError.configuration(.invalidValue)
        }
        return key
      }
      guard byte >= 0x20 else { throw ValidationError.configuration(.invalidValue) }
      if byte != 0x5C {
        decoded.append(byte)
        continue
      }
      guard index < bytes.count else { throw ValidationError.configuration(.invalidValue) }
      let escape = bytes[index]
      index += 1
      switch escape {
      case 0x22, 0x5C, 0x2F: decoded.append(escape)
      case 0x62: decoded.append(0x08)
      case 0x66: decoded.append(0x0C)
      case 0x6E: decoded.append(0x0A)
      case 0x72: decoded.append(0x0D)
      case 0x74: decoded.append(0x09)
      case 0x75:
        var value = try hexQuad()
        if (0xD800...0xDBFF).contains(value) {
          // Surrogate pairs are one scalar; lone or reversed surrogates are invalid JSON strings.
          guard consume(0x5C), consume(0x75) else {
            throw ValidationError.configuration(.invalidValue)
          }
          let low = try hexQuad()
          guard (0xDC00...0xDFFF).contains(low) else {
            throw ValidationError.configuration(.invalidValue)
          }
          value = 0x10000 + (value - 0xD800) * 0x400 + (low - 0xDC00)
        }
        guard let scalar = Unicode.Scalar(value) else {
          throw ValidationError.configuration(.invalidValue)
        }
        decoded.append(contentsOf: String(scalar).utf8)
      default: throw ValidationError.configuration(.invalidValue)
      }
    }
    throw ValidationError.configuration(.invalidValue)
  }

  private mutating func hexQuad() throws -> UInt32 {
    var value: UInt32 = 0
    for _ in 0..<4 {
      guard index < bytes.count else { throw ValidationError.configuration(.invalidValue) }
      let byte = bytes[index]
      let digit: UInt32
      switch byte {
      case 0x30...0x39: digit = UInt32(byte - 0x30)
      case 0x41...0x46: digit = UInt32(byte - 0x41) + 10
      case 0x61...0x66: digit = UInt32(byte - 0x61) + 10
      default: throw ValidationError.configuration(.invalidValue)
      }
      value = value * 16 + digit
      index += 1
    }
    return value
  }

  private mutating func expect(_ byte: UInt8) throws {
    skipWhitespace()
    guard consume(byte) else { throw ValidationError.configuration(.invalidValue) }
  }

  private mutating func consume(_ byte: UInt8) -> Bool {
    guard index < bytes.count, bytes[index] == byte else { return false }
    index += 1
    return true
  }

  private mutating func skipWhitespace() {
    while index < bytes.count, isWhitespace(bytes[index]) { index += 1 }
  }

  private func isWhitespace(_ byte: UInt8) -> Bool {
    byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D
  }
}

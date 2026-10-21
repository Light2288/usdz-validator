import CryptoKit
import Foundation

/// Keep original identity bytes beside a finding until final ordering, even when display is redacted.
/// This internal key is deliberately not part of the serializable public report model.
struct FindingKey {
  let ruleID: String
  let entryNameBytes: Data?
  let entryOffset: UInt64?
  let contentOffset: UInt64?
  let discriminator: String
}

enum FindingIdentity {
  // V1 encoding: required fields have a UInt64 big-endian byte length followed by bytes.
  // Optional fields begin with 0x00 (absent) or 0x01 (present); present names use the same
  // length prefix, and present offsets are exactly eight unsigned big-endian bytes.
  static func native(_ key: FindingKey) -> String {
    var tuple = Data()
    appendBytes(Data("uvk-occurrence-v1".utf8), to: &tuple)
    appendBytes(Data(key.ruleID.utf8), to: &tuple)
    if let name = key.entryNameBytes {
      tuple.append(1)
      appendBytes(name, to: &tuple)
    } else {
      tuple.append(0)
    }
    appendOffset(key.entryOffset, to: &tuple)
    appendOffset(key.contentOffset, to: &tuple)
    appendBytes(Data(key.discriminator.utf8), to: &tuple)
    return digest(tuple)
  }

  static func external(toolVersion: String, ruleID: String, outcome: String) -> String {
    var tuple = Data()
    for field in ["uvk-external-occurrence-v1", "usdchecker", toolVersion, ruleID, outcome] {
      appendBytes(Data(field.utf8), to: &tuple)
    }
    return digest(tuple)
  }

  private static func appendBytes(_ bytes: Data, to tuple: inout Data) {
    appendUInt64(UInt64(bytes.count), to: &tuple)
    tuple.append(bytes)
  }

  private static func appendOffset(_ offset: UInt64?, to tuple: inout Data) {
    if let offset {
      tuple.append(1)
      appendUInt64(offset, to: &tuple)
    } else {
      tuple.append(0)
    }
  }

  private static func appendUInt64(_ value: UInt64, to tuple: inout Data) {
    var bigEndian = value.bigEndian
    withUnsafeBytes(of: &bigEndian) { tuple.append(contentsOf: $0) }
  }

  private static func digest(_ tuple: Data) -> String {
    let hex = Array("0123456789abcdef".utf8)
    return String(
      decoding: SHA256.hash(data: tuple).flatMap { [hex[Int($0 >> 4)], hex[Int($0 & 15)]] },
      as: UTF8.self)
  }
}

enum FindingOrder {
  static func sorted(_ records: [(finding: Finding, key: FindingKey)]) -> [Finding] {
    records.sorted { lhs, rhs in
      let leftRank = rank(lhs.finding.category)
      let rightRank = rank(rhs.finding.category)
      if leftRank != rightRank { return leftRank < rightRank }
      if !lhs.key.ruleID.utf8.elementsEqual(rhs.key.ruleID.utf8) {
        return lhs.key.ruleID.utf8.lexicographicallyPrecedes(rhs.key.ruleID.utf8)
      }
      if lhs.key.entryNameBytes != rhs.key.entryNameBytes {
        switch (lhs.key.entryNameBytes, rhs.key.entryNameBytes) {
        case (nil, _): return true
        case (_, nil): return false
        case (.some(let left), .some(let right)): return left.lexicographicallyPrecedes(right)
        }
      }
      if lhs.key.entryOffset != rhs.key.entryOffset {
        return precedes(lhs.key.entryOffset, rhs.key.entryOffset)
      }
      if lhs.key.contentOffset != rhs.key.contentOffset {
        return precedes(lhs.key.contentOffset, rhs.key.contentOffset)
      }
      return lhs.finding.occurrenceID.utf8.lexicographicallyPrecedes(rhs.finding.occurrenceID.utf8)
    }.map(\.finding)
  }

  private static func precedes(_ lhs: UInt64?, _ rhs: UInt64?) -> Bool {
    switch (lhs, rhs) {
    case (nil, .some): return true
    case (.some(let left), .some(let right)): return left < right
    default: return false
    }
  }

  private static func rank(_ category: FindingCategory) -> Int {
    switch category {
    case .archiveSpecification: return 0
    case .appleCompatibility: return 1
    case .policy: return 2
    case .validatorLimitation: return 3
    }
  }
}

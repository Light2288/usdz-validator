import Foundation

enum ReferenceClassification: Equatable {
  case literal, unsupportedExpression
}

struct ReferenceOccurrence: Equatable {
  let valueBytes: Data
  let classification: ReferenceClassification
  let site: ReferenceSite
}

enum ReferenceSite: Equatable {
  case usda(offset: UInt64, line: UInt64, column: UInt64)
  case usdc(USDCReferenceLocator)
}

enum ReferenceClassifier {
  /// Recognize unevaluated syntax without changing serialized bytes or guessing a target.
  static func classify(_ bytes: Data) -> ReferenceClassification {
    if bytes.contains(0x60) || bytes.contains(0x5b) || bytes.contains(0x5d) {
      return .unsupportedExpression
    }
    for syntax in ["${", "<UDIM>", "<UVTILE>", "####"] {
      if bytes.range(of: Data(syntax.utf8)) != nil { return .unsupportedExpression }
    }
    let value = Array(bytes)
    for index in value.indices where value[index] == 0x25 {
      var end = index + 1
      while end < value.count, (0x30...0x39).contains(value[end]) { end += 1 }
      if end < value.count, value[end] == 0x64 { return .unsupportedExpression }
    }
    if let colon = bytes.firstIndex(of: 0x3a) {
      let prefix = bytes[..<colon]
      let isDrive =
        prefix.count == 1
        && prefix.allSatisfy {
          (0x41...0x5a).contains($0) || (0x61...0x7a).contains($0)
        }
      if !isDrive { return .unsupportedExpression }
    }
    return .literal
  }
}

import Foundation

/// Presentation policy only; original bounded bytes continue to define native identity.
enum DisclosureKind {
  case basename, member, reference, message, evidence, error, toolDetail, path
}

enum Privacy {
  private static let marker = "[truncated]"

  /// Escapes display controls and bounds the final UTF-8 value, including escape expansion.
  /// Messages have a 1 KiB cap; every other variable display string has a 4 KiB cap.
  static func render(_ value: String, kind: DisclosureKind, sensitive: Bool) -> String {
    let limit = kind == .message ? 1_024 : 4_096
    let retained: String
    if kind == .basename {
      let scalars = value.unicodeScalars
      let separator = scalars.lastIndex { $0.value == 0x2f || $0.value == 0x5c }
      let start = separator.map { scalars.index(after: $0) } ?? scalars.startIndex
      retained = bounded(value[start...], bytes: limit)
    } else {
      retained = bounded(value, bytes: limit)
    }
    if !sensitive {
      switch kind {
      case .error: return "[redacted error]"
      case .toolDetail: return "[redacted tool detail]"
      case .path: return "[redacted path]"
      case .member, .reference:
        if unsafePath(retained) { return "[redacted path]" }
      case .message, .evidence:
        var inToken = false
        if retained.unicodeScalars.split(whereSeparator: { scalar in
          // Marks extend names, but cannot conceal a leading path separator after punctuation.
          switch scalar.properties.generalCategory {
          case .nonspacingMark, .spacingMark, .enclosingMark: return !inToken
          default: break
          }
          switch scalar.value {
          case 0x2f, 0x3a, 0x5c, 0x2e, 0x5f, 0x2d, 0x2b, 0x7e, 0x25: inToken = true
          default: inToken = scalar.properties.isAlphabetic || scalar.properties.numericType != nil
          }
          return !inToken
        })
        .contains(where: { unsafePath(String(String.UnicodeScalarView($0))) }) {
          return "[redacted path]"
        }
      case .basename: break
      }
    }
    return escaped(retained, bytes: limit)
  }

  /// Retention cap before serialization; does not escape, redact, or normalize identity bytes.
  static func bounded<S: StringProtocol>(_ value: S, bytes: Int) -> String {
    let prefix = Array(value.utf8.prefix(bytes + 1))
    guard prefix.count > bytes else { return String(decoding: prefix, as: UTF8.self) }
    var end = bytes - marker.utf8.count
    while end > 0, String(bytes: prefix.prefix(end), encoding: .utf8) == nil { end -= 1 }
    return String(decoding: prefix.prefix(max(0, end)), as: UTF8.self) + marker
  }

  private static func unsafePath(_ value: String) -> Bool {
    // ASCII grammar is byte-defined; combining marks must not hide separators or punctuation.
    let bytes = value.utf8
    if bytes.isEmpty || bytes.first == 0x2f || bytes.first == 0x7e || bytes.contains(0x5c) {
      return true
    }
    if bytes.split(separator: 0x2f, omittingEmptySubsequences: false)
      .contains(where: { $0.elementsEqual([0x2e, 0x2e]) })
    {
      return true
    }
    if let colon = bytes.firstIndex(of: 0x3a) {
      let scheme = bytes[..<colon]
      if let first = scheme.first, isASCIILetter(first),
        scheme.allSatisfy({
          isASCIILetter($0) || (0x30...0x39).contains($0) || $0 == 0x2b || $0 == 0x2d || $0 == 0x2e
        })
      {
        return true
      }
    }
    return false
  }

  private static func isASCIILetter(_ byte: UInt8) -> Bool {
    (0x41...0x5a).contains(byte) || (0x61...0x7a).contains(byte)
  }

  private static func escaped(_ value: String, bytes: Int) -> String {
    var result = ""
    var count = 0
    // Retain scalar boundaries as well as escape-token boundaries when adding the marker.
    var boundaries = [0]
    for scalar in value.unicodeScalars {
      let token: String
      switch scalar.value {
      case 0x5c: token = "\\\\"
      case 0x0a: token = "\\n"
      case 0x0d: token = "\\r"
      case 0x09: token = "\\t"
      default:
        switch scalar.properties.generalCategory {
        case .control, .format, .lineSeparator, .paragraphSeparator:
          let hex = String(scalar.value, radix: 16, uppercase: true)
          token = "\\u{" + String(repeating: "0", count: max(0, 4 - hex.count)) + hex + "}"
        default: token = String(scalar)
        }
      }
      if count + token.utf8.count > bytes {
        let available = bytes - marker.utf8.count
        while let last = boundaries.last, last > available { boundaries.removeLast() }
        let end = result.utf8.index(result.utf8.startIndex, offsetBy: boundaries.last ?? 0)
        return String(decoding: result.utf8[..<end], as: UTF8.self) + marker
      }
      result += token
      count += token.utf8.count
      boundaries.append(count)
    }
    return result
  }
}

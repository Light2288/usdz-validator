import Foundation

enum ReferenceResolver {
  /// Cover both anchor attempts, including split/base/normalized arrays and transient growth.
  /// The allowance sums their owners even where lifetimes do not overlap; it is not an RSS bound.
  static func binaryScratchCapacity(
    valueBytes: UnsafeRawBufferPointer, author: ZIPEntry, defaultEntry: ZIPEntry?
  ) throws -> UInt64 {
    let valueCount = UInt64(valueBytes.count)
    let authorCount = UInt64(author.nameBytes.count)
    let defaultCount = UInt64(defaultEntry?.nameBytes.count ?? 0)
    guard valueCount <= SafetyResource.tokenBytes.limit,
      authorCount <= SafetyResource.entryNameBytes.limit,
      defaultCount <= SafetyResource.entryNameBytes.limit
    else { throw InspectionFailure.resourceLimit(.usdcWorkingBytes) }
    // Counting separators requires no split array before the reservation succeeds.
    let valueComponents = valueBytes.reduce(UInt64(1)) { $0 + ($1 == 0x2f ? 1 : 0) }
    let authorComponents = author.nameBytes.reduce(UInt64(1)) { $0 + ($1 == 0x2f ? 1 : 0) }
    let defaultComponents =
      defaultEntry?.nameBytes.reduce(UInt64(1)) { $0 + ($1 == 0x2f ? 1 : 0) } ?? 0
    let components = valueComponents + authorComponents + defaultComponents
    let bytes = valueCount + authorCount + defaultCount
    // At most 12 asset and 7 of each anchor's Data slots coexist when counting
    // split/map results, both normalizations, COW copies and geometric growth.
    let arrays = try USDCStorage.checkedByteCount(
      count: components, stride: UInt64(MemoryLayout<Data>.stride) * 12)
    // Three split sequences and two normalized copies can each own slice/backing
    // metadata per asset component; two owners per anchor fit within this bound.
    let owners = try USDCStorage.checkedByteCount(count: components, stride: 5 * 128)
    // 20 source-byte capacities cover classifier/String/prefix/candidate/lookup
    // buffers; four cover component payload copies. Allow 2 KiB for fixed headers.
    let buffers = try USDCStorage.checkedByteCount(count: bytes, stride: 24)
    return arrays + owners + buffers + 2048
  }

  /// The caller must establish a safe namespace and recognize its first regular
  /// entry as the default USD layer. Lookup never returns or constructs a host URL.
  static func check(
    token: AssetToken, author: ZIPEntry, namespace: PackageNamespace,
    diagnostics: NativeDiagnostics
  ) {
    check(
      occurrence: ReferenceOccurrence(
        valueBytes: token.valueBytes, classification: token.classification,
        site: .usda(offset: token.layerByteOffset, line: token.line, column: token.column)),
      author: author, namespace: namespace, diagnostics: diagnostics)
  }

  static func check(
    occurrence: ReferenceOccurrence, author: ZIPEntry, namespace: PackageNamespace,
    diagnostics: NativeDiagnostics
  ) {
    let value = occurrence.valueBytes
    guard !value.isEmpty else { return }
    let unsupported = occurrence.classification == .unsupportedExpression
    let unsafe = isUnsafe(value)
    if unsafe {
      report(
        "UVK-PATH-004", reason: "unsafeReference", occurrence: occurrence, author: author,
        diagnostics: diagnostics)
    }
    if unsupported {
      // Only the prefix before unevaluated syntax can establish a root escape.
      // Components after an expression might have unknown depth and are never guessed.
      if !unsafe, normalize(literalPrefix(value), relativeTo: directory(author)) == nil {
        report(
          "UVK-PATH-005", reason: "packageRootEscape", occurrence: occurrence, author: author,
          diagnostics: diagnostics)
      }
      report(
        "UVK-LIM-003", reason: "unsupportedReference", occurrence: occurrence, author: author,
        diagnostics: diagnostics)
      return
    }
    guard !unsafe else { return }
    guard let candidate = normalize(value, relativeTo: directory(author)) else {
      report(
        "UVK-PATH-005", reason: "packageRootEscape", occurrence: occurrence, author: author,
        diagnostics: diagnostics)
      return
    }
    let components = value.split(separator: 0x2f, omittingEmptySubsequences: false)
    let last = components.last
    let directoryTarget =
      last?.isEmpty == true || last?.elementsEqual([0x2e]) == true
      || last?.elementsEqual([0x2e, 0x2e]) == true
    if !directoryTarget, namespace.regularEntry(namedUTF8: candidate) != nil { return }
    // An author-relative directory is a known invalid file target, even if the
    // fallback directory contains a regular member with the same relative name.
    if candidate.isEmpty || namespace.directoryExists(namedUTF8: candidate)
      || namespace.regularEntry(namedUTF8: candidate) != nil
    {
      report(
        "UVK-PATH-006", reason: "directoryTarget", occurrence: occurrence, author: author,
        diagnostics: diagnostics)
      return
    }
    let anchored = value.starts(with: [0x2e, 0x2f]) || value.starts(with: [0x2e, 0x2e, 0x2f])
    if !anchored, let defaultEntry = namespace.defaultEntry {
      guard let fallback = normalize(value, relativeTo: directory(defaultEntry)) else {
        report(
          "UVK-PATH-005", reason: "packageRootEscape", occurrence: occurrence, author: author,
          diagnostics: diagnostics)
        return
      }
      if !directoryTarget, namespace.regularEntry(namedUTF8: fallback) != nil { return }
      if fallback.isEmpty || namespace.directoryExists(namedUTF8: fallback)
        || namespace.regularEntry(namedUTF8: fallback) != nil
      {
        report(
          "UVK-PATH-006", reason: "directoryTarget", occurrence: occurrence, author: author,
          diagnostics: diagnostics)
        return
      }
    }
    report(
      "UVK-PATH-006", reason: "missingTarget", occurrence: occurrence, author: author,
      diagnostics: diagnostics)
  }

  private static func isUnsafe(_ value: Data) -> Bool {
    if value.first == 0x2f || value.contains(where: { $0 < 0x20 || $0 == 0x7f || $0 == 0x5c }) {
      return true
    }
    if let text = String(data: value, encoding: .utf8),
      text.unicodeScalars.contains(where: { (0x80...0x9f).contains($0.value) })
    {
      return true
    }
    // RFC scheme syntax also catches drive-qualified paths, including C:relative.
    guard let first = value.first, isLetter(first) else { return false }
    for byte in value.dropFirst() {
      if byte == 0x3a { return true }
      if !isLetter(byte) && !(0x30...0x39).contains(byte)
        && byte != 0x2b && byte != 0x2d && byte != 0x2e
      {
        return false
      }
    }
    return false
  }

  private static func isLetter(_ byte: UInt8) -> Bool {
    (0x41...0x5a).contains(byte) || (0x61...0x7a).contains(byte)
  }

  private static func directory(_ entry: ZIPEntry) -> [Data] {
    entry.nameBytes.split(separator: 0x2f).dropLast().map { Data($0) }
  }

  private static func normalize(_ value: Data, relativeTo base: [Data]) -> Data? {
    var components = base
    for component in value.split(separator: 0x2f) {
      if component.elementsEqual([0x2e]) { continue }
      if component.elementsEqual([0x2e, 0x2e]) {
        guard components.popLast() != nil else { return nil }
      } else {
        components.append(Data(component))
      }
    }
    var result = Data()
    for component in components {
      if !result.isEmpty { result.append(0x2f) }
      result.append(component)
    }
    return result
  }

  private static func literalPrefix(_ value: Data) -> Data {
    var end = value.endIndex
    for syntax in ["`", "[", "]", "${", "<UDIM>", "<UVTILE>", "####", ":"] {
      if let match = value.range(of: Data(syntax.utf8)) { end = min(end, match.lowerBound) }
    }
    let bytes = Array(value)
    for index in bytes.indices where bytes[index] == 0x25 {
      var next = index + 1
      while next < bytes.count, (0x30...0x39).contains(bytes[next]) { next += 1 }
      if next < bytes.count, bytes[next] == 0x64 { end = min(end, value.startIndex + index) }
    }
    // A component cut by a template is not literal, even when its authored prefix
    // happens to be '..'. Only slash-terminated components have established depth.
    guard let slash = value[..<end].lastIndex(of: 0x2f) else { return Data() }
    return Data(value[...slash])
  }

  private static func report(
    _ ruleID: String, reason: String, occurrence: ReferenceOccurrence, author: ZIPEntry,
    diagnostics: NativeDiagnostics
  ) {
    let message: String
    switch ruleID {
    case "UVK-PATH-004": message = "The asset reference contains an unsafe or external path."
    case "UVK-PATH-005": message = "The asset reference escapes the package root."
    case "UVK-PATH-006": message = "The asset reference has no regular package target."
    default:
      message = "The asset reference requires unsupported expression or identifier resolution."
    }
    switch occurrence.site {
    case .usda(let offset, let line, let column):
      // Preserve the original USDA key tuple and authored delimiter location.
      USDLayer.gap(
        ruleID, reason: reason, entry: author, diagnostics: diagnostics,
        message: message, offset: offset, line: line, column: column)
    case .usdc(let locator):
      USDCReporting.record(
        ruleID: ruleID, reason: reason, message: message, locator: locator,
        entry: author, diagnostics: diagnostics)
    }
  }
}

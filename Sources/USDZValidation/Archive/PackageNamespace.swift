import Foundation

struct PackageNamespace {
  let entries: [ZIPEntry]
  let defaultEntry: ZIPEntry?
  private let nodes: [Data: Node]
  private let sortedNames: [Data]

  private enum Node {
    case regular(ZIPEntry)
    case directory
  }

  private enum Kind {
    case regular, directory
  }

  static func build(index: ZIPIndex, diagnostics: NativeDiagnostics) -> PackageNamespace? {
    guard index.entries.count <= Int(SafetyResource.entryCount.limit) else {
      diagnostics.limit(.entryCount, location: nil)
      return nil
    }
    var nodes: [Data: Node] = [:]
    var firstRegular: ZIPEntry?
    var valid = true
    for entry in index.entries {
      guard entry.nameBytes.count <= Int(SafetyResource.entryNameBytes.limit) else {
        diagnostics.limit(
          .entryNameBytes, location: FindingLocation(archiveByteOffset: entry.localHeaderOffset))
        valid = false
        continue
      }
      let kind = classify(entry, diagnostics: diagnostics)
      let safeName = validateName(entry, kind: kind, diagnostics: diagnostics)
      if kind == .directory, entry.compressedSize != 0 || entry.uncompressedSize != 0 {
        fail("UVK-PATH-003", "directoryPayload", entry: entry, diagnostics: diagnostics)
        valid = false
      }
      guard let kind, safeName else {
        valid = false
        continue
      }
      // A directory's optional slash denotes the same node, without changing its
      // original record/name bytes used for findings or physical-entry inspection.
      let key = directoryKey(entry.nameBytes)
      guard nodes[key] == nil else {
        fail("UVK-PATH-002", "duplicateNode", entry: entry, diagnostics: diagnostics)
        valid = false
        continue
      }
      switch kind {
      case .regular:
        nodes[key] = .regular(entry)
        if firstRegular == nil { firstRegular = entry }
      case .directory: nodes[key] = .directory
      }
    }
    let names = nodes.keys.sorted { $0.lexicographicallyPrecedes($1) }
    // Keep only explicit keys. Materializing every implicit parent would multiply
    // retained storage for deep paths; a sorted prefix search needs one temporary key.
    for entry in index.entries {
      guard entry.nameBytes.count <= Int(SafetyResource.entryNameBytes.limit),
        case .regular(let original) = nodes[entry.nameBytes],
        original.localHeaderOffset == entry.localHeaderOffset
      else { continue }
      if hasDescendant(entry.nameBytes, names: names) {
        fail("UVK-PATH-002", "regularParent", entry: entry, diagnostics: diagnostics)
        valid = false
      }
    }
    guard valid else { return nil }
    return PackageNamespace(
      entries: index.entries, defaultEntry: firstRegular, nodes: nodes, sortedNames: names)
  }

  func regularEntry(namedUTF8 name: Data) -> ZIPEntry? {
    guard case .regular(let entry) = nodes[name] else { return nil }
    return entry
  }

  func directoryExists(namedUTF8 name: Data) -> Bool {
    let key = Self.directoryKey(name)
    if case .directory = nodes[key] { return true }
    return Self.hasDescendant(key, names: sortedNames)
  }

  private static func directoryKey(_ name: Data) -> Data {
    name.last == 0x2f ? Data(name.dropLast()) : name
  }

  private static func hasDescendant(_ name: Data, names: [Data]) -> Bool {
    let prefix = name + Data([0x2f])
    var lower = 0
    var upper = names.count
    while lower < upper {
      let middle = lower + (upper - lower) / 2
      if names[middle].lexicographicallyPrecedes(prefix) {
        lower = middle + 1
      } else {
        upper = middle
      }
    }
    return lower < names.count && names[lower].starts(with: prefix)
  }

  private static func classify(_ entry: ZIPEntry, diagnostics: NativeDiagnostics) -> Kind? {
    let host = entry.versionMadeBy >> 8
    guard host == 0 || host == 3 else {
      fail("UVK-LIM-001", "typeHost", entry: entry, diagnostics: diagnostics)
      return nil
    }
    if host == 3 {
      let type = (entry.externalAttributes >> 16) & 0o170000
      switch type {
      case 0o100000: return .regular
      case 0o040000: return .directory
      case 0: break
      case 0o120000, 0o020000, 0o060000, 0o010000, 0o140000:
        fail("UVK-PATH-003", "nonRegularType", entry: entry, diagnostics: diagnostics)
        return nil
      default:
        fail("UVK-LIM-001", "unixType", entry: entry, diagnostics: diagnostics)
        return nil
      }
    }
    guard entry.externalAttributes & 0x08 == 0 else {
      fail("UVK-PATH-003", "dosVolumeLabel", entry: entry, diagnostics: diagnostics)
      return nil
    }
    return entry.externalAttributes & 0x10 == 0 ? .regular : .directory
  }

  private static func validateName(
    _ entry: ZIPEntry, kind: Kind?, diagnostics: NativeDiagnostics
  ) -> Bool {
    let name = entry.nameBytes
    let bytes = Array(name)
    let drive =
      bytes.count >= 2 && bytes[1] == 0x3a
      && ((0x41...0x5a).contains(bytes[0]) || (0x61...0x7a).contains(bytes[0]))
    let components = directoryKey(name).split(separator: 0x2f, omittingEmptySubsequences: false)
    let unsafe =
      bytes.isEmpty || bytes.first == 0x2f || drive
      || bytes.contains { $0 < 0x20 || $0 == 0x7f || $0 == 0x5c }
      || (bytes.last == 0x2f && kind == .regular)
      || components.contains {
        $0.isEmpty || $0.elementsEqual([0x2e]) || $0.elementsEqual([0x2e, 0x2e])
      }
    var valid = !unsafe
    if unsafe { fail("UVK-PATH-001", "unsafeName", entry: entry, diagnostics: diagnostics) }
    // Inspect raw path syntax before decoding, and never decode an undeclared encoding.
    if entry.flags & 0x0800 == 0 && bytes.contains(where: { $0 > 0x7f }) {
      fail("UVK-LIM-001", "nameEncoding", entry: entry, diagnostics: diagnostics)
      return false
    }
    guard let text = String(data: name, encoding: .utf8) else {
      fail("UVK-PATH-001", "invalidUTF8", entry: entry, diagnostics: diagnostics)
      return false
    }
    if !unsafe, text.unicodeScalars.contains(where: { (0x80...0x9f).contains($0.value) }) {
      fail("UVK-PATH-001", "controlName", entry: entry, diagnostics: diagnostics)
      valid = false
    }
    return valid
  }

  private static func fail(
    _ ruleID: String, _ reason: String, entry: ZIPEntry, diagnostics: NativeDiagnostics
  ) {
    let location = FindingLocation(archiveByteOffset: entry.localHeaderOffset)
    diagnostics.emit(
      ruleID: ruleID,
      message: ruleID == "UVK-LIM-001"
        ? "The archive member requires unsupported filename or type interpretation."
        : "The archive member has an unsafe name, type, or namespace conflict.",
      evidence: ["reason": .string(reason)], location: location,
      key: FindingKey(
        ruleID: ruleID, entryNameBytes: entry.nameBytes, entryOffset: entry.localHeaderOffset,
        contentOffset: nil, discriminator: reason))
    let coverageReason = CoverageReason(ruleID: ruleID, reasonID: reason, location: location)
    diagnostics.mark(area: .entrySafety, state: .partial, reason: coverageReason)
    for area: CoverageArea in [.references, .textureDimensions, .appleAdvice] {
      diagnostics.mark(area: area, state: .notRun, reason: coverageReason)
    }
  }
}

import Foundation

/// Pure comparisons over established metadata and bounded header results. The engine
/// owns prerequisite selection and coverage completion; this stage performs no reads.
enum BudgetRules {
  static func evaluate(
    archiveBytes: UInt64, entries: [ZIPEntry], dimensions: [UInt64: TextureDimensions],
    configuration: ValidationConfiguration, diagnostics: NativeDiagnostics
  ) {
    let budgets = configuration.budgets
    compare(
      [("archiveBytes", "UVK-BUD-001", archiveBytes, budgets.archiveBytes)],
      diagnostics: diagnostics)
    var fileCount: UInt64 = 0
    var totalTextureBytes: UInt64? = 0
    for entry in entries.sorted(by: { $0.localHeaderOffset < $1.localHeaderOffset }) {
      guard MetadataMemberType.of(entry) == .regular else { continue }
      // The array's Int-bounded count makes the regular-entry count representable.
      fileCount += 1
      compare(
        [("fileBytes", "UVK-BUD-002", entry.compressedSize, budgets.fileBytes)],
        entry: entry, diagnostics: diagnostics)
      let kind = MemberClassifier.kind(nameBytes: entry.nameBytes)
      guard kind == .png || kind == .jpeg || kind == .exr || kind == .avif else { continue }
      compare(
        [("textureBytes", "UVK-BUD-004", entry.compressedSize, budgets.textureBytes)],
        entry: entry, diagnostics: diagnostics)
      if budgets.totalTextureBytes != nil, let total = totalTextureBytes {
        let (next, overflow) = total.addingReportingOverflow(entry.compressedSize)
        if overflow {
          // Never compare a wrapped or invented total, even for synthetic inputs
          // outside the already validated ZIP metadata contract.
          diagnostics.limit(
            .aggregateEntryBytes,
            location: FindingLocation(archiveByteOffset: entry.localHeaderOffset))
          totalTextureBytes = nil
        } else {
          totalTextureBytes = next
        }
      }
      if kind == .png || kind == .jpeg, let size = dimensions[entry.localHeaderOffset] {
        compare(
          [
            (
              "textureMaxDimension", "UVK-BUD-006", UInt64(max(size.width, size.height)),
              budgets.textureMaxDimension
            )
          ], entry: entry, diagnostics: diagnostics)
      }
    }
    var aggregateChecks: [Comparison] = [
      ("fileCount", "UVK-BUD-003", fileCount, budgets.fileCount)
    ]
    if let totalTextureBytes {
      aggregateChecks.append(
        ("totalTextureBytes", "UVK-BUD-005", totalTextureBytes, budgets.totalTextureBytes))
    }
    compare(aggregateChecks, diagnostics: diagnostics)
  }

  private typealias Comparison = (key: String, rule: String, observed: UInt64, threshold: Int64?)

  private static func compare(
    _ comparisons: [Comparison], entry: ZIPEntry? = nil, diagnostics: NativeDiagnostics
  ) {
    for check in comparisons {
      guard let threshold = check.threshold, check.observed > UInt64(threshold) else { continue }
      // Effective thresholds are positive Int64 values. Real metadata is safety-bounded;
      // retain exact decimal evidence rather than trapping on a synthetic wider UInt64.
      let observed =
        Int64(exactly: check.observed).map(EvidenceValue.integer)
        ?? .string(String(check.observed))
      diagnostics.emit(
        ruleID: check.rule,
        message: "The observed \(check.key) value exceeds its configured warning budget.",
        evidence: [
          "budget": .string(check.key), "observed": observed, "threshold": .integer(threshold),
        ],
        location: entry.map { FindingLocation(archiveByteOffset: $0.localHeaderOffset) },
        key: FindingKey(
          ruleID: check.rule, entryNameBytes: entry?.nameBytes,
          entryOffset: entry?.localHeaderOffset, contentOffset: nil, discriminator: check.key))
    }
  }
}

/// Frozen project policy and Apple advice. Layer kinds must come from Task 9's
/// safe probes; missing recognition is unavailable evidence, never a failed probe.
enum ProfileRules {
  static func evaluate(
    entries: [ZIPEntry], layerKinds: [UInt64: LayerKind], profile: Profile,
    diagnostics: NativeDiagnostics
  ) {
    var firstRegular: ZIPEntry?
    var defaultSelectionUnavailable = false
    for entry in entries.sorted(by: { $0.localHeaderOffset < $1.localHeaderOffset }) {
      guard let type = MetadataMemberType.of(entry) else {
        if firstRegular == nil { defaultSelectionUnavailable = true }
        continue
      }
      guard type == .regular else { continue }
      if firstRegular == nil, !defaultSelectionUnavailable { firstRegular = entry }
      let kind = MemberClassifier.kind(nameBytes: entry.nameBytes)
      if kind == .unknown {
        emit(
          "UVK-POL-002", discriminator: "memberSuffix", entry: entry, diagnostics: diagnostics,
          message: "The regular member suffix is outside the v0.1 project catalogue.")
      }
      guard profile == .applePortableV1 else { continue }
      if isLayerCandidate(kind), let layer = layerKinds[entry.localHeaderOffset],
        layer == .usda || layer == .unsupportedEncoding
      {
        emit(
          "UVK-APL-001", discriminator: "binaryDelivery", entry: entry, diagnostics: diagnostics,
          message:
            "The frozen Apple profile recommends binary USD delivery; current Apple systems may support text USD. This advice does not certify renderer compatibility."
        )
      }
      if kind == .exr || kind == .avif {
        emit(
          "UVK-APL-002", discriminator: "portableTexture", entry: entry, diagnostics: diagnostics,
          message:
            "The frozen Apple profile recommends PNG/JPEG textures; current Apple systems may support EXR/AVIF. This advice does not certify renderer compatibility."
        )
      }
    }
    guard !defaultSelectionUnavailable else { return }
    if let firstRegular {
      let suffix = MemberClassifier.kind(nameBytes: firstRegular.nameBytes)
      if isLayerCandidate(suffix) {
        // A missing result can mean a failed CRC or another unavailable prerequisite.
        guard let layer = layerKinds[firstRegular.localHeaderOffset] else { return }
        guard layer == .unrecognized else { return }
      }
      emitDefaultFailure(firstRegular, diagnostics: diagnostics)
    } else {
      emitDefaultFailure(nil, diagnostics: diagnostics)
    }
  }

  private static func isLayerCandidate(_ kind: MemberKind) -> Bool {
    kind == .usd || kind == .usda || kind == .usdc
  }

  private static func emitDefaultFailure(_ entry: ZIPEntry?, diagnostics: NativeDiagnostics) {
    emit(
      "UVK-POL-001", discriminator: "standaloneDefault", entry: entry, diagnostics: diagnostics,
      message:
        "The standalone default-layer policy requires the first regular member to be recognized as native USD."
    )
  }

  private static func emit(
    _ ruleID: String, discriminator: String, entry: ZIPEntry?, diagnostics: NativeDiagnostics,
    message: String
  ) {
    diagnostics.emit(
      ruleID: ruleID, message: message, evidence: ["reason": .string(discriminator)],
      location: entry.map { FindingLocation(archiveByteOffset: $0.localHeaderOffset) },
      key: FindingKey(
        ruleID: ruleID, entryNameBytes: entry?.nameBytes, entryOffset: entry?.localHeaderOffset,
        contentOffset: nil, discriminator: discriminator))
  }
}

/// Applicability only, matching the namespace's supported metadata interpretation.
/// Unknown/prohibited types remain unavailable; this helper emits no type findings.
private enum MetadataMemberType {
  case regular, directory

  static func of(_ entry: ZIPEntry) -> Self? {
    let host = entry.versionMadeBy >> 8
    guard host == 0 || host == 3 else { return nil }
    if host == 3 {
      switch (entry.externalAttributes >> 16) & 0o170000 {
      case 0o100000: return .regular
      case 0o040000: return .directory
      case 0: break
      default: return nil
      }
    }
    guard entry.externalAttributes & 0x08 == 0 else { return nil }
    return entry.externalAttributes & 0x10 == 0 ? .regular : .directory
  }
}

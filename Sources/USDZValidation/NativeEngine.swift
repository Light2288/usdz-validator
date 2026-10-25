import Foundation

/// Native metadata deliberately carries no local path. The facade owns presentation.
struct NativeResult {
  let inputByteSize: UInt64
  let findings: [Finding]
  let coverage: Coverage
  let containerSafeForExternal: Bool
}

enum NativeEngine {
  static func inspect(snapshot: FileSnapshot, configuration: ValidationConfiguration) throws
    -> NativeResult
  {
    let result = try inspect(
      size: snapshot.size, configuration: configuration, ledger: ResourceLedger(),
      readAt: { try snapshot.read(offset: $0, count: $1) })
    try snapshot.verifyUnchanged()
    return result
  }

  /// The snapshot and bounded in-memory callers share the same pipeline and invocation ledger.
  static func inspect(
    size: UInt64, configuration: ValidationConfiguration, ledger: ResourceLedger,
    readAt: @escaping (UInt64, Int) throws -> Data
  ) throws -> NativeResult {
    let budgets = configuration.budgets
    let dimensionsRequested = budgets.textureMaxDimension != nil
    let diagnostics = NativeDiagnostics(
      profile: configuration.profile,
      byteBudgetsRequested: [
        budgets.archiveBytes, budgets.fileBytes, budgets.fileCount,
        budgets.textureBytes, budgets.totalTextureBytes,
      ].contains { $0 != nil },
      textureDimensionsRequested: dimensionsRequested)
    let reader = BoundedReader(size: size, ledger: ledger) { offset, count in
      guard !diagnostics.processingTruncated else {
        throw InspectionFailure.resourceLimit(.findings)
      }
      return try readAt(offset, count)
    }
    guard let directory = try ZIPDirectory.read(from: reader, diagnostics: diagnostics),
      let index = try ZIPIndex.build(directory: directory, reader: reader, diagnostics: diagnostics)
    else {
      // The archive size remains known even when member metadata is unavailable.
      BudgetRules.evaluate(
        archiveBytes: size, entries: [], dimensions: [:],
        configuration: configuration, diagnostics: diagnostics)
      return finish(size, diagnostics: diagnostics, containerEligible: false)
    }

    let namespace = PackageNamespace.build(index: index, diagnostics: diagnostics)
    let namespaceCoverage = diagnostics.finish().1
    var namespaceReasons: [UInt64: CoverageReason] = [:]
    for reason in namespaceCoverage.areas[.entrySafety]?.reasons ?? [] {
      if let offset = reason.location?.archiveByteOffset, namespaceReasons[offset] == nil {
        namespaceReasons[offset] = reason
      }
    }
    let knownRegularFileCount = UInt64(index.entries.lazy.filter { knownRegular($0) }.count)
    let budgetEntries = index.entries.filter { knownRegular($0) && stored($0) }
    for entry in index.entries
    where !knownDirectory(entry) && (!knownRegular(entry) || !stored(entry)) {
      guard
        budgets.fileBytes != nil
          || (!knownRegular(entry) && budgets.fileCount != nil)
          || (isTexture(MemberClassifier.kind(nameBytes: entry.nameBytes))
            && (budgets.textureBytes != nil || budgets.totalTextureBytes != nil))
      else { continue }
      let reason: CoverageReason?
      if !knownRegular(entry) {
        reason =
          namespaceReasons[entry.localHeaderOffset]
          ?? namespaceCoverage.areas[.entrySafety]?.reasons.first { $0.ruleID == "UVK-RES-001" }
      } else {
        let storage = entry.method != 0 || entry.compressedSize != entry.uncompressedSize
        reason = CoverageReason(
          ruleID: storage ? "UVK-ARC-004" : "UVK-ARC-005",
          reasonID: storage ? "storage" : "encryption",
          location: FindingLocation(archiveByteOffset: entry.payloadRange.lowerBound))
      }
      if let reason { diagnostics.mark(area: .byteBudgets, state: .partial, reason: reason) }
    }
    guard let namespace else {
      // A namespace failure forbids all payload interpretation, while independently
      // established stored byte metadata still supports budget comparisons.
      for entry in index.entries where knownRegular(entry) || knownDirectory(entry) {
        _ = StoredPayload.checkMetadata(entry: entry, diagnostics: diagnostics)
      }
      if let reason = namespaceCoverage.areas[.entrySafety]?.reasons.first {
        diagnostics.mark(area: .containerStructure, state: .partial, reason: reason)
      }
      BudgetRules.evaluate(
        archiveBytes: size, entries: budgetEntries, dimensions: [:],
        configuration: configuration, diagnostics: diagnostics,
        knownRegularFileCount: knownRegularFileCount)
      ProfileRules.evaluate(
        entries: index.entries, layerKinds: [:], profile: configuration.profile,
        diagnostics: diagnostics)
      diagnostics.complete(area: .byteBudgets)
      return finish(size, diagnostics: diagnostics, containerEligible: false)
    }
    diagnostics.complete(area: .entrySafety)

    let regularEntries = index.entries.filter {
      namespace.regularEntry(namedUTF8: $0.nameBytes)?.localHeaderOffset == $0.localHeaderOffset
    }
    var eligible: Set<UInt64> = []
    var failures: [UInt64: CoverageReason] = [:]
    var failedEntries: [ZIPEntry] = []
    for entry in index.entries {
      if knownDirectory(entry) {
        _ = try StoredPayload.check(entry: entry, reader: reader, diagnostics: diagnostics)
        continue
      }
      if entry.uncompressedSize > SafetyResource.textLayerBytes.limit,
        StoredPayload.checkMetadata(entry: entry, diagnostics: diagnostics),
        let reason = try textLimitStop(entry, reader: reader, diagnostics: diagnostics)
      {
        failures[entry.localHeaderOffset] = reason
        failedEntries.append(entry)
        continue
      }
      if try StoredPayload.check(entry: entry, reader: reader, diagnostics: diagnostics) {
        eligible.insert(entry.localHeaderOffset)
      } else {
        failedEntries.append(entry)
      }
    }
    // Collect actual prerequisite findings once, after integrity discovery, rather
    // than guessing which false result (CRC, alignment, storage, resource) occurred.
    var integrityReasons: [UInt64: CoverageReason] = [:]
    let integrityResult = diagnostics.finish()
    for finding in integrityResult.0 {
      guard let offset = finding.location?.archiveByteOffset,
        finding.ruleID.hasPrefix("UVK-ARC-") || finding.ruleID == "UVK-RES-001"
      else { continue }
      let reason: String
      if case .string(let value) = finding.evidence["reason"] ?? finding.evidence["resource"] {
        reason = value
      } else {
        reason = "payloadPrerequisite"
      }
      if integrityReasons[offset] == nil {
        integrityReasons[offset] = CoverageReason(
          ruleID: finding.ruleID, reasonID: reason,
          location: finding.location)
      }
    }
    for entry in failedEntries {
      let reason =
        failures[entry.localHeaderOffset] ?? integrityReasons[entry.payloadRange.lowerBound]
        ?? integrityResult.1.areas[.containerStructure]?.reasons.first {
          $0.ruleID == "UVK-RES-001"
        }
        ?? CoverageReason(
          ruleID: "UVK-ARC-001", reasonID: "payloadPrerequisite",
          location: FindingLocation(archiveByteOffset: entry.payloadRange.lowerBound))
      failures[entry.localHeaderOffset] = reason
      // A completed CRC/alignment check can conclusively fail without losing
      // container coverage. Storage and processing stops leave CRC unavailable.
      if reason.ruleID != "UVK-ARC-003" && reason.ruleID != "UVK-ARC-006" {
        diagnostics.mark(area: .containerStructure, state: .partial, reason: reason)
      }
    }
    diagnostics.complete(area: .containerStructure)

    var layerKinds: [UInt64: LayerKind] = [:]
    for entry in regularEntries where eligible.contains(entry.localHeaderOffset) {
      let kind = MemberClassifier.kind(nameBytes: entry.nameBytes)
      guard isLayer(kind) || kind == .usdz else { continue }
      if diagnostics.processingTruncated {
        failures[entry.localHeaderOffset] = CoverageReason(
          ruleID: "UVK-RES-001", reasonID: "findings",
          location: FindingLocation(archiveByteOffset: entry.payloadRange.lowerBound))
        continue
      }
      let identified = try USDLayer.identify(entry: entry, reader: reader, diagnostics: diagnostics)
      // identify returns unrecognized on a processing stop as well as on a real
      // negative probe. A large payload can encounter the text cap after recognition.
      if identified == .unrecognized
        && entry.uncompressedSize > SafetyResource.textLayerBytes.limit,
        let reason = diagnostics.finish().1.areas[.references]?.reasons.first(where: {
          $0.ruleID == "UVK-RES-001"
            && $0.location?.archiveByteOffset == entry.payloadRange.lowerBound
        })
      {
        failures[entry.localHeaderOffset] = reason
      } else {
        layerKinds[entry.localHeaderOffset] = identified
      }
    }

    let defaultEntry = namespace.defaultEntry
    let defaultKind = defaultEntry.flatMap { layerKinds[$0.localHeaderOffset] }
    let recognizedDefault =
      defaultEntry.map { isLayer(MemberClassifier.kind(nameBytes: $0.nameBytes)) } == true
      && (defaultKind == .usda || defaultKind == .usdc || defaultKind == .unsupportedEncoding)
    if !recognizedDefault {
      let reason =
        defaultEntry.flatMap { failures[$0.localHeaderOffset] }
        ?? CoverageReason(
          ruleID: "UVK-POL-001", reasonID: "standaloneDefault",
          location: defaultEntry.map { FindingLocation(archiveByteOffset: $0.localHeaderOffset) })
      diagnostics.mark(area: .references, state: .notRun, reason: reason)
    } else {
      for entry in regularEntries {
        let kind = MemberClassifier.kind(nameBytes: entry.nameBytes)
        if let reason = failures[entry.localHeaderOffset], isLayer(kind) || kind == .usdz {
          diagnostics.mark(area: .references, state: .partial, reason: reason)
        }
        switch layerKinds[entry.localHeaderOffset] {
        case .usda:
          try USDALexer.scan(entry: entry, reader: reader, diagnostics: diagnostics) { token in
            ReferenceResolver.check(
              token: token, author: entry, namespace: namespace, diagnostics: diagnostics)
          }
        case .usdc:
          var recoveredInventory = false
          var uninspectedReason: String?
          let state: USDCScanState
          do {
            state = try USDCReader.scan(
              entry: entry, reader: reader, defaultEntry: namespace.defaultEntry,
              onReference: { occurrence in
                recoveredInventory = true
                ReferenceResolver.check(
                  occurrence: occurrence, author: entry, namespace: namespace,
                  diagnostics: diagnostics)
              },
              onIssue: { issue in
                if issue.locator == nil, case .unsupported(let reason) = issue.failure {
                  // Structural prerequisites return uninspected; retain only the fixed
                  // reason until the layer outcome can choose its whole-layer rule.
                  uninspectedReason = reason.rawValue
                } else {
                  recoveredInventory = true
                  USDCReporting.record(issue: issue, entry: entry, diagnostics: diagnostics)
                }
              })
          } catch let failure as InspectionFailure {
            // A thrown safety stop carries no scanner outcome. Only delivered inventory
            // establishes partial progress; an empty recovered inventory remains unavailable.
            state = recoveredInventory ? .partial : .uninspected
            switch failure {
            case .resourceLimit(let resource):
              diagnostics.limit(
                resource,
                location: FindingLocation(entryName: String(data: entry.nameBytes, encoding: .utf8))
              )
            case .shortRead, .malformedRange:
              USDCReporting.record(
                issue: USDCIssue(failure: .malformed(.invalidRange), locator: nil),
                entry: entry, diagnostics: diagnostics)
            }
          }
          // The scanner has released its storage before layer-level reporting or the next member.
          if state != .complete {
            USDCReporting.record(
              ruleID: state == .uninspected ? "UVK-LIM-002" : "UVK-LIM-007",
              reason: state == .uninspected
                ? uninspectedReason ?? "binaryReferences" : "partialBinaryReferences",
              message: state == .uninspected
                ? "Native reference inspection is unavailable for this binary USD layer."
                : "Native reference inspection is incomplete for this binary USD layer.",
              locator: nil, entry: entry, diagnostics: diagnostics)
          }
        default: continue
        }
      }
      diagnostics.complete(area: .references)
    }

    var dimensions: [UInt64: TextureDimensions] = [:]
    if dimensionsRequested {
      for entry in regularEntries {
        let kind = MemberClassifier.kind(nameBytes: entry.nameBytes)
        guard isTexture(kind) else { continue }
        if let reason = failures[entry.localHeaderOffset] {
          diagnostics.mark(area: .textureDimensions, state: .partial, reason: reason)
          continue
        }
        guard eligible.contains(entry.localHeaderOffset) else { continue }
        if let size = try TextureHeaders.inspect(
          entry: entry, kind: kind, reader: reader, diagnostics: diagnostics)
        {
          dimensions[entry.localHeaderOffset] = size
        }
      }
      diagnostics.complete(area: .textureDimensions)
    }
    BudgetRules.evaluate(
      archiveBytes: size, entries: budgetEntries, dimensions: dimensions,
      configuration: configuration, diagnostics: diagnostics,
      knownRegularFileCount: knownRegularFileCount)
    diagnostics.complete(area: .byteBudgets)
    ProfileRules.evaluate(
      entries: index.entries, layerKinds: layerKinds, profile: configuration.profile,
      diagnostics: diagnostics)
    for entry in regularEntries where isLayer(MemberClassifier.kind(nameBytes: entry.nameBytes)) {
      if let reason = failures[entry.localHeaderOffset] {
        diagnostics.mark(area: .appleAdvice, state: .partial, reason: reason)
      }
    }
    diagnostics.complete(area: .appleAdvice)
    let safeNames = Dictionary(
      uniqueKeysWithValues: index.entries.compactMap { entry in
        String(data: entry.nameBytes, encoding: .utf8).map { (entry.localHeaderOffset, $0) }
      })
    let safePayloadNames = Dictionary(
      uniqueKeysWithValues: index.entries.compactMap { entry in
        String(data: entry.nameBytes, encoding: .utf8).map { (entry.payloadRange.lowerBound, $0) }
      })
    return finish(
      size, diagnostics: diagnostics, containerEligible: failedEntries.isEmpty,
      safeNames: safeNames, safePayloadNames: safePayloadNames)
  }

  private static func textLimitStop(
    _ entry: ZIPEntry, reader: BoundedReader,
    diagnostics: NativeDiagnostics
  ) throws -> CoverageReason? {
    guard entry.uncompressedSize > SafetyResource.textLayerBytes.limit else { return nil }
    let kind = MemberClassifier.kind(nameBytes: entry.nameBytes)
    var oversizedText = kind == .usda
    if kind == .usd, stored(entry) {
      do {
        let header = try reader.read(
          offset: entry.payloadRange.lowerBound,
          count: Int(min(48, entry.uncompressedSize)))
        oversizedText = USDLayer.hasTextHeader(header) || USDLayer.hasUnsupportedTextHeader(header)
      } catch let failure as InspectionFailure {
        USDLayer.recordReadFailure(failure, entry: entry, diagnostics: diagnostics)
        if case .resourceLimit(let resource) = failure {
          return CoverageReason(
            ruleID: "UVK-RES-001", reasonID: resource.rawValue,
            location: FindingLocation(archiveByteOffset: entry.payloadRange.lowerBound))
        }
        return CoverageReason(
          ruleID: "UVK-ARC-001", reasonID: "layerRead",
          location: FindingLocation(archiveByteOffset: entry.payloadRange.lowerBound))
      }
    }
    guard oversizedText else { return nil }
    diagnostics.limit(
      .textLayerBytes, location: FindingLocation(archiveByteOffset: entry.payloadRange.lowerBound))
    return CoverageReason(
      ruleID: "UVK-RES-001", reasonID: "textLayerBytes",
      location: FindingLocation(archiveByteOffset: entry.payloadRange.lowerBound))
  }

  private static func finish(
    _ size: UInt64, diagnostics: NativeDiagnostics,
    containerEligible: Bool, safeNames: [UInt64: String] = [:],
    safePayloadNames: [UInt64: String] = [:]
  ) -> NativeResult {
    let (findings, coverage) = diagnostics.finish()
    let unsafe = findings.contains {
      ($0.category == .archiveSpecification && $0.severity == .error)
        || $0.ruleID == "UVK-RES-001" || $0.ruleID == "UVK-PATH-004" || $0.ruleID == "UVK-PATH-005"
    }
    // Enrich only after full namespace success and final sorting. Header and payload
    // offsets have different meanings; a zero-size payload may share the next header.
    func located(_ location: FindingLocation?, ruleID: String) -> FindingLocation? {
      guard let location, location.entryName == nil, let offset = location.archiveByteOffset else {
        return location
      }
      let name: String?
      switch ruleID {
      case "UVK-ARC-003", "UVK-ARC-004", "UVK-ARC-005", "UVK-ARC-006":
        name = safePayloadNames[offset]
      case "UVK-RES-001":
        let header = safeNames[offset]
        let payload = safePayloadNames[offset]
        if let header, let payload, !header.utf8.elementsEqual(payload.utf8) {
          name = nil
        } else {
          name = header ?? payload
        }
      default:
        name =
          ruleID.hasPrefix("UVK-BUD-") || ruleID.hasPrefix("UVK-POL-")
            || ruleID.hasPrefix("UVK-APL-")
          ? safeNames[offset] : nil
      }
      guard let name else { return location }
      return FindingLocation(
        entryName: name, archiveByteOffset: offset,
        layerByteOffset: location.layerByteOffset, line: location.line, column: location.column)
    }
    let locatedFindings = findings.map { finding in
      Finding(
        ruleID: finding.ruleID, occurrenceID: finding.occurrenceID,
        category: finding.category, severity: finding.severity, message: finding.message,
        evidence: finding.evidence,
        location: located(finding.location, ruleID: finding.ruleID),
        provenance: finding.provenance)
    }
    let locatedCoverage = Coverage(
      areas: coverage.areas.mapValues { area in
        CoverageAreaResult(
          requested: area.requested, state: area.state,
          reasons: area.reasons.map { reason in
            CoverageReason(
              ruleID: reason.ruleID, reasonID: reason.reasonID,
              location: located(reason.location, ruleID: reason.ruleID))
          })
      })
    return NativeResult(
      inputByteSize: size, findings: locatedFindings, coverage: locatedCoverage,
      containerSafeForExternal: containerEligible && !unsafe
        && coverage.areas[.containerStructure]?.state == .complete
        && coverage.areas[.entrySafety]?.state == .complete)
  }

  private static func stored(_ entry: ZIPEntry) -> Bool {
    entry.method == 0 && entry.flags & 1 == 0 && entry.compressedSize == entry.uncompressedSize
  }

  private static func knownRegular(_ entry: ZIPEntry) -> Bool {
    knownType(entry, directory: false)
  }

  private static func knownDirectory(_ entry: ZIPEntry) -> Bool {
    knownType(entry, directory: true)
  }

  private static func knownType(_ entry: ZIPEntry, directory: Bool) -> Bool {
    let host = entry.versionMadeBy >> 8
    guard host == 0 || host == 3 else { return false }
    if host == 3 {
      let type = (entry.externalAttributes >> 16) & 0o170000
      if type != 0 { return type == (directory ? 0o040000 : 0o100000) }
    }
    guard entry.externalAttributes & 0x08 == 0 else { return false }
    return (entry.externalAttributes & 0x10 != 0) == directory
  }

  private static func isLayer(_ kind: MemberKind) -> Bool {
    kind == .usd || kind == .usda || kind == .usdc
  }

  private static func isTexture(_ kind: MemberKind) -> Bool {
    kind == .png || kind == .jpeg || kind == .exr || kind == .avif
  }
}

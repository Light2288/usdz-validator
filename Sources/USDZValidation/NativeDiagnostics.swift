import Foundation

/// Retains discovery order until final sorting, with fixed bounds for findings and reasons.
final class NativeDiagnostics {
  private static let descriptors = Dictionary(
    uniqueKeysWithValues: RuleCatalogue.descriptors(profile: .applePortableV1).map {
      ($0.ruleID, $0)
    })
  private static let retentionLimit = Int(SafetyResource.findings.limit)
  private var records: [(finding: Finding, key: FindingKey)] = []
  private var identities: Set<Identity> = []
  private let requestedAreas: [CoverageArea]
  private var states: [CoverageArea: CoverageState] = [:]
  private var markedAreas: Set<CoverageArea> = []
  private var reasons: [(area: CoverageArea, reason: CoverageReason)] = []
  private var reasonIdentities: Set<ReasonIdentity> = []
  private var findingsTruncated = false
  private var reasonsTruncated = false

  // String's equality normalizes Unicode. Identity must compare the original bytes instead.
  private struct Identity: Hashable {
    let ruleID: Data
    let name: Data?
    let entryOffset: UInt64?
    let contentOffset: UInt64?
    let discriminator: Data

    init(_ key: FindingKey) {
      ruleID = Data(key.ruleID.utf8)
      name = key.entryNameBytes
      entryOffset = key.entryOffset
      contentOffset = key.contentOffset
      discriminator = Data(key.discriminator.utf8)
    }
  }

  private struct ReasonIdentity: Hashable {
    let area: CoverageArea
    let ruleID: Data
    let reasonID: Data
    let name: Data?
    let archiveOffset: UInt64?
    let layerOffset: UInt64?
    let line: Int64?
    let column: Int64?

    init(area: CoverageArea, reason: CoverageReason) {
      self.area = area
      ruleID = Data(reason.ruleID.utf8)
      reasonID = Data(reason.reasonID.utf8)
      name = reason.location?.entryName.map { Data($0.utf8) }
      archiveOffset = reason.location?.archiveByteOffset
      layerOffset = reason.location?.layerByteOffset
      line = reason.location?.line
      column = reason.location?.column
    }
  }

  init(
    profile: Profile = .generalV1, byteBudgetsRequested: Bool = true,
    textureDimensionsRequested: Bool = true
  ) {
    requestedAreas = CoverageArea.allCases.filter { area in
      switch area {
      case .appleAdvice: profile == .applePortableV1
      case .byteBudgets: byteBudgetsRequested
      case .textureDimensions: textureDimensionsRequested
      default: true
      }
    }
  }

  func emit(
    ruleID: String, message: String, evidence: [String: EvidenceValue],
    location: FindingLocation?, key: FindingKey
  ) {
    guard !findingsTruncated else { return }
    // Oversized raw names cannot be retained for sorting. Record their processing stop instead.
    guard key.entryNameBytes?.count ?? 0 <= Int(SafetyResource.entryNameBytes.limit) else {
      limit(.entryNameBytes, location: location)
      return
    }
    guard key.discriminator.utf8.prefix(4_097).count <= 4_096 else {
      limit(.tokenBytes, location: location)
      return
    }
    let retainedKey = FindingKey(
      ruleID: ruleID, entryNameBytes: key.entryNameBytes, entryOffset: key.entryOffset,
      contentOffset: key.contentOffset, discriminator: key.discriminator)
    let identity = Identity(retainedKey)
    guard !identities.contains(identity) else { return }
    guard records.count < Self.retentionLimit else {
      truncateFindings()
      return
    }
    let descriptor = Self.descriptors[ruleID]
    let finding = Finding(
      ruleID: ruleID, occurrenceID: FindingIdentity.native(retainedKey),
      category: descriptor?.category ?? .policy, severity: descriptor?.defaultSeverity ?? .error,
      message: Self.bounded(message, bytes: 1_024),
      evidence: evidence.mapValues { value in
        if case .string(let string) = value {
          return .string(Self.bounded(string, bytes: 4_096))
        }
        return value
      },
      location: Self.bounded(location),
      provenance: .native(validatorVersion: ValidatorVersion.current))
    records.append((finding, retainedKey))
    identities.insert(identity)
  }

  func limit(_ resource: SafetyResource, location: FindingLocation?) {
    // Reaching the dimension scan boundary is an explicit nonfatal coverage limitation.
    let isTextureBoundary = resource == .textureHeaderBytes
    let ruleID = isTextureBoundary ? "UVK-LIM-005" : "UVK-RES-001"
    emit(
      ruleID: ruleID,
      message: isTextureBoundary
        ? "Texture dimensions were not established within the header scan limit."
        : "A fixed native processing ceiling was exceeded.",
      evidence: ["resource": .string(resource.rawValue), "limit": .integer(Int64(resource.limit))],
      location: location,
      key: FindingKey(
        ruleID: ruleID, entryNameBytes: nil, entryOffset: location?.archiveByteOffset,
        contentOffset: location?.layerByteOffset, discriminator: resource.rawValue))
    for area in affectedAreas(resource) {
      mark(
        area: area, state: .partial,
        reason: CoverageReason(ruleID: ruleID, reasonID: resource.rawValue, location: location))
    }
  }

  func mark(area: CoverageArea, state: CoverageState, reason: CoverageReason) {
    guard requestedAreas.contains(area) else { return }
    if markedAreas.insert(area).inserted {
      states[area] = state
    } else if states[area] != state {
      // A later success cannot erase evidence of an earlier incomplete part of this area.
      states[area] = .partial
    }
    guard !reasonsTruncated else { return }
    let boundedReason = CoverageReason(
      ruleID: Self.bounded(reason.ruleID, bytes: 4_096),
      reasonID: Self.bounded(reason.reasonID, bytes: 4_096), location: Self.bounded(reason.location)
    )
    let identity = ReasonIdentity(area: area, reason: boundedReason)
    guard !reasonIdentities.contains(identity) else { return }
    guard reasons.count < Self.retentionLimit else {
      truncateReasons()
      return
    }
    reasons.append((area, boundedReason))
    reasonIdentities.insert(identity)
  }

  func finish() -> ([Finding], Coverage) {
    var areas: [CoverageArea: CoverageAreaResult] = [:]
    for area in CoverageArea.allCases {
      areas[area] = CoverageAreaResult(
        requested: requestedAreas.contains(area), state: states[area] ?? .notRun,
        reasons: reasons.lazy.filter { $0.area == area }.map(\.reason))
    }
    return (FindingOrder.sorted(records), Coverage(areas: areas))
  }

  private func truncateFindings() {
    guard !findingsTruncated else { return }
    // Exactly 10,000 ordinary findings may fit. Only discovery of the next unique identity
    // replaces slot 10,000; the first 9,999 occurrence identities remain untouched.
    if let removed = records.popLast() { identities.remove(Identity(removed.key)) }
    limit(.findings, location: nil)
    findingsTruncated = true
  }

  private func truncateReasons() {
    guard !reasonsTruncated else { return }
    reasonsTruncated = true
    // The same 10,000-record retention envelope covers all areas combined. Make room for
    // one explicit stop per selected area rather than growing a second input-sized collection.
    let retainedCount = Self.retentionLimit - requestedAreas.count
    reasons.removeLast(max(0, reasons.count - retainedCount))
    for area in requestedAreas {
      states[area] = .partial
      markedAreas.insert(area)
      reasons.append((area, CoverageReason(ruleID: "UVK-RES-001", reasonID: "coverageReasons")))
    }
    reasonIdentities.removeAll()
    limit(.findings, location: nil)
  }

  private func affectedAreas(_ resource: SafetyResource) -> [CoverageArea] {
    switch resource {
    case .textLayerBytes, .tokenBytes, .tokenCount: [.references]
    case .textureHeaderBytes: [.textureDimensions]
    default: requestedAreas
    }
  }

  private static func bounded(_ location: FindingLocation?) -> FindingLocation? {
    location.map {
      FindingLocation(
        entryName: $0.entryName.map { bounded($0, bytes: 4_096) },
        archiveByteOffset: $0.archiveByteOffset, layerByteOffset: $0.layerByteOffset,
        line: $0.line, column: $0.column)
    }
  }

  private static func bounded(_ value: String, bytes: Int) -> String {
    // Materialize only a fixed prefix, including when value's storage belongs to a large slice.
    let prefix = Array(value.utf8.prefix(bytes + 1))
    guard prefix.count > bytes else { return String(decoding: prefix, as: UTF8.self) }
    let marker = "[truncated]"
    var retainedCount = bytes - marker.utf8.count
    while retainedCount > 0 {
      if let retained = String(bytes: prefix.prefix(retainedCount), encoding: .utf8) {
        return retained + marker
      }
      retainedCount -= 1
    }
    return marker
  }
}

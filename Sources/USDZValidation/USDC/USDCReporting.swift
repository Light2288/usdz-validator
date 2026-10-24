import Foundation

struct USDCIssue: Equatable {
  let failure: USDCFailure
  let locator: USDCReferenceLocator?
}

enum USDCReporting {
  /// This records a specific cause. Layer-level completeness reporting belongs to orchestration.
  static func record(issue: USDCIssue, entry: ZIPEntry, diagnostics: NativeDiagnostics) {
    let ruleID: String
    let reason: String
    let message: String
    switch issue.failure {
    case .unsupported(let gap):
      ruleID = "UVK-LIM-007"
      reason = gap.rawValue
      message = "Binary USD reference inspection encountered an unsupported representation."
    case .malformed(let corruption):
      ruleID = "UVK-USD-001"
      reason = corruption.rawValue
      message = "The inspected binary USD structure is malformed."
    }
    record(
      ruleID: ruleID, reason: reason, message: message, locator: issue.locator,
      entry: entry, diagnostics: diagnostics)
  }

  static func record(
    ruleID: String, reason: String, message: String, locator: USDCReferenceLocator?,
    entry: ZIPEntry, diagnostics: NativeDiagnostics
  ) {
    // Compressed/shared values have no truthful source byte region. Entry identity is
    // retained for hashing, while display includes only the package member location.
    let location = FindingLocation(entryName: String(data: entry.nameBytes, encoding: .utf8))
    diagnostics.emit(
      ruleID: ruleID, message: message, evidence: ["reason": .string(reason)], location: location,
      key: FindingKey(
        ruleID: ruleID, entryNameBytes: entry.nameBytes, entryOffset: entry.localHeaderOffset,
        contentOffset: nil,
        discriminator: locator?.discriminator(reason: reason) ?? "\(reason)|usdc-v1"))
    diagnostics.mark(
      area: .references, state: .partial,
      reason: CoverageReason(ruleID: ruleID, reasonID: reason, location: location))
  }
}

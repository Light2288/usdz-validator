import Foundation

enum TextReport {
  static func encode(_ report: ValidationReport) throws -> Data {
    var writer = Writer(sensitive: report.configuration.includeSensitiveDetails)
    try writer.line("tool: ", writer.text(report.tool.name), " ", writer.text(report.tool.version))
    try writer.line("schemaVersion: ", String(report.schemaVersion))
    try writer.line("input: ", writer.text(report.input.displayName, .basename))
    try writer.line("input bytes: ", report.input.byteSize.map(String.init) ?? "unavailable")
    if writer.sensitive, let details = report.input.sensitiveDetails {
      try writer.line("input path: ", writer.text(details.absolutePath, .path))
    }
    let configuration = report.configuration
    try writer.line("profile: ", configuration.profile.rawValue)
    try writer.line("safetyEnvelopeVersion: ", String(configuration.safetyEnvelopeVersion))
    try writer.line("failOn: ", configuration.gatePolicy.failOn.rawValue)
    try writer.line("allowIncomplete: ", String(configuration.gatePolicy.allowIncomplete))
    try writer.line("includeSensitiveDetails: ", String(configuration.includeSensitiveDetails))
    try writer.line("external request: ", configuration.externalCheck.rawValue)
    let budgets = configuration.budgets
    for (name, value) in [
      ("archiveBytes", budgets.archiveBytes), ("fileBytes", budgets.fileBytes),
      ("fileCount", budgets.fileCount), ("textureBytes", budgets.textureBytes),
      ("totalTextureBytes", budgets.totalTextureBytes),
      ("textureMaxDimension", budgets.textureMaxDimension),
    ] {
      try writer.line("budget ", name, ": ", value.map(String.init) ?? "disabled")
    }
    try writer.line("validationStatus: ", report.validationStatus.rawValue)
    try writer.line("gate: ", report.gateDecision.rawValue)
    try writer.line("acceptedIncomplete: ", String(report.acceptedIncomplete))
    try writer.line("exit: ", String(report.exitCode))
    for area in CoverageArea.allCases {
      guard let result = report.coverage.areas[area] else { continue }
      try writer.line(
        "coverage ", area.rawValue, ": ", result.state.rawValue,
        " requested: ", String(result.requested))
      for reason in result.reasons {
        try writer.line("  reason: ", writer.text(reason.ruleID), " ", writer.text(reason.reasonID))
        try writer.location(reason.location)
      }
    }
    try writer.counts(report.summary.native, source: "native")
    try writer.counts(report.summary.external, source: "external")
    try writer.line("native findings: ", String(report.nativeFindings.count))
    for finding in report.nativeFindings { try writer.finding(finding) }
    let external = report.externalCheck
    try writer.line("external requested: ", String(external.requested))
    try writer.line("external phase: ", external.phase?.rawValue ?? "unavailable")
    try writer.line("external availability: ", external.availability.rawValue)
    try writer.line("external version: ", external.version.map { writer.text($0) } ?? "unavailable")
    try writer.line("external policy: ", external.policy?.rawValue ?? "unavailable")
    try writer.line("external status: ", external.status.rawValue)
    try writer.line("external outcome: ", external.outcome?.rawValue ?? "unavailable")
    try writer.line("external exit: ", external.exitCode.map(String.init) ?? "unavailable")
    try writer.line("external signal: ", external.signal.map(String.init) ?? "unavailable")
    try writer.line(
      "external stdout bytes: ", String(external.stdoutBytes),
      " present: ", String(external.hasStdout))
    try writer.line(
      "external stderr bytes: ", String(external.stderrBytes),
      " present: ", String(external.hasStderr))
    if writer.sensitive, let details = external.sensitiveDetails {
      for argument in details.arguments {
        try writer.line("external argument: ", writer.text(argument, .toolDetail))
      }
      try writer.line("external stdout: ", writer.text(details.stdout, .toolDetail))
      try writer.line("external stderr: ", writer.text(details.stderr, .toolDetail))
    }
    try writer.line("external findings: ", String(external.findings.count))
    for finding in external.findings { try writer.finding(finding) }
    for error in report.operationalErrors {
      let category: String
      let reason: String
      switch error {
      case .configuration(let value):
        category = "configuration"
        reason = value.rawValue
      case .operational(let value):
        category = "operational"
        reason = value.rawValue
      case .internalFailure(let value):
        category = "internalFailure"
        reason = value.rawValue
      }
      try writer.line("error: ", category, " ", reason)
    }
    return writer.buffer.finish()
  }

  private struct Writer {
    let sensitive: Bool
    var buffer = CappedBuffer()

    func text(_ value: String, _ kind: DisclosureKind = .evidence) -> String {
      Privacy.render(value, kind: kind, sensitive: sensitive)
    }

    mutating func line(_ parts: String...) throws {
      // Each dynamic part is bounded independently before reaching this writer.
      for part in parts { try buffer.append(Data(part.utf8)) }
      try buffer.append(Data([0x0a]))
    }

    mutating func counts(_ counts: FindingCounts, source: String) throws {
      for severity in Severity.allCases {
        try line(
          source, " count ", severity.rawValue, ": ", String(counts.bySeverity[severity] ?? 0))
      }
      for category in FindingCategory.allCases {
        try line(
          source, " count ", category.rawValue, ": ", String(counts.byCategory[category] ?? 0))
      }
    }

    mutating func finding(_ finding: Finding) throws {
      try line(
        "finding: ", text(finding.ruleID), " ", finding.category.rawValue, " ",
        finding.severity.rawValue, " ", text(finding.occurrenceID))
      try line("  message: ", text(finding.message, .message))
      switch finding.provenance {
      case .native(let version): try line("  provenance: native ", text(version))
      case .usdchecker(let tool, let version, let invocationID):
        try line(
          "  provenance: usdchecker ", text(tool), " ", version.map { text($0) } ?? "unavailable")
        if sensitive { try line("  invocation: ", text(invocationID)) }
      }
      try location(finding.location)
      for key in finding.evidence.keys.sorted() {
        guard let value = finding.evidence[key] else { continue }
        let rendered: String
        switch value {
        case .string(let string): rendered = text(string)
        case .integer(let integer): rendered = String(integer)
        case .boolean(let boolean): rendered = String(boolean)
        case .null: rendered = "unavailable"
        }
        try line("  evidence ", text(key), ": ", rendered)
      }
    }

    mutating func location(_ location: FindingLocation?) throws {
      guard let location else { return }
      if let name = location.entryName { try line("  member: ", text(name, .member)) }
      if let offset = location.archiveByteOffset { try line("  archive byte: ", String(offset)) }
      if let offset = location.layerByteOffset { try line("  layer byte: ", String(offset)) }
      if let lineNumber = location.line { try line("  line: ", String(lineNumber)) }
      if let column = location.column { try line("  column: ", String(column)) }
    }
  }
}

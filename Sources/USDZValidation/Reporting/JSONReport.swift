enum JSONReport {
  static func value(_ report: ValidationReport) throws -> JSONValue {
    let renderer = Renderer(sensitive: report.configuration.includeSensitiveDetails)
    let configuration = report.configuration
    let budgets = configuration.budgets
    var input: [String: JSONValue] = [
      "displayName": renderer.text(report.input.displayName, .basename),
      "byteSize": renderer.integer(report.input.byteSize),
    ]
    if renderer.sensitive {
      input["sensitiveDetails"] =
        report.input.sensitiveDetails.map {
          .object(["absolutePath": renderer.text($0.absolutePath, .path)])
        } ?? .null
    }
    var areas: [String: JSONValue] = [:]
    for (area, result) in report.coverage.areas {
      areas[area.rawValue] = .object([
        "requested": .bool(result.requested), "state": .string(result.state.rawValue),
        "reasons": .array(
          result.reasons.map {
            .object([
              "ruleID": renderer.text($0.ruleID), "reasonID": renderer.text($0.reasonID),
              "location": renderer.location($0.location),
            ])
          }),
      ])
    }
    return .object([
      "schemaVersion": .integer(Int64(report.schemaVersion)),
      "tool": .object([
        "name": renderer.text(report.tool.name), "version": renderer.text(report.tool.version),
      ]),
      "input": .object(input),
      "configuration": .object([
        "profile": .string(configuration.profile.rawValue),
        "budgets": .object([
          "archiveBytes": renderer.integer(budgets.archiveBytes),
          "fileBytes": renderer.integer(budgets.fileBytes),
          "fileCount": renderer.integer(budgets.fileCount),
          "textureBytes": renderer.integer(budgets.textureBytes),
          "totalTextureBytes": renderer.integer(budgets.totalTextureBytes),
          "textureMaxDimension": renderer.integer(budgets.textureMaxDimension),
        ]),
        "safetyEnvelopeVersion": .integer(Int64(configuration.safetyEnvelopeVersion)),
        "gatePolicy": .object([
          "failOn": .string(configuration.gatePolicy.failOn.rawValue),
          "allowIncomplete": .bool(configuration.gatePolicy.allowIncomplete),
        ]),
        "includeSensitiveDetails": .bool(configuration.includeSensitiveDetails),
        "externalCheck": .string(configuration.externalCheck.rawValue),
      ]),
      "coverage": .object([
        "areas": .object(areas), "isComplete": .bool(report.coverage.isComplete),
      ]),
      "nativeFindings": .array(try report.nativeFindings.map(renderer.finding)),
      "externalCheck": try renderer.external(report.externalCheck),
      "operationalErrors": .array(report.operationalErrors.map(renderer.error)),
      "summary": .object([
        "native": renderer.counts(report.summary.native),
        "external": renderer.counts(report.summary.external),
        "externalOutcome": report.summary.externalOutcome.map { .string($0.rawValue) } ?? .null,
      ]),
      "validationStatus": .string(report.validationStatus.rawValue),
      "gateDecision": .string(report.gateDecision.rawValue),
      "acceptedIncomplete": .bool(report.acceptedIncomplete),
      "exitCode": .integer(Int64(report.exitCode)),
    ])
  }

  private struct Renderer {
    let sensitive: Bool

    func text(_ value: String, _ kind: DisclosureKind = .evidence) -> JSONValue {
      .string(Privacy.render(value, kind: kind, sensitive: sensitive))
    }

    func integer(_ value: Int64?) -> JSONValue { value.map(JSONValue.integer) ?? .null }

    func location(_ value: FindingLocation?) -> JSONValue {
      guard let value else { return .null }
      return .object([
        "entryName": value.entryName.map { text($0, .member) } ?? .null,
        "archiveByteOffset": value.archiveByteOffset.map(JSONValue.unsignedInteger) ?? .null,
        "layerByteOffset": value.layerByteOffset.map(JSONValue.unsignedInteger) ?? .null,
        "line": integer(value.line), "column": integer(value.column),
      ])
    }

    func finding(_ finding: Finding) throws -> JSONValue {
      var evidence: [String: JSONValue] = [:]
      for (key, value) in finding.evidence {
        let renderedKey = Privacy.render(key, kind: .evidence, sensitive: sensitive)
        // Redaction, escaping or truncation may collapse distinct caller-provided keys.
        guard evidence[renderedKey] == nil else {
          throw ValidationError.operational(.reportEncodingFailed)
        }
        switch value {
        case .string(let value): evidence[renderedKey] = text(value)
        case .integer(let value): evidence[renderedKey] = .integer(value)
        case .boolean(let value): evidence[renderedKey] = .bool(value)
        case .null: evidence[renderedKey] = .null
        }
      }
      let provenance: JSONValue
      switch finding.provenance {
      case .native(let version):
        provenance = .object(["kind": .string("native"), "validatorVersion": text(version)])
      case .usdchecker(let tool, let version, let invocationID):
        var fields: [String: JSONValue] = [
          "kind": .string("usdchecker"), "tool": text(tool),
          "version": version.map { text($0) } ?? .null,
        ]
        if sensitive {
          fields["sensitiveDetails"] = .object(["invocationID": text(invocationID)])
        }
        provenance = .object(fields)
      }
      return .object([
        "ruleID": text(finding.ruleID), "occurrenceID": text(finding.occurrenceID),
        "category": .string(finding.category.rawValue),
        "severity": .string(finding.severity.rawValue),
        "message": text(finding.message, .message), "evidence": .object(evidence),
        "location": location(finding.location), "provenance": provenance,
      ])
    }

    func external(_ external: ExternalCheck) throws -> JSONValue {
      var fields: [String: JSONValue] = [
        "requested": .bool(external.requested),
        "phase": external.phase.map { .string($0.rawValue) } ?? .null,
        "availability": .string(external.availability.rawValue),
        "version": external.version.map { text($0) } ?? .null,
        "policy": external.policy.map { .string($0.rawValue) } ?? .null,
        "status": .string(external.status.rawValue),
        "outcome": external.outcome.map { .string($0.rawValue) } ?? .null,
        "exitCode": external.exitCode.map { .integer(Int64($0)) } ?? .null,
        "signal": external.signal.map { .integer(Int64($0)) } ?? .null,
        "stdoutBytes": .integer(external.stdoutBytes),
        "stderrBytes": .integer(external.stderrBytes),
        "hasStdout": .bool(external.hasStdout), "hasStderr": .bool(external.hasStderr),
        "findings": .array(try external.findings.map(finding)),
      ]
      if sensitive {
        fields["sensitiveDetails"] =
          external.sensitiveDetails.map {
            .object([
              "arguments": .array($0.arguments.map { text($0, .toolDetail) }),
              "stdout": text($0.stdout, .toolDetail), "stderr": text($0.stderr, .toolDetail),
            ])
          } ?? .null
      }
      return .object(fields)
    }

    func error(_ error: ValidationError) -> JSONValue {
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
      return .object(["category": .string(category), "reason": .string(reason)])
    }

    func counts(_ counts: FindingCounts) -> JSONValue {
      .object([
        "bySeverity": .object(
          Dictionary(
            uniqueKeysWithValues: Severity.allCases.map {
              ($0.rawValue, .integer(Int64(counts.bySeverity[$0] ?? 0)))
            })),
        "byCategory": .object(
          Dictionary(
            uniqueKeysWithValues: FindingCategory.allCases.map {
              ($0.rawValue, .integer(Int64(counts.byCategory[$0] ?? 0)))
            })),
      ])
    }
  }
}

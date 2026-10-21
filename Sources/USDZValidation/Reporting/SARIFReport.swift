enum SARIFReport {
  static func value(_ report: ValidationReport) throws -> JSONValue {
    // Reuse the disclosure projection, including its typed evidence-key collision failure.
    let model = try object(JSONReport.value(report))
    let input = try object(model["input"])
    let summary = try object(model["summary"])
    let uri = packageURI(report.input.displayName)
    var artifact: [String: JSONValue] = ["location": .object(["uri": .string(uri)])]
    if let bytes = report.input.byteSize { artifact["length"] = .integer(bytes) }
    var properties: [String: JSONValue] = [
      "input": omittingUnavailable(.object(input)),
      "configuration": try required(model["configuration"]),
      "coverage": omittingUnavailable(try required(model["coverage"])),
      "counts": try required(summary["native"]),
      "provenance": .object([
        "kind": .string("native"), "validatorVersion": .string(report.tool.version),
      ]),
    ]
    for key in ["validationStatus", "gateDecision", "acceptedIncomplete", "exitCode"] {
      properties[key] = try required(model[key])
    }
    let errors = try array(model["operationalErrors"])
    properties["operationalErrors"] = .array(errors)
    let nativeSuccessful = report.validationStatus != .error
    var nativeInvocation: [String: JSONValue] = ["executionSuccessful": .bool(nativeSuccessful)]
    if !nativeSuccessful {
      var notifications = try errors.map { value -> JSONValue in
        let error = try object(value)
        return notification(
          "\(try string(error["category"])): \(try string(error["reason"]))")
      }
      if notifications.isEmpty {
        notifications = [notification("Native validator failed internally.")]
      }
      nativeInvocation["toolExecutionNotifications"] = .array(notifications)
    }
    var nativeDriver = try object(model["tool"])
    nativeDriver["rules"] = .array(
      RuleCatalogue.descriptors(profile: report.configuration.profile).map(descriptor))
    var runs: [JSONValue] = [
      .object([
        "tool": .object(["driver": .object(nativeDriver)]),
        "artifacts": .array([.object(artifact)]),
        "invocations": .array([.object(nativeInvocation)]),
        "results": .array(
          try array(model["nativeFindings"]).map { value in
            .deferred { try result(value, uri: uri) }
          }),
        "properties": .object(properties),
      ])
    ]
    if report.externalCheck.requested {
      var external = try object(model["externalCheck"])
      let findings = try array(external.removeValue(forKey: "findings"))
      let checker = report.externalCheck
      let successful = checker.status == .completed && checker.outcome != nil
      var invocation: [String: JSONValue] = ["executionSuccessful": .bool(successful)]
      if let exitCode = checker.exitCode { invocation["exitCode"] = .integer(Int64(exitCode)) }
      if let signal = checker.signal { invocation["exitSignalNumber"] = .integer(Int64(signal)) }
      if !successful {
        let reason = checker.status == .completed ? "missingOutcome" : checker.status.rawValue
        invocation["toolExecutionNotifications"] = .array([
          notification("usdchecker invocation did not complete: \(reason).")
        ])
      }
      var driver: [String: JSONValue] = [
        "name": .string("usdchecker"),
        "rules": .array([
          .object([
            "id": .string("USDCK-001"),
            "shortDescription": .object(["text": .string("External checker reported failure")]),
            "fullDescription": .object([
              "text": .string("Aggregate failure reported by the optional usdchecker.")
            ]),
            "defaultConfiguration": .object(["level": .string("error")]),
            "properties": .object(["category": .string("appleCompatibility")]),
          ])
        ]),
      ]
      if let version = checker.version {
        driver["version"] = .string(
          Privacy.render(
            version, kind: .evidence, sensitive: report.configuration.includeSensitiveDetails))
      }
      var externalProperties: [String: JSONValue] = [
        "profile": .string(report.configuration.profile.rawValue),
        "counts": try required(summary["external"]),
        "externalCheck": omittingUnavailable(.object(external)),
        "provenance": .object(["kind": .string("usdchecker"), "tool": .string("usdchecker")]),
      ]
      for key in ["validationStatus", "gateDecision", "acceptedIncomplete", "exitCode"] {
        externalProperties[key] = try required(model[key])
      }
      runs.append(
        .object([
          "tool": .object(["driver": .object(driver)]),
          "artifacts": .array([.object(artifact)]),
          "invocations": .array([.object(invocation)]),
          "results": .array(
            findings.map { value in .deferred { try result(value, uri: uri) } }),
          "properties": .object(externalProperties),
        ]))
    }
    return .object([
      "$schema": .string(
        "https://docs.oasis-open.org/sarif/sarif/v2.1.0/os/schemas/sarif-schema-2.1.0.json"),
      "version": .string("2.1.0"), "runs": .array(runs),
    ])
  }

  private static func result(_ value: JSONValue, uri: String) throws -> JSONValue {
    let finding = try object(value)
    var fields: [String: JSONValue] = [
      "ruleId": try required(finding["ruleID"]),
      "level": try required(finding["severity"]),
      "message": .object(["text": try required(finding["message"])]),
      "partialFingerprints": .object(["uvkOccurrence/v1": try required(finding["occurrenceID"])]),
      "properties": .object([
        "category": try required(finding["category"]),
        // Null is legitimate typed evidence; omission applies only to unavailable model fields.
        "evidence": try required(finding["evidence"]),
        "provenance": omittingUnavailable(try required(finding["provenance"])),
      ]),
    ]
    if case .object(let source) = finding["location"] {
      let location = try object(omittingUnavailable(.object(source)))
      if !location.isEmpty {
        var physical: [String: JSONValue] = ["artifactLocation": .object(["uri": .string(uri)])]
        if let offset = location["archiveByteOffset"] {
          physical["region"] = .object(["byteOffset": offset])
        }
        var logicalProperties: [String: JSONValue] = [:]
        for key in ["layerByteOffset", "line", "column"] { logicalProperties[key] = location[key] }
        var logical: [String: JSONValue] = [:]
        if let name = location["entryName"] { logical["fullyQualifiedName"] = name }
        if !logicalProperties.isEmpty { logical["properties"] = .object(logicalProperties) }
        var resultLocation: [String: JSONValue] = ["physicalLocation": .object(physical)]
        if !logical.isEmpty { resultLocation["logicalLocations"] = .array([.object(logical)]) }
        fields["locations"] = .array([.object(resultLocation)])
      }
    }
    return .object(fields)
  }

  private static func descriptor(_ rule: RuleDescriptor) -> JSONValue {
    func text(_ value: String) -> JSONValue {
      .string(Privacy.render(value, kind: .evidence, sensitive: false))
    }
    var properties: [String: JSONValue] = [
      "category": .string(rule.category.rawValue), "applicability": text(rule.applicability),
      "rationale": text(rule.rationale),
    ]
    if let family = rule.family { properties["family"] = .string(family.rawValue) }
    return .object([
      "id": text(rule.ruleID), "shortDescription": .object(["text": text(rule.title)]),
      "fullDescription": .object(["text": text(rule.description)]),
      "defaultConfiguration": .object(["level": .string(rule.defaultSeverity.rawValue)]),
      "properties": .object(properties),
    ])
  }

  private static func notification(_ message: String) -> JSONValue {
    .object(["level": .string("error"), "message": .object(["text": .string(message)])])
  }

  private static func packageURI(_ displayName: String) -> String {
    // Encode original basename bytes: display escapes would identify a different artifact.
    let scalars = displayName.unicodeScalars
    let separator = scalars.lastIndex { $0.value == 0x2f }
    let start = separator.map { scalars.index(after: $0) } ?? scalars.startIndex
    let basename = Privacy.bounded(displayName[start...], bytes: 4_096)
    let hex = Array("0123456789ABCDEF".utf8)
    let dotSegment = basename == "." || basename == ".."
    var bytes: [UInt8] = []
    for byte in basename.utf8 {
      if (0x41...0x5a).contains(byte) || (0x61...0x7a).contains(byte)
        || (0x30...0x39).contains(byte) || [0x2d, 0x5f, 0x7e].contains(byte)
        || (byte == 0x2e && !dotSegment)
      {
        bytes.append(byte)
      } else {
        bytes.append(contentsOf: [0x25, hex[Int(byte >> 4)], hex[Int(byte & 0xf)]])
      }
    }
    return String(decoding: bytes, as: UTF8.self)
  }

  private static func omittingUnavailable(_ value: JSONValue) -> JSONValue {
    switch value {
    case .object(let fields):
      return .object(
        fields.compactMapValues { value in
          if case .null = value { return nil }
          return omittingUnavailable(value)
        })
    case .array(let values): return .array(values.map(omittingUnavailable))
    case .deferred(let project): return .deferred { omittingUnavailable(try project()) }
    default: return value
    }
  }

  private static func required(_ value: JSONValue?) throws -> JSONValue {
    guard let value else { throw ValidationError.operational(.reportEncodingFailed) }
    return value
  }

  private static func object(_ value: JSONValue?) throws -> [String: JSONValue] {
    if case .deferred(let project) = value { return try object(project()) }
    guard case .object(let fields) = value else {
      throw ValidationError.operational(.reportEncodingFailed)
    }
    return fields
  }

  private static func array(_ value: JSONValue?) throws -> [JSONValue] {
    guard case .array(let values) = value else {
      throw ValidationError.operational(.reportEncodingFailed)
    }
    return values
  }

  private static func string(_ value: JSONValue?) throws -> String {
    guard case .string(let value) = value else {
      throw ValidationError.operational(.reportEncodingFailed)
    }
    return value
  }
}

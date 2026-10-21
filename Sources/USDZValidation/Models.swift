public enum Severity: String, CaseIterable, Equatable, Sendable {
  case error
  case warning
  case note
}

public enum FindingCategory: String, CaseIterable, Equatable, Sendable {
  case archiveSpecification
  case appleCompatibility
  case policy
  case validatorLimitation
}

public enum RuleFamily: String, Equatable, Sendable {
  case container
  case references
  case budgets
}

public struct RuleDescriptor: Equatable, Sendable {
  public let ruleID: String
  public let family: RuleFamily?
  public let category: FindingCategory
  public let defaultSeverity: Severity
  public let title: String
  public let description: String
  public let applicability: String
  public let rationale: String

  public init(
    ruleID: String, family: RuleFamily?, category: FindingCategory, defaultSeverity: Severity,
    title: String, description: String, applicability: String, rationale: String
  ) {
    self.ruleID = ruleID
    self.family = family
    self.category = category
    self.defaultSeverity = defaultSeverity
    self.title = title
    self.description = description
    self.applicability = applicability
    self.rationale = rationale
  }
}

/// Diagnostics enforce the evidence string retention bound before report construction.
public enum EvidenceValue: Equatable, Sendable {
  case string(String)
  case integer(Int64)
  case boolean(Bool)
  case null
}

public struct FindingLocation: Equatable, Sendable {
  public let entryName: String?
  public let archiveByteOffset: UInt64?
  public let layerByteOffset: UInt64?
  public let line: Int64?
  public let column: Int64?

  public init(
    entryName: String? = nil, archiveByteOffset: UInt64? = nil, layerByteOffset: UInt64? = nil,
    line: Int64? = nil, column: Int64? = nil
  ) {
    self.entryName = entryName
    self.archiveByteOffset = archiveByteOffset
    self.layerByteOffset = layerByteOffset
    self.line = line
    self.column = column
  }
}

public enum Provenance: Equatable, Sendable {
  case native(validatorVersion: String)
  case usdchecker(tool: String, version: String?, invocationID: String)
}

public struct Finding: Equatable, Sendable {
  public let ruleID: String
  public let occurrenceID: String
  public let category: FindingCategory
  public let severity: Severity
  public let message: String
  public let evidence: [String: EvidenceValue]
  public let location: FindingLocation?
  public let provenance: Provenance

  public init(
    ruleID: String, occurrenceID: String, category: FindingCategory, severity: Severity,
    message: String, evidence: [String: EvidenceValue], location: FindingLocation?,
    provenance: Provenance
  ) {
    self.ruleID = ruleID
    self.occurrenceID = occurrenceID
    self.category = category
    self.severity = severity
    self.message = message
    self.evidence = evidence
    self.location = location
    self.provenance = provenance
  }
}

public enum CoverageArea: String, CaseIterable, Equatable, Sendable {
  case containerStructure
  case entrySafety
  case references
  case byteBudgets
  case textureDimensions
  case appleAdvice
}

public enum CoverageState: String, Equatable, Sendable {
  case complete
  case partial
  case notRun
}

public struct CoverageReason: Equatable, Sendable {
  public let ruleID: String
  public let reasonID: String
  public let location: FindingLocation?

  public init(ruleID: String, reasonID: String, location: FindingLocation? = nil) {
    self.ruleID = ruleID
    self.reasonID = reasonID
    self.location = location
  }
}

public struct CoverageAreaResult: Equatable, Sendable {
  public let requested: Bool
  public let state: CoverageState
  public let reasons: [CoverageReason]

  public init(requested: Bool, state: CoverageState, reasons: [CoverageReason]) {
    self.requested = requested
    self.state = state
    self.reasons = reasons
  }
}

public struct Coverage: Equatable, Sendable {
  public let areas: [CoverageArea: CoverageAreaResult]

  public var isComplete: Bool {
    areas.values.allSatisfy { !$0.requested || $0.state == .complete }
  }

  public init(areas: [CoverageArea: CoverageAreaResult]) {
    self.areas = areas
  }
}

public enum ExternalPhase: String, Equatable, Sendable {
  case versionProbe
  case validation
}

public enum ExternalAvailability: String, Equatable, Sendable {
  case unknown
  case available
  case unavailable
}

/// Identifies the fixed supported adapter policy, not a native Apple compatibility verdict.
public enum ExternalPolicy: String, Equatable, Sendable {
  case general = "strict-root-package-only-v1"
  case applePortable = "strict-root-package-only-arkit-v1"
}

public enum ExternalStatus: String, Equatable, Sendable {
  case notRequested
  case unavailable
  case unsupportedVersion
  case skippedUnsafeInput
  case completed
  case launchFailed
  case timedOut
  case outputLimitExceeded
}

public enum ExternalOutcome: String, Equatable, Sendable {
  case noFailureReported
  case failureReported
}

/// Fixed process observations only; never contains an underlying OS diagnostic.
public enum ExternalTerminationReason: String, Equatable, Sendable {
  case exited, uncaughtSignal, terminated, killed, launchError, invalidRequest, captureError,
    reapError
}

public struct ExternalSensitiveDetails: Equatable, Sendable {
  public let arguments: [String]
  public let stdout: String
  public let stderr: String

  public init(arguments: [String], stdout: String, stderr: String) {
    self.arguments = arguments
    self.stdout = stdout
    self.stderr = stderr
  }
}

public struct ExternalCheck: Equatable, Sendable {
  public let requested: Bool
  public let phase: ExternalPhase?
  public let availability: ExternalAvailability
  public let version: String?
  public let policy: ExternalPolicy?
  public let status: ExternalStatus
  public let outcome: ExternalOutcome?
  public let exitCode: Int32?
  public let signal: Int32?
  public let terminationReason: ExternalTerminationReason?
  public let stdoutBytes: Int64
  public let stderrBytes: Int64
  public let hasStdout: Bool
  public let hasStderr: Bool
  public let sensitiveDetails: ExternalSensitiveDetails?
  public let findings: [Finding]

  public static let notRequested = ExternalCheck(requested: false, status: .notRequested)

  public init(
    requested: Bool, phase: ExternalPhase? = nil,
    availability: ExternalAvailability = .unknown, version: String? = nil,
    policy: ExternalPolicy? = nil, status: ExternalStatus, outcome: ExternalOutcome? = nil,
    exitCode: Int32? = nil, signal: Int32? = nil,
    terminationReason: ExternalTerminationReason? = nil,
    stdoutBytes: Int64 = 0, stderrBytes: Int64 = 0, hasStdout: Bool = false,
    hasStderr: Bool = false,
    sensitiveDetails: ExternalSensitiveDetails? = nil, findings: [Finding] = []
  ) {
    self.requested = requested
    self.phase = phase
    self.availability = availability
    self.version = version
    self.policy = policy
    self.status = status
    self.outcome = outcome
    self.exitCode = exitCode
    self.signal = signal
    self.terminationReason = terminationReason
    self.stdoutBytes = stdoutBytes
    self.stderrBytes = stderrBytes
    self.hasStdout = hasStdout
    self.hasStderr = hasStderr
    self.sensitiveDetails = sensitiveDetails
    self.findings = findings
  }
}

public enum ValidationStatus: String, Equatable, Sendable {
  case passed
  case failed
  case incomplete
  case error
}

public enum GateDecision: String, Equatable, Sendable {
  case pass
  case fail
}

public struct ReportTool: Equatable, Sendable {
  public let name: String
  public let version: String

  public init(name: String = "usdz-validator", version: String = ValidatorVersion.current) {
    self.name = name
    self.version = version
  }
}

public struct InputSensitiveDetails: Equatable, Sendable {
  public let absolutePath: String

  public init(absolutePath: String) {
    self.absolutePath = absolutePath
  }
}

public struct ReportInput: Equatable, Sendable {
  public let displayName: String
  public let byteSize: Int64?
  public let sensitiveDetails: InputSensitiveDetails?

  public init(
    displayName: String, byteSize: Int64?, sensitiveDetails: InputSensitiveDetails? = nil
  ) {
    self.displayName = displayName
    self.byteSize = byteSize
    self.sensitiveDetails = sensitiveDetails
  }
}

public struct FindingCounts: Equatable, Sendable {
  public let bySeverity: [Severity: Int]
  public let byCategory: [FindingCategory: Int]

  init(findings: [Finding]) {
    var severityCounts = Dictionary(uniqueKeysWithValues: Severity.allCases.map { ($0, 0) })
    var categoryCounts = Dictionary(uniqueKeysWithValues: FindingCategory.allCases.map { ($0, 0) })
    for finding in findings {
      severityCounts[finding.severity, default: 0] += 1
      categoryCounts[finding.category, default: 0] += 1
    }
    self.bySeverity = severityCounts
    self.byCategory = categoryCounts
  }
}

public struct ValidationSummary: Equatable, Sendable {
  public let native: FindingCounts
  public let external: FindingCounts
  public let externalOutcome: ExternalOutcome?

  init(nativeFindings: [Finding], externalCheck: ExternalCheck) {
    self.native = FindingCounts(findings: nativeFindings)
    self.external = FindingCounts(findings: externalCheck.findings)
    self.externalOutcome = externalCheck.outcome
  }
}

public struct ValidationReport: Equatable, Sendable {
  public let schemaVersion: Int = 1
  public let tool: ReportTool
  public let input: ReportInput
  public let configuration: ValidationConfiguration
  public let coverage: Coverage
  public let nativeFindings: [Finding]
  public let externalCheck: ExternalCheck
  public let operationalErrors: [ValidationError]
  public let summary: ValidationSummary
  public let validationStatus: ValidationStatus
  public let gateDecision: GateDecision
  public let acceptedIncomplete: Bool
  public let exitCode: Int32

  /// Derive all gate fields once so consumers cannot apply a second policy to the report.
  public init(
    input: ReportInput, configuration: ValidationConfiguration, coverage: Coverage,
    nativeFindings: [Finding], externalCheck: ExternalCheck = .notRequested,
    operationalErrors: [ValidationError] = [], internalFailure: Bool = false
  ) {
    let gate = configuration.gatePolicy.evaluate(
      nativeFindings: nativeFindings, coverage: coverage, externalCheck: externalCheck,
      operationalErrors: operationalErrors, internalFailure: internalFailure
    )
    self.tool = ReportTool()
    self.input = input
    self.configuration = configuration
    self.coverage = coverage
    self.nativeFindings = nativeFindings
    self.externalCheck = externalCheck
    self.operationalErrors = operationalErrors
    self.summary = ValidationSummary(nativeFindings: nativeFindings, externalCheck: externalCheck)
    self.validationStatus = gate.validationStatus
    self.gateDecision = gate.gateDecision
    self.acceptedIncomplete = gate.acceptedIncomplete
    self.exitCode = gate.exitCode
  }
}

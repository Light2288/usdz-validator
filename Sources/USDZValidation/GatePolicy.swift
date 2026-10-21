public enum FailureThreshold: String, Equatable, Sendable {
  case error
  case warning
}

public struct GatePolicy: Equatable, Sendable {
  public let failOn: FailureThreshold
  public let allowIncomplete: Bool

  public static let `default` = GatePolicy()

  public init(failOn: FailureThreshold = .error, allowIncomplete: Bool = false) {
    self.failOn = failOn
    self.allowIncomplete = allowIncomplete
  }

  /// Configuration/invocation failure is handled before a report can exist (exit 64).
  func evaluate(
    nativeFindings: [Finding], coverage: Coverage, externalCheck: ExternalCheck,
    operationalErrors: [ValidationError], internalFailure: Bool
  ) -> GateResult {
    if internalFailure
      || operationalErrors.contains(where: {
        if case .internalFailure = $0 { return true }
        return false
      })
    {
      return GateResult(validationStatus: .error, exitCode: 70)
    }
    if !operationalErrors.isEmpty {
      return GateResult(validationStatus: .error, exitCode: 3)
    }
    let blockingFinding = nativeFindings.contains {
      $0.severity == .error || (failOn == .warning && $0.severity == .warning)
    }
    if blockingFinding || (externalCheck.requested && externalCheck.outcome == .failureReported) {
      return GateResult(validationStatus: .failed, exitCode: 1)
    }
    let unsuccessfulChecker =
      externalCheck.requested
      && (externalCheck.status != .completed || externalCheck.outcome != .noFailureReported)
    let nativeGap = !coverage.isComplete
    if unsuccessfulChecker || (nativeGap && !allowIncomplete) {
      return GateResult(validationStatus: .incomplete, exitCode: 2)
    }
    return GateResult(
      validationStatus: nativeGap ? .incomplete : .passed, exitCode: 0,
      acceptedIncomplete: nativeGap && allowIncomplete
    )
  }
}

struct GateResult: Equatable, Sendable {
  let validationStatus: ValidationStatus
  let gateDecision: GateDecision
  let acceptedIncomplete: Bool
  let exitCode: Int32

  init(validationStatus: ValidationStatus, exitCode: Int32, acceptedIncomplete: Bool = false) {
    self.validationStatus = validationStatus
    self.gateDecision = exitCode == 0 ? .pass : .fail
    self.acceptedIncomplete = acceptedIncomplete
    self.exitCode = exitCode
  }
}

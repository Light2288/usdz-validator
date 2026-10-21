import Foundation

struct USDCheckerAdapter {
  private static let executable = URL(fileURLWithPath: "/usr/bin/usdchecker")
  private static let supportedVersion = "Apple USD Tools (0.25.11)"
  private let execute: (ProcessRequest) -> ProcessResult
  private let isExecutable: (URL) -> Bool

  init() {
    self.init(
      execute: { ProcessRunner().run($0) },
      isExecutable: { FileManager.default.isExecutableFile(atPath: $0.path) })
  }

  init(execute: @escaping (ProcessRequest) -> ProcessResult, isExecutable: @escaping (URL) -> Bool)
  {
    self.execute = execute
    self.isExecutable = isExecutable
  }

  func run(fileAt: URL, configuration: ValidationConfiguration, nativeEligible: Bool)
    -> ExternalCheck
  {
    guard configuration.externalCheck == .usdchecker else { return .notRequested }
    let policy: ExternalPolicy =
      configuration.profile == .applePortableV1 ? .applePortable : .general
    guard nativeEligible else {
      return ExternalCheck(requested: true, policy: policy, status: .skippedUnsafeInput)
    }
    guard isExecutable(Self.executable) else {
      return ExternalCheck(
        requested: true, availability: .unavailable, policy: policy, status: .unavailable)
    }
    let probe = request(fileAt: fileAt, arguments: ["--version"], timeout: 5, outputLimit: 16_384)
    let probed = execute(probe)
    guard status(probed) == .completed, probed.exitCode == 0 else {
      return record(
        probed, request: probe, configuration: configuration, policy: policy,
        phase: .versionProbe, version: nil,
        status: status(probed) == .completed ? .launchFailed : status(probed))
    }
    let versionText = capturedText(probed, limit: probe.outputLimit)
    let reportedVersion = [versionText.stdout, versionText.stderr].filter { !$0.isEmpty }
      .joined(separator: "\n").trimmingCharacters(in: .newlines)
    let version = reportedVersion.isEmpty ? nil : Privacy.bounded(reportedVersion, bytes: 4_096)
    guard reportedVersion == Self.supportedVersion else {
      return record(
        probed, request: probe, configuration: configuration, policy: policy,
        phase: .versionProbe, version: version, status: .unsupportedVersion)
    }
    var arguments = ["--strict", "--rootPackageOnly", "--out", "stderr"]
    if policy == .applePortable { arguments.append("--arkit") }
    arguments.append(fileAt.path)
    let validation = request(
      fileAt: fileAt, arguments: arguments, timeout: 60, outputLimit: 1_048_576)
    let validated = execute(validation)
    return record(
      validated, request: validation, configuration: configuration, policy: policy,
      phase: .validation, version: Self.supportedVersion, status: status(validated))
  }

  private func request(
    fileAt: URL, arguments: [String], timeout: TimeInterval, outputLimit: Int
  ) -> ProcessRequest {
    ProcessRequest(
      executable: Self.executable, arguments: arguments,
      environment: ["PATH": "/usr/bin:/bin", "LANG": "C", "LC_ALL": "C"],
      workingDirectory: fileAt.deletingLastPathComponent(), timeout: timeout,
      outputLimit: outputLimit)
  }

  private func status(_ result: ProcessResult) -> ExternalStatus {
    guard Int64(exactly: result.stdoutByteCount) != nil,
      Int64(exactly: result.stderrByteCount) != nil
    else { return .launchFailed }
    switch result.outcome {
    case .timedOut: return .timedOut
    case .outputLimitExceeded: return .outputLimitExceeded
    case .launchFailed: return .launchFailed
    case .completed:
      // A later deferred reap cannot promote this synchronous observation to success.
      return result.childReaped && result.terminationReason == .exited && result.signal == nil
        && result.exitCode != nil && !result.truncated ? .completed : .launchFailed
    }
  }

  private func record(
    _ result: ProcessResult, request: ProcessRequest, configuration: ValidationConfiguration,
    policy: ExternalPolicy, phase: ExternalPhase, version: String?, status: ExternalStatus
  ) -> ExternalCheck {
    let outcome: ExternalOutcome? =
      phase == .validation && status == .completed
      ? (result.exitCode == 0 ? .noFailureReported : .failureReported) : nil
    var findings: [Finding] = []
    if outcome == .failureReported, let exitCode = result.exitCode, let version {
      findings = [
        Finding(
          ruleID: "USDCK-001",
          occurrenceID: FindingIdentity.external(
            toolVersion: version, ruleID: "USDCK-001", outcome: "failureReported"),
          category: .appleCompatibility, severity: .error,
          message: "The installed checker reported a validation failure.",
          evidence: ["exitCode": .integer(Int64(exitCode))], location: nil,
          provenance: .usdchecker(
            tool: "usdchecker", version: version, invocationID: policy.rawValue))
      ]
    }
    let details: ExternalSensitiveDetails?
    if configuration.includeSensitiveDetails {
      let text = capturedText(result, limit: request.outputLimit)
      details = ExternalSensitiveDetails(
        arguments: request.arguments, stdout: text.stdout, stderr: text.stderr)
    } else {
      details = nil
    }
    let reason: ExternalTerminationReason
    switch result.terminationReason {
    case .exited: reason = .exited
    case .uncaughtSignal: reason = .uncaughtSignal
    case .terminated: reason = .terminated
    case .killed: reason = .killed
    case .launchError: reason = .launchError
    case .invalidRequest: reason = .invalidRequest
    case .captureError: reason = .captureError
    case .reapError: reason = .reapError
    }
    return ExternalCheck(
      requested: true, phase: phase, availability: .available, version: version, policy: policy,
      status: status, outcome: outcome, exitCode: result.exitCode, signal: result.signal,
      terminationReason: reason,
      stdoutBytes: Int64(exactly: result.stdoutByteCount) ?? Int64.max,
      stderrBytes: Int64(exactly: result.stderrByteCount) ?? Int64.max,
      hasStdout: result.stdoutPresent, hasStderr: result.stderrPresent,
      sensitiveDetails: details, findings: findings)
  }

  private func capturedText(_ result: ProcessResult, limit: Int) -> (stdout: String, stderr: String)
  {
    let stdout = result.stdout.prefix(limit)
    let stderr = result.stderr.prefix(limit - stdout.count)
    return (String(decoding: stdout, as: UTF8.self), String(decoding: stderr, as: UTF8.self))
  }
}

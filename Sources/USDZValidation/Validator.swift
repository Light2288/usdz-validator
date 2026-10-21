import Foundation

public struct Validator {
  private let adapter: USDCheckerAdapter
  private let inspect: (FileSnapshot, ValidationConfiguration) throws -> NativeResult

  public init() {
    self.init(adapter: USDCheckerAdapter())
  }
  init(
    adapter: USDCheckerAdapter,
    inspect: @escaping (FileSnapshot, ValidationConfiguration) throws -> NativeResult = NativeEngine
      .inspect
  ) {
    self.adapter = adapter
    self.inspect = inspect
  }

  public func validate(fileAt: URL, configuration: ValidationConfiguration) throws
    -> ValidationReport
  {
    // Recheck effective advisory values before opening input or considering a tool.
    _ = try ValidationConfiguration(
      profile: configuration.profile, budgets: configuration.budgets,
      gatePolicy: configuration.gatePolicy,
      includeSensitiveDetails: configuration.includeSensitiveDetails,
      externalCheck: configuration.externalCheck)
    do {
      let snapshot = try FileSnapshot.open(fileAt)
      let native = try inspect(snapshot, configuration)
      try snapshot.verifyUnchanged()
      guard let byteSize = Int64(exactly: native.inputByteSize) else {
        throw ValidationError.internalFailure(.invariantViolation)
      }
      let external = adapter.run(
        fileAt: fileAt, configuration: configuration,
        nativeEligible: native.containerSafeForExternal)
      try snapshot.verifyUnchanged()
      try snapshot.close()
      return ValidationReport(
        input: Self.input(fileAt, byteSize: byteSize, configuration: configuration),
        configuration: configuration, coverage: native.coverage,
        nativeFindings: native.findings, externalCheck: external)
    } catch let error as ValidationError {
      throw error
    } catch {
      throw ValidationError.internalFailure(.unexpectedFailure)
    }
  }

  fileprivate static func input(
    _ fileAt: URL, byteSize: Int64?, configuration: ValidationConfiguration
  ) -> ReportInput {
    ReportInput(
      // Keep basename bytes for SARIF artifact identity; encoders apply display escaping once.
      displayName: Privacy.bounded(fileAt.lastPathComponent, bytes: 4_096),
      byteSize: byteSize,
      sensitiveDetails: configuration.includeSensitiveDetails
        ? InputSensitiveDetails(absolutePath: Privacy.bounded(fileAt.path, bytes: 4_096)) : nil)
  }
}

extension ValidationReport {
  /// Projects operational/internal failures. Invocation/configuration errors precede reports.
  public init(failure: ValidationError, fileAt: URL, configuration: ValidationConfiguration) {
    let budgets = configuration.budgets
    let byteBudgetsRequested = [
      budgets.archiveBytes, budgets.fileBytes, budgets.fileCount,
      budgets.textureBytes, budgets.totalTextureBytes,
    ].contains { $0 != nil }
    var areas: [CoverageArea: CoverageAreaResult] = [:]
    for area in CoverageArea.allCases {
      let requested: Bool
      switch area {
      case .containerStructure, .entrySafety, .references: requested = true
      case .byteBudgets: requested = byteBudgetsRequested
      case .textureDimensions: requested = budgets.textureMaxDimension != nil
      case .appleAdvice: requested = configuration.profile == .applePortableV1
      }
      areas[area] = CoverageAreaResult(requested: requested, state: .notRun, reasons: [])
    }
    self.init(
      input: Validator.input(fileAt, byteSize: nil, configuration: configuration),
      configuration: configuration, coverage: Coverage(areas: areas), nativeFindings: [],
      externalCheck: configuration.externalCheck == .usdchecker
        ? ExternalCheck(
          requested: true,
          policy: configuration.profile == .applePortableV1 ? .applePortable : .general,
          status: .skippedUnsafeInput) : .notRequested,
      operationalErrors: [failure])
  }
}

#if UVK_PROCESS_TESTING
  extension Validator {
    /// Fixed compile-only fakes retain native inspection, adapter orchestration, and gate policy.
    public static func processTestScenario(_ scenario: String) throws -> Validator {
      guard
        ["internalFailure", "checkerUnavailable", "checkerSuccess", "checkerFailure"].contains(
          scenario)
      else {
        throw ValidationError.internalFailure(.invariantViolation)
      }
      let adapter = USDCheckerAdapter(
        execute: { request in
          let probe = request.arguments == ["--version"]
          let output = probe ? Data("Apple USD Tools (0.25.11)\n".utf8) : Data()
          return ProcessResult(
            outcome: .completed, exitCode: probe || scenario != "checkerFailure" ? 0 : 17,
            signal: nil, stdout: output, stderr: Data(), stdoutByteCount: UInt64(output.count),
            stderrByteCount: 0, truncated: false, terminationReason: .exited,
            processIdentifier: nil, childReaped: true)
        }, isExecutable: { _ in scenario != "checkerUnavailable" })
      if scenario == "internalFailure" {
        return Validator(
          adapter: adapter,
          inspect: { _, _ in throw ValidationError.internalFailure(.invariantViolation) })
      }
      return Validator(adapter: adapter)
    }
  }
#endif

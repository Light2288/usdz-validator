import XCTest

@testable import USDZValidation

final class GatePolicyTests: XCTestCase {
  func testPrecedenceAndAcceptance() {
    struct Case {
      let name: String
      let policy: GatePolicy
      let findings: [Finding]
      let coverage: Coverage
      let external: ExternalCheck
      let errors: [ValidationError]
      let internalFailure: Bool
      let status: ValidationStatus
      let exitCode: Int32
      let acceptedIncomplete: Bool
    }

    let complete = coverage(state: .complete)
    let gap = coverage(state: .partial)
    let unrun = coverage(state: .notRun)
    let accepting = GatePolicy(allowIncomplete: true)
    let warningGate = GatePolicy(failOn: .warning, allowIncomplete: true)
    let operational = ValidationError.operational(.inputReadFailed)
    let cases: [Case] = [
      Case(
        name: "70 outranks 3, 1 and 2", policy: accepting, findings: [finding(.error)],
        coverage: gap, external: external(.unavailable), errors: [operational],
        internalFailure: true, status: .error, exitCode: 70, acceptedIncomplete: false),
      Case(
        name: "typed internal failure", policy: .default, findings: [], coverage: complete,
        external: .notRequested, errors: [.internalFailure(.unexpectedFailure)],
        internalFailure: false, status: .error, exitCode: 70, acceptedIncomplete: false),
      Case(
        name: "3 outranks 1 and 2", policy: accepting, findings: [finding(.error)],
        coverage: gap, external: external(.unavailable), errors: [operational],
        internalFailure: false, status: .error, exitCode: 3, acceptedIncomplete: false),
      Case(
        name: "1 outranks 2", policy: .default, findings: [finding(.error)],
        coverage: gap, external: external(.unavailable), errors: [],
        internalFailure: false, status: .failed, exitCode: 1, acceptedIncomplete: false),
      Case(
        name: "acceptance cannot override errors", policy: accepting,
        findings: [finding(.error)], coverage: gap, external: .notRequested, errors: [],
        internalFailure: false, status: .failed, exitCode: 1, acceptedIncomplete: false),
      Case(
        name: "warnings pass error threshold", policy: .default, findings: [finding(.warning)],
        coverage: complete, external: .notRequested, errors: [], internalFailure: false,
        status: .passed, exitCode: 0, acceptedIncomplete: false),
      Case(
        name: "warnings block warning threshold despite acceptance", policy: warningGate,
        findings: [finding(.warning)], coverage: gap, external: .notRequested, errors: [],
        internalFailure: false, status: .failed, exitCode: 1, acceptedIncomplete: false),
      Case(
        name: "errors block warning threshold", policy: warningGate, findings: [finding(.error)],
        coverage: complete, external: .notRequested, errors: [], internalFailure: false,
        status: .failed, exitCode: 1, acceptedIncomplete: false),
      Case(
        name: "notes never block", policy: warningGate, findings: [finding(.note)],
        coverage: complete, external: .notRequested, errors: [], internalFailure: false,
        status: .passed, exitCode: 0, acceptedIncomplete: false),
      Case(
        name: "unaccepted native gap", policy: .default, findings: [],
        coverage: gap, external: .notRequested, errors: [], internalFailure: false,
        status: .incomplete, exitCode: 2, acceptedIncomplete: false),
      Case(
        name: "requested area not run is incomplete", policy: .default, findings: [],
        coverage: unrun, external: .notRequested, errors: [], internalFailure: false,
        status: .incomplete, exitCode: 2, acceptedIncomplete: false),
      Case(
        name: "accepted native gap", policy: accepting, findings: [finding(.warning)],
        coverage: gap, external: .notRequested, errors: [], internalFailure: false,
        status: .incomplete, exitCode: 0, acceptedIncomplete: true),
      Case(
        name: "unselected areas are not gaps", policy: .default, findings: [],
        coverage: coverage(state: .complete, unselectedState: .partial),
        external: .notRequested, errors: [], internalFailure: false,
        status: .passed, exitCode: 0, acceptedIncomplete: false),
      Case(
        name: "completed successful checker", policy: .default, findings: [],
        coverage: complete, external: external(.completed, outcome: .noFailureReported),
        errors: [], internalFailure: false, status: .passed, exitCode: 0,
        acceptedIncomplete: false),
      Case(
        name: "checker cannot upgrade native coverage", policy: .default, findings: [],
        coverage: gap, external: external(.completed, outcome: .noFailureReported),
        errors: [], internalFailure: false, status: .incomplete, exitCode: 2,
        acceptedIncomplete: false),
      Case(
        name: "tool failure blocks despite acceptance", policy: accepting, findings: [],
        coverage: gap, external: external(.completed, outcome: .failureReported),
        errors: [], internalFailure: false, status: .failed, exitCode: 1,
        acceptedIncomplete: false),
    ]

    for testCase in cases {
      let result = testCase.policy.evaluate(
        nativeFindings: testCase.findings, coverage: testCase.coverage,
        externalCheck: testCase.external, operationalErrors: testCase.errors,
        internalFailure: testCase.internalFailure
      )
      XCTAssertEqual(result.validationStatus, testCase.status, testCase.name)
      XCTAssertEqual(result.exitCode, testCase.exitCode, testCase.name)
      XCTAssertEqual(result.gateDecision, testCase.exitCode == 0 ? .pass : .fail, testCase.name)
      XCTAssertEqual(result.acceptedIncomplete, testCase.acceptedIncomplete, testCase.name)
      if result.gateDecision == .fail {
        XCTAssertFalse(result.acceptedIncomplete, testCase.name)
      }
    }

    for status: ExternalStatus in [
      .notRequested, .unavailable, .unsupportedVersion, .skippedUnsafeInput,
      .launchFailed, .timedOut, .outputLimitExceeded, .completed,
    ] {
      // Requested records without a completed no-failure outcome cannot be accepted.
      let requestedUnavailable = accepting.evaluate(
        nativeFindings: [], coverage: gap, externalCheck: external(status),
        operationalErrors: [], internalFailure: false
      )
      XCTAssertEqual(requestedUnavailable.exitCode, 2, status.rawValue)
      XCTAssertEqual(requestedUnavailable.validationStatus, .incomplete, status.rawValue)
      XCTAssertFalse(requestedUnavailable.acceptedIncomplete, status.rawValue)
    }

    let acceptedGap = accepting.evaluate(
      nativeFindings: [], coverage: gap, externalCheck: .notRequested,
      operationalErrors: [], internalFailure: false
    )
    XCTAssertEqual(acceptedGap.exitCode, 0)
    XCTAssertEqual(acceptedGap.validationStatus, .incomplete)
    XCTAssertEqual(acceptedGap.gateDecision, .pass)
    XCTAssertTrue(acceptedGap.acceptedIncomplete)
  }

  func testReportDerivesGateAndSeparatesCounts() throws {
    let gap = coverage(state: .partial)
    let toolFailure = Finding(
      ruleID: "USDCK-001", occurrenceID: "tool-occurrence", category: .policy,
      severity: .error, message: "Checker reported failure", evidence: ["exitCode": .integer(1)],
      location: nil,
      provenance: .usdchecker(
        tool: "usdchecker", version: "Apple USD Tools (0.25.11)", invocationID: "general-v1"
      )
    )
    let externalCheck = ExternalCheck(
      requested: true, phase: .validation, availability: .available,
      version: "Apple USD Tools (0.25.11)", policy: .general,
      status: .completed, outcome: .failureReported, exitCode: 1,
      findings: [toolFailure]
    )
    let report = ValidationReport(
      input: ReportInput(displayName: "asset.usdz", byteSize: 123),
      configuration: try ValidationConfiguration(gatePolicy: GatePolicy(allowIncomplete: true)),
      coverage: gap, nativeFindings: [finding(.warning)], externalCheck: externalCheck
    )
    XCTAssertEqual(report.schemaVersion, 1)
    XCTAssertEqual(report.tool.name, "usdz-validator")
    XCTAssertEqual(report.tool.version, "0.1.0")
    XCTAssertEqual(report.coverage, gap)
    XCTAssertEqual(report.validationStatus, .failed)
    XCTAssertEqual(report.gateDecision, .fail)
    XCTAssertFalse(report.acceptedIncomplete)
    XCTAssertEqual(report.exitCode, 1)
    XCTAssertEqual(report.summary.native.bySeverity[.error], 0)
    XCTAssertEqual(report.summary.native.bySeverity[.warning], 1)
    XCTAssertEqual(report.summary.native.byCategory[.policy], 1)
    XCTAssertEqual(report.summary.external.bySeverity[.error], 1)
    XCTAssertEqual(report.summary.external.bySeverity[.warning], 0)
    XCTAssertEqual(report.summary.externalOutcome, .failureReported)
    XCTAssertEqual(report.operationalErrors, [])
    XCTAssertNil(report.input.sensitiveDetails)
    XCTAssertNil(report.externalCheck.sensitiveDetails)
  }

  private func finding(_ severity: Severity) -> Finding {
    Finding(
      ruleID: "UVK-TEST-001", occurrenceID: "test-occurrence", category: .policy,
      severity: severity, message: "Test finding", evidence: [:], location: nil,
      provenance: .native(validatorVersion: "0.1.0")
    )
  }

  private func coverage(
    state: CoverageState, unselectedState: CoverageState = .notRun
  ) -> Coverage {
    Coverage(areas: [
      .containerStructure: CoverageAreaResult(requested: true, state: state, reasons: []),
      .appleAdvice: CoverageAreaResult(requested: false, state: unselectedState, reasons: []),
    ])
  }

  private func external(
    _ status: ExternalStatus, outcome: ExternalOutcome? = nil
  ) -> ExternalCheck {
    ExternalCheck(
      requested: true, phase: .validation, availability: .available,
      version: "Apple USD Tools (0.25.11)", policy: .general, status: status, outcome: outcome
    )
  }
}

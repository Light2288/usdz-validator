import Foundation
import XCTest

@testable import USDZValidation

final class USDCheckerAdapterTests: XCTestCase {
  private let file = URL(fileURLWithPath: "/private/asset folder/input.usdz")
  private let supported = "Apple USD Tools (0.25.11)"

  func testDisabledNeverProbes() throws {
    var probes = 0
    var executions = 0
    let adapter = USDCheckerAdapter(
      execute: { _ in
        executions += 1
        return self.result()
      },
      isExecutable: { _ in
        probes += 1
        return true
      })
    for eligible in [false, true] {
      XCTAssertEqual(
        adapter.run(
          fileAt: file, configuration: try ValidationConfiguration(), nativeEligible: eligible),
        .notRequested)
    }
    XCTAssertEqual(probes, 0)
    XCTAssertEqual(executions, 0)
  }

  func testEveryAdapterState() throws {
    let configuration = try ValidationConfiguration(externalCheck: .usdchecker)
    var probes = 0
    var calls = 0
    let unavailable = USDCheckerAdapter(
      execute: { _ in
        calls += 1
        return self.result()
      },
      isExecutable: { url in
        probes += 1
        XCTAssertEqual(url.path, "/usr/bin/usdchecker")
        return false
      })
    let unsafe = unavailable.run(fileAt: file, configuration: configuration, nativeEligible: false)
    assertState(unsafe, .skippedUnsafeInput, nil, .unknown, nil, nil)
    XCTAssertEqual(probes, 0)
    let missing = unavailable.run(fileAt: file, configuration: configuration, nativeEligible: true)
    assertState(missing, .unavailable, nil, .unavailable, nil, nil)
    XCTAssertEqual(probes, 1)
    XCTAssertEqual(calls, 0)

    let failures: [(String, ProcessResult, ExternalStatus)] = [
      (
        "launch", result(.launchFailed, exit: nil, reason: .launchError, reaped: false),
        .launchFailed
      ),
      (
        "signal", result(.launchFailed, exit: nil, signal: 9, reason: .uncaughtSignal),
        .launchFailed
      ),
      ("timeout", result(.timedOut, exit: nil, reason: .terminated), .timedOut),
      ("output", result(.outputLimitExceeded, exit: nil, reason: .killed), .outputLimitExceeded),
      ("capture", result(reason: .captureError), .launchFailed),
      ("reap", result(reason: .reapError, reaped: false), .launchFailed),
      ("unreaped", result(reaped: false), .launchFailed),
      ("missing exit", result(exit: nil), .launchFailed),
    ]
    for (name, process, status) in failures {
      for phase: ExternalPhase in [.versionProbe, .validation] {
        var requests: [ProcessRequest] = []
        let adapter = USDCheckerAdapter(
          execute: { request in
            requests.append(request)
            return requests.count == 1 && phase == .validation
              ? self.result(stdout: self.supported + "\n") : process
          }, isExecutable: { _ in true })
        let check = adapter.run(fileAt: file, configuration: configuration, nativeEligible: true)
        assertState(check, status, phase, .available, phase == .validation ? supported : nil, nil)
        XCTAssertEqual(check.exitCode, process.exitCode, name)
        XCTAssertEqual(check.signal, process.signal, name)
        if name == "reap" { XCTAssertEqual(check.terminationReason, .reapError) }
        if name == "capture" { XCTAssertEqual(check.terminationReason, .captureError) }
        if name == "signal" { XCTAssertEqual(check.terminationReason, .uncaughtSignal) }
        XCTAssertTrue(check.findings.isEmpty, name)
        XCTAssertEqual(requests.count, phase == .validation ? 2 : 1, name)
      }
    }
    for version in ["", "0.25.11", "Apple USD Tools (0.25.12)", "Apple USD Tools (0.25.11) extra"] {
      var executions = 0
      let adapter = USDCheckerAdapter(
        execute: { _ in
          executions += 1
          return self.result(stdout: version)
        },
        isExecutable: { _ in true })
      let check = adapter.run(fileAt: file, configuration: configuration, nativeEligible: true)
      assertState(
        check, .unsupportedVersion, .versionProbe, .available, version.isEmpty ? nil : version, nil)
      XCTAssertEqual(executions, 1)
    }
    let failedProbe = USDCheckerAdapter(
      execute: { _ in self.result(exit: 1, stdout: self.supported) }, isExecutable: { _ in true })
    assertState(
      failedProbe.run(fileAt: file, configuration: configuration, nativeEligible: true),
      .launchFailed, .versionProbe, .available, nil, nil)
  }

  func testSupportedInvocationUsesFixedContextAndLimits() throws {
    for profile: Profile in [.generalV1, .applePortableV1] {
      var requests: [ProcessRequest] = []
      let adapter = USDCheckerAdapter(
        execute: { request in
          requests.append(request)
          return self.result(stdout: requests.count == 1 ? self.supported + "\n" : "success")
        }, isExecutable: { _ in true })
      let check = adapter.run(
        fileAt: file,
        configuration: try ValidationConfiguration(profile: profile, externalCheck: .usdchecker),
        nativeEligible: true)
      assertState(
        check, .completed, .validation, .available, supported, .noFailureReported,
        policy: profile == .generalV1 ? .general : .applePortable)
      XCTAssertEqual(check.policy, profile == .generalV1 ? .general : .applePortable)
      XCTAssertEqual(check.exitCode, 0)
      XCTAssertEqual(check.terminationReason, .exited)
      XCTAssertEqual(check.stdoutBytes, 7)
      XCTAssertTrue(check.hasStdout)
      XCTAssertFalse(check.hasStderr)
      XCTAssertNil(check.sensitiveDetails)
      XCTAssertTrue(check.findings.isEmpty)
      XCTAssertEqual(requests.count, 2)
      guard requests.count == 2 else { continue }
      for request in requests {
        XCTAssertEqual(request.executable.path, "/usr/bin/usdchecker")
        XCTAssertEqual(request.environment, ["PATH": "/usr/bin:/bin", "LANG": "C", "LC_ALL": "C"])
        XCTAssertEqual(request.workingDirectory, file.deletingLastPathComponent())
      }
      XCTAssertEqual(requests[0].arguments, ["--version"])
      XCTAssertEqual(requests[0].timeout, 5)
      XCTAssertEqual(requests[0].outputLimit, 16_384)
      XCTAssertEqual(
        requests[1].arguments,
        ["--strict", "--rootPackageOnly", "--out", "stderr"]
          + (profile == .applePortableV1 ? ["--arkit"] : []) + [file.path])
      XCTAssertEqual(requests[1].timeout, 60)
      XCTAssertEqual(requests[1].outputLimit, 1_048_576)
    }
  }

  func testOpaqueFailureProvenanceAndSensitiveCapture() throws {
    var previousID: String?
    for sensitive in [false, true] {
      for diagnostic in [
        "/Users/private/problem.usd: ERROR at line 99", "totally different\u{001b}text",
      ] {
        var calls = 0
        let adapter = USDCheckerAdapter(
          execute: { _ in
            calls += 1
            return calls == 1
              ? self.result(stdout: self.supported + "\n")
              : self.result(exit: 17, stdout: diagnostic, stderr: "opaque stderr")
          }, isExecutable: { _ in true })
        let check = adapter.run(
          fileAt: file,
          configuration: try ValidationConfiguration(
            includeSensitiveDetails: sensitive, externalCheck: .usdchecker), nativeEligible: true)
        assertState(check, .completed, .validation, .available, supported, .failureReported)
        XCTAssertEqual(check.exitCode, 17)
        XCTAssertEqual(check.findings.count, 1)
        let finding = try XCTUnwrap(check.findings.first)
        XCTAssertEqual(finding.ruleID, "USDCK-001")
        XCTAssertEqual(finding.category, .appleCompatibility)
        XCTAssertEqual(finding.severity, .error)
        XCTAssertEqual(finding.evidence["exitCode"], .integer(17))
        XCTAssertNil(finding.location)
        XCTAssertFalse(finding.message.contains(diagnostic))
        if let previousID { XCTAssertEqual(finding.occurrenceID, previousID) }
        previousID = finding.occurrenceID
        guard case .usdchecker(let tool, let version, let invocation) = finding.provenance else {
          XCTFail("External aggregate must retain external provenance")
          continue
        }
        XCTAssertEqual(tool, "usdchecker")
        XCTAssertEqual(version, supported)
        XCTAssertEqual(invocation, ExternalPolicy.general.rawValue)
        if sensitive {
          XCTAssertEqual(check.sensitiveDetails?.stdout, diagnostic)
          XCTAssertEqual(check.sensitiveDetails?.stderr, "opaque stderr")
          XCTAssertEqual(check.sensitiveDetails?.arguments.last, file.path)
        } else {
          XCTAssertNil(check.sensitiveDetails)
        }
      }
    }
  }

  func testUnrepresentableDiagnosticCountsFailWithoutTrapping() throws {
    for phase: ExternalPhase in [.versionProbe, .validation] {
      var calls = 0
      let overflowing = ProcessResult(
        outcome: .completed, exitCode: 0, signal: nil, stdout: Data(), stderr: Data(),
        stdoutByteCount: UInt64.max, stderrByteCount: UInt64(Int64.max) + 1, truncated: false,
        terminationReason: .exited, processIdentifier: 42, childReaped: true)
      let adapter = USDCheckerAdapter(
        execute: { _ in
          calls += 1
          return calls == 1 && phase == .validation
            ? self.result(stdout: self.supported) : overflowing
        }, isExecutable: { _ in true })
      let check = adapter.run(
        fileAt: file, configuration: try ValidationConfiguration(externalCheck: .usdchecker),
        nativeEligible: true)
      XCTAssertEqual(check.status, .launchFailed)
      XCTAssertEqual(check.phase, phase)
      XCTAssertNil(check.outcome)
      XCTAssertEqual(check.stdoutBytes, Int64.max)
      XCTAssertEqual(check.stderrBytes, Int64.max)
      XCTAssertTrue(check.hasStdout)
      XCTAssertTrue(check.hasStderr)
    }
  }

  private func assertState(
    _ check: ExternalCheck, _ status: ExternalStatus, _ phase: ExternalPhase?,
    _ availability: ExternalAvailability, _ version: String?, _ outcome: ExternalOutcome?,
    policy: ExternalPolicy = .general,
    file: StaticString = #filePath, line: UInt = #line
  ) {
    XCTAssertTrue(check.requested, file: file, line: line)
    XCTAssertEqual(check.status, status, file: file, line: line)
    XCTAssertEqual(check.phase, phase, file: file, line: line)
    XCTAssertEqual(check.availability, availability, file: file, line: line)
    XCTAssertEqual(check.version, version, file: file, line: line)
    XCTAssertEqual(check.outcome, outcome, file: file, line: line)
    XCTAssertEqual(check.policy, policy, file: file, line: line)
  }

  private func result(
    _ outcome: ProcessResult.Outcome = .completed, exit: Int32? = 0, signal: Int32? = nil,
    stdout: String = "", stderr: String = "", reason: ProcessResult.TerminationReason = .exited,
    reaped: Bool = true
  ) -> ProcessResult {
    ProcessResult(
      outcome: outcome, exitCode: exit, signal: signal, stdout: Data(stdout.utf8),
      stderr: Data(stderr.utf8),
      stdoutByteCount: UInt64(stdout.utf8.count), stderrByteCount: UInt64(stderr.utf8.count),
      truncated: outcome == .outputLimitExceeded, terminationReason: reason,
      processIdentifier: outcome == .launchFailed && !reaped ? nil : 42, childReaped: reaped)
  }
}

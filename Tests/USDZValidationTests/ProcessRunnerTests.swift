import Darwin
import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

final class ProcessRunnerTests: XCTestCase {
  func testConcurrentPipesAndCombinedCap() {
    bounded {
      for _ in 0..<3 {
        let complete = ProcessRunner().run(
          Self.request(ProcessScenarios.concurrentOutput, limit: 524_288))
        XCTAssertEqual(complete.outcome, .completed)
        XCTAssertEqual(complete.stdout.count, 262_144)
        XCTAssertEqual(complete.stderr.count, 262_144)
        XCTAssertEqual(complete.stdoutByteCount, 262_144)
        XCTAssertEqual(complete.stderrByteCount, 262_144)
        XCTAssertFalse(complete.truncated)
        Self.assertReaped(complete)
        for cap in [16_384, 1_048_576] {
          let request = Self.request(ProcessScenarios.concurrentOutput, limit: cap)
          let result = ProcessRunner().run(request)
          XCTAssertEqual(result.outcome, cap == 16_384 ? .outputLimitExceeded : .completed)
          XCTAssertLessThanOrEqual(result.stdout.count + result.stderr.count, request.outputLimit)
          XCTAssertEqual(result.truncated, cap == 16_384)
          Self.assertReaped(result)
        }
      }
    }
  }

  func testTimeoutKillAndReap() {
    bounded {
      for _ in 0..<3 {
        let start = ContinuousClock.now
        let result = ProcessRunner().run(
          Self.request(ProcessScenarios.ignoresTermination, timeout: 0.05))
        XCTAssertEqual(result.outcome, .timedOut)
        XCTAssertEqual(result.signal, SIGKILL)
        XCTAssertEqual(result.terminationReason, .killed)
        XCTAssertTrue(result.stdoutPresent)
        XCTAssertLessThan(start.duration(to: .now), .seconds(1))
        Self.assertReaped(result)
      }
    }
  }

  func testHeldWriterHasBoundedDrainAndCancellation() {
    bounded {
      var out: [Int32] = [0, 0]
      var err: [Int32] = [0, 0]
      guard pipe(&out) == 0 else {
        XCTFail("stdout pipe creation")
        return
      }
      guard pipe(&err) == 0 else {
        close(out[0])
        close(out[1])
        XCTFail("stderr pipe creation")
        return
      }
      defer {
        close(out[1])
        close(err[1])
      }
      let capture = ProcessPipeCapture(stdout: out[0], stderr: err[0], outputLimit: 8)
      defer { capture.cancel() }
      let outBytes: [UInt8] = [97, 98, 99, 100]
      let errBytes: [UInt8] = [69, 70, 71, 72, 73]
      XCTAssertEqual(write(out[1], outBytes, outBytes.count), 4)
      XCTAssertEqual(write(err[1], errBytes, errBytes.count), 5)
      let start = ContinuousClock.now
      XCTAssertFalse(capture.finish(within: 0.03))
      XCTAssertEqual(capture.stdout.count + capture.stderr.count, 8)
      XCTAssertEqual(capture.stdoutByteCount + capture.stderrByteCount, 9)
      XCTAssertTrue(capture.overflow)
      XCTAssertLessThan(start.duration(to: .now), .seconds(0.5))
      errno = 0
      XCTAssertEqual(fcntl(out[0], F_GETFD), -1)
      XCTAssertEqual(errno, EBADF)
      errno = 0
      XCTAssertEqual(fcntl(err[0], F_GETFD), -1)
      XCTAssertEqual(errno, EBADF)
      capture.cancel()
    }
  }

  func testLaunchFailureAndAbnormalSignal() {
    bounded {
      let absent = ProcessRequest(
        executable: URL(fileURLWithPath: "/nonexistent/uvk-task18"), arguments: [],
        environment: [:],
        workingDirectory: URL(fileURLWithPath: "/"), timeout: 0.2, outputLimit: 8)
      let missing = ProcessRunner().run(absent)
      XCTAssertEqual(missing.outcome, .launchFailed)
      XCTAssertEqual(missing.terminationReason, .launchError)
      XCTAssertNil(missing.processIdentifier)
      for request in [
        Self.request(ProcessScenarios.immediateExit, timeout: .nan),
        Self.request(ProcessScenarios.immediateExit, limit: -1),
      ] {
        let invalid = ProcessRunner().run(request)
        XCTAssertEqual(invalid.outcome, .launchFailed)
        XCTAssertEqual(invalid.terminationReason, .invalidRequest)
        XCTAssertNil(invalid.processIdentifier)
      }
      let signal = ProcessRunner().run(Self.request(ProcessScenarios.abnormalSignal))
      XCTAssertEqual(signal.outcome, .launchFailed)
      XCTAssertEqual(signal.signal, SIGKILL)
      XCTAssertEqual(signal.terminationReason, .uncaughtSignal)
      Self.assertReaped(signal)
    }
  }

  func testExactCaptureBoundaryAndOverflowInBothAdapterPhases() {
    bounded {
      for _ in 0..<5 {
        let exact = ProcessRunner().run(Self.request(ProcessScenarios.exactBoundary, limit: 8))
        XCTAssertEqual(exact.outcome, .completed)
        XCTAssertEqual(exact.stdout, Data("abcd".utf8))
        XCTAssertEqual(exact.stderr, Data("EFGH".utf8))
        XCTAssertFalse(exact.truncated)
        let beyond = ProcessRunner().run(Self.request(ProcessScenarios.oneByteOverflow, limit: 8))
        XCTAssertEqual(beyond.outcome, .outputLimitExceeded)
        XCTAssertEqual(beyond.stdout.count + beyond.stderr.count, 8)
        XCTAssertEqual(beyond.stdoutByteCount + beyond.stderrByteCount, 9)
        XCTAssertTrue(beyond.truncated)
      }
      let empty = ProcessRunner().run(Self.request(ProcessScenarios.immediateExit, limit: 0))
      XCTAssertEqual(empty.outcome, .completed)
      XCTAssertFalse(empty.stdoutPresent)
      XCTAssertFalse(empty.stderrPresent)
      let zero = ProcessRunner().run(Self.request(ProcessScenarios.oneByteOverflow, limit: 0))
      XCTAssertEqual(zero.outcome, .outputLimitExceeded)
      XCTAssertTrue(zero.stdout.isEmpty && zero.stderr.isEmpty)
      for limit in [16_384, 1_048_576] {
        // The same fixed producer runs enough times in one shell to exceed either phase cap.
        let script =
          "j=0; while [ \"$j\" -lt 3 ]; do " + ProcessScenarios.concurrentOutput
          + "; j=$((j + 1)); done"
        let result = ProcessRunner().run(Self.request(script, limit: limit))
        XCTAssertEqual(result.outcome, .outputLimitExceeded)
        XCTAssertEqual(result.stdout.count + result.stderr.count, limit)
        Self.assertReaped(result)
      }
    }
  }

  func testExactEnvironmentWorkingDirectoryAndExitCode() {
    bounded {
      let context = ProcessRequest(
        executable: URL(fileURLWithPath: "/bin/sh"),
        arguments: ["-c", ProcessScenarios.exactContext],
        environment: ["ONLY": "literal"], workingDirectory: URL(fileURLWithPath: "/private/tmp"),
        timeout: 1, outputLimit: 100)
      let result = ProcessRunner().run(context)
      XCTAssertEqual(result.outcome, .completed)
      XCTAssertEqual(result.stdout, Data("literal|unset|/private/tmp".utf8))
      let nonzero = ProcessRunner().run(Self.request(ProcessScenarios.successfulExit))
      XCTAssertEqual(nonzero.outcome, .completed)
      XCTAssertEqual(nonzero.exitCode, 7)
      XCTAssertEqual(nonzero.stdout, Data("out".utf8))
      XCTAssertEqual(nonzero.stderr, Data("err".utf8))
      Self.assertReaped(nonzero)
    }
  }

  func testSimultaneousObservationsHaveFixedPrecedence() {
    bounded {
      for _ in 0..<20 {
        XCTAssertEqual(
          ProcessRunner.observedOutcome(overflow: true, timedOut: true, completed: true),
          .outputLimitExceeded)
        XCTAssertEqual(
          ProcessRunner.observedOutcome(overflow: false, timedOut: true, completed: true), .timedOut
        )
        XCTAssertEqual(
          ProcessRunner.observedOutcome(overflow: false, timedOut: false, completed: true),
          .completed)
        let result = ProcessRunner().run(Self.request(ProcessScenarios.immediateExit, timeout: 0))
        XCTAssertEqual(result.outcome, .timedOut)
        Self.assertReaped(result)
      }
    }
  }

  private static func request(_ script: String, timeout: TimeInterval = 2, limit: Int = 1024)
    -> ProcessRequest
  {
    ProcessRequest(
      executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", script],
      environment: ["PATH": "/usr/bin:/bin", "LANG": "C", "LC_ALL": "C"],
      workingDirectory: URL(fileURLWithPath: "/"), timeout: timeout, outputLimit: limit)
  }

  private static func assertReaped(
    _ result: ProcessResult, file: StaticString = #filePath, line: UInt = #line
  ) {
    XCTAssertTrue(result.childReaped, file: file, line: line)
    guard let pid = result.processIdentifier else {
      XCTFail("missing child PID", file: file, line: line)
      return
    }
    var status: Int32 = 0
    errno = 0
    XCTAssertEqual(waitpid(pid, &status, WNOHANG), -1, file: file, line: line)
    XCTAssertEqual(errno, ECHILD, file: file, line: line)
  }

  private func bounded(
    _ body: @escaping @Sendable () -> Void, file: StaticString = #filePath, line: UInt = #line
  ) {
    let done = expectation(description: "bounded process scenario")
    DispatchQueue.global().async {
      body()
      done.fulfill()
    }
    wait(for: [done], timeout: 15)
  }
}

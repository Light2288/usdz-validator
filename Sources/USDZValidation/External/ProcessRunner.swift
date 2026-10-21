import Darwin
import Foundation

struct ProcessRequest: Sendable {
  let executable: URL
  let arguments: [String]
  let environment: [String: String]
  let workingDirectory: URL
  let timeout: TimeInterval
  let outputLimit: Int
}

struct ProcessResult: Sendable {
  enum Outcome: Sendable { case completed, launchFailed, timedOut, outputLimitExceeded }
  enum TerminationReason: Sendable {
    case exited, uncaughtSignal, terminated, killed, launchError, invalidRequest, captureError,
      reapError
  }
  let outcome: Outcome
  let exitCode: Int32?
  let signal: Int32?
  let stdout: Data
  let stderr: Data
  let stdoutByteCount: UInt64
  let stderrByteCount: UInt64
  let truncated: Bool
  let terminationReason: TerminationReason
  let processIdentifier: Int32?
  let childReaped: Bool
  var stdoutPresent: Bool { stdoutByteCount > 0 }
  var stderrPresent: Bool { stderrByteCount > 0 }
}

/// A single synchronous coordinator owns the child, both readers, the combined counter and
/// terminal observations. No callback can race another callback to choose the result.
struct ProcessRunner {
  private static let terminationGrace: TimeInterval = 0.1
  private static let reapGrace: TimeInterval = 1
  private static let drainGrace: TimeInterval = 0.2

  func run(_ request: ProcessRequest) -> ProcessResult {
    guard request.outputLimit >= 0, request.timeout.isFinite, request.timeout >= 0,
      !request.executable.path.utf8.contains(0), !request.workingDirectory.path.utf8.contains(0),
      request.arguments.allSatisfy({ !$0.utf8.contains(0) }),
      request.environment.allSatisfy({
        !$0.key.isEmpty && !$0.key.contains("=") && !$0.key.utf8.contains(0)
          && !$0.value.utf8.contains(0)
      })
    else { return failure(.invalidRequest) }

    var out: [Int32] = [-1, -1]
    var err: [Int32] = [-1, -1]
    guard pipe(&out) == 0 else { return failure(.launchError) }
    guard pipe(&err) == 0 else {
      close(out[0])
      close(out[1])
      return failure(.launchError)
    }
    let capture = ProcessPipeCapture(
      stdout: out[0], stderr: err[0], outputLimit: request.outputLimit)
    defer { capture.cancel() }
    var pid: pid_t = 0
    let launchError = spawn(request, stdout: out[1], stderr: err[1], pid: &pid)
    close(out[1])
    close(err[1])
    guard launchError == 0 else { return failure(.launchError) }

    let deadline = ProcessInfo.processInfo.systemUptime + request.timeout
    var status: Int32 = 0
    var reaped = false
    var reapFailed = false
    var timedOut = false
    var outcome: ProcessResult.Outcome?
    while outcome == nil {
      capture.drainAvailable()
      let waited = waitpid(pid, &status, WNOHANG)
      reaped = waited == pid
      reapFailed = waited < 0 && errno != EINTR
      timedOut = ProcessInfo.processInfo.systemUptime >= deadline
      outcome = Self.observedOutcome(
        overflow: capture.overflow, timedOut: timedOut, completed: reaped)
      if reapFailed || capture.failed { outcome = outcome ?? .launchFailed }
      if outcome == nil { capture.waitForReadiness() }
    }

    var sentKill = false
    var sentTerm = false
    if !reaped && !reapFailed {
      // Signal only the still-unreaped PID; an exited child cannot have its PID reused yet.
      sentTerm = kill(pid, SIGTERM) == 0
      let killDeadline = ProcessInfo.processInfo.systemUptime + Self.terminationGrace
      let reapDeadline = killDeadline + Self.reapGrace
      while !reaped && !reapFailed {
        capture.drainAvailable()
        let waited = waitpid(pid, &status, WNOHANG)
        reaped = waited == pid
        reapFailed = waited < 0 && errno != EINTR
        let now = ProcessInfo.processInfo.systemUptime
        if !reaped && !reapFailed && !sentKill && now >= killDeadline {
          sentKill = kill(pid, SIGKILL) == 0
          if !sentKill && errno != ESRCH { reapFailed = true }
        }
        if now >= reapDeadline { break }
        if !reaped && !reapFailed { capture.waitForReadiness() }
      }
    }
    let drained = capture.finish(within: Self.drainGrace)
    // Late buffered bytes may expose an overflow after an exit/timeout observation.
    // Completion never overwrites a stronger observation, regardless of pipe readiness order.
    outcome = Self.observedOutcome(overflow: capture.overflow, timedOut: timedOut, completed: true)
    let signal = reaped && (status & 0x7f) != 0 ? status & 0x7f : nil
    var reason: ProcessResult.TerminationReason
    if !reaped || reapFailed {
      reason = .reapError
      if outcome == .completed { outcome = .launchFailed }
    } else if capture.failed || !drained {
      reason = .captureError
      if outcome == .completed { outcome = .launchFailed }
    } else if signal != nil {
      reason = sentKill ? .killed : (sentTerm ? .terminated : .uncaughtSignal)
      if outcome == .completed { outcome = .launchFailed }
    } else {
      reason = .exited
    }
    return ProcessResult(
      outcome: outcome ?? .launchFailed,
      exitCode: reaped && signal == nil ? (status >> 8) & 0xff : nil,
      signal: signal, stdout: capture.stdout, stderr: capture.stderr,
      stdoutByteCount: capture.stdoutByteCount, stderrByteCount: capture.stderrByteCount,
      truncated: capture.overflow || !drained, terminationReason: reason,
      processIdentifier: pid, childReaped: reaped)
  }

  static func observedOutcome(overflow: Bool, timedOut: Bool, completed: Bool) -> ProcessResult
    .Outcome?
  {
    if overflow { return .outputLimitExceeded }
    if timedOut { return .timedOut }
    return completed ? .completed : nil
  }

  private func failure(_ reason: ProcessResult.TerminationReason) -> ProcessResult {
    ProcessResult(
      outcome: .launchFailed, exitCode: nil, signal: nil, stdout: Data(), stderr: Data(),
      stdoutByteCount: 0, stderrByteCount: 0, truncated: false, terminationReason: reason,
      processIdentifier: nil, childReaped: false)
  }

  private func spawn(_ request: ProcessRequest, stdout: Int32, stderr: Int32, pid: inout pid_t)
    -> Int32
  {
    var actions: posix_spawn_file_actions_t?
    var attributes: posix_spawnattr_t?
    var error = posix_spawn_file_actions_init(&actions)
    guard error == 0 else { return error }
    defer { posix_spawn_file_actions_destroy(&actions) }
    error = posix_spawnattr_init(&attributes)
    guard error == 0 else { return error }
    defer { posix_spawnattr_destroy(&attributes) }
    error = posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_CLOEXEC_DEFAULT))
    guard error == 0 else { return error }
    error = posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0)
    guard error == 0 else { return error }
    error = posix_spawn_file_actions_adddup2(&actions, stdout, STDOUT_FILENO)
    guard error == 0 else { return error }
    error = posix_spawn_file_actions_adddup2(&actions, stderr, STDERR_FILENO)
    guard error == 0 else { return error }
    error = posix_spawn_file_actions_addchdir_np(&actions, request.workingDirectory.path)
    guard error == 0 else { return error }

    let argv = ([request.executable.path] + request.arguments).map { strdup($0) } + [nil]
    let envp =
      request.environment.sorted { $0.key < $1.key }.map { strdup($0.key + "=" + $0.value) } + [nil]
    defer {
      for pointer in argv { free(pointer) }
      for pointer in envp { free(pointer) }
    }
    guard argv.dropLast().allSatisfy({ $0 != nil }), envp.dropLast().allSatisfy({ $0 != nil })
    else {
      return ENOMEM
    }
    return argv.withUnsafeBufferPointer { arguments in
      envp.withUnsafeBufferPointer { environment in
        posix_spawn(
          &pid, request.executable.path, &actions, &attributes,
          UnsafeMutablePointer(mutating: arguments.baseAddress!),
          UnsafeMutablePointer(mutating: environment.baseAddress!))
      }
    }
  }
}

/// Owns both read descriptors. All methods must run on the owning synchronous coordinator.
/// Nonblocking reads alternate streams in bounded chunks; retention shares one combined cap.
final class ProcessPipeCapture {
  private var descriptors: [Int32]
  private let outputLimit: Int
  private(set) var stdout = Data()
  private(set) var stderr = Data()
  private(set) var stdoutByteCount: UInt64 = 0
  private(set) var stderrByteCount: UInt64 = 0
  private(set) var overflow = false
  private(set) var failed = false

  init(stdout: Int32, stderr: Int32, outputLimit: Int) {
    descriptors = [stdout, stderr]
    self.outputLimit = max(0, outputLimit)
    for fd in descriptors {
      let flags = fcntl(fd, F_GETFL)
      if flags < 0 || fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0 { failed = true }
    }
    if failed { cancel() }
  }

  deinit { cancel() }

  func drainAvailable() {
    var buffer = [UInt8](repeating: 0, count: 65_536)
    for stream in descriptors.indices where descriptors[stream] >= 0 {
      let count = read(descriptors[stream], &buffer, buffer.count)
      if count > 0 {
        let retained = min(count, outputLimit - stdout.count - stderr.count)
        let bytes = Data(buffer.prefix(retained))
        if stream == 0 {
          stdout.append(bytes)
          stdoutByteCount = addingClamped(stdoutByteCount, count)
        } else {
          stderr.append(bytes)
          stderrByteCount = addingClamped(stderrByteCount, count)
        }
        if retained < count { overflow = true }
      } else if count == 0 {
        closeReader(stream)
      } else if errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR {
        failed = true
        closeReader(stream)
      }
    }
  }

  func waitForReadiness() {
    var fds = descriptors.filter { $0 >= 0 }.map {
      pollfd(fd: $0, events: Int16(POLLIN), revents: 0)
    }
    let result = poll(&fds, nfds_t(fds.count), 5)
    if result < 0 && errno != EINTR { failed = true }
  }

  /// EOF is optional: inherited/held writers cannot extend this deadline. Cancellation closes
  /// the readers even if the corresponding child has already exited and been reaped.
  @discardableResult
  func finish(within seconds: TimeInterval) -> Bool {
    let deadline = ProcessInfo.processInfo.systemUptime + max(0, seconds)
    repeat {
      drainAvailable()
      if descriptors.allSatisfy({ $0 < 0 }) { return !failed }
      if ProcessInfo.processInfo.systemUptime >= deadline { break }
      waitForReadiness()
    } while true
    cancel()
    return false
  }

  func cancel() {
    for stream in descriptors.indices { closeReader(stream) }
  }

  private func closeReader(_ stream: Int) {
    if descriptors[stream] >= 0 {
      close(descriptors[stream])
      descriptors[stream] = -1
    }
  }

  private func addingClamped(_ value: UInt64, _ count: Int) -> UInt64 {
    let (sum, overflow) = value.addingReportingOverflow(UInt64(count))
    return overflow ? UInt64.max : sum
  }
}

import Darwin
import Foundation

public struct CLIResult {
  public let stdout: Data
  public let stderr: Data
  public let exitCode: Int32
}

/// Uses files to avoid pipe backpressure; a fixed deadline bounds child lifetime.
public enum CLIHarness {
  public static func run(
    arguments: [String], environment: [String: String], executable: URL,
    workingDirectory: URL? = nil
  ) throws -> CLIResult {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let out = directory.appendingPathComponent("stdout")
    let err = directory.appendingPathComponent("stderr")
    FileManager.default.createFile(atPath: out.path, contents: nil)
    FileManager.default.createFile(atPath: err.path, contents: nil)
    let stdout = try FileHandle(forWritingTo: out)
    let stderr = try FileHandle(forWritingTo: err)
    defer {
      try? stdout.close()
      try? stderr.close()
    }
    let process = Process()
    process.executableURL = executable
    process.arguments = arguments
    process.currentDirectoryURL = workingDirectory
    process.environment = environment
    process.standardOutput = stdout
    process.standardError = stderr
    try process.run()
    let deadline = ProcessInfo.processInfo.systemUptime + 15
    while process.isRunning && ProcessInfo.processInfo.systemUptime < deadline { usleep(10_000) }
    if process.isRunning {
      process.terminate()
      usleep(100_000)
      if process.isRunning { kill(process.processIdentifier, SIGKILL) }
      process.waitUntilExit()
      throw HarnessError.deadline
    }
    process.waitUntilExit()
    return CLIResult(
      stdout: try Data(contentsOf: out), stderr: try Data(contentsOf: err),
      exitCode: process.terminationStatus)
  }
  public enum HarnessError: Error { case deadline }
}

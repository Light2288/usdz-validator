import Darwin
import Foundation
import TestSupport
import XCTest

final class CLIProcessTests: XCTestCase {
  private var executable: URL {
    if let path = ProcessInfo.processInfo.environment["UVK_CLI_EXECUTABLE"] {
      return URL(fileURLWithPath: path)
    }
    let suite = Bundle(for: CLIProcessTests.self).bundleURL
    return suite.deletingLastPathComponent().appendingPathComponent("usdz-validator")
  }
  private func run(_ arguments: [String], scenario: String? = nil, directory: URL? = nil) throws
    -> CLIResult
  {
    var environment = ["PATH": "/usr/bin:/bin", "LANG": "C", "LC_ALL": "C"]
    var path = executable
    if let scenario {
      guard let hook = ProcessInfo.processInfo.environment["UVK_CLI_TEST_EXECUTABLE"],
        FileManager.default.isExecutableFile(atPath: hook)
      else {
        throw XCTSkip("Compile-only process executable absent; run sh Scripts/test-cli.sh")
      }
      path = URL(fileURLWithPath: hook)
      environment["UVK_CLI_TEST_SCENARIO"] = scenario
    }
    return try CLIHarness.run(
      arguments: arguments, environment: environment, executable: path, workingDirectory: directory)
  }
  private func withAssets(_ body: (URL, URL, URL, URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let good = try Fixtures.write(Fixtures.validUSDA(), basename: "arbitrary.asset", in: directory)
    let binary = try Fixtures.write(
      ArchiveRecipe(entries: [
        .init(nameBytes: Data("root.usdc".utf8), payload: Data("PXR-USDCsynthetic".utf8))
      ]).encode(), basename: "gap", in: directory)
    let bad = try Fixtures.write(Data("invalid ZIP".utf8), basename: "bad", in: directory)
    try body(directory, good, binary, bad)
  }
  private func json(_ result: CLIResult) throws -> [String: Any] {
    XCTAssertEqual(result.stdout.last, 10)
    XCTAssertFalse(
      result.stdout.dropLast().contains(10), "Canonical machine output is one document plus one LF")
    XCTAssertEqual(result.stdout.first, 123)
    XCTAssertTrue(result.stderr.isEmpty)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: result.stdout) as? [String: Any])
  }
  func testInvocationAndExitMatrix() throws {
    for args in [
      ["--help"], ["--version"], ["validate", "--help"], ["rules", "--help"], ["help", "validate"],
      ["rules"], ["rules", "--format", "json"],
      ["rules", "--format", "json", "--profile", "apple-portable-v1"],
    ] {
      let result = try run(args)
      XCTAssertEqual(result.exitCode, 0, "\(args)")
      XCTAssertFalse(result.stdout.isEmpty)
      XCTAssertTrue(result.stderr.isEmpty)
    }
    try withAssets { directory, good, binary, bad in
      for args in [
        [], ["validate"], ["validate", good.path, good.path], ["validate", "-"],
        ["validate", "https://example.invalid/a"], ["validate", "file:///tmp/a"],
        ["validate", directory.path], ["validate", good.path, "--unknown"],
        ["validate", good.path, "--profile", "unknown"],
        ["validate", good.path, "--format", "other"], ["rules", "--format", "sarif"],
        ["validate", good.path, "--fail-on", "note"],
      ] {
        let result = try run(args)
        XCTAssertEqual(result.exitCode, 64, "\(args)")
        XCTAssertTrue(result.stdout.isEmpty, "\(args)")
        XCTAssertFalse(result.stderr.isEmpty, "\(args)")
      }
      for format in ["text", "json", "sarif"] {
        for (asset, code) in [
          (good, Int32(0)), (bad, 1), (binary, 2), (directory.appendingPathComponent("missing"), 3),
        ] {
          let result = try run(["validate", asset.path, "--format", format])
          XCTAssertEqual(result.exitCode, code, "\(format) \(asset.lastPathComponent)")
          XCTAssertFalse(result.stdout.isEmpty)
          if code != 3 { XCTAssertTrue(result.stderr.isEmpty) }
          if format != "text" {
            XCTAssertEqual(result.stdout.last, 10)
            XCTAssertFalse(result.stdout.dropLast().contains(10))
            let document = try XCTUnwrap(
              JSONSerialization.jsonObject(with: result.stdout) as? [String: Any])
            if format == "json" { XCTAssertEqual(document["exitCode"] as? Int, Int(code)) }
          }
        }
      }
      let option = try Fixtures.write(Fixtures.validUSDA(), basename: "-option", in: directory)
      XCTAssertEqual(
        try run(
          ["validate", "--format", "json", "--", option.lastPathComponent], directory: directory
        ).exitCode, 0)
    }
  }
  func testPrecedenceAndPureStreams() throws {
    try withAssets { directory, good, binary, bad in
      for format in ["json", "sarif"] {
        let first = try run(["validate", good.path, "--format", format])
        _ = try json(first)
        XCTAssertEqual(try run(["validate", good.path, "--format", format]).stdout, first.stdout)
        XCTAssertFalse(String(decoding: first.stdout, as: UTF8.self).contains(directory.path))
      }
      let accepted = try json(
        run(["validate", binary.path, "--format", "json", "--allow-incomplete"]))
      XCTAssertEqual(accepted["exitCode"] as? Int, 0)
      XCTAssertEqual(accepted["validationStatus"] as? String, "incomplete")
      XCTAssertEqual(accepted["acceptedIncomplete"] as? Bool, true)
      let blocked = try json(run(["validate", bad.path, "--format", "json", "--allow-incomplete"]))
      XCTAssertEqual(blocked["exitCode"] as? Int, 1)
      XCTAssertEqual((blocked["coverage"] as? [String: Any])?["isComplete"] as? Bool, false)
      let defaultExternal = try XCTUnwrap(accepted["externalCheck"] as? [String: Any])
      XCTAssertTrue(defaultExternal["terminationReason"] is NSNull)
      let config = try Fixtures.write(
        Data(#"{"schemaVersion":1,"budgets":{"archiveBytes":1}}"#.utf8), basename: "config.json",
        in: directory)
      XCTAssertEqual(try run(["validate", good.path, "--config", config.path]).exitCode, 0)
      XCTAssertEqual(
        try run(["validate", good.path, "--config", config.path, "--fail-on", "warning"]).exitCode,
        1)
      XCTAssertEqual(
        try run([
          "validate", binary.path, "--config", config.path, "--fail-on", "warning",
          "--allow-incomplete",
        ]).exitCode, 1)
      let invalid = try Fixtures.write(Data("{}".utf8), basename: "invalid.json", in: directory)
      let result = try run([
        "validate", directory.appendingPathComponent("missing").path, "--config", invalid.path,
        "--format", "json",
      ])
      XCTAssertEqual(result.exitCode, 64)
      XCTAssertTrue(result.stdout.isEmpty)
      XCTAssertFalse(result.stderr.isEmpty)
    }
  }
  func testHookScenariosExerciseFacadeAndGate() throws {
    try withAssets { _, good, binary, bad in
      for scenario in ["checkerUnavailable", "checkerSuccess", "checkerFailure"] {
        for allow in [false, true] {
          for asset in [good, binary] {
            let args =
              ["validate", asset.path, "--format", "json", "--usdchecker"]
              + (allow ? ["--allow-incomplete"] : [])
            let result = try run(args, scenario: scenario)
            let document = try json(result)
            let expected: Int32 =
              scenario == "checkerUnavailable"
              ? 2 : scenario == "checkerFailure" ? 1 : asset == binary && !allow ? 2 : 0
            XCTAssertEqual(result.exitCode, expected)
            let external = try XCTUnwrap(document["externalCheck"] as? [String: Any])
            XCTAssertEqual(
              external["status"] as? String,
              scenario == "checkerUnavailable" ? "unavailable" : "completed")
            XCTAssertEqual(
              external["availability"] as? String,
              scenario == "checkerUnavailable" ? "unavailable" : "available")
            if scenario == "checkerUnavailable" {
              XCTAssertTrue(external["terminationReason"] is NSNull)
            } else {
              XCTAssertEqual(external["terminationReason"] as? String, "exited")
            }
            let native = try json(run(["validate", asset.path, "--format", "json"]))
            XCTAssertEqual(
              try JSONSerialization.data(
                withJSONObject: document["nativeFindings"] ?? [], options: [.sortedKeys]),
              try JSONSerialization.data(
                withJSONObject: native["nativeFindings"] ?? [], options: [.sortedKeys]))
            XCTAssertEqual(
              try JSONSerialization.data(
                withJSONObject: document["coverage"]!, options: [.sortedKeys]),
              try JSONSerialization.data(
                withJSONObject: native["coverage"]!, options: [.sortedKeys]))
          }
        }
        let unsafe = try run(
          ["validate", bad.path, "--format", "json", "--usdchecker", "--allow-incomplete"],
          scenario: scenario)
        XCTAssertEqual(unsafe.exitCode, 1)
        let check = try XCTUnwrap(try json(unsafe)["externalCheck"] as? [String: Any])
        XCTAssertEqual(check["status"] as? String, "skippedUnsafeInput")
      }
      for format in ["text", "json", "sarif"] {
        let internalFailure = try run(
          ["validate", good.path, "--format", format], scenario: "internalFailure")
        XCTAssertEqual(internalFailure.exitCode, 70)
        XCTAssertFalse(internalFailure.stdout.isEmpty)
        XCTAssertFalse(internalFailure.stderr.isEmpty)
        if format != "text" { _ = try JSONSerialization.jsonObject(with: internalFailure.stdout) }
      }
      let invalid = try run(
        ["validate", good.path, "--config", good.path, "--format", "json", "--usdchecker"],
        scenario: "internalFailure")
      XCTAssertEqual(invalid.exitCode, 64)
      XCTAssertTrue(invalid.stdout.isEmpty)
      XCTAssertFalse(invalid.stderr.isEmpty)
    }
  }
  func testInputSpecialFilesReturnControlledReports() throws {
    try withAssets { directory, good, _, _ in
      let link = directory.appendingPathComponent("link")
      try FileManager.default.createSymbolicLink(at: link, withDestinationURL: good)
      let fifo = directory.appendingPathComponent("fifo")
      XCTAssertEqual(mkfifo(fifo.path, 0o600), 0)
      for asset in [link, fifo] {
        let result = try run(["validate", asset.path, "--format", "json"])
        XCTAssertEqual(result.exitCode, 3)
        XCTAssertFalse(result.stderr.isEmpty)
        let document = try XCTUnwrap(
          JSONSerialization.jsonObject(with: result.stdout) as? [String: Any])
        XCTAssertEqual(document["exitCode"] as? Int, 3)
        XCTAssertFalse(
          String(decoding: result.stdout + result.stderr, as: UTF8.self).contains(directory.path))
      }
    }
  }
  func testSensitiveOptInAndMaliciousBasename() throws {
    try withAssets { directory, good, _, _ in
      let unusual = directory.appendingPathComponent("asset\\segment\u{001B}\n.data")
      try FileManager.default.moveItem(at: good, to: unusual)
      for sensitive in [false, true] {
        let result = try run(
          ["validate", unusual.path, "--format", "json"]
            + (sensitive ? ["--include-sensitive-details"] : []))
        let document = try json(result)
        let input = try XCTUnwrap(document["input"] as? [String: Any])
        XCTAssertEqual(input["displayName"] as? String, "asset\\\\segment\\u{001B}\\n.data")
        XCTAssertEqual(input["sensitiveDetails"] != nil, sensitive)
        XCTAssertFalse(result.stdout.contains(27))
      }
      let sarif = try json(run(["validate", unusual.path, "--format", "sarif"]))
      let runs = try XCTUnwrap(sarif["runs"] as? [[String: Any]])
      let artifacts = try XCTUnwrap(runs.first?["artifacts"] as? [[String: Any]])
      let location = try XCTUnwrap(artifacts.first?["location"] as? [String: Any])
      XCTAssertEqual(location["uri"] as? String, "asset%5Csegment%1B%0A.data")
    }
  }
  func testNormalExecutableIgnoresHookEnvironment() throws {
    let good = Fixtures.root.appendingPathComponent("valid-usda.usdz")
    for scenario in ["internalFailure", "checkerUnavailable", "checkerSuccess", "checkerFailure"] {
      let result = try CLIHarness.run(
        arguments: ["validate", good.path, "--format", "json"],
        environment: [
          "UVK_CLI_TEST_SCENARIO": scenario, "UVK_CLI_TEST_EXECUTABLE": "/invalid",
          "UVK_CLI_EXECUTABLE": "/invalid",
        ], executable: executable)
      XCTAssertEqual(result.exitCode, 0)
      _ = try json(result)
    }
  }
  func testBrokenPipeIsOperationalFailure() throws {
    let process = Process()
    process.executableURL = executable
    process.arguments = ["rules", "--format", "json"]
    let pipe = Pipe()
    try pipe.fileHandleForReading.close()
    process.standardOutput = pipe.fileHandleForWriting
    process.standardError = FileHandle.nullDevice
    try process.run()
    try pipe.fileHandleForWriting.close()
    let deadline = ProcessInfo.processInfo.systemUptime + 10
    while process.isRunning && ProcessInfo.processInfo.systemUptime < deadline { usleep(10_000) }
    if process.isRunning {
      kill(process.processIdentifier, SIGKILL)
      XCTFail("Broken-pipe invocation exceeded deadline")
    }
    process.waitUntilExit()
    XCTAssertEqual(process.terminationReason, .exit)
    XCTAssertEqual(process.terminationStatus, 3)
  }
}

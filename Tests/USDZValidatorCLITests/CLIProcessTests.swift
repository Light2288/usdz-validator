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
        .init(nameBytes: Data("root.usdc".utf8), payload: USDCFixtures.unsupportedVersion())
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
  // Default CLI validation must inspect binary assets while checker execution stays opt-in.
  func testAutomaticBinaryInspectionAndCheckerOptIn() throws {
    let fixture = Fixtures.root.appendingPathComponent("valid-usdc.usdz")
    let native = try json(run(["validate", fixture.path, "--format", "json"]))
    XCTAssertEqual(native["exitCode"] as? Int, 0)
    XCTAssertEqual((native["coverage"] as? [String: Any])?["isComplete"] as? Bool, true)
    XCTAssertEqual(
      (native["externalCheck"] as? [String: Any])?["status"] as? String, "notRequested")
    try withAssets { directory, _, _, _ in
      let missing = try Fixtures.write(
        ArchiveRecipe(entries: [
          .init(
            nameBytes: Data("root.usdc".utf8),
            payload: Data(
              contentsOf: USDCFixtures.root.appendingPathComponent("baseline/containers.usdc")))
        ]).encode(),
        basename: "missing-targets", in: directory)
      let document = try json(run(["validate", missing.path, "--format", "json"]))
      XCTAssertEqual(document["exitCode"] as? Int, 1)
      let findings = document["nativeFindings"] as? [[String: Any]]
      XCTAssertEqual(findings?.filter { $0["ruleID"] as? String == "UVK-PATH-006" }.count, 7)
      let truncated = try Fixtures.write(
        ArchiveRecipe(entries: [
          .init(nameBytes: Data("root.usdc".utf8), payload: Data("PXR-USDC".utf8))
        ]).encode(),
        basename: "truncated", in: directory)
      let corrupt = try json(
        run(["validate", truncated.path, "--format", "json", "--allow-incomplete"]))
      XCTAssertEqual(corrupt["exitCode"] as? Int, 1)
      XCTAssertTrue(
        (corrupt["nativeFindings"] as? [[String: Any]])?.contains {
          $0["ruleID"] as? String == "UVK-USD-001"
        } == true)
    }
  }

  func testBinaryCheckerRemainsExplicit() throws {
    let fixture = Fixtures.root.appendingPathComponent("valid-usdc.usdz")
    let native = try run(["validate", fixture.path], scenario: "checkerFailure")
    XCTAssertEqual(native.exitCode, 0)
    let requested = try run(["validate", fixture.path, "--usdchecker"], scenario: "checkerFailure")
    XCTAssertEqual(requested.exitCode, 1)
  }

  func testOutputDestinationAndFailurePrivacy() throws {
    try withAssets { directory, good, binary, bad in
      let output = directory.appendingPathComponent("report\u{001B}\n.json")
      for format in ["text", "json", "sarif"] {
        for (asset, expected) in [
          (good, Int32(0)), (binary, 2), (bad, 1), (directory.appendingPathComponent("missing"), 3),
        ] {
          try Data("previous report".utf8).write(to: output)
          let result = try run([
            "validate", asset.path, "--format", format, "--output", output.path,
          ])
          XCTAssertEqual(result.exitCode, expected)
          XCTAssertTrue(result.stdout.isEmpty)
          let bytes = try Data(contentsOf: output)
          XCTAssertEqual(bytes.last, 10)
          if format != "text" {
            XCTAssertEqual(bytes.first, 123)
            if bytes.first == 123 { _ = try JSONSerialization.jsonObject(with: bytes) }
          }
          XCTAssertEqual(bytes, try run(["validate", asset.path, "--format", format]).stdout)
        }
      }
      let original = try Data(contentsOf: good)
      let link = directory.appendingPathComponent("hardlink")
      XCTAssertEqual(Darwin.link(good.path, link.path), 0)
      let symbolic = directory.appendingPathComponent("symlink")
      try FileManager.default.createSymbolicLink(at: symbolic, withDestinationURL: output)
      for destination in [
        good, link, symbolic, directory, directory.appendingPathComponent("missing/report"),
      ] {
        let asset = destination == good || destination == link ? good : bad
        let protected = try run(["validate", asset.path, "--output", destination.path])
        XCTAssertEqual(protected.exitCode, 3)
        XCTAssertTrue(protected.stdout.isEmpty)
        XCTAssertFalse(protected.stderr.isEmpty)
        XCTAssertFalse(String(decoding: protected.stderr, as: UTF8.self).contains(directory.path))
        XCTAssertFalse(protected.stderr.contains(27))
      }
      XCTAssertEqual(try Data(contentsOf: good), original)
      for asset in [binary, bad] {
        let failed = try run([
          "validate", asset.path, "--output",
          directory.appendingPathComponent("missing/report").path,
        ])
        XCTAssertEqual(failed.exitCode, 3)
        XCTAssertTrue(failed.stdout.isEmpty)
        XCTAssertFalse(failed.stderr.isEmpty)
      }
      let failure = try run(
        ["validate", good.path, "--output", directory.path], scenario: "internalFailure")
      XCTAssertEqual(failure.exitCode, 70)
      XCTAssertTrue(failure.stdout.isEmpty)
      XCTAssertFalse(failure.stderr.isEmpty)
    }
  }

  func testEncodingCapPreservesExistingOutput() throws {
    try withAssets { directory, good, _, _ in
      let output = directory.appendingPathComponent("report")
      let previous = Data("previous report".utf8)
      try previous.write(to: output)
      let result = try run(
        ["validate", good.path, "--format", "text", "--output", output.path],
        scenario: "encodingCap")
      XCTAssertEqual(result.exitCode, 3)
      XCTAssertTrue(result.stdout.isEmpty)
      XCTAssertFalse(result.stderr.isEmpty)
      XCTAssertEqual(try Data(contentsOf: output), previous)
      XCTAssertFalse(String(decoding: result.stderr, as: UTF8.self).contains(directory.path))
      XCTAssertEqual(
        try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted(),
        ["arbitrary.asset", "bad", "gap", "report"])
    }
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
    let arguments = ["validate", good.path, "--format", "json"]
    let controlledEnvironment = ["PATH": "/usr/bin:/bin", "LANG": "C", "LC_ALL": "C"]
    let normal = try CLIHarness.run(
      arguments: arguments, environment: controlledEnvironment, executable: executable)
    XCTAssertEqual(normal.exitCode, 0)
    _ = try json(normal)
    for scenario in [
      "internalFailure", "checkerUnavailable", "checkerSuccess", "checkerFailure", "encodingCap",
    ] {
      var environment = controlledEnvironment
      environment["UVK_CLI_TEST_SCENARIO"] = scenario
      environment["UVK_CLI_TEST_EXECUTABLE"] = "/invalid"
      environment["UVK_CLI_EXECUTABLE"] = "/invalid"
      let result = try CLIHarness.run(
        arguments: arguments, environment: environment, executable: executable)
      XCTAssertEqual(result.exitCode, normal.exitCode)
      XCTAssertEqual(result.stdout, normal.stdout)
      XCTAssertEqual(result.stderr, normal.stderr)
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

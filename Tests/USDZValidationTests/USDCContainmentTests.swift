import Darwin
import Foundation
import MachO
import TestSupport
import XCTest

@testable import USDZValidation

final class USDCContainmentTests: XCTestCase {
  // A new required host lookup, tool execution, write, or network access in the real
  // native pipeline must fail after all exact inputs and runtime paths are preloaded.
  func testChildOnlyDenyPolicy() throws {
    if ProcessInfo.processInfo.environment["UVK_CONTAINMENT_CHILD"] == "1" {
      do { try runContainedChild() } catch {
        childFinish(["error": String(describing: error)], code: 1)
      }
    }
    let output = Pipe()
    let process = Process()
    let locator = Process()
    let located = Pipe()
    locator.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    locator.arguments = ["--find", "xctest"]
    locator.standardOutput = located
    try locator.run()
    locator.waitUntilExit()
    XCTAssertEqual(locator.terminationStatus, 0)
    let runner = String(decoding: located.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    process.executableURL = URL(fileURLWithPath: runner)
    process.arguments = [
      "-XCTest", "USDZValidationTests.USDCContainmentTests/testChildOnlyDenyPolicy",
      Bundle(for: Self.self).bundleURL.path,
    ]
    process.environment = ProcessInfo.processInfo.environment.merging([
      "UVK_CONTAINMENT_CHILD": "1"
    ]) { _, next in next }
    // xcrun is a protected launcher that strips DYLD insertion. Launch the resolved
    // runner directly and preload the same sanitizer runtime when this test is sanitized.
    for index in 0..<_dyld_image_count() {
      if let name = _dyld_get_image_name(index) {
        let path = String(cString: name)
        if path.hasSuffix("libclang_rt.asan_osx_dynamic.dylib") {
          process.environment?["DYLD_INSERT_LIBRARIES"] = path
        }
      }
    }
    process.standardOutput = output
    process.standardError = output
    try process.run()
    let deadline = ProcessInfo.processInfo.systemUptime + 60
    while process.isRunning && ProcessInfo.processInfo.systemUptime < deadline { usleep(10_000) }
    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
    process.waitUntilExit()
    let bytes = output.fileHandleForReading.readDataToEndOfFile()
    let text = String(decoding: bytes, as: UTF8.self)
    XCTAssertEqual(process.terminationStatus, 0, text)
    let receiptLine = try XCTUnwrap(
      text.split(separator: "\n").first { $0.hasPrefix("UVK-CONTAINMENT ") }, text)
    let receipt = try XCTUnwrap(
      try JSONSerialization.jsonObject(
        with: Data(receiptLine.dropFirst("UVK-CONTAINMENT ".count).utf8)) as? [String: Any])
    XCTAssertEqual(receipt["sandboxInit"] as? Int, 0, text)
    let controls = try XCTUnwrap(receipt["controls"] as? [String: Int])
    XCTAssertEqual(
      Set(controls.keys), ["read", "stat", "enumerate", "connect", "execute", "write"])
    for (name, code) in controls { XCTAssertEqual(code, Int(EPERM), name) }
    XCTAssertEqual(receipt["fixtures"] as? Int, 27)
    XCTAssertEqual(receipt["occurrences"] as? Int, 72)
    XCTAssertEqual(receipt["syntheticInputs"] as? Int, 12)
    XCTAssertEqual(receipt["syntheticOccurrences"] as? Int, 5)
    XCTAssertEqual(receipt["failures"] as? [String], [])
    XCTAssertEqual(receipt["forbiddenInputReads"] as? Int, 0)
    XCTAssertGreaterThan(receipt["inputReadRequests"] as? Int ?? 0, 0)
    XCTAssertEqual(receipt["workingBytesAfterScans"] as? Int, 0)
    print(text)
    // The parent remains unrestricted: the policy must never leak into the runner.
    XCTAssertFalse(try Data(contentsOf: URL(fileURLWithPath: "/etc/hosts")).isEmpty)
  }

  // The real FileSnapshot may recheck only its supplied pathname. Keep this separate
  // from denial, which intentionally forbids those pathname consistency checks.
  func testRealSnapshotReadsOnlySuppliedInputRanges() throws {
    let fixture = try XCTUnwrap(USDCFixtures.cases().first { $0.id == "baseline/containers" })
    let bytes = try ArchiveRecipe(entries: [
      .init(nameBytes: Data("root.usdc".utf8), payload: fixture.crate)
    ]).encode()
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try bytes.write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    let snapshot = try FileSnapshot.open(url)
    defer { try? snapshot.close() }
    let ledger = ResourceLedger()
    var requests = 0
    var forbiddenInputReads = 0
    var observedBytes: UInt64 = 0
    let result = try NativeEngine.inspect(
      size: snapshot.size, configuration: ValidationConfiguration(), ledger: ledger
    ) { offset, count in
      let (end, overflow) = offset.addingReportingOverflow(UInt64(max(count, 0)))
      guard !overflow, count > 0, count <= 65_536, end <= snapshot.size else {
        forbiddenInputReads += 1
        throw InspectionFailure.malformedRange
      }
      requests += 1
      observedBytes += UInt64(count)
      return try snapshot.read(offset: offset, count: count)
    }
    try snapshot.verifyUnchanged()
    XCTAssertGreaterThan(requests, 0)
    XCTAssertEqual(forbiddenInputReads, 0)
    XCTAssertEqual(ledger.totalReadBytes, observedBytes)
    XCTAssertEqual(ledger.usdcLiveBytes, 0, "Scanner owners must release before reporting")
    XCTAssertFalse(result.findings.contains { $0.ruleID == "UVK-USD-001" })
  }

  private func runContainedChild() throws -> Never {
    let genuine = try USDCFixtures.cases() + USDCFixtures.extraCases()
    let synthetic = try syntheticCases()
    let fixtures =
      genuine.map { InputCase(id: $0.id, crate: $0.crate, values: $0.expectedValues) }
      + synthetic
    let configuration = try ValidationConfiguration()
    let packages = try fixtures.map { fixture in
      try ArchiveRecipe(entries: [
        .init(nameBytes: Data("root.usdc".utf8), payload: fixture.crate),
        .init(nameBytes: Data("textures/a.png".utf8), payload: Fixtures.pixelPNG()),
      ]).encode()
    }
    var expected: [NativeResult] = []
    var expectedScans: [ScanReceipt] = []
    for (fixture, bytes) in zip(fixtures, packages) {
      let scanned = try scan(fixture.crate)
      guard
        scanned.references.map(\.valueBytes).sorted(by: USDCReferenceTests.order)
          == fixture.values.sorted(by: USDCReferenceTests.order)
      else { throw ChildFailure.changedResult }
      if let outcome = fixture.outcome {
        guard scanned.state == outcome.state, scanned.failure == outcome.failure,
          scanned.issues.map(\.failure) == outcome.issues
        else { throw ChildFailure.changedResult }
      }
      expectedScans.append(scanned)
      expected.append(
        try NativeEngine.inspect(
          size: UInt64(bytes.count), configuration: configuration, ledger: ResourceLedger()
        ) { offset, count in bytes.subdata(in: Int(offset)..<(Int(offset) + count)) })
    }
    // Resolve/load everything before denial, including result encoding and control ABI paths.
    _ = try JSONSerialization.data(withJSONObject: ["warm": 1], options: [.sortedKeys])
    guard let library = dlopen("/usr/lib/libsandbox.dylib", RTLD_NOW),
      let symbol = dlsym(library, "sandbox_init")
    else { throw ChildFailure.setup }
    typealias SandboxInit =
      @convention(c) (
        UnsafePointer<CChar>?, UInt64, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
      ) -> Int32
    let initialize = unsafeBitCast(symbol, to: SandboxInit.self)
    let profile =
      "(version 1)(allow default)(deny file-read*)(deny file-write*)(deny network*)(deny process-exec)(deny process-fork)"
    // Open the socket before denial so the negative control proves an actual
    // connect is denied, rather than accepting an earlier socket-creation denial.
    let network = socket(AF_INET, SOCK_STREAM, 0)
    guard network >= 0 else { throw ChildFailure.setup }
    defer { Darwin.close(network) }
    var error: UnsafeMutablePointer<CChar>?
    let result = profile.withCString { initialize($0, 0, &error) }
    guard result == 0 else { throw ChildFailure.setup }

    var controls: [String: Int] = [:]
    var metadata = stat()
    errno = 0
    let readFD = Darwin.open("/etc/hosts", O_RDONLY)
    controls["read"] = readFD == -1 ? Int(errno) : 0
    if readFD >= 0 { Darwin.close(readFD) }
    errno = 0
    controls["stat"] = fstatat(AT_FDCWD, "/etc/hosts", &metadata, 0) == -1 ? Int(errno) : 0
    errno = 0
    let directory = opendir("/tmp")
    controls["enumerate"] = directory == nil ? Int(errno) : 0
    if let directory { closedir(directory) }
    errno = 0
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = UInt16(9).bigEndian
    address.sin_addr.s_addr = inet_addr("127.0.0.1")
    let connected = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Darwin.connect(network, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    controls["connect"] = connected == -1 ? Int(errno) : 0
    var pid: pid_t = 0
    let executable = strdup("/usr/bin/true")!
    defer { free(executable) }
    var arguments: [UnsafeMutablePointer<CChar>?] = [executable, nil]
    controls["execute"] = Int(posix_spawn(&pid, executable, nil, nil, &arguments, environ))
    errno = 0
    let writeFD = Darwin.open(
      "/tmp/uvk-containment-must-not-create", O_WRONLY | O_CREAT | O_EXCL, 0o600)
    controls["write"] = writeFD == -1 ? Int(errno) : 0
    if writeFD >= 0 { Darwin.close(writeFD) }
    guard controls.count == 6, controls.values.allSatisfy({ $0 == Int(EPERM) }) else {
      childFinish(["sandboxInit": result, "controls": controls], code: 1)
    }
    var requests = 0
    var forbiddenInputReads = 0
    var totalOccurrences = 0
    var syntheticOccurrences = 0
    var scannerRequests = 0
    var finalLiveBytes: UInt64 = 0
    var failures: [String] = []
    for (index, bytes) in packages.enumerated() {
      let fixture = fixtures[index]
      let ledger = ResourceLedger()
      let actual = try NativeEngine.inspect(
        size: UInt64(bytes.count), configuration: configuration, ledger: ledger
      ) { offset, count in
        let (end, overflow) = offset.addingReportingOverflow(UInt64(max(0, count)))
        guard !overflow, count > 0, count <= 65_536, end <= UInt64(bytes.count) else {
          forbiddenInputReads += 1
          throw InspectionFailure.malformedRange
        }
        requests += 1
        return bytes.subdata(in: Int(offset)..<Int(end))
      }
      finalLiveBytes += ledger.usdcLiveBytes
      if actual.findings != expected[index].findings || actual.coverage != expected[index].coverage
      {
        failures.append(fixture.id + ": native findings/coverage changed")
      }
      let scanLedger = ResourceLedger()
      let scanned = try scan(fixture.crate, ledger: scanLedger) { offset, count in
        let (end, overflow) = offset.addingReportingOverflow(UInt64(max(0, count)))
        guard !overflow, count > 0, count <= 65_536, end <= UInt64(fixture.crate.count) else {
          forbiddenInputReads += 1
          throw InspectionFailure.malformedRange
        }
        scannerRequests += 1
        return fixture.crate.subdata(in: Int(offset)..<Int(end))
      }
      finalLiveBytes += scanLedger.usdcLiveBytes
      if scanned != expectedScans[index] { failures.append(fixture.id + ": semantic scan changed") }
      if index < genuine.count {
        totalOccurrences += scanned.references.count
      } else {
        syntheticOccurrences += scanned.references.count
      }
    }
    childFinish(
      [
        "sandboxInit": result, "controls": controls, "fixtures": genuine.count,
        "occurrences": totalOccurrences, "syntheticInputs": synthetic.count,
        "syntheticOccurrences": syntheticOccurrences,
        "inputReadRequests": requests + scannerRequests, "packageReadRequests": requests,
        "scannerReadRequests": scannerRequests, "failures": failures,
        "forbiddenInputReads": forbiddenInputReads, "workingBytesAfterScans": finalLiveBytes,
      ], code: failures.isEmpty && finalLiveBytes == 0 && forbiddenInputReads == 0 ? 0 : 1)
  }

  private struct ScanReceipt: Equatable {
    let state: USDCScanState?
    let references: [ReferenceOccurrence]
    let issues: [USDCIssue]
    let failure: InspectionFailure?
  }

  private struct Outcome {
    let state: USDCScanState?
    let issues: [USDCFailure]
    let failure: InspectionFailure?
  }

  private struct InputCase {
    let id: String
    let crate: Data
    let values: [Data]
    var outcome: Outcome? = nil
  }

  // Independent expected outcomes are checked before denial; the same exact semantic
  // sites, issues, typed hard failures and native findings/coverage must survive denial.
  private func syntheticCases() throws -> [InputCase] {
    let w = USDCReferenceTests.word
    let complete = Outcome(state: .complete, issues: [], failure: nil)
    var inputs: [InputCase] = []
    for flags: UInt64 in [0x80, 0xa0] {
      for count: UInt64 in [0, 250_000, 250_001, .max] {
        inputs.append(
          InputCase(
            id: "synthetic/numeric-\(flags)-\(count)",
            crate: try USDCMutationRecipe.valueCrate(
              reps: [(flags << 56) | (3 << 48) | 88], body: w(count, 8)),
            values: [], outcome: complete))
      }
    }
    inputs.append(
      InputCase(
        id: "synthetic/shared-numeric-asset",
        crate: try USDCMutationRecipe.valueCrate(
          reps: [0x8003_0000_0000_0058, 0x800c_0000_0000_0058, 0x800c_0000_0000_0058],
          body: w(2, 8) + w(0, 4) + w(0, 4)),
        values: Array(repeating: Data("a.png".utf8), count: 4), outcome: complete))
    inputs.append(
      InputCase(
        id: "synthetic/shared-asset-items-over",
        crate: try USDCMutationRecipe.valueCrate(
          reps: [0x8003_0000_0000_0058, 0x800c_0000_0000_0058], body: w(250_001, 8)),
        values: [], outcome: Outcome(state: nil, issues: [], failure: .resourceLimit(.usdcItems))))
    inputs.append(
      InputCase(
        id: "synthetic/unknown-flags",
        crate: try USDCMutationRecipe.valueCrate(
          reps: [0xc003_0000_0000_0058, 0x400c_0000_0000_0002], body: w(.max, 8)),
        values: [Data("a.png".utf8)],
        outcome: Outcome(state: .partial, issues: [.unsupported(.unsupportedValue)], failure: nil)))
    inputs.append(
      InputCase(
        id: "synthetic/truncated-header",
        crate: try USDCMutationRecipe.valueCrate(
          reps: [0x8003_0000_0000_0058], body: Data(repeating: 0, count: 7)),
        values: [],
        outcome: Outcome(state: .partial, issues: [.malformed(.invalidRange)], failure: nil)))
    return inputs
  }

  private func scan(
    _ bytes: Data, ledger: ResourceLedger = ResourceLedger(),
    read: ((UInt64, Int) throws -> Data)? = nil
  ) throws -> ScanReceipt {
    let entry = USDCReferenceTests.input(bytes, ledger: ledger).entry
    let reader = BoundedReader(size: UInt64(bytes.count), ledger: ledger) { offset, count in
      if let read { return try read(offset, count) }
      return bytes.subdata(in: Int(offset)..<(Int(offset) + count))
    }
    var references: [ReferenceOccurrence] = []
    var issues: [USDCIssue] = []
    do {
      let state = try USDCReader.scan(
        entry: entry, reader: reader, onReference: { references.append($0) },
        onIssue: { issues.append($0) })
      return ScanReceipt(state: state, references: references, issues: issues, failure: nil)
    } catch let failure as InspectionFailure {
      return ScanReceipt(state: nil, references: references, issues: issues, failure: failure)
    }
  }

  private enum ChildFailure: Error { case setup, changedResult }

  /// Exit without asking XCTest/Foundation teardown to access files under the child's policy.
  private func childFinish(_ value: [String: Any], code: Int32) -> Never {
    do {
      let data =
        Data("UVK-CONTAINMENT ".utf8)
        + (try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])) + Data([10])
      data.withUnsafeBytes { bytes in
        _ = Darwin.write(STDOUT_FILENO, bytes.baseAddress, bytes.count)
      }
      _exit(code)
    } catch { _exit(2) }
  }
}

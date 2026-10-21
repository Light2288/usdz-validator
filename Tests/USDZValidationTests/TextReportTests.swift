import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

final class TextReportTests: XCTestCase {
  func testCombiningMarkBasenameRelocationAndPathRedaction() throws {
    let path = "/\u{0301}Users/fixture-owner/input"
    let finding = Finding(
      ruleID: "UVK-PATH-004", occurrenceID: "stable-combining-id", category: .policy,
      severity: .error, message: "unsafe reference `\u{0301}" + path + "`",
      evidence: ["reference": .string(path)],
      location: FindingLocation(entryName: path, archiveByteOffset: 64),
      provenance: .native(validatorVersion: "0.1.0"))
    let configuration = try ValidationConfiguration()
    let coverage = Coverage(areas: [
      .references: CoverageAreaResult(
        requested: true, state: .partial,
        reasons: [
          CoverageReason(ruleID: "UVK-PATH-004", reasonID: "unsafeReference")
        ])
    ])
    let first = ValidationReport(
      input: ReportInput(displayName: "/private/\u{0301}input.usdz", byteSize: 123),
      configuration: configuration, coverage: coverage, nativeFindings: [finding])
    let relocated = ValidationReport(
      input: ReportInput(displayName: "/elsewhere/\u{0301}input.usdz", byteSize: 123),
      configuration: configuration, coverage: coverage, nativeFindings: [finding])
    let bytes = try ReportEncoder.encode(first, format: .text)
    let text = String(decoding: bytes, as: UTF8.self)
    XCTAssertTrue(text.contains("input: \u{0301}input.usdz\n"))
    XCTAssertFalse(text.contains("private/"))
    XCTAssertFalse(text.contains(path))
    XCTAssertFalse(text.contains("fixture-owner"))
    XCTAssertTrue(text.contains("stable-combining-id"))
    XCTAssertTrue(text.contains("unsafeReference"))
    XCTAssertEqual(bytes, try ReportEncoder.encode(relocated, format: .text))
    XCTAssertEqual(first.nativeFindings, [finding])
    XCTAssertEqual(first.coverage, coverage)
  }

  func testEquivalentMeaning() throws {
    let location = FindingLocation(
      entryName: "root.usda", archiveByteOffset: 64, layerByteOffset: 9, line: 2, column: 1)
    let finding = Finding(
      ruleID: "UVK-LIM-004", occurrenceID: "stable-id", category: .validatorLimitation,
      severity: .warning, message: "Binary references unavailable.",
      evidence: ["reason": .string("binaryLayer")], location: location,
      provenance: .native(validatorVersion: "0.1.0"))
    let external = Finding(
      ruleID: "USDCK-001", occurrenceID: "external-id", category: .appleCompatibility,
      severity: .error, message: "The checker reported failure.", evidence: [:], location: nil,
      provenance: .usdchecker(
        tool: "usdchecker", version: "Apple USD Tools (0.25.11)",
        invocationID: "/Users/fixture-owner/random-id"))
    let report = ValidationReport(
      input: ReportInput(
        displayName: "/Users/fixture-owner/input.usdz", byteSize: 123,
        sensitiveDetails: InputSensitiveDetails(absolutePath: "/Users/fixture-owner/input.usdz")),
      configuration: try ValidationConfiguration(gatePolicy: GatePolicy(allowIncomplete: true)),
      coverage: Coverage(areas: [
        .references: CoverageAreaResult(
          requested: true, state: .partial,
          reasons: [
            CoverageReason(ruleID: "UVK-LIM-004", reasonID: "binaryLayer", location: location)
          ])
      ]), nativeFindings: [finding],
      externalCheck: ExternalCheck(
        requested: true, phase: .validation, availability: .available,
        version: "Apple USD Tools (0.25.11)", policy: .general, status: .completed,
        outcome: .failureReported, exitCode: 1, stderrBytes: 99, hasStderr: true,
        sensitiveDetails: ExternalSensitiveDetails(
          arguments: ["/usr/bin/usdchecker", "/Users/fixture-owner/input.usdz"],
          stdout: "raw tool stdout", stderr: "/Users/fixture-owner/error\u{001b}"),
        findings: [external]))
    let bytes = try ReportEncoder.encode(report, format: .text)
    let text = String(decoding: bytes, as: UTF8.self)
    for visible in [
      "validatorLimitation", "warning", "native", "UVK-LIM-004", "binaryLayer", "references",
      "partial", "root.usda", "64", "stable-id", "appleCompatibility", "error", "usdchecker",
      "USDCK-001", "external-id", "completed", "failureReported", "gate", "fail", "exit", "1",
      "acceptedIncomplete: false",
    ] {
      XCTAssertTrue(text.contains(visible), visible)
    }
    XCTAssertFalse(text.contains("/Users/fixture-owner/"))
    XCTAssertFalse(text.contains("/usr/bin/usdchecker"))
    XCTAssertFalse(text.contains("raw tool stdout"))
    XCTAssertEqual(bytes.last, 0x0a)
    XCTAssertFalse(bytes.starts(with: [0xef, 0xbb, 0xbf]))
    XCTAssertEqual(bytes, try ReportEncoder.encode(report, format: .text))
  }

  func testSensitiveDetailsAreEscapedAndErrorsUseReasonCodes() throws {
    let raw = "/Users/fixture-owner/input\u{001b}\n.usdz"
    let report = ValidationReport(
      input: ReportInput(
        displayName: raw, byteSize: nil, sensitiveDetails: InputSensitiveDetails(absolutePath: raw)),
      configuration: try ValidationConfiguration(includeSensitiveDetails: true),
      coverage: Coverage(areas: [:]), nativeFindings: [],
      externalCheck: ExternalCheck(
        requested: true, status: .launchFailed,
        sensitiveDetails: ExternalSensitiveDetails(
          arguments: ["/usr/bin/usdchecker", raw], stdout: "\u{001b}tool", stderr: "failure\n")),
      operationalErrors: [.operational(.inputReadFailed)])
    let text = String(decoding: try ReportEncoder.encode(report, format: .text), as: UTF8.self)
    XCTAssertTrue(text.contains("input path: /Users/fixture-owner/input\\u{001B}\\n.usdz"))
    XCTAssertTrue(text.contains("external argument: /usr/bin/usdchecker"))
    XCTAssertTrue(text.contains("external stdout: \\u{001B}tool"))
    XCTAssertTrue(text.contains("external stderr: failure\\n"))
    XCTAssertTrue(text.contains("error: operational inputReadFailed"))
    XCTAssertTrue(text.contains("validationStatus: error"))
    XCTAssertTrue(text.contains("exit: 3"))
    XCTAssertFalse(text.contains("\u{001b}"))
  }

  func testOversizedReportThrowsBeforeReturningAnyDocument() throws {
    let finding = Finding(
      ruleID: "UVK-PATH-006", occurrenceID: "stable-id", category: .policy,
      severity: .error, message: "Missing reference.",
      evidence: ["detail": .string(String(repeating: "a", count: 4_096))], location: nil,
      provenance: .native(validatorVersion: "0.1.0"))
    let report = ValidationReport(
      input: ReportInput(displayName: "input.usdz", byteSize: 1),
      configuration: try ValidationConfiguration(), coverage: Coverage(areas: [:]),
      nativeFindings: Array(repeating: finding, count: 8_200))
    XCTAssertThrowsError(try ReportEncoder.encode(report, format: .text)) {
      XCTAssertEqual($0 as? ValidationError, .operational(.reportLimitExceeded))
    }
  }

  func testActualNativeFindingsAreEscapedAndRelocationIndependent() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let member = "Sources/texture\u{202e}.exr"
    let bytes = try ArchiveRecipe(entries: [
      .init(
        nameBytes: Data("root.usda".utf8),
        payload: Data("#usda 1.0\n@/Users/fixture-owner/external.png@".utf8)),
      .init(nameBytes: Data(member.utf8), payload: Data("bytes".utf8), flags: 0x0800),
      .init(nameBytes: Data("bad.usda".utf8), payload: Data("#usda 1.0\n".utf8), declaredCRC32: 1),
    ]).encode()
    let configuration = try ValidationConfiguration(
      profile: .applePortableV1, budgets: WarningBudgets(fileBytes: 1, textureBytes: 1))
    let url = try Fixtures.write(bytes, basename: "input.usdz", in: directory)
    let snapshot = try FileSnapshot.open(url)
    defer { try? snapshot.close() }
    let native = try NativeEngine.inspect(snapshot: snapshot, configuration: configuration)
    XCTAssertTrue(
      native.findings.contains { $0.ruleID == "UVK-BUD-004" && $0.location?.entryName == member })
    XCTAssertTrue(native.findings.contains { $0.ruleID == "UVK-APL-001" })
    XCTAssertTrue(
      native.findings.contains {
        $0.ruleID == "UVK-ARC-003" && $0.location?.entryName == "bad.usda"
      })
    let report = ValidationReport(
      input: ReportInput(displayName: url.path, byteSize: Int64(native.inputByteSize)),
      configuration: configuration, coverage: native.coverage, nativeFindings: native.findings)
    let rendered = try ReportEncoder.encode(report, format: .text)
    let text = String(decoding: rendered, as: UTF8.self)
    XCTAssertTrue(text.contains("Sources/texture\\u{202E}.exr"))
    XCTAssertTrue(text.contains("unsafeReference"))
    XCTAssertFalse(text.contains("\u{202e}"))
    XCTAssertFalse(text.contains("/Users/fixture-owner/"))
    for finding in native.findings { XCTAssertTrue(text.contains(finding.occurrenceID)) }
    let relocated = ValidationReport(
      input: ReportInput(
        displayName: "/another/place/input.usdz", byteSize: Int64(native.inputByteSize)),
      configuration: configuration, coverage: native.coverage, nativeFindings: native.findings)
    XCTAssertEqual(rendered, try ReportEncoder.encode(relocated, format: .text))
    XCTAssertEqual(report.nativeFindings, native.findings)
    XCTAssertEqual(report.coverage, native.coverage)
  }
}

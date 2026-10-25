import Foundation
import TestSupport
import XCTest

@testable import USDZValidation

final class AdversarialTests: XCTestCase {
  func testBoundedMutationCorpus() throws {
    // Removing a length/range check, changing unsupported to malformed, reading
    // neighboring payloads, or probing a disabled tool must break these assertions.
    let seed: UInt64 = 0x5556_4b01
    let cases = MutationRecipes.cases(seed: seed)
    XCTAssertEqual(cases.count, 251)
    XCTAssertEqual(Set(cases.map(\.id)).count, 251)
    XCTAssertEqual(cases, MutationRecipes.cases(seed: seed))
    XCTAssertNotEqual(cases, MutationRecipes.cases(seed: seed ^ 1))
    XCTAssertEqual(Set(cases.map(\.surface)), Set(MutationCase.Surface.allCases))
    XCTAssertTrue(cases.contains { $0.id == "zip.interaction.name-crosses-directory" })
    XCTAssertTrue(cases.contains { $0.id == "zip.interaction.extra-crosses-directory" })
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    addTeardownBlock { try FileManager.default.removeItem(at: directory) }

    var externalExecutionCount = 0
    var externalProbeCount = 0
    let adapter = USDCheckerAdapter(
      execute: { _ in
        externalExecutionCount += 1
        XCTFail("Native adversarial validation executed a tool")
        return ProcessResult(
          outcome: .launchFailed, exitCode: nil, signal: nil, stdout: Data(), stderr: Data(),
          stdoutByteCount: 0, stderrByteCount: 0, truncated: false,
          terminationReason: .launchError, processIdentifier: nil, childReaped: true)
      },
      isExecutable: { _ in
        externalProbeCount += 1
        XCTFail("Native adversarial validation probed a tool")
        return false
      })
    let validator = Validator(adapter: adapter)
    let configuration = try ValidationConfiguration()
    var malformed = 0
    var unsupported = 0
    for mutation in cases {
      XCTAssertFalse(mutation.recipe.isEmpty, mutation.id)
      XCTAssertLessThan(mutation.bytes.count, 4_096, mutation.id)
      let url = try Fixtures.write(mutation.bytes, basename: "input.usdz", in: directory)
      // These stable local regular files require findings for content failures;
      // an untyped throw or an internal/configuration failure is never an oracle.
      let first = try validator.validate(fileAt: url, configuration: configuration)
      let repeated = try validator.validate(fileAt: url, configuration: configuration)
      XCTAssertEqual(first.nativeFindings, repeated.nativeFindings, mutation.id)
      XCTAssertEqual(first, repeated, mutation.id)
      XCTAssertEqual(first.externalCheck, .notRequested, mutation.id)
      XCTAssertTrue(first.operationalErrors.isEmpty, mutation.id)
      assertControlled(first.nativeFindings, id: mutation.id)
      switch mutation.oracle {
      case .invariants: break
      case .malformed(let ruleID):
        malformed += 1
        XCTAssertTrue(
          first.nativeFindings.contains { $0.ruleID == ruleID && $0.severity == .error },
          "\(mutation.id): expected \(ruleID), got \(first.nativeFindings.map(\.ruleID))")
      case .unsupported(let ruleID):
        unsupported += 1
        XCTAssertTrue(
          first.nativeFindings.contains {
            $0.ruleID == ruleID && $0.category == .validatorLimitation && $0.severity == .warning
          }, "\(mutation.id): expected \(ruleID), got \(first.nativeFindings.map(\.ruleID))")
        XCTAssertFalse(first.coverage.isComplete, mutation.id)
        XCTAssertFalse(first.nativeFindings.contains { $0.severity == .error }, mutation.id)
      }
      let observed = try instrument(mutation.bytes, id: mutation.id)
      let again = try instrument(mutation.bytes, id: mutation.id)
      XCTAssertEqual(observed, again, mutation.id)
      XCTAssertLessThanOrEqual(observed.totalReadBytes, 1_207_959_552, mutation.id)
      XCTAssertLessThanOrEqual(
        observed.totalReadBytes, UInt64(mutation.bytes.count) * 8, mutation.id)
      XCTAssertLessThanOrEqual(observed.maximumReadBytes, 65_536, mutation.id)
      XCTAssertLessThanOrEqual(observed.readCalls, observed.totalReadBytes, mutation.id)
      XCTAssertEqual(externalExecutionCount, 0, mutation.id)
      XCTAssertEqual(externalProbeCount, 0, mutation.id)
      XCTAssertEqual(try Data(contentsOf: url), mutation.bytes, mutation.id)
      try FileManager.default.removeItem(at: url)
    }
    XCTAssertEqual(malformed, 24)
    XCTAssertEqual(unsupported, 7)
    // Archive member names never become filesystem destinations. All mutations
    // share the same temporary basename, which is removed after each case.
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [])
  }

  private struct Observed: Equatable {
    let findings: [Finding]
    let coverage: Coverage
    let totalReadBytes: UInt64
    let maximumReadBytes: Int
    let readCalls: UInt64
  }

  /// Supplemental composition pass through real parser entry points. NativeEngine
  /// separately runs above; these counters describe this pass, not its private ledger.
  private func instrument(_ bytes: Data, id: String) throws -> Observed {
    let ledger = ResourceLedger()
    let diagnostics = NativeDiagnostics()
    var allowedRange = UInt64(0)..<UInt64(bytes.count)
    var readBytes: UInt64 = 0
    var maximumReadBytes = 0
    var readCalls: UInt64 = 0
    let caseReadLimit = UInt64(bytes.count) * 8
    let reader = BoundedReader(size: UInt64(bytes.count), ledger: ledger) { offset, count in
      let (end, overflow) = offset.addingReportingOverflow(UInt64(count))
      guard !overflow, count > 0, count <= 65_536,
        offset >= allowedRange.lowerBound, end <= allowedRange.upperBound,
        end <= UInt64(bytes.count)
      else {
        XCTFail("\(id): read escaped its validated archive/member range")
        throw InspectionFailure.malformedRange
      }
      guard readBytes + UInt64(count) <= caseReadLimit else {
        XCTFail("\(id): parser exceeded eight archive passes")
        throw InspectionFailure.resourceLimit(.totalReadBytes)
      }
      readBytes += UInt64(count)
      readCalls += 1
      maximumReadBytes = max(maximumReadBytes, count)
      return bytes.subdata(in: Int(offset)..<Int(end))
    }
    if let directory = try ZIPDirectory.read(from: reader, diagnostics: diagnostics),
      let index = try ZIPIndex.build(
        directory: directory, reader: reader, diagnostics: diagnostics),
      let namespace = PackageNamespace.build(index: index, diagnostics: diagnostics)
    {
      XCTAssertLessThanOrEqual(index.entries.count, 10_000, id)
      for entry in index.entries {
        allowedRange = entry.payloadRange
        guard try StoredPayload.check(entry: entry, reader: reader, diagnostics: diagnostics),
          namespace.regularEntry(namedUTF8: entry.nameBytes) != nil
        else { continue }
        let kind = MemberClassifier.kind(nameBytes: entry.nameBytes)
        switch kind {
        case .usd, .usda, .usdc, .usdz:
          let layerKind = try USDLayer.identify(
            entry: entry, reader: reader, diagnostics: diagnostics)
          if layerKind == .usdc {
            _ = try USDCReader.scan(
              entry: entry, reader: reader,
              onReference: { occurrence in
                ReferenceResolver.check(
                  occurrence: occurrence, author: entry, namespace: namespace,
                  diagnostics: diagnostics)
              },
              onIssue: { USDCReporting.record(issue: $0, entry: entry, diagnostics: diagnostics) })
            XCTAssertEqual(ledger.usdcLiveBytes, 0)
          } else if layerKind == .usda {
            try USDALexer.scan(entry: entry, reader: reader, diagnostics: diagnostics) { token in
              ReferenceResolver.check(
                token: token, author: entry, namespace: namespace, diagnostics: diagnostics)
            }
          }
        case .png, .jpeg:
          _ = try TextureHeaders.inspect(
            entry: entry, kind: kind, reader: reader, diagnostics: diagnostics)
        default: break
        }
      }
    }
    let (findings, coverage) = diagnostics.finish()
    assertControlled(findings, id: id)
    XCTAssertEqual(ledger.totalReadBytes, readBytes, id)
    XCTAssertLessThanOrEqual(ledger.totalReadBytes, 1_207_959_552, id)
    return Observed(
      findings: findings, coverage: coverage, totalReadBytes: ledger.totalReadBytes,
      maximumReadBytes: maximumReadBytes, readCalls: readCalls)
  }

  private func assertControlled(_ findings: [Finding], id: String) {
    let knownRules = Set(RuleCatalogue.descriptors(profile: .applePortableV1).map(\.ruleID))
    XCTAssertLessThanOrEqual(findings.count, 10_000, id)
    XCTAssertEqual(Set(findings.map(\.occurrenceID)).count, findings.count, id)
    for finding in findings {
      XCTAssertTrue(knownRules.contains(finding.ruleID), id)
      XCTAssertEqual(finding.provenance, .native(validatorVersion: ValidatorVersion.current), id)
      XCTAssertEqual(finding.occurrenceID.utf8.count, 64, id)
      XCTAssertLessThanOrEqual(finding.message.utf8.count, 1_024, id)
      for value in finding.evidence.values {
        if case .string(let string) = value {
          XCTAssertLessThanOrEqual(string.utf8.count, 4_096, id)
        }
      }
    }
  }
}

extension AdversarialTests {
  // Length/index/cycle mutations must give repeatable declared failures, never a crash
  // or a silently complete inventory. Expectations are literal wire-contract reasons.
  func testDeterministicUSDCStructuralMutations() throws {
    let valid = try USDCMutationRecipe.valueCrate(reps: [0x400c_0000_0000_0002])
    let cycle = try USDCMutationRecipe.valueCrate(
      reps: [0x0034_0000_0000_0058],
      body: USDCReferenceTests.word(8) + USDCReferenceTests.word(0x0034_0000_0000_0058))
    let vectors: [(String, Data, USDCScanState, USDCFailure)] = [
      ("header-short", Data(valid.prefix(87)), .uninspected, .malformed(.invalidHeader)),
      (
        "future-version", try USDCMutationRecipe.patch(valid, at: 8, bytes: Data([0, 11, 0])),
        .uninspected, .unsupported(.unsupportedVersion)
      ),
      (
        "toc-outside",
        try USDCMutationRecipe.patch(valid, at: 16, bytes: USDCReferenceTests.word(.max)),
        .uninspected, .malformed(.invalidSection)
      ),
      (
        "asset-index", try USDCMutationRecipe.valueCrate(reps: [0x400c_0000_0000_ffff]),
        .partial, .malformed(.invalidIndex)
      ),
      ("active-cycle", cycle, .partial, .malformed(.invalidGraph)),
      (
        "unknown-type", try USDCMutationRecipe.valueCrate(reps: [0x003f_0000_0000_0058]),
        .partial, .unsupported(.unsupportedValue)
      ),
    ]
    for (name, bytes, state, failure) in vectors {
      for _ in 0..<2 {
        let ledger = ResourceLedger()
        let result = try USDCReferenceTests.scan(bytes, ledger: ledger)
        XCTAssertEqual(result.state, state, name)
        XCTAssertEqual(result.issues.map(\.failure), [failure], name)
        XCTAssertTrue(result.references.isEmpty, name)
        XCTAssertEqual(ledger.usdcLiveBytes, 0, name)
      }
    }
  }
}

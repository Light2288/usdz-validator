import CryptoKit
import Foundation
import XCTest

@testable import USDZValidation

/// Private evidence is opt-in and never part of the distributable fixture corpus.
/// Freeze schema-1 expectations from historical authored receipts before candidate
/// collection. Inputs name the five corpus IDs, absolute originals and SHA-256;
/// references retain base64 member/value bytes, path elements, field and semantic
/// container keys/indices. Carry corpus/oracle receipt hashes and explicitly resolved
/// oracle omissions. Keep manifests and raw receipts in ignored .build/verification/.
/// No manifest skips the original-dependent tests; invalid supplied evidence fails.
/// USDA sites use the existing lexical offset/line/column identity. The five frozen
/// originals have scalar USDC default sites; new containers fail for investigation.
final class USDCPrivateCorpusTests: XCTestCase {
  // A permissive comparator would hide changed bytes/sites, duplicates, or incomplete evidence.
  func testPrivateManifestComparatorRejectsWrongEvidence() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let original = folder.appendingPathComponent("original.usdz")
    try Data([0x61, 0x62, 0x63]).write(to: original)
    let hash = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    let first = Site(
      memberNameBytes: Data("root.usdc".utf8), valueBytes: Data("same.png".utf8),
      pathElements: ["/", "One", ".asset"], field: "default", container: [])
    let second = Site(
      memberNameBytes: Data("root.usdc".utf8), valueBytes: Data("same.png".utf8),
      pathElements: ["/", "Two", ".asset"], field: "default",
      container: [.key("texture"), .index(0)])
    let expected = [first, second]
    XCTAssertNoThrow(try compare(expected, [second, first]))
    var changed = first
    changed.valueBytes = Data("wrong.png".utf8)
    XCTAssertThrowsError(try compare(expected, [changed, second]))
    changed = first
    changed.pathElements = ["/", "Wrong", ".asset"]
    XCTAssertThrowsError(try compare(expected, [changed, second]))
    changed = second
    changed.container = [.key("texture"), .index(1)]
    XCTAssertThrowsError(try compare(expected, [first, changed]))
    XCTAssertThrowsError(try compare(expected, [first, first, second]))
    XCTAssertThrowsError(try compare([first, first, second], expected))
    let sources = [
      "corpus-final.json": String(repeating: "a", count: 64),
      "oracle-final.json": String(repeating: "b", count: 64),
    ]
    var manifest = Manifest(
      schemaVersion: 1,
      inputs: Self.samples.map { id, count in
        Input(
          id: id, path: original.path, sha256: hash,
          expectedReferences: Array(repeating: first, count: count),
          sourceReceiptHashes: sources,
          oracleOmissions: (0..<Self.omissionCounts[id]!).map { index in
            Omission(
              pathElements: ["/", "[target\(index)]"],
              reason: "Traverse path has no Python SdfSpec object",
              classification: "target-path-without-serialized-spec",
              resolution: "Independent serialized-spec census")
          })
      })
    XCTAssertNoThrow(try validate(manifest))
    XCTAssertNoThrow(try verifyOriginal(manifest.inputs[0]))
    var wrong = manifest.inputs[0]
    wrong.sha256 = String(repeating: "0", count: 64)
    XCTAssertThrowsError(try verifyOriginal(wrong))
    wrong.path = folder.appendingPathComponent("absent.usdz").path
    XCTAssertThrowsError(try verifyOriginal(wrong))
    let complete = manifest
    manifest.inputs.removeLast()
    XCTAssertThrowsError(try validate(manifest))
    manifest = complete
    let completeOmissions = manifest.inputs[0].oracleOmissions
    manifest.inputs[0].oracleOmissions.removeLast()
    XCTAssertThrowsError(try validate(manifest))
    manifest.inputs[0].oracleOmissions = completeOmissions
    manifest.inputs[0].oracleOmissions[0] =
      Omission(
        pathElements: ["/", "Target"], reason: "unexposed", classification: "", resolution: "")
    XCTAssertThrowsError(try validate(manifest))
    XCTAssertThrowsError(try loadManifest(folder.appendingPathComponent("absent.json").path))
    let supplied = folder.appendingPathComponent("manifest.json")
    for malformed in [
      Data("{".utf8), Data("{}".utf8), Data("{\"schemaVersion\":1,\"inputs\":[]}".utf8),
    ] {
      try malformed.write(to: supplied)
      XCTAssertThrowsError(try loadManifest(supplied.path))
    }
  }

  func testPrivateOriginalSemanticInventories() throws {
    let manifest = try privateManifest()
    let output = try evidenceDirectory().appendingPathComponent("inventories", isDirectory: true)
    guard !FileManager.default.fileExists(atPath: output.path) else {
      throw EvidenceError.invalid("Private evidence destination must be fresh")
    }
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
    var total = 0
    for input in manifest.inputs {
      try verifyOriginal(input)
      let sites = try inventory(input)
      try compare(input.expectedReferences, sites)
      try write(
        sites,
        to: output.appendingPathComponent(input.id.components(separatedBy: "/").last! + ".json"))
      try verifyOriginal(input)
      total += sites.count
    }
    XCTAssertEqual(total, 59)
  }

  func testPrivateOriginalReleaseMeasurements() throws {
    let manifest = try privateManifest()
    let output = try evidenceDirectory().appendingPathComponent("release", isDirectory: true)
    guard !FileManager.default.fileExists(atPath: output.path) else {
      throw EvidenceError.invalid("Private evidence destination must be fresh")
    }
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
    let executable = Self.root.appendingPathComponent(".build/release/usdz-validator")
    guard FileManager.default.isExecutableFile(atPath: executable.path) else {
      throw EvidenceError.invalid("Build the release CLI before private measurement")
    }
    for input in manifest.inputs {
      try verifyOriginal(input)
      try measure(input, executable: executable, output: output)
      try verifyOriginal(input)
    }
  }

  private static let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  private static let samples = [
    ("corpus/seahorse_anim_mtl_variant.usdz", 20), ("corpus/pancakes_photogrammetry.usdz", 20),
    ("corpus/fender_stratocaster.usdz", 10), ("corpus/slide.usdz", 4), ("corpus/teapot.usdz", 5),
  ]

  private static let omissionCounts = [
    "corpus/seahorse_anim_mtl_variant.usdz": 75, "corpus/pancakes_photogrammetry.usdz": 82,
    "corpus/fender_stratocaster.usdz": 68, "corpus/slide.usdz": 14, "corpus/teapot.usdz": 17,
  ]

  private struct Manifest: Codable {
    var schemaVersion: Int
    var inputs: [Input]
  }
  private struct Input: Codable {
    var id: String
    var path: String
    var sha256: String
    var expectedReferences: [Site]
    var sourceReceiptHashes: [String: String]
    var oracleOmissions: [Omission]
  }
  private struct Omission: Codable {
    var pathElements: [String]
    var reason: String
    var classification: String
    var resolution: String
  }
  private enum Coordinate: Hashable, Codable {
    case key(String)
    case index(UInt64)
    init(from decoder: Decoder) throws {
      let c = try decoder.singleValueContainer()
      if let key = try? c.decode(String.self) {
        self = .key(key)
      } else {
        self = .index(try c.decode(UInt64.self))
      }
    }
    func encode(to encoder: Encoder) throws {
      var c = encoder.singleValueContainer()
      switch self {
      case .key(let key): try c.encode(key)
      case .index(let index): try c.encode(index)
      }
    }
  }
  private struct Site: Hashable, Codable {
    var memberNameBytes: Data
    var valueBytes: Data
    var pathElements: [String]
    var field: String
    var container: [Coordinate]
  }
  private enum EvidenceError: Error { case invalid(String) }

  private func compare(_ expected: [Site], _ actual: [Site]) throws {
    let expectedCounts = Dictionary(grouping: expected, by: { $0 }).mapValues(\.count)
    let actualCounts = Dictionary(grouping: actual, by: { $0 }).mapValues(\.count)
    guard expectedCounts == actualCounts else {
      // Keep authored values and sites in the ignored inventory, never in XCTest output.
      throw EvidenceError.invalid(
        "Semantic occurrence multisets differ: expected \(expected.count), actual \(actual.count)")
    }
  }

  private func validate(_ manifest: Manifest) throws {
    guard manifest.schemaVersion == 1, manifest.inputs.count == Self.samples.count,
      Set(manifest.inputs.map(\.id)) == Set(Self.samples.map { $0.0 })
    else {
      throw EvidenceError.invalid("Missing, duplicate, extra sample or unsupported manifest schema")
    }
    for input in manifest.inputs {
      guard input.path.hasPrefix("/"), validHash(input.sha256),
        input.expectedReferences.count == Self.samples.first(where: { $0.0 == input.id })?.1,
        validHash(input.sourceReceiptHashes["corpus-final.json"] ?? ""),
        validHash(input.sourceReceiptHashes["oracle-final.json"] ?? ""),
        input.sourceReceiptHashes.values.allSatisfy(validHash),
        input.expectedReferences.allSatisfy({
          !$0.memberNameBytes.isEmpty && $0.memberNameBytes.count <= 4096
            && $0.valueBytes.count <= 4096 && $0.pathElements.first == "/"
            && $0.pathElements.count <= 33 && !$0.field.isEmpty && $0.container.count <= 96
        }),
        input.oracleOmissions.count == Self.omissionCounts[input.id],
        Set(input.oracleOmissions.map(\.pathElements)).count == input.oracleOmissions.count,
        input.oracleOmissions.allSatisfy({
          !$0.pathElements.isEmpty && $0.reason == "Traverse path has no Python SdfSpec object"
            && $0.classification == "target-path-without-serialized-spec" && !$0.resolution.isEmpty
        })
      else {
        throw EvidenceError.invalid(
          "Incomplete input fingerprint, expectations, provenance or oracle omission resolution")
      }
    }
  }

  private func validHash(_ value: String) -> Bool {
    value.utf8.count == 64
      && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
  }

  private func verifyOriginal(_ input: Input) throws {
    let snapshot = try FileSnapshot.open(URL(fileURLWithPath: input.path))
    do {
      var digest = SHA256()
      var offset: UInt64 = 0
      while offset < snapshot.size {
        let count = Int(min(SafetyResource.readChunkBytes.limit, snapshot.size - offset))
        digest.update(data: try snapshot.read(offset: offset, count: count))
        offset += UInt64(count)
      }
      try snapshot.verifyUnchanged()
      try snapshot.close()
      guard digest.finalize().map({ String(format: "%02x", $0) }).joined() == input.sha256 else {
        throw EvidenceError.invalid("Original fingerprint mismatch")
      }
    } catch {
      try snapshot.close()
      throw error
    }
  }

  private func privateManifest() throws -> Manifest {
    guard let path = ProcessInfo.processInfo.environment["UVK_USDC_PRIVATE_CORPUS_MANIFEST"] else {
      throw XCTSkip("Private originals absent: UVK_USDC_PRIVATE_CORPUS_MANIFEST is unset")
    }
    return try loadManifest(path)
  }

  private func loadManifest(_ path: String) throws -> Manifest {
    guard path.hasPrefix("/") else { throw EvidenceError.invalid("Manifest path must be absolute") }
    let snapshot = try FileSnapshot.open(URL(fileURLWithPath: path))
    let bytes: Data
    do {
      guard snapshot.size <= 1_048_576 else {
        throw EvidenceError.invalid("Manifest exceeds 1 MiB")
      }
      var bounded = Data()
      var offset: UInt64 = 0
      while offset < snapshot.size {
        let count = Int(min(SafetyResource.readChunkBytes.limit, snapshot.size - offset))
        bounded.append(try snapshot.read(offset: offset, count: count))
        offset += UInt64(count)
      }
      bytes = bounded
      try snapshot.close()
    } catch {
      try snapshot.close()
      throw error
    }
    let manifest = try JSONDecoder().decode(Manifest.self, from: bytes)
    try validate(manifest)
    return manifest
  }

  private func evidenceDirectory() throws -> URL {
    guard let path = ProcessInfo.processInfo.environment["UVK_USDC_PRIVATE_EVIDENCE_DIR"],
      path.hasPrefix("/")
    else { throw EvidenceError.invalid("An absolute fresh private evidence directory is required") }
    let output = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath()
    let ignored = Self.root.appendingPathComponent(".build/verification").resolvingSymlinksInPath()
    guard output.path.hasPrefix(ignored.path + "/") else {
      throw EvidenceError.invalid(
        "Raw private receipts must remain under ignored .build/verification/")
    }
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    return output
  }

  private func inventory(_ input: Input) throws -> [Site] {
    let snapshot = try FileSnapshot.open(URL(fileURLWithPath: input.path))
    do {
      let ledger = ResourceLedger()
      var sourceReads = 0
      var forbiddenRanges = 0
      let readSource: (UInt64, Int) throws -> Data = { offset, count in
        guard let bytes = UInt64(exactly: count) else {
          forbiddenRanges += 1
          throw InspectionFailure.malformedRange
        }
        let (end, overflow) = offset.addingReportingOverflow(bytes)
        guard !overflow, end <= snapshot.size else {
          forbiddenRanges += 1
          throw InspectionFailure.malformedRange
        }
        sourceReads += 1
        return try snapshot.read(offset: offset, count: count)
      }
      let reader = BoundedReader(size: snapshot.size, ledger: ledger, readAt: readSource)
      let diagnostics = NativeDiagnostics()
      let directory = try XCTUnwrap(ZIPDirectory.read(from: reader, diagnostics: diagnostics))
      let index = try XCTUnwrap(
        ZIPIndex.build(directory: directory, reader: reader, diagnostics: diagnostics))
      let namespace = try XCTUnwrap(PackageNamespace.build(index: index, diagnostics: diagnostics))
      let defaultEntry = try XCTUnwrap(namespace.defaultEntry)
      var eligible = Set<UInt64>()
      for entry in index.entries {
        guard try StoredPayload.check(entry: entry, reader: reader, diagnostics: diagnostics) else {
          throw EvidenceError.invalid("Archive integrity prerequisite failed")
        }
        if namespace.regularEntry(namedUTF8: entry.nameBytes) != nil {
          eligible.insert(entry.localHeaderOffset)
        }
      }
      let defaultKind = try USDLayer.identify(
        entry: defaultEntry, reader: reader, diagnostics: diagnostics)
      guard defaultKind == .usdc || defaultKind == .usda else {
        throw EvidenceError.invalid("Default layer prerequisite failed")
      }
      var sites: [Site] = []
      for entry in index.entries where eligible.contains(entry.localHeaderOffset) {
        let memberKind = MemberClassifier.kind(nameBytes: entry.nameBytes)
        guard [.usd, .usda, .usdc, .usdz].contains(memberKind) else { continue }
        let kind = try USDLayer.identify(entry: entry, reader: reader, diagnostics: diagnostics)
        switch kind {
        case .usdc:
          var occurrences: [ReferenceOccurrence] = []
          var issueCount = 0
          let state = try USDCReader.scan(
            entry: entry, reader: reader, defaultEntry: defaultEntry,
            onReference: { occurrences.append($0) }, onIssue: { _ in issueCount += 1 })
          guard state == .complete, issueCount == 0, ledger.usdcLiveBytes == 0 else {
            throw EvidenceError.invalid("Incomplete private USDC scan or retained scanner storage")
          }
          // Re-reading metadata for test-only site reconstruction uses its own ledger;
          // that helper overhead cannot establish production scanner work or CLI RSS.
          let semanticLedger = ResourceLedger()
          let semanticReader = BoundedReader(
            size: snapshot.size, ledger: semanticLedger, readAt: readSource)
          sites += try semanticSites(occurrences, entry: entry, reader: semanticReader)
          XCTAssertEqual(semanticLedger.usdcLiveBytes, 0)
        case .usda:
          try USDALexer.scan(entry: entry, reader: reader, diagnostics: diagnostics) { token in
            sites.append(
              Site(
                memberNameBytes: entry.nameBytes, valueBytes: token.rawValueBytes,
                pathElements: ["/"], field: "assetLiteral",
                container: [
                  .key("offset"), .index(token.layerByteOffset), .key("line"), .index(token.line),
                  .key("column"), .index(token.column),
                ]))
          }
        default: throw EvidenceError.invalid("Eligible layer is unrecognized or unsupported")
        }
        guard sites.count <= Int(SafetyResource.tokenCount.limit) else {
          throw EvidenceError.invalid("Private inventory occurrence cap exceeded")
        }
      }
      guard diagnostics.finish().0.isEmpty else {
        throw EvidenceError.invalid("Package prerequisite or lexical diagnostic")
      }
      XCTAssertEqual(ledger.usdcLiveBytes, 0)
      XCTAssertEqual(forbiddenRanges, 0)
      XCTAssertGreaterThan(sourceReads, 0)
      let metrics = [
        "sourceReads": UInt64(sourceReads), "forbiddenRanges": UInt64(forbiddenRanges),
        "scannerLiveBytesAfter": ledger.usdcLiveBytes, "scannerWorkUnits": ledger.usdcWorkUnits,
        "scannerDecodeBytes": ledger.usdcDecodeBytes, "occurrences": UInt64(sites.count),
      ]
      let name = input.id.components(separatedBy: "/").last! + ".metrics"
      try write(
        metrics,
        to: evidenceDirectory().appendingPathComponent("inventories").appendingPathComponent(name))
      try snapshot.verifyUnchanged()
      try snapshot.close()
      return sites
    } catch {
      try snapshot.close()
      throw error
    }
  }

  private func semanticSites(
    _ occurrences: [ReferenceOccurrence], entry: ZIPEntry, reader: BoundedReader
  ) throws -> [Site] {
    let tables = try USDCTables.read(input: USDCInput(entry: entry, reader: reader))
    let wanted = Set(
      try occurrences.map { occurrence in
        guard case .usdc(let locator) = occurrence.site else {
          throw EvidenceError.invalid("Binary occurrence required")
        }
        return "\(locator.specIndex):\(locator.fieldOrdinal)"
      })
    var fields: [String: USDCLiveField] = [:]
    try tables.forEachLiveField { field in
      let key = "\(field.specIndex):\(field.fieldOrdinal)"
      if wanted.contains(key) { fields[key] = field }
    }
    return try occurrences.map { occurrence in
      guard case .usdc(let locator) = occurrence.site,
        let field = fields["\(locator.specIndex):\(locator.fieldOrdinal)"]
      else {
        throw EvidenceError.invalid("Missing binary authored field")
      }
      // The frozen five-original oracle establishes scalar default sites. A new
      // container is a discrepancy requiring investigation, never guessed coordinates.
      guard locator.steps.isEmpty else {
        throw EvidenceError.invalid("Unexpected private-original container site")
      }
      var path: UInt32? = field.pathIndex
      var parts: [String] = []
      while let index = path {
        guard parts.count <= Int(SafetyResource.usdcDepth.limit) else {
          throw EvidenceError.invalid("Semantic path depth exceeded")
        }
        let element = try tables.pathElement(at: index)
        let token = try tables.withTokenBytes(at: element.tokenIndex) {
          String(decoding: $0, as: UTF8.self)
        }
        parts.append(element.parentIndex == nil ? "/" : (element.isProperty ? "." : "") + token)
        path = element.parentIndex
      }
      let name = try tables.withTokenBytes(at: field.nameTokenIndex) {
        String(decoding: $0, as: UTF8.self)
      }
      return Site(
        memberNameBytes: entry.nameBytes, valueBytes: occurrence.valueBytes,
        pathElements: parts.reversed(), field: name, container: [])
    }
  }

  private func measure(_ input: Input, executable: URL, output: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [
      "python3", "-c", Self.measurementScript, executable.path, input.path, output.path,
    ]
    let log = output.appendingPathComponent(
      URL(fileURLWithPath: input.path).lastPathComponent + ".driver.log")
    guard FileManager.default.createFile(atPath: log.path, contents: nil) else {
      throw EvidenceError.invalid("Cannot create private measurement log")
    }
    let handle = try FileHandle(forWritingTo: log)
    process.standardOutput = handle
    process.standardError = handle
    do {
      try process.run()
      process.waitUntilExit()
      try handle.close()
    } catch {
      try handle.close()
      throw error
    }
    guard process.terminationReason == .exit, process.terminationStatus == 0 else {
      throw EvidenceError.invalid(
        "Release measurement failed; inspect ignored per-sample driver receipt")
    }
  }

  // This test driver measures the complete CLI, including JSON delivery. Python is
  // verification infrastructure only; the product does not launch this subprocess.
  private static let measurementScript = #"""
    import hashlib,json,os,pathlib,platform,re,signal,subprocess,sys,time
    executable,original,output=map(pathlib.Path,sys.argv[1:])
    assert platform.system()=='Darwin', 'Darwin /usr/bin/time -l required'
    def sha(path):
        with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
    executable_hash=sha(executable); original_hash=sha(original)
    candidate=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
    harness_hash=sha(pathlib.Path('Tests/USDZValidationTests/USDCPrivateCorpusTests.swift'))
    rows=[]; reports=[]; failures=[]
    for run in range(1,4):
        prefix=output/(original.stem+'-run-'+str(run))
        report=prefix.with_suffix('.json'); stdout=prefix.with_suffix('.stdout'); stderr=prefix.with_suffix('.stderr')
        assert not any(p.exists() for p in [report,stdout,stderr]), 'Fresh evidence destination required'
        command=['/usr/bin/time','-l',str(executable),'validate',str(original),'--format','json','--output',str(report)]
        start=time.perf_counter(); timed_out=False
        with stdout.open('wb') as out,stderr.open('wb') as err:
            child=subprocess.Popen(command,stdout=out,stderr=err,start_new_session=True)
            try:child.wait(timeout=60)
            except subprocess.TimeoutExpired:
                timed_out=True;os.killpg(child.pid,signal.SIGKILL);child.wait()
        elapsed=time.perf_counter()-start
        diagnostic=stderr.read_text(errors='replace')
        rss=re.search(r'(\d+)\s+maximum resident set size',diagnostic)
        native_time=re.search(r'([\d.]+)\s+real\s+',diagnostic)
        peak=int(rss.group(1)) if rss else None
        if native_time:elapsed=max(elapsed,float(native_time.group(1)))
        problems=[]
        if timed_out or elapsed>60:problems.append('elapsed/deadline')
        if peak is None or peak>268435456:problems.append('peak RSS missing/exceeded')
        if child.returncode!=0:problems.append('exit expected 0')
        if stdout.stat().st_size:problems.append('unexpected stdout')
        if report.exists():
            payload=report.read_bytes();reports.append(payload);document=json.loads(payload)
            if document['tool']['version']!='0.2.0':problems.append('product identity')
            if document['configuration']['safetyEnvelopeVersion']!=3:problems.append('envelope identity')
            if document['configuration']['profile']!='general-v1':problems.append('default profile')
            if document['externalCheck']['status']!='notRequested':problems.append('external checker')
            if document['gateDecision']!='pass' or document['acceptedIncomplete']:problems.append('default acceptance')
            if not document['coverage']['isComplete']:problems.append('incomplete native coverage')
            if any(a['requested'] and a['state']!='complete' for a in document['coverage']['areas'].values()):problems.append('requested native gap')
        else:problems.append('missing report')
        rows.append(dict(run=run,command=command,exit=child.returncode,elapsedSeconds=elapsed,peakRSSBytes=peak,timedOut=timed_out,failures=problems))
        failures.extend(problems)
    if len(reports)!=3 or len(set(reports))!=1:failures.append('repeat report mismatch')
    if sha(original)!=original_hash:failures.append('original changed')
    if sha(executable)!=executable_hash:failures.append('executable changed')
    receipt=dict(candidate=candidate,harnessSHA256=harness_hash,host=platform.platform(),machine=platform.machine(),executableSHA256=executable_hash,originalSHA256Before=original_hash,originalSHA256After=sha(original),reportHashes=[hashlib.sha256(r).hexdigest() for r in reports],runs=rows,failures=failures)
    (output/(original.stem+'-measurement.json')).write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(dict(runs=len(rows),failures=failures)))
    sys.exit(bool(failures))
    """#

  private func write<T: Encodable>(_ value: T, to url: URL) throws {
    try JSONEncoder().encode(value).write(to: url)
  }
}

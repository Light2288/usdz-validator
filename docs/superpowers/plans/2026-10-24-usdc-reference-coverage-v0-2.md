# USDC Reference Coverage v0.2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically inspect the approved package-local authored-reference subset of exact USDC 0.8.0, 0.9.0 and 0.10.0, with truthful coverage and measured resource bounds.

**Architecture:** A selective Swift reader follows live crate structural joins and streams reference occurrences into the existing package namespace resolver. A private C target supplies pinned LZ4 decoding; shared invocation accounting bounds reads, allocations, expansion and work. Unsupported representations retain gaps, and only conclusive malformed structures produce corruption findings.

**Tech Stack:** Swift 6 / SwiftPM, Foundation, a private vendored LZ4 1.10.0 C target, XCTest, existing offline Python schema and verification tools.

**Spec:** `docs/superpowers/specs/2026-10-24-usdc-reference-coverage-v0-2-design.md` — APPROVED.

**Slug:** `usdc-reference-coverage-v0-2`
**Status:** APPROVED — implementation authorized; sequential subagent-driven execution selected.
**Date:** 2026-10-24
**Execution tier:** full
**Implementation model role:** full
**Execution method:** Subagent-driven, tasks run sequentially, explicitly selected by the user after separate plan approval.
**Provenance:** Approved specification above; direct repository inspection at `c4f1229187c8ee430d1d77cdf17abfcae0b6589a`; the two 2026-10-24 feasibility reports under `docs/deliverables/experiments/`. No legacy plan is a source. Exact-slug plan resolution was MISSING before this file was created.
**Approval evidence:** Specification approval: “approved” on 2026-10-24, after the saved specification was presented. Separate plan approval: “plan is approved”. Execution selection: “proceed with subagent-driven execution, with tasks run sequentially”. Both approved artifacts were saved before implementation. These messages authorize Stage 4 within the approved scope and Git workflow; no push, merge or publication is authorized.

## Global Constraints

- Exact supported crate versions: **0.8.0, 0.9.0 and 0.10.0**. No header relabeling as positive evidence and no alternate-parser fallback.
- Read-only snapshot and package-local lookup only. No extraction, host reference resolution, network, subprocesses, plugins, composition or expression evaluation in native inspection. ZIP entries remain stored-only; only bounded crate-internal metadata decompression is permitted.
- Independent Swift reader; private C target from **LZ4 1.10.0**, with actual source hashes, BSD-2-Clause license and notices. No host LZ4, Python, Apple tools or OpenUSD runtime prerequisite for the product or native tests.
- Source compatibility target: OpenUSD commit `96c1989167d2aaab5bd34627f32a321a6b79866b`, one-byte compression counts and four-byte signed chunk lengths. Published/source discrepancies remain documented; ambiguity is a limitation.
- Safety-envelope version **2**; preserve every existing ceiling. Each compressed or decoded metadata block **16 MiB**; cumulative reserved decode capacity **32 MiB**; charged live USDC working storage **64 MiB**; each table/container **250,000** items; structural work **2,000,000** units; value/path depth **32**.
- USDA/USDC share **4,096 UTF-8 bytes per asset value** and **100,000 occurrences**. Count processed table/container elements, graph edges, ValueReps and compression chunks. Charge checked sizes before allocation, including transient copies, C buffers, tables, strings, indexes, traversal and scratch storage.
- Process layers sequentially; no whole-large-crate copy. Release transient storage before report rendering. Complete release CLI invocations, including reporting, must meet **268,435,456 bytes peak RSS** and **60 seconds** on the recorded current host.
- Preserve report/config/catalogue schema major **1**, profiles, gates, default privacy, deterministic order and existing USDA occurrence identity semantics. No public option, switch or reference-inventory API. Product version becomes **0.2.0**, without publishing.
- Binary identity uses bounded numeric structural coordinates. No authored keys/scene paths in default evidence and no invented line, column or compressed-value physical offset.
- Preserve the **nine baseline + fourteen version-specific fixtures / 71 expected occurrences** and independent expectations. Five Apple originals / 59 occurrences remain optional local evidence; no assumed redistribution rights.
- Current-host arm64 verification is required; macOS 15 and other host/toolchain combinations remain explicitly unverified until executed. Keep tag `v0.1.0` available.
- Follow the user's Git gates: no main update, branch, implementation or commit before separate spec and plan approvals. Thereafter work in the existing checkout, preserve local work, use a conventional `feat/` branch, commit explicit paths, and do not push or merge.

## Review Focus

1. Many occurrences share one interned/compressed value: retain distinct structural identities without multiplying uncharged copies. Pin with `USDCReferenceTests.testSharedValueKeepsDistinctSites` (Task 6) and `USDCReportingTests.testSharedValueIdentityVectors` (Task 5).
2. A readable asset precedes an unsupported or corrupt field: retain its finding and leave coverage partial; never let later success erase the gap. Pin with `USDCIntegrationTests.testEarlierFindingSurvivesLaterStop` (Task 7).
3. A plain string in `clips` / `templateAssetPath` carries unresolved path semantics: emit a limitation without guessing a target, while unrelated strings remain non-references. Pin with `USDCReferenceTests.testClipTemplateStringCannotCertifyCoverage` (Task 6).
4. Several individually small layers exhaust an invocation quota, or a 4 KiB character value exceeds 4 KiB in UTF-8: stop before the forbidden allocation/occurrence. Pin with `USDCResourceTests.testCrossLayerAndUTF8Boundaries` (Task 9).
5. A legal-looking alternate frame or path topology contradicts the pinned interpretation: retain a limitation rather than speculate about corruption or retry another decoder. Pin with `USDCTableTests.testAmbiguousRepresentationIsNotCorruption` (Task 4); dictionary-key ambiguity is separately tested in Task 6.

---

## Repository evidence and command catalogue

Planning baseline: HEAD `c4f1229187c8ee430d1d77cdf17abfcae0b6589a`, branch `main`. Only the specification and prior `docs/deliverables/` research were untracked at discovery; preserve them. Recheck current state at execution time rather than assuming this HEAD is still current.

Architecture map: `docs/architecture/map.md` **MISSING** at that HEAD. ADR/decision records: **MISSING** in the inspected documentation tree. Freshness was checked against `Package.swift`, `Sources/USDZValidation/FileSnapshot.swift`, `Sources/USDZValidation/BoundedReader.swift`, `Sources/USDZValidation/ResourceLedger.swift`, `Sources/USDZValidation/NativeEngine.swift`, `Sources/USDZValidation/Rules/USDLayer.swift`, `Sources/USDZValidation/Rules/USDALexer.swift`, `Sources/USDZValidation/Rules/ReferenceResolver.swift`, `Sources/USDZValidation/FindingIdentity.swift`, `Sources/USDZValidation/NativeDiagnostics.swift`, reporting sources and verification scripts. No map was generated; no accepted ADR was found to constrain the approved design.

Relevant current seams:

- `BoundedReader.read(offset:count:)` limits each request to 65,536 bytes and charges reads before I/O. Its ledger currently accumulates only reads and text tokens.
- `USDLayer.identify` currently emits blanket `UVK-LIM-002` on recognition. `NativeEngine` subsequently scans USDA only, after namespace, stored-payload, CRC and recognized-default prerequisites.
- `AssetToken` owns text-only coordinates and delimiter unescaping. `ReferenceResolver.check(token:author:namespace:diagnostics:)` resolves only package names but reports through a text-specific helper.
- `FindingKey` already supports an optional content offset and a discriminator. Preserve the `uvk-occurrence-v1` tuple and USDA key construction.
- `FixtureTests.testManifestCoversCorpusAndGenerators` hashes **every file** under `Tests/Fixtures` and `Tests/TestSupport`, excluding the manifest itself. Update its manifest whenever a helper changes.
- Report schema v1 currently fixes `safetyEnvelopeVersion` to 1. Existing verification fixes 73 exports, 13 reviewed documents, 86 total files and product version 0.1.0. Task 8 deliberately updates these bindings while retaining v1 schema compatibility.

All build/test commands below specialize commands already used by `Makefile`, `docs/releasing.md`, `Scripts/verify-release.sh` and the existing `docs/superpowers/plans/2026-10-20-usdz-validation-kit.md`. New XCTest filters select new suites using the same established command shape. Do not run these commands during planning.

| Purpose | Existing command/source |
| --- | --- |
| Focused RED/GREEN cycle | `swift test --filter 'SuiteName|OtherSuite'`; existing test plans / release runner |
| Build tests | `swift build --build-tests`; `Makefile` |
| Sanitizer | `swift test --sanitize=address --filter 'SuiteName|OtherSuite'`; release runner's ASAN invocation, narrowed to owning suites |
| Formatting | `make format-check`; `Makefile` |
| Schema contracts | `make schemas`; `Makefile`, using existing hash-locked `.venv` |
| CLI and adversarial process tests | `sh Scripts/test-cli.sh`, `sh Scripts/test-adversarial.sh`; `Makefile` |
| Verifier regressions | `python3 -m unittest discover -s Tests -p 'test_verification_tools.py'`; release runner |
| Release resources | `swift build -c release`; `UVK_RUN_RESOURCE_TESTS=1 swift test -c release --filter ResourceBoundaryTests`; `python3 Scripts/verify-resources.py --executable .build/release/usdz-validator --output docs/verification/resource-results.md`; `Makefile` |
| Final full gate | `sh Scripts/verify-release.sh --evidence-dir .build/verification/usdc-v0-2-current`; documented custom evidence path. Require an empty path; use a fresh sibling on rerun. |

`swift package resolve` and development schema bootstrap follow `docs/releasing.md` / `Tools/README.md` only if needed during approved execution. Preserve `Package.resolved`; the C source is vendored, not a newly resolved Swift package. Do not run optional installed-checker smoke without an explicit request.

## File responsibilities and dependency order

All paths below are repository-relative. Keep new internals internal to `USDZValidation`; there is no additional executable product.

| Files | Responsibility / owning task |
| --- | --- |
| `Tests/Fixtures/USDC/{baseline,versions,sources,extra}/`, `Tests/Fixtures/USDC/inventory.json`, `Tests/TestSupport/USDCFixtures.swift`, `Tests/TestSupport/USDCMutationRecipe.swift` | Original durable bytes, independent expectations and hostile literal/block recipes (1; extend in 6/9) |
| `Sources/USDZValidation/ResourceLedger.swift`, `Sources/USDZValidation/USDC/USDCInput.swift`, `Sources/USDZValidation/USDC/USDCStorage.swift` under `Sources/USDZValidation/` | Checked layer-relative range reads, invocation quotas and explicit storage ownership (2) |
| `Sources/CUSDCCompression/lz4.c`, `Sources/CUSDCCompression/include/lz4.h`, `LICENSE`, `source-manifest.json`, `README.md`; `Sources/USDZValidation/USDC/USDCCompression.swift` | Pinned dependency and bounded source-compatible framing (3) |
| `Sources/USDZValidation/USDC/USDCFormat.swift`, `Sources/USDZValidation/USDC/USDCTables.swift` | Version/representation classification and structural tables/live joins (4; value matrix extended in 6) |
| `Sources/USDZValidation/Rules/ReferenceOccurrence.swift`, `Sources/USDZValidation/USDC/USDCReferenceLocator.swift`, `Sources/USDZValidation/USDC/USDCReporting.swift` | Shared byte semantics and format-specific sites/diagnostics (5) |
| `Sources/USDZValidation/USDC/USDCValues.swift`, `Sources/USDZValidation/USDC/USDCReader.swift` | Selective live-value traversal and scanner outcome (6) |
| `Sources/USDZValidation/NativeEngine.swift`, `Sources/USDZValidation/Rules/USDLayer.swift` | Automatic dispatch and prerequisite/coverage orchestration (7) |
| Reporting/config/version/schema/golden/verifier files listed in Task 8 | Public compatibility and immutable evidence bindings (8) |
| `Tests/USDZValidationTests/USDC*Tests.swift`, existing resource/CLI/consumer suites | Owning unit, contract, boundary and end-to-end tests (1–9) |
| Existing user/security/release documentation listed in Task 10 | Accurate claims and final acceptance evidence (10) |

Dependencies: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10. These are one feature with shared safety/coverage contracts, not independent products. Do not parallelize overlapping files. Refresh fixture-manifest hashes in each task that changes `Tests/TestSupport` or fixture bytes.

Before Task 1, **only after plan approval**, identify the two approved artifact paths and their separate approval messages, record the chosen execution method, and recheck Git state. Safely fetch/update `main` by fast-forward only, preserving all local files; stop on a conflict or diverged main rather than discard work. Create `feat/usdc-reference-coverage-v0-2` in this checkout, then commit only the approved specification and plan paths. If updated repository evidence changes this plan materially, return for plan approval before coding. No worktree, push or merge is authorized.

### Task 1: Preserve the independent corpus and mutation harness [size: M | risk: none | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-02, AC-03, AC-04, AC-13, AC-14.

**Files:** Create the `Tests/Fixtures/USDC/` tree and `inventory.json`; create `Tests/TestSupport/USDCFixtures.swift`, `Tests/TestSupport/USDCMutationRecipe.swift`, `Tests/USDZValidationTests/USDCFixtureTests.swift`; modify `Tests/Fixtures/manifest.json` and `docs/fixtures.md`.

**Interfaces:** `USDCFixtures.cases() throws -> [USDCFixtureCase]`, with `id: String`, `crate: Data`, `version: [UInt8]`, `expectedValues: [Data]`, `expectedInspectionComplete: Bool` and independently authored logical-site expectations in the inventory. `USDCMutationRecipe` exposes `patch(_:at:bytes:) throws -> Data` and a literal-only LZ4 block/frame encoder for synthetic hostile tests. It does not import the product decoder. Keep archive construction in the existing `ArchiveRecipe`.

- [ ] **Step 1 — Write fixture-contract tests.** Add `testPreservedCorpusHas23CasesAnd71Occurrences`: `XCTAssertEqual(cases.count, 23)` and `XCTAssertEqual(cases.reduce(0) { $0 + $1.expectedValues.count }, 71)`. Also assert 9 baseline / 14 newer, 41 + 30 values including one empty literal, genuine version bytes and live tag 56/57 evidence. Add `testExpectationsAreIndependentAndRawWrapperRemainsPartial`, `testLiteralFrameRecipeHasFixedBytes` and provenance/hash checks. Expectations come from authored definitions and independent evidence, never scanner output.
- [ ] **Step 2 — RED.** Run `swift test --filter 'USDCFixtureTests|FixtureTests'`. Expected: new helper/corpus assertions fail or fail compilation because the declared helpers do not exist; retain that evidence.
- [ ] **Step 3 — Add original bytes and minimal helpers.** Verify existing hashes, then copy the nine baseline crates and their sources from `.verification/usdc-feasibility-2026-10-24/`; copy the fourteen named Apple/OpenUSD outputs and seven sources from `.verification/usdc-feasibility-09-010-2026-10-24/`. Preserve basenames within `baseline/` and `versions/`; do not copy Apple model packages. Record writer/version/arguments, source/crate hashes, source license and semantic expectations, with portable paths. Preserve the distinction between raw unregistered bytes and parsed occurrences. Document API omissions (`ListInfoKeys`, subLayerOffsets conversion) and the related small exported-text evidence; an empty oracle result cannot certify completeness. Add only independent patch/literal encoders needed by later tests and update the fixture manifest.
- [ ] **Step 4 — GREEN.** Run `swift test --filter 'USDCFixtureTests|FixtureTests'`. Expected: both suites pass without a writer, Python runtime, installed tool, oracle environment or download.
- [ ] **Step 5 — Commit.** Explicitly stage this task's fixture tree, two helpers, test, manifest and `docs/fixtures.md`; commit `test: preserve authored USDC fixture evidence`.

### Task 2: Add checked input ranges and invocation allocation accounting [size: M | risk: security | mechanical: false | clear_pattern: false | objectively_verifiable: true | concerns: security,performance]

**Acceptance criteria:** AC-08, AC-09, AC-10, AC-15.

**Risk:** Untrusted sizes can trigger an allocation or read before a limit check; Swift copy-on-write can obscure live capacity.

**Files:** Modify `Sources/USDZValidation/ResourceLedger.swift`, `Sources/USDZValidation/NativeDiagnostics.swift`; create `Sources/USDZValidation/USDC/USDCInput.swift`, `Sources/USDZValidation/USDC/USDCStorage.swift`, `Tests/USDZValidationTests/USDCResourceTests.swift`, `Tests/USDZValidationTests/USDCInputTests.swift`; extend `Tests/USDZValidationTests/ResourceLedgerTests.swift` and `Tests/USDZValidationTests/ResourceBoundaryTests.swift` for the new exhaustive resource cases.

**Interfaces:** Add SafetyResource cases `usdcMetadataBlockBytes`, `usdcDecodeBytes`, `usdcWorkingBytes`, `usdcItems`, `usdcWork`, `usdcDepth` with exact limits from Global Constraints. Add `ResourceLedger.reserveUSDCDecode(_ capacity: UInt64) throws`, `consumeUSDCWork(_ units: UInt64) throws`, `reserveUSDCStorage(_ bytes: UInt64) throws -> USDCStorageReservation`; the reservation has idempotent `release()` and a deinit fallback. Retain `consumeTokens(_:)` as the shared occurrence counter. Expose internal read-only `usdcLiveBytes`, `usdcDecodeBytes` and `usdcWorkUnits: UInt64` for tests.

`USDCInput(entry: ZIPEntry, reader: BoundedReader)` provides `withBytes<R>(offset: UInt64, count: Int, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R` using layer-relative offsets and the existing 64 KiB ceiling. The scoped borrow retains its staging reservation until the closure returns or throws; consumers must charge any retained copy. This internal refinement replaces an escaping `read -> Data` signature so the approved lifetime accounting remains enforceable. `USDCStorage.allocate(byteCount: UInt64, ledger: ResourceLedger) throws -> USDCStorage` owns a raw allocation/reservation, `capacity: Int` and bounded initialized `count: Int`; read borrowing exposes initialized bytes only and write borrowing validates the initialized count. Define `USDCFailure.unsupported(USDCGapReason)` / `.malformed(USDCCorruptionReason)` with fixed safe reason enums; resource and snapshot operational errors retain their existing types.

- [ ] **Step 1 — Write accounting and read tests.** Assert exact-boundary success / +1 rejection for all six new resources, arithmetic/Int conversion overflow and persistent cumulative counters. In `testReservationsPrecedeAllocationAndReleaseOnThrow`, use `XCTAssertEqual(allocationCalls, 0)` after rejection and `XCTAssertEqual(ledger.usdcLiveBytes, 0)` after throwing-path release. In `testLayerRangesNeverReadAnotherMember`, assert every read stays in the author payload and <=65,536 bytes; invalid ranges never call the source. Forward a sentinel `ValidationError.operational` unchanged.
- [ ] **Step 2 — RED.** Run `swift test --filter 'USDCResourceTests|USDCInputTests|ResourceLedgerTests|ResourceBoundaryTests'`. Expected: new symbols/tests fail before the implementation; existing exhaustive resource tests expose the new cases until extended.
- [ ] **Step 3 — Implement checked accounting and ownership.** Reserve before allocation; checked count × stride includes all tables and scratch capacity. Charge input staging Data concurrently with destination storage and retain the reservation for its actual lifetime. Prefer packed typed buffers, a single token blob with ranges and bounded traversal stacks; do not retain per-element Foundation strings/maps. Any unavoidable Data/String copy must have an explicit conservative live-capacity charge. Keep peak-live, cumulative-decode and work counters separate; only live reservations are released. Mark reference coverage partial on new hard resource failures through `NativeDiagnostics.affectedAreas`.
- [ ] **Step 4 — GREEN.** Run the Step 2 command, then `swift test --sanitize=address --filter 'USDCResourceTests|USDCInputTests'`. Expected: boundary assertions pass and no sanitizer failure. Ordinary opt-in real-size tests may remain skipped at this stage; Task 9 runs the required dedicated gate.
- [ ] **Step 5 — Commit.** Stage the exact source/test files above; commit `feat: bound USDC input and working storage`.

### Task 3: Vendor LZ4 and decode only the pinned crate framing [size: M | risk: security | mechanical: false | clear_pattern: false | objectively_verifiable: true | concerns: security,performance]

**Acceptance criteria:** AC-07, AC-08, AC-09, AC-16.

**Risk:** C decoder lengths and framed expansions must never exceed reserved capacity or accept an alternate layout accidentally.

**Files:** Modify `Package.swift`, `NOTICE`; create `Sources/CUSDCCompression/lz4.c`, `Sources/CUSDCCompression/include/lz4.h`, `LICENSE`, `source-manifest.json`, `README.md`; create `Sources/USDZValidation/USDC/USDCCompression.swift`, `Tests/USDZValidationTests/USDCCompressionTests.swift`.

**Interfaces:** Private target `CUSDCCompression` depends only on its vendored source/header. `USDCCompression.decode(input: USDCInput, range: Range<UInt64>, decodedCapacity: UInt64) throws -> USDCStorage` returns reserved storage with its actual initialized `count <= capacity`; callers check exact decoded lengths only where the format supplies one. No full decoded Data copy. Call `LZ4_decompress_safe` only after checked Int32 length conversion. `USDZValidation` depends on the C target; no separate product is exposed.

- [ ] **Step 1 — Write framing/expansion tests.** `testPinnedSingleAndTwoChunkFrames` uses fixed literal blocks and independent synthetic frames: `XCTAssertEqual(outputBytes, expectedLiteralBytes)`, including valid output shorter than capacity. Assert one-byte count / signed four-byte chunk lengths and charged work. Reject truncation, negative/overrunning lengths, LZ4 failure, sum overflow and block sizes above 16,777,216 before allocation. `testAlternateFramingDoesNotFallback` asserts unsupported status and `XCTAssertEqual(decodeAttempts, 1)`. Failed decoding still consumes its reserved cumulative capacity.
- [ ] **Step 2 — RED.** Run `swift test --filter USDCCompressionTests`. Expected: missing target/decoder failure before implementation.
- [ ] **Step 3 — Vendor and implement.** Retrieve upstream LZ4 1.10.0 `lib/lz4.c`, `lib/lz4.h` and license from its tagged source, verify version macros, retain notices and record actual file URLs/revision/SHA-256 values. Ship no OpenUSD implementation code. Bound compressed staging, decoded output, chunk scratch and temporary copies through Task 2. Use one deterministic frame interpretation; failures caused by disputed framing remain unsupported, while independently established truncation or impossible ranges are malformed. Do not alter ZIP handling or link a system/Homebrew library.
- [ ] **Step 4 — GREEN.** Run `swift build --build-tests`, `swift test --filter USDCCompressionTests`, then `swift test --sanitize=address --filter USDCCompressionTests`. Expected: self-contained C compilation, exact vectors and rejection tests pass. Check the recorded link/build inputs contain the vendored source rather than a host `-llz4` search path.
- [ ] **Step 5 — Commit.** Stage `Package.swift`, `NOTICE`, the exact C target tree, Swift decoder and test; commit `feat: add pinned bounded crate compression decoder`.

### Task 4: Read structural tables and establish only live joins [size: L | risk: security | mechanical: false | clear_pattern: false | objectively_verifiable: true | concerns: security,performance]

**Acceptance criteria:** AC-02, AC-03, AC-07, AC-08, AC-09.

**Risk:** Forged indices/topology and unknown representations can cause unsafe traversal or a false claim that references are absent.

**Files:** Create `Sources/USDZValidation/USDC/USDCFormat.swift`, `Sources/USDZValidation/USDC/USDCTables.swift`, `Tests/USDZValidationTests/USDCTableTests.swift`; extend `Sources/USDZValidation/USDC/USDCInput.swift` reason enums and `Tests/TestSupport/USDCMutationRecipe.swift` only as needed; refresh `Tests/Fixtures/manifest.json` if the helper changes.

**Interfaces:** `USDCVersion` represents exact major/minor/patch bytes. `USDCTables.read(input: USDCInput) throws -> USDCTables` owns charged packed tables and exposes `forEachLiveField(_ body: (USDCLiveField) throws -> Void) throws`. `USDCLiveField` contains `specIndex: UInt32`, `pathIndex: UInt32`, `fieldOrdinal: UInt32`, `fieldIndex: UInt32`, `nameTokenIndex: UInt32`, `valueRep: UInt64`. Add bounded token/string lookup and path-parent accessors; borrowed data must not outlive the owning tables. No array of expanded scene paths.

- [ ] **Step 1 — Write table/live-join tests.** Assert versions and structural joins for all 23 cases. `testDeadFieldAndUnusedAssetLookingTokenAreNotLive` appends unreachable records: `XCTAssertEqual(mutatedLiveFields, originalLiveFields)`. Mutate TOC counts/ranges, duplicate required sections, terminators, integer-compression counts, UTF-8, string/field/spec indices, FIELDSETS sentinels/ranges and PATHS topology. Test cycles, work/depth stops and UInt64 overflow. `testAmbiguousRepresentationIsNotCorruption` pins PATHS/framing discrepancies to unsupported failures without retries. Patch/future/major headers are unsupported, never positive fixtures.
- [ ] **Step 2 — RED.** Run `swift test --filter USDCTableTests`. Expected: missing table implementation, then precise invariant assertions fail until covered.
- [ ] **Step 3 — Implement bounded structural decoding.** Follow bootstrap/TOC → TOKENS/STRINGS → FIELDS/FIELDSETS → PATHS/SPECS as established by the pinned-source research. Validate section spans and checked joins before following them; distinguish section requirements from unrelated sections that need not be interpreted. Charge every processed element/edge and retained buffer. Decode integer-compressed metadata without unchecked expansion. Validate structural paths within depth 32; do not reconstruct private scene names for diagnostics. Unsupported topology/key encodings stop dependent traversal. Define malformed cases only where the supported source layout proves the violated invariant.
- [ ] **Step 4 — GREEN.** Run `swift test --filter 'USDCTableTests|USDCCompressionTests'`, then `swift test --sanitize=address --filter USDCTableTests`. Expected: genuine fixtures have correct live joins; hostile bytes yield typed failures without forbidden reads or unsafe allocation.
- [ ] **Step 5 — Commit.** Stage the exact new table/format/test files and any named helper/manifest/reason-enum changes; commit `feat: read bounded live USDC structural tables`.

### Task 5: Share reference byte semantics and add structural diagnostics [size: M | risk: data | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: data]

**Acceptance criteria:** AC-05, AC-07, AC-11, AC-12.

**Risk:** Adapting text reporting can change existing identities, merge binary occurrences or disclose authored data.

**Files:** Create `Sources/USDZValidation/Rules/ReferenceOccurrence.swift`, `Sources/USDZValidation/USDC/USDCReferenceLocator.swift`, `Sources/USDZValidation/USDC/USDCReporting.swift`, `Tests/USDZValidationTests/USDCReportingTests.swift`; modify `Sources/USDZValidation/Rules/USDALexer.swift`, `Sources/USDZValidation/Rules/ReferenceResolver.swift`, `Sources/USDZValidation/RuleCatalogue.swift`; extend `Tests/USDZValidationTests/ReferenceResolverTests.swift`, `Tests/USDZValidationTests/FindingIdentityTests.swift`, `Tests/USDZValidationTests/RuleCatalogueTests.swift`, `Tests/USDZValidationTests/SARIFReportTests.swift` (catalogue counts only). Update independent descriptors in `Tests/Goldens/rule-catalogue-v1.json` and its hash in `Tests/Schemas/manifest.json` so this task's catalogue tests pass.

**Interfaces:** `ReferenceClassification` has `.literal` / `.unsupportedExpression`; `ReferenceClassifier.classify(_ bytes: Data) -> ReferenceClassification` preserves the lexer's existing byte rules. `AssetToken.Classification` becomes an internal alias. `ReferenceOccurrence(valueBytes: Data, classification: ReferenceClassification, site: ReferenceSite)` has `.usda(offset: UInt64, line: UInt64, column: UInt64)` or `.usdc(USDCReferenceLocator)` sites. The locator contains `specIndex`, `fieldOrdinal` and a depth-bounded numeric sequence of `(kind,index)` container steps (array, dictionary, list bucket/item, sample, wrapper, reference customData).

Add `ReferenceResolver.check(occurrence: ReferenceOccurrence, author: ZIPEntry, namespace: PackageNamespace, diagnostics: NativeDiagnostics)`; retain the token overload as an adapter. Define `USDCIssue(failure: USDCFailure, locator: USDCReferenceLocator?)` and `USDCReporting.record(issue: USDCIssue, entry: ZIPEntry, diagnostics: NativeDiagnostics)`. Layer outcome reporting remains Task 7.

- [ ] **Step 1 — Write contract tests.** `testUSDAAdapterPreservesKeysAndUnescaping` pins existing USDA vectors and verifies binary bytes are never text-unescaped. `testSharedValueIdentityVectors` independently encodes keys with nil content offset and numeric discriminators `reason|usdc-v1|s:<n>|f:<n>|<numeric-steps>`: `XCTAssertNotEqual(firstID, secondID)` and compare each with an independent literal hash. Assert no dependence on input URL and no binary line/column/layer offset or fabricated SARIF region. Assert LIM-007 warning/validatorLimitation/references, USD-001 error/policy/references, 34 Apple / 32 general descriptors, and no privacy sentinel in evidence/discriminators.
- [ ] **Step 2 — RED.** Run `swift test --filter 'USDCReportingTests|ReferenceResolverTests|FindingIdentityTests|RuleCatalogueTests'`. Expected: new APIs/descriptors absent; old identity vectors already provide the regression baseline.
- [ ] **Step 3 — Implement the internal adapter and reporting.** Extract only byte classification; preserve text delimiter handling and author/default lookup. Keep USDA keys unchanged. Binary keys use the existing v1 encoder, original entry identity, nil content offset and numeric ASCII discriminator below 4,096 bytes. Omit unknown physical coordinates. Reuse path/LIM-003 rules and safe-prefix checks. Add approved descriptors, revise applicability text and independently update catalogue expectations plus SARIF rule counts to 34/32. Preserve profiles/severities.
- [ ] **Step 4 — GREEN.** Run the Step 2 command plus `swift test --filter 'USDALexerTests|PrivacyTests|SARIFReportTests'`. Expected: unchanged USDA contracts and deterministic binary diagnostics. Update only independent catalogue descriptors/hash here; version metadata and report goldens belong to Task 8. Never capture product output as an expectation.
- [ ] **Step 5 — Commit.** Stage only the exact files listed above; commit `feat: add structural binary reference diagnostics`.

### Task 6: Traverse the supported live-value subset [size: L | risk: security | mechanical: false | clear_pattern: false | objectively_verifiable: true | concerns: security,performance]

**Acceptance criteria:** AC-02, AC-03, AC-04, AC-05, AC-06, AC-07, AC-08, AC-09, AC-13, AC-14.

**Risk:** An overbroad skip/type rule can hide references; recursive containers and shared value bodies can amplify work and storage.

**Files:** Create `Sources/USDZValidation/USDC/USDCValues.swift`, `Sources/USDZValidation/USDC/USDCReader.swift`, `Tests/USDZValidationTests/USDCReferenceTests.swift`, `Tests/USDZValidationTests/USDCValueTypeTests.swift`; extend `Sources/USDZValidation/USDC/USDCFormat.swift`; extend fixture sources/bytes under `Tests/Fixtures/USDC/extra/`, `Tests/TestSupport/USDCFixtures.swift`, `Tests/TestSupport/USDCMutationRecipe.swift`, `inventory.json` and `Tests/Fixtures/manifest.json` for the additional cases.

**Interfaces:** `USDCValues.walk(field: USDCLiveField, tables: USDCTables, input: USDCInput, onReference: (ReferenceOccurrence) -> Void, onIssue: (USDCIssue) -> Void) throws`. `USDCReader.scan(entry: ZIPEntry, reader: BoundedReader, onReference: (ReferenceOccurrence) -> Void, onIssue: (USDCIssue) -> Void) throws -> USDCScanState`, where state is `.complete`, `.partial` or `.uninspected`. The scanner releases table/value storage before returning. Snapshot operational errors propagate; only declared inspectable failures become issues. A completed scanner state is inventory classification, not successful package target validation.

- [ ] **Step 1 — Write positive inventory tests.** Assert `XCTAssertEqual(actualValueMultiset, expectedValueMultiset)` for all 71 occurrences and independently expected sites. Cover six authored reference/payload buckets, legacy payload, sublayers, reference customData, dictionaries/wrappers, samples, inactive prims and both variants. `testSharedValueKeepsDistinctSites` asserts shared bodies retain distinct locators and bounded scratch use. Empty/internal references create no target requirement; customData assets remain inspected.
- [ ] **Step 2 — Write type/gap tests.** `testGenuineTimeCodeAndPathExpressionForms` pins 56 from 0.9 / 57 from 0.10, scalar/array/empty/sample forms and no false file references. Test raw/unregistered lists, disputed dictionary keys, wrappers, invalid UTF-8/indices/counts, cycles, 32/33 nesting and amplification. `testClipTemplateStringCannotCertifyCoverage` asserts `XCTAssertFalse(issues.isEmpty)` and `XCTAssertTrue(references.isEmpty)` for nonempty template strings; empty/unrelated strings create no gap. Preserve authored asset expressions. Add small original clip/unregistered cases under `extra/` when needed, generated once with provenance; native tests never run the writer. Unproved cases remain gaps.

  Minimum representation matrix (flags: array `0x80`, inline `0x40`, compressed `0x20`): asset tag 12 supports flags `0`, `0x40`, `0x80`; dictionary 31 supports `0` and empty-inline `0x40`; reference/unregistered/payload list ops 35/54/55, legacy payload 47, wrappers 52/53 and time samples 46 use flags `0`; subLayers string-vector 50 uses flags `0`. TimeCode 56 and PathExpression 57 support demonstrated flags `0` / `0x80` at their version floors; unproved inline/compressed forms retain gaps. Test all six list-bucket mask bits individually and together. For non-asset tags, add explicit source-proven per-tag flags to `USDCFormat`, with pinned-source citations; do not copy the experiment's broad type-only skip. Unknown tags/flags and newer tags under older headers are unsupported. Skipping a proven non-asset body does not claim its geometry validity.
- [ ] **Step 3 — RED.** Run `swift test --filter 'USDCReferenceTests|USDCValueTypeTests'`. Expected: missing walker/scanner or unmet inventory/type assertions.
- [ ] **Step 4 — Implement the selective walker.** Follow live fields and every authored bucket with stable numeric positions. Charge shared tokens before each literal callback (including empty asset literals), check 4,096 UTF-8 bytes before copying, charge repeated visits and use a depth-bounded cycle stack. Apply the matrix; detect path-bearing string metadata before generic skips. Retain prior findings/issues; continue independent fields only with known prerequisites. Return `.uninspected` when structural prerequisites prevent establishing the live-field set, `.partial` on any gap, otherwise `.complete` after exhaustive traversal, including a proven empty set. Zero output alone never certifies completeness.
- [ ] **Step 5 — GREEN.** Run `swift test --filter 'USDCReferenceTests|USDCValueTypeTests|USDCFixtureTests|FixtureTests'`, then `swift test --sanitize=address --filter 'USDCReferenceTests|USDCValueTypeTests'`. Expected: durable expectations match, raw/unproved forms remain partial and resource counters are charged before expansion. No oracle is needed. Record whether supplementary authored cases had independent API or source/text corroboration and disclose its limits.
- [ ] **Step 6 — Commit.** Stage the exact walker/reader/format/test/helper/fixture paths above and refreshed manifest; commit `feat: inspect the supported authored USDC value subset`.

### Task 7: Integrate automatic inspection with native prerequisites and coverage [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security]

**Acceptance criteria:** AC-01, AC-05, AC-06, AC-07, AC-10, AC-12.

**Risk:** Dispatching a binary scanner before integrity/default prerequisites or promoting mixed coverage would breach the existing boundary.

**Files:** Modify `Sources/USDZValidation/NativeEngine.swift`, `Sources/USDZValidation/Rules/USDLayer.swift`; create `Tests/USDZValidationTests/USDCIntegrationTests.swift`; extend `Tests/USDZValidationTests/NativeEngineTests.swift`, `Tests/USDZValidationTests/USDLayerTests.swift`, `Tests/USDZValidationTests/ValidatorTests.swift`, `Tests/LibraryConsumerTests/LibraryConsumerTests.swift`, `Tests/USDZValidatorCLITests/CLIProcessTests.swift`. Any durable package/helper additions update the fixture manifest.

**Interfaces:** Reuse `USDCReader.scan` and the common resolver from Tasks 5–6. Preserve `NativeEngine.inspect(snapshot:configuration:)`, `Validator.validate` and all public APIs. Recognition reports signature/suffix issues but no longer declares all binary reference inspection unavailable before scanning.

- [ ] **Step 1 — Write orchestration tests.** `testEveryEligibleBinaryLayerIsInspected` covers root `.usdc`, binary `.usd`, unreferenced binaries and mixed versions. `testPrerequisiteFailureForbidsBinaryReads` covers namespace, ZIP method, CRC, alignment and default failures: `XCTAssertEqual(binaryTableReads, 0)`. `testEarlierFindingSurvivesLaterStop` asserts retained missing-target and later gap/corruption findings with `XCTAssertEqual(referenceState, .partial)`. Add uninspected/complete outcomes, default failure propagation and shared counts. Library-consumer test imports only `USDZValidation` and validates a durable binary package. CLI tests assert automatic behavior and unchanged checker opt-in.
- [ ] **Step 2 — RED.** Run `swift test --filter 'USDCIntegrationTests|USDLayerTests|NativeEngineTests|LibraryConsumerTests'`. Expected: blanket LIM-002 / absent binary findings cause new assertions to fail.
- [ ] **Step 3 — Integrate sequential dispatch.** In the current regular-entry order and recognized-default gate, dispatch eligible `.usda` and `.usdc` to their scanners sharing the same reader/ledger. Feed occurrences synchronously into package-only resolution. Emit LIM-002 for a wholly uninspected binary layer and LIM-007 for partial binary inspection, retaining specific LIM-003 / USD-001 / RES-001 causes subject to existing finding truncation. Only conclusive supported malformed structures emit USD-001. Scanner completion cannot erase earlier resolver/prerequisite gaps. Release all USDC transient storage before the next layer and before report construction; cumulative invocation counters remain charged. Propagate snapshot operational errors unchanged and retain native/external separation.
  Update recognition-only `USDLayerTests` to stop expecting recognition itself to emit LIM-002. Existing `PXR-USDCsynthetic` process/facade fixtures are nonconforming: test conclusive truncated-bootstrap rejection separately. For exit-2 limitation scenarios, use a structurally intact fixture with an explicitly unsupported version, preserving those tests' original gate purpose.
- [ ] **Step 4 — GREEN.** Run the Step 2 command, `swift test --filter 'ValidatorTests|ReferenceResolverTests|ProfileTests|GatePolicyTests'`, and `sh Scripts/test-cli.sh`. Expected: new end-to-end behavior passes and existing gates/profile/exit precedence remain unchanged. Fixed golden expectations are addressed next.
- [ ] **Step 5 — Commit.** Stage only the exact source/test files and any explicitly added durable fixture/manifest files; commit `feat: enable automatic native USDC reference inspection`.

### Task 8: Bind v0.2 reporting, schema compatibility and immutable verification [size: M | risk: data | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: data]

**Acceptance criteria:** AC-11, AC-12, AC-16, AC-17.

**Risk:** Version/schema/golden drift can disguise identity regressions or leave C inputs outside evidence hashes.

**Files:** Modify `Sources/USDZValidation/Configuration.swift`, `Sources/USDZValidation/Version.swift`; modify `Sources/USDZValidation/Reporting/SARIFReport.swift` only if the no-offset test exposes a fallback; extend `Tests/USDZValidationTests/ConfigurationTests.swift`, `Tests/USDZValidationTests/GatePolicyTests.swift` (existing product-version literal only), `Tests/USDZValidationTests/GoldenCompatibilityTests.swift`, `Tests/USDZValidationTests/JSONReportTests.swift`, `Tests/USDZValidationTests/SARIFReportTests.swift`, `Tests/USDZValidationTests/PrivacyTests.swift` under `Tests/USDZValidationTests/`; add `Tests/USDZValidationTests/USDCReportTests.swift`. Modify `Schemas/report-v1.schema.json`, `Tests/Schemas/manifest.json`, `Tests/test_schema_contracts.py`, `Tests/test_verification_tools.py`, `Scripts/compare-compatibility.py`, `Scripts/verify-release.sh`, `Scripts/verify-examples.py`, `Tools/README.md`, `examples/report-v1.json`, `examples/report.sarif`, `examples/catalogue-v1.json`. Existing golden edits are exactly `Tests/Goldens/{report-complete-v1.json,report-incomplete-v1.json,report-operational-v1.json,external-failure-v1.json,external-success-v1.json,external-failure-v1.sarif,external-unavailable-v1.sarif,native-v1.sarif,rule-catalogue-v1.json}`; add only the eight files named below.

**Interfaces:** Product `ValidatorVersion.current == "0.2.0"`; immutable configuration `safetyEnvelopeVersion == 2`. Report schema major stays 1 and accepts envelope versions **1 and 2**, retaining historical v0.1 report validity. Existing budget-config input schema and public configuration surface remain unchanged. Add four independently authored JSON/SARIF golden pairs: `report-usdc-complete-v1`, `report-usdc-partial-v1`, `report-usdc-malformed-v1`, `report-usdc-duplicates-v1`.

- [ ] **Step 1 — Write fixed report/verification tests.** Assert `XCTAssertEqual(configuration.safetyEnvelopeVersion, 2)` and product `"0.2.0"`; schema accepts literal envelope 1 and rejects 3. Assert no-offset SARIF, rule categories, privacy, duplicate IDs, deterministic truncation, profiles, `--allow-incomplete`, fail-on and external separation. Independently compute binary vectors; retain USDA hashes. Manifest tests require changing any C/header/license/source-manifest byte or adding/removing an export to fail evidence validation.
- [ ] **Step 2 — RED.** Run `swift test --filter 'USDCReportTests|GoldenCompatibilityTests|ConfigurationTests|JSONReportTests|SARIFReportTests|PrivacyTests'`, `make schemas`, and `python3 -m unittest discover -s Tests -p 'test_verification_tools.py'`. Expected: deliberate version/schema/catalogue/golden/count assertions fail before their corresponding updates. Missing development schema tooling is a failed prerequisite, not a passed or skipped gate.
- [ ] **Step 3 — Update independent expectations and bindings.** Author new literal goldens from fixed models and independent serialization recipes before comparing encoders; never record encoder output as expected bytes. Update existing current-product golden/example version/envelope metadata and the literal catalogue to 34 Apple / 32 general rules without changing USDA identity vectors. Retain schema filenames/major 1; widen only the envelope discriminator to `[1,2]`. Refresh reviewed hashes and recipe checksums in schema manifests/tests. Add the eight binary documents to both checked-in schema validation and fixed exports: **81 exports + 21 reviewed documents = 102 files**. Update all exact-count bindings in verifier scripts/tests/documented recipes together; restrict manifest validator version to 0.2.0. Include all product `.swift`, vendored `.c` / `.h`, dependency license/source manifest and NOTICE in the input hash binding, and regression-test missing/extra file detection. Preserve prior release evidence directories.
- [ ] **Step 4 — GREEN.** Repeat the Step 2 commands and `sh Scripts/test-cli.sh`. Expected: all pass, exactly 81 fixed exports when the release runner requests export, and old USDA identity vectors unchanged. Verify native public module/config/CLI additions are limited to approved additive rule/version behavior. Do not run cross-host comparison against v0.1 exports and call the intentional differences a regression.
- [ ] **Step 5 — Commit.** Explicitly stage only the Task 8 paths and its eight new golden files; commit `feat: bind v0.2 reporting and verification contracts`.

### Task 9: Prove containment and aggregate resource acceptance [size: L | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security,performance]

**Acceptance criteria:** AC-08, AC-09, AC-10, AC-15, AC-16.

**Risk:** Logical quotas may miss live copies or aggregate amplification; a byte-only unit test alone cannot establish host containment or full-process RSS.

**Files:** Extend `Tests/USDZValidationTests/USDCResourceTests.swift`, `Tests/USDZValidationTests/AdversarialTests.swift`, `Tests/USDZValidationTests/ResourceBoundaryTests.swift`; create `Tests/USDZValidationTests/USDCContainmentTests.swift`; extend `Tests/TestSupport/USDCMutationRecipe.swift`, `Tests/TestSupport/ResourceRecipes.swift`, `Tests/Fixtures/manifest.json`; modify `Scripts/verify-resources.py`, `Tests/test_verification_tools.py`, `docs/verification/resource-results.md`. Extend the new USDC suites for any counterexample found; do not loosen ceilings.

**Interfaces:** Continue existing `ResourceRecipes` streaming archives and `verify-resources.py` recipe/measure/report interfaces. Add streamed USDC structural recipes built independently of the shipping decoder. Required real-size rows are invoked through the existing `ResourceBoundaryTests` resource gate. A test-only containment child runs the internal scanner with preloaded bytes and its normal resolver with an in-memory namespace; no product sandbox or production test hook is added.

- [ ] **Step 1 — Write the unexercised boundary tests.** `testCrossLayerAndUTF8Boundaries` tests every limit at/+1: cross-layer 32 MiB decode / two-million work, 64 MiB live, 250,000 items, depth 32 and mixed 100,000 occurrences. Include multibyte 4,096/4,097-byte assets, shared/deep sites, failure-path copies, compressed amplification, repeated edges and fan-out. Assert `XCTAssertEqual(forbiddenAllocations, 0)` and `XCTAssertEqual(ledger.usdcLiveBytes, baselineLiveBytes)` between layers/before reports, without resetting cumulative counters. Deterministic structural mutations must produce repeatable typed failures without crashes.
- [ ] **Step 2 — Write containment and full-process acceptance tests.** Parent XCTest spawns a bounded disposable child, warming runtime/LZ4 and preloading the exact fixtures before applying the research denial policy. Exercise genuine 0.9/0.10 and expression cases. Assert six negative controls return EPERM: unlisted read, stat, directory enumeration, network connection, execution and write. Assert scanning/resolution succeeds with no forbidden attempts. Keep snapshot I/O separately instrumented to permit only supplied input ranges; the denial child receives bytes because a real `FileSnapshot` deliberately rechecks its supplied pathname. Treat unavailable/failed containment setup on the required host as a failed acceptance gate. Ensure sandboxing affects only the child, never the test runner.
- [ ] **Step 3 — RED.** Run `swift test --filter 'USDCResourceTests|USDCContainmentTests|AdversarialTests'` and `python3 -m unittest discover -s Tests -p 'test_verification_tools.py'`. Expected: missing containment/resource recipes or uncovered accounting assertions fail. Real-size measurement rows must fail validation if absent, skipped, misclassified, above RSS/time, or missing expected resource findings.
- [ ] **Step 4 — Extend the independent release matrix.** Add cases for metadata expansion, dense/max-count tables, long UTF-8 tokens, shared values/deep containers, near/beyond per-block and aggregate quotas, several sequential layers, a large binary layer with small metadata (no whole-layer copy), and binary findings under JSON/SARIF near-report and report-cap pressure. Generate temporary archives in <=64 KiB chunks, record recipe/hash/expected exit and rule/reason; retain existing atomic-output/report-cap guarantees. Measure the **entire** release CLI, including retained findings/reporting, with checker disabled. Use the existing process-group deadline, OS/time/RSS capture and 256 MiB/60-second failure thresholds. Product fixes needed to meet these approved limits return to the owning task tests; any proposed scope/limit change requires renewed specification approval.
- [ ] **Step 5 — GREEN and measured gate.** Run `swift test --sanitize=address --filter 'USDCResourceTests|USDCContainmentTests|AdversarialTests'`, `sh Scripts/test-adversarial.sh`, then `swift build -c release`, `UVK_RUN_RESOURCE_TESTS=1 swift test -c release --filter ResourceBoundaryTests`, and `python3 Scripts/verify-resources.py --executable .build/release/usdz-validator --output docs/verification/resource-results.md`. Expected: required resource and containment rows run without skips; every full invocation <=268,435,456 bytes and <=60 seconds, with exact expected stop/exit semantics. Record actual hardware/OS/Xcode/Swift, counts and failures; no universal sandbox/minimum-platform claim. Run the verifier regression command again. Do not repeat a passing resource matrix unless later changes affect its evidence.
- [ ] **Step 6 — Commit.** Stage the exact test/helper/manifest/resource-script/evidence paths above; commit `test: verify USDC containment and resource acceptance`.

### Task 10: Document conditional coverage and close the full verification gate [size: M | risk: none | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-14, AC-16, AC-17. The final whole-branch gate also verifies AC-01…AC-17.

**Files:** Modify `README.md`, `SECURITY.md`, `NOTICE` only for verified final notices, `docs/inspection-boundary.md`, `docs/fixtures.md`, `docs/report-compatibility.md`, `docs/cli.md`, `docs/releasing.md`, `docs/verification/release-matrix.md`, `docs/verification/release-summary.md`, `Tools/README.md`; add `docs/verification/usdc-v0-2.md`. Preserve existing experiment reports unchanged; link them as historical evidence rather than rewriting their original conditional conclusions. If committing them is desired as cited project evidence, stage only their two explicitly named 2026-10-24 experiment report paths, not all of `docs/deliverables/`.

**Interfaces:** Documentation describes the shipped native subset and actual evidence. No new product behavior or release artifact is introduced.

- [ ] **Step 1 — Draft factual documentation.** Replace blanket binary incompleteness with exact supported versions/containers and explicit exceptions; distinguish reference coverage from USD/conformance/geometry validity. Document internal metadata decompression while ZIP stays stored-only, envelope 2 limits/allocation accounting, new rule meanings, structural identity format, expression/clip/raw-wrapper gaps, private pinned LZ4 notices and offline native tests. Fix safety-envelope anchors and examples consistently. Keep v0.1 history/tag available. Record remaining unverified platforms and oracle omissions. Optional Apple originals may be rechecked only when available; record actual hashes/counts rather than assuming 59 implies success.
- [ ] **Step 2 — Check docs against contracts.** Run `make format-check`, `make schemas`, `python3 -m unittest discover -s Tests -p 'test_verification_tools.py'`, and `python3 Scripts/verify-examples.py --executable .build/release/usdz-validator`. Expected: all pass, including five documented example commands. Never regenerate expectations from encoder output; include changed manifest-bound documentation in fresh evidence.
- [ ] **Step 3 — Run the full required current-host gate once.** Run `sh Scripts/verify-release.sh --evidence-dir .build/verification/usdc-v0-2-current`, with a fresh empty path. Expected: unchanged lock, debug/release builds/tests, isolated CLI process tests, ASAN including new C paths, offline schemas, verifier tests, examples, all 81 golden exports / 21 reviewed files, dedicated real-size resources and full-process measurements pass. Native tests need no oracle/writer/download. Current-host acceptance PASS does not promote deferred macOS 15/cross-host/Python baseline rows; preserve their UNVERIFIED status. Inspect actual link inputs for no host LZ4 and the library-only consumer result.
- [ ] **Step 4 — Perform the mandated final reviews.** Use `personal-workflows:code-review` for sequential specification then quality review of the whole implementation branch, following the chosen execution workflow. Cover all changed product, C, tests, fixture, schema, verification and documentation inputs. Resolve actionable findings through the owning tests; rerun affected checks and the full gate only where changes invalidate prior evidence. A material change to the approved specification/plan returns to its named approval gate. No acceptance claim while required findings/checks remain unresolved.
- [ ] **Step 5 — Record acceptance and commit.** In `docs/verification/usdc-v0-2.md`, map AC-01…AC-17 to actual test/evidence paths, source/dependency hashes, environment, optional corpus/oracle results and remaining uncertainty. Do not treat planned checks or oracle absence as passing evidence. Explicitly stage final documentation/evidence paths; commit `docs: record USDC v0.2 coverage and verification`. End with the local branch/commit and verification result for user review. Do not tag, publish, push or merge.

## Acceptance traceability

| Criterion | Owning tasks and proof |
| --- | --- |
| AC-01 | 7: eligible/unreferenced/binary-.usd integration and CLI tests; 10: final gate |
| AC-02 | 1/4/6: genuine fixture headers, exact-version rejection and live-type tests |
| AC-03 | 1/4/6: independent 71-occurrence inventory, live joins, buckets/containers/sites |
| AC-04 | 1/6: genuine 56/57 scalar/array/empty/sample cases |
| AC-05 | 5/6/7: shared resolver, expression/safe-prefix, clip-template and boundary cases |
| AC-06 | 6/7: exhaustive scanner state, mixed layers and no coverage upgrade after gaps |
| AC-07 | 3/4/6/7: conclusive versus ambiguous failures and retained earlier findings |
| AC-08 | 2/3/4/6/9: arithmetic, compression, joins, topology, flags, cycles and ASAN mutations |
| AC-09 | 2/6/9: at/+1, pre-allocation, cross-layer, shared occurrence and UTF-8 accounting |
| AC-10 | 2/7/9: bounded snapshot read instrumentation plus six child containment controls |
| AC-11 | 5/6/8: independent ID vectors, shared bodies, repeat/relocation/rename invariance for the existing tuple contract, no false locations |
| AC-12 | 5/7/8/10: independent v1 JSON/SARIF goldens/schemas, privacy, profiles, gates, external separation |
| AC-13 | 1/6: durable 9+14 originals / 71 independent expected occurrences, offline execution |
| AC-14 | 1/6/10: retained semantic comparison/provenance and explicit API omissions; no false zero-result completeness |
| AC-15 | 2/9/10: charged lifetime tests and full release CLI RSS/time/resource/report-pressure evidence |
| AC-16 | 3/8/9/10: LZ4 provenance/license/link-input evidence, C hash binding and exact host record |
| AC-17 | 8/10: version/envelope/schema and user/security/resource/reporting documentation; preserved v0.1 tag |

## Assumptions, review result and approval handoff

The approved scope has no new unresolved product decision. Implementation details selected here are packed charged storage, a streaming occurrence adapter, numeric binary sites and eight additional independent golden documents. If any genuine representation cannot be supported within the approved subset and limits, record the evidence and request renewed specification review instead of silently reducing coverage or relaxing a limit.

Planner self-review completed against the five writing-plans checks: every AC has an owning task; each task names files, interfaces, RED/GREEN assertions and explicit commit scope; cross-task type names are consistent; all five Review Focus cases have owning tests; implementation bodies and speculative abstractions are omitted. No production files, tests, schemas or scripts were changed while preparing this plan.

**Current stage: Stage 4 — approved implementation.** The specification and this plan received separate explicit approvals. The user selected subagent-driven execution with tasks run sequentially. Implementation proceeds under the approved scope and Git workflow; no push, merge or publication is authorized.

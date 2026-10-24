# Opaque USDC Numeric Arrays v0.2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove declared-element charges only for admitted opaque numeric arrays, preserving package-local reference inventories and demonstrating the amended resource policy on the current host.

**Architecture:** Keep the selective Swift reader and existing representation admission. In its numeric-array skip path, retain the bounded count-header read while excluding the ignored count from item/work admission; keep other containers and actual traversal charged. Verify through native tests, an opt-in private-corpus test and complete release-process measurements.

**Tech Stack:** Swift 6 / SwiftPM, Foundation, XCTest, existing private LZ4 1.10.0 target, existing offline Python schema/resource tools.

**Spec:** `docs/superpowers/specs/2026-10-25-usdc-opaque-numeric-arrays-v0-2.md` — APPROVED. Parent: `docs/superpowers/specs/2026-10-24-usdc-reference-coverage-v0-2-design.md`; its unaffected contracts remain binding.

**Slug:** `usdc-opaque-numeric-arrays-v0-2`
**Status:** APPROVED — Stage 4 implementation authorized; sequential subagent execution selected.
**Date:** 2026-10-25
**Paired artifact naming:** The specification and implementation plan use the identical basename `2026-10-25-usdc-opaque-numeric-arrays-v0-2.md` in their respective directories, per the user's standing naming preference.
**Execution tier:** full
**Implementation model role:** full
**Execution method:** Subagent-driven, tasks sequential, preserving the user's earlier explicit selection “proceed with subagent-driven execution, with tasks run sequentially”. Do not run implementers or review stages concurrently.
**Provenance:** Approved amendment and direct repository evidence at HEAD `bf1f23ad934e133ff1e5d290aad93fb182f99f11`; original approved plan `docs/superpowers/plans/2026-10-24-usdc-reference-coverage-v0-2.md`; investigation and baseline receipts named in the amendment. Exact-slug plan resolution was MISSING before creating this file. No legacy plan is a source.
**Approval evidence:** Stage 1: the user's first “i approve” for the narrow scope. Stage 2: the subsequent “i approve” immediately after presentation of the saved DRAFT amendment and its safety-envelope 3 proposal. Stage 3: after this separate saved plan was presented, the user stated “i always want the spec define and plan to have the same name / apart from this, i approve the content of the files”. This approves the plan content and requests identical specification/plan basenames. The naming/reference corrections do not change approved scope. Stage 4 execution is authorized; no push, merge, tag or publication is authorized.

## Global Constraints

- Product **0.2.0**; safety-envelope version **3**; report/config/catalogue schema major **1**. Report schema accepts historical identities **1, 2 and 3**. No new CLI option, public reference-inventory API, profile or rule ID.
- Exact crate versions **0.8.0, 0.9.0 and 0.10.0** only. Exempt array flags `0x80` for tags **1–9 and 13–30**, plus `0xa0` for tags **3–9**, after existing admission. No widened scalar/type/flag/version support or name-based exception.
- Zero payload requires no header read. Nonzero payload requires a pointer inside value data and a complete **eight-byte** count header. Counts **0, 250,000, 250,001 and UInt64.max** must not drive numeric allocation, iteration, decoding, arithmetic, item rejection or proportional work.
- String/token and asset arrays, dictionaries, wrappers, sublayers, list operations, time-sample containers and tags **56/57** are excluded. Enclosing containers and actual repeated visits remain charged; sharing an offset never suppresses a real asset occurrence.
- Preserve every numerical ceiling: metadata blocks **16 MiB**, cumulative decode **32 MiB**, live USDC storage **64 MiB**, nonexempt table/container items **250,000**, structural work **2,000,000**, depth **32**, asset bytes **4,096**, shared occurrences **100,000**, and all archive/read/finding/report limits.
- Native inspection remains supplied-input/read-only/package-local. No extraction, host reference resolution, network, native subprocesses, plugins, composition, expression evaluation or geometry decoding. Bounded crate-metadata decompression alone remains permitted; dependency pins/licenses stay unchanged.
- Complete release invocations, including reporting, must meet **256 MiB peak RSS and 60 seconds** on the recorded current host. Counters, partial measurements and historical envelope 2 results cannot establish envelope 3 acceptance.
- Retain canonical **71** and supplementary **one** genuine reference occurrences. All **five private Apple originals** must have complete requested native coverage/default acceptance and reconciled semantic inventories totaling **59**, including Fender's **10**. Keep originals and raw authored inventories local; do not assume redistribution rights.
- Preserve deterministic identities, privacy, gates, failure classification and earlier findings. Current-host results do not verify macOS 15 or cross-host equality. Keep `v0.1.0` available. No push, merge, publication or release tag.

## Review Focus

1. A numeric ValueRep and a real asset array share a payload offset: the asset remains counted and bounded. Task 1's `testSharedNumericOffsetDoesNotHideAssetArray` pins both traversal orders and duplicate sites.
2. Unknown numeric flags appear before a readable asset: retain a gap and the asset finding. Task 1's `testUnknownNumericRepresentationRetainsLaterAsset` covers flags and unsupported versions separately.
3. A UInt64.max numeric count sits inside a dictionary, wrapper or sample: the leaf remains opaque while the enclosing structure retains its limits. Task 1's `testNestedNumericCountsLeaveEnclosingContainersCharged` pins this distinction.
4. Removing count charges admits much more repeated live traversal: the two-million work stop must still arise from processed structure. Task 4's actual-work recipe and Task 1's exact accounting test cover this without relying on a forged numeric count.
5. A private manifest contains correct totals but wrong sites or duplicated/lost occurrences: parity must fail. Task 3's manifest/comparator tests use deliberate value/site/multiplicity/hash mutations, independent of candidate output.

---

## Evidence, assumptions and command provenance

Planning baseline is branch `feat/usdc-reference-coverage-v0-2`, HEAD `bf1f23ad934e133ff1e5d290aad93fb182f99f11`. Only the amendment specification and pre-existing `docs/deliverables/comparisons/` were untracked before planning. Preserve the comparisons, historical research, original approved specification/plan and prior evidence directories. No production command or verification build was run during planning.

Architecture map `docs/architecture/map.md`: **MISSING** at that HEAD; no map HEAD/freshness assertion is possible. The documentation tree and tracked architecture/ADR/decision paths contained no accepted or proposed ADR. Do not generate a map or ADR here. Fresh key-path checks inspected `Package.swift`, `Configuration.swift`, `ResourceLedger.swift`, `NativeEngine.swift`, `BoundedReader.swift`, `USDCValues.swift`, `USDCFormat.swift`, `USDCReader.swift`, the affected tests and verification scripts. The map absence is disclosed, not replaced with a claim that an old map is current.

Important seams:

- `USDCValues.Walker.skip(tag:flags:payload:)` currently calls `count(_:stride:)` for opaque arrays; that common function checks item/size admission and consumes declared-element work. Keep it unchanged for nonexempt users.
- `USDCValueFormat.admit(tag:flags:payload:version:)` already defines the exact matrix; preserve it. `USDCReader.scan(entry:reader:defaultEntry:onReference:onIssue:)` supplies synchronous internal callbacks.
- `USDCResourceTests.testCrossLayerAndUTF8Boundaries` and `testCrossLayerWorkReachesExactLimitWithoutRefunding` deliberately assert the old numeric charges. Revise their affected portions; preserve unrelated checks.
- `Scripts/verify-resources.py` currently uses eight shared numeric arrays for `usdc-work-over`. That recipe must change, rather than weakening its expected resource failure.
- `ValidationConfiguration.safetyEnvelopeVersion` is the current public constant. JSON/text/SARIF project configuration through existing encoders; no encoder redesign is necessary.
- `Tools/README.md` retains three independent golden-authoring recipes. `Tests/Schemas/manifest.json` and schema-contract tests pin those recipes and reviewed documents. `Tests/Fixtures/manifest.json` pins every fixture/TestSupport file and the resource generator; update affected hashes only after final bytes are established.

There is no unresolved product decision: the approved specification includes envelope 3. Private fixtures are local inputs, not CI prerequisites. The test-only manifest and opt-in environment controls below are implementation choices within the approved verification scope. If originals, historical receipts or a needed oracle environment are unavailable at execution, report the missing evidence and keep acceptance incomplete; do not substitute candidate-generated expectations.

| Check | Command and repository evidence |
| --- | --- |
| Focused RED/GREEN | `swift test --filter 'USDCNumericArrayTests|USDCResourceTests|USDCValueTypeTests'`; existing SwiftPM filter form in the parent plan and `Scripts/verify-release.sh`, specialized to owning suites |
| Focused sanitizer | `swift test --sanitize=address --filter 'USDCNumericArrayTests|USDCResourceTests|USDCContainmentTests'`; release runner's ASAN command narrowed to owning suites |
| Fixture/reference/integration | `swift test --filter 'USDCFixtureTests|USDCReferenceTests|USDCIntegrationTests|FixtureTests'`; same existing filter form |
| Schema contracts | `make schemas`; `Makefile` and existing hash-locked `.venv` |
| Reporting/goldens | `swift test --filter 'ConfigurationTests|JSONReportTests|SARIFReportTests|TextReportTests|USDCReportTests|GoldenCompatibilityTests'`; existing filter form and golden export suite |
| Tool regressions | `python3 -m unittest discover -s Tests -p 'test_verification_tools.py'`; release runner |
| Release resources | `make resources`; `Makefile` builds release, runs `UVK_RUN_RESOURCE_TESTS=1` tests and invokes `Scripts/verify-resources.py` |
| Full current-host gate | `sh Scripts/verify-release.sh --evidence-dir .build/verification/usdc-numeric-v0-2-current`; existing runner with a fresh destination |
| Format | `make format-check`; `Makefile` |

The private-corpus command in Task 3 specializes the same XCTest mechanism, adding new **test-only** environment inputs defined there. Do not run any listed command during planning. During execution, one focused RED/GREEN cycle per change and one final full gate suffice unless subsequent changes or failures require repetition.

## Files and ownership

| Owner task | Paths and responsibility |
| --- | --- |
| 1 | Modify `Sources/USDZValidation/USDC/USDCValues.swift`; create `Tests/USDZValidationTests/USDCNumericArrayTests.swift`; revise only affected expectations in `USDCResourceTests.swift`. No type-admission or general storage-limit changes. |
| 2 | Modify `Sources/USDZValidation/Configuration.swift`, the envelope comment in `ResourceLedger.swift`, `Schemas/report-v1.schema.json`, configuration/report/schema tests, `Tests/Goldens/`, affected report examples, `Tests/Schemas/manifest.json`, and golden recipes in `Tools/README.md`. |
| 3 | Create `Tests/USDZValidationTests/USDCPrivateCorpusTests.swift`; strengthen semantic checks in `USDCReferenceTests.swift`/`USDCValueTypeTests.swift` only where missing. Store private manifests/receipts under ignored `.build/verification/`, without committing originals. |
| 4 | Modify `Scripts/verify-resources.py`, `Tests/test_verification_tools.py`, `USDCContainmentTests.swift` and `ResourceBoundaryTests.swift`; update `Tests/Fixtures/manifest.json` for actual generator changes. Add synthetic containment cases inside owning test files. |
| 5 | Update `README.md`, `SECURITY.md`, `docs/inspection-boundary.md`, `docs/report-compatibility.md`, `docs/verification/release-summary.md`; create `docs/verification/usdc-numeric-v0-2.md`; preserve/refresh `docs/verification/resource-results.md` with actual measurements. |

Do not restructure large existing files, add general parser abstractions or create a new dependency. Avoid modifying TestSupport helpers when current literal recipes suffice; if a helper is genuinely required, its fixture-manifest binding belongs to that task.

## Execution preflight after plan approval

- [ ] Re-read both approved artifacts and record the separate approval messages before changes. Set this plan's lifecycle to approved only after its actual approval.
- [ ] Recheck status/HEAD. Continue the existing approved feature branch in the existing checkout; it already contains the parent implementation. Do not create a worktree, restart the original implementation, reset local research, or move/rebase the branch onto main. If branch ownership/state has materially changed, stop to resolve that state.
- [ ] Commit only the approved amendment specification and plan on this feature branch, with `docs: record approved numeric-array amendment`. Leave unrelated comparisons uncommitted. Assign each subsequent task to one implementer and finish its sequential specification and quality reviews before starting the next task, following `personal-workflows:spec-implement`.

### Task 1: Numeric exemption and actual accounting [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security,performance]

**Acceptance criteria:** AC-01, AC-02, AC-03, AC-04, AC-05, AC-06.

**Files:** Task 1 ownership above. Security risk: a broader skip or removed charge could hide references or permit excessive live traversal.

**Interfaces:** Consume existing `USDCMutationRecipe.valueCrate(reps:body:tokens:strings:names:version:tokenEncoding:tokenCapacity:)`, `USDCReferenceTests.scan(_:ledger:)`, `USDCReferenceTests.word(_:_:)`, and `USDCValues.walk(field:tables:input:onReference:onIssue:)`. Keep `Walker.skip(tag: UInt8, flags: UInt8, payload: UInt64) throws` and `count(_ cursor: inout USDCByteCursor, stride: UInt64) throws -> UInt64`; expose no new production API. Later tasks rely on identical callback/site types and changed numeric work totals only.

- [ ] **Step 1 — Write failing policy tests.** Add `USDCNumericArrayTests.testAdmittedNumericCountsAreOpaque`, looping the approved versions/tags/flags and counts, with literal header-only bodies. Assert `.complete`, zero references/issues and equal `usdcWorkUnits`, `usdcDecodeBytes`, read-event sequences and observed live-storage charges for otherwise identical count variants; final `usdcLiveBytes == 0`. For zero payload assert no value-data header read. Add `testNumericHeaderAndValueRegionRemainBounded` with seven-byte header, pointer before value data, pointer into metadata and exact eight-byte boundary. Assert `.malformed(.invalidRange)` issues and no out-of-range source read, using the existing injected `BoundedReader` closure. Bodies with asset-looking bytes produce zero references.
- [ ] **Step 2 — Add boundary/multiplicity tests.** `testSharedNumericOffsetDoesNotHideAssetArray` uses a body with count 2 and two string indices, referenced by both numeric and asset ValueReps in both orders; assert two emitted assets per asset site, distinct locators, and asset counts 250,001 still fail `.usdcItems`. `testUnknownNumericRepresentationRetainsLaterAsset` asserts partial coverage plus the later asset for unknown flags; unsupported crate versions remain uninspected. `testNestedNumericCountsLeaveEnclosingContainersCharged` builds literal dictionary/relative-wrapper/time-sample cases around numeric leaves and verifies enclosing excesses still fail. Include string/token arrays and tags 56/57 as explicit negative exemption controls.
- [ ] **Step 3 — RED.** Run the focused RED/GREEN command from the catalogue. Expected: new high-count numeric cases fail with current `.usdcItems`/`.usdcWork`; new preservation cases pass. Record the actual assertion failures, rather than treating compilation errors as policy evidence.
- [ ] **Step 4 — Make the minimal skip change.** In the existing admitted array path, keep zero-payload return and `cursor(payload)`. For tags 1–9 and 13–30 only, consume the raw eight-byte integer and discard it without `count`/checked-byte-count calls; other arrays keep `count`. Preserve admission, `visit` work, cycle/depth handling and actual read/storage charges. Explain the intentional geometry exclusion in a short intent comment; do not add a cache, bypass, geometry-length calculation or new format helper.
- [ ] **Step 5 — Replace obsolete work expectations.** In the two identified resource tests, remove declared numeric counts from hand-derived work totals. Add `testRepeatedNumericVisitsAndCrossLayerActualWork` proving extra visits cost work regardless of payload sharing, accumulation survives layers and storage returns to an existing owner's baseline. Preserve exact 2,000,000/+1 ledger behavior and add actual structural-work exhaustion with an independently derived fixture, coordinated with Task 4. Keep item admission/allocator overflow tests unchanged.
- [ ] **Step 6 — GREEN and scoped safety verification.** Run focused RED/GREEN, focused sanitizer and fixture/reference/integration commands from the catalogue. Expected: all selected cases pass with no unexpected skip/sanitizer error; historical 71 occurrences and supplementary case remain correct. Review the count-only variants' read/work/charge receipts; final release RSS remains Task 4/5 evidence.
- [ ] **Step 7 — Commit/review.** Commit explicit Task 1 paths with `feat: exempt opaque numeric arrays from element charges`; complete sequential task reviews. Do not resolve unrelated review findings by broadening admission.

### Task 2: Envelope 3 and report compatibility [size: M | risk: other | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-10, AC-11.

**Files:** Task 2 ownership above, including existing `ConfigurationTests.swift`, `JSONReportTests.swift`, `Tests/test_schema_contracts.py` and affected report/golden checks. Compatibility risk: report consumers and independent expected bytes must agree on the policy identity.

**Interfaces:** Keep `ValidationConfiguration.safetyEnvelopeVersion: Int`, changing its constant to 3, and `ValidatorVersion.current == "0.2.0"`. Keep encoder and configuration initializers unchanged. Report schema's existing integer enum becomes `[1, 2, 3]`.

- [ ] **Step 1 — Write failing compatibility assertions.** Expect configuration, JSON/text/SARIF exports to carry envelope 3 and product 0.2.0. In `testHistoricalAndCurrentSafetyEnvelopesKeepSchemaMajorOne`, require validity for 1/2/3 and rejection of 0/4/true/string values. Retain literal historical envelope 1/2 documents in test inputs, so validation is exercised independently of the new current goldens. Preserve USDA/binary identity vectors and privacy/gate expectations.
- [ ] **Step 2 — RED.** Run reporting/goldens and `make schemas`. Expected: envelope-3 assertions/schema acceptance fail against envelope 2. Separate intentional golden mismatches from unrelated failures.
- [ ] **Step 3 — Update the policy identity and independent expectations.** Change the configuration constant and envelope comment only; leave numerical limits unchanged. Update schema, current report examples and current golden configuration metadata using the literal recipes in `Tools/README.md`, in temporary staging. Do not capture expected bytes from product encoders or blindly replace historical research/specification text. Refresh actual recipe hashes, schema-manifest bindings and corresponding pinned tests after intentional review; preserve unrelated golden fields and identity bytes.
- [ ] **Step 4 — GREEN.** Run reporting/goldens, `make schemas`, and fixture/reference/integration checks. Expected: current envelope 3 projections match independently authored goldens, historical reports validate, and schema major/profile/ID semantics remain intact. No export-count increase is necessary.
- [ ] **Step 5 — Commit/review.** Commit explicit compatibility paths with `feat: identify numeric-array policy as safety envelope 3`; complete sequential reviews.

### Task 3: Semantic parity on genuine fixtures and private originals [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security]

**Acceptance criteria:** AC-06, AC-07, AC-11; supports AC-09.

**Files:** Task 3 ownership above. Security risk: verification must not add a production resolver/export path, traverse host dependencies or expose private authored content in tracked files.

**Interfaces:** New test class `USDCPrivateCorpusTests`, with `testPrivateManifestComparatorRejectsWrongEvidence() throws`, `testPrivateOriginalSemanticInventories() throws` and `testPrivateOriginalReleaseMeasurements() throws`. Private opt-in inputs: `UVK_USDC_PRIVATE_CORPUS_MANIFEST` points to a local JSON manifest; `UVK_USDC_PRIVATE_EVIDENCE_DIR` points to a fresh ignored output directory. No manifest means explicit skip of the two original-dependent tests; a supplied missing/malformed/incomplete manifest is a failure. The comparator regression runs without private assets.

Manifest contract: `schemaVersion: 1`, `inputs` containing exactly the five known sample IDs and each supplied absolute `path`, `sha256`, and `expectedReferences`. Each expectation records member name bytes, authored value bytes (base64), `pathElements`, `field`, and semantic container key/index coordinates. Expectations carry source receipt hashes and oracle omissions; compare multisets, never sets. Test helpers consume existing internal `ZIPDirectory.read(from:diagnostics:)`, `ZIPIndex.build(directory:reader:diagnostics:)`, package prerequisites and scanner callbacks. Reconstruct semantic sites only inside the test; no production API changes.

- [ ] **Step 1 — Freeze independent expectations before candidate collection.** Build the local manifest from historical `corpus-final.json` and independently cross-check with `oracle-final.json`, recorded source/provenance and the existing development-only authored Sdf oracle where practical. Counts must reconcile per sample **20, 20, 10, 4, 5**, total **59**. Record the semantic normalization of property/path/container coordinates, empty/internal references and any API omissions. Hash originals before/after. Do not derive expected sites/values from the candidate, and do not blindly rerun historical scripts that write fixed output paths or pin the old executable.
- [ ] **Step 2 — Write comparator/manifest tests and run RED.** Use an independently literal two-occurrence synthetic expectation. Assert that a changed value, site, duplicate multiplicity, input hash, absent original, missing sample or unresolved oracle omission fails; reordering alone preserves equality. Run `swift test --filter USDCPrivateCorpusTests` (existing XCTest command form). Expected: precise missing comparator/assertion failures during development; after implementation the asset-independent comparator test passes and the two opt-in tests explicitly skip without a manifest.
- [ ] **Step 3 — Implement only the test harness.** Use bounded `FileSnapshot` reads and existing native archive/index/integrity/default-layer prerequisites. Scan every eligible supplied layer, collecting typed internal occurrences and test-only semantic coordinates; support USDA layers through existing lexical callbacks if present. Require zero forbidden ranges and released scanner storage. Keep inventory collection bounded by existing limits; no whole-archive copy/extraction or dependency lookup. Separately run the actual complete release CLI with `/usr/bin/time -l`, the existing 60-second process-group deadline pattern, default `general-v1`/JSON/no external checker, and record three runs per original. Candidate inventory/helper overhead is not CLI RSS evidence.
- [ ] **Step 4 — GREEN on committed corpus.** Run fixture/reference/integration commands and the private test class without inputs. Expected: canonical 71 plus supplementary one remain pinned semantically, mutation comparator passes, private inputs are reported as absent rather than passed. Keep known raw-wrapper/oracle gaps truthful.
- [ ] **Step 5 — GREEN on private inputs after a release build.** Run `swift build -c release`, then the following specialization of the existing opt-in XCTest pattern:

  ```sh
  UVK_USDC_PRIVATE_CORPUS_MANIFEST="$PWD/.build/verification/usdc-numeric-private-inputs.json" UVK_USDC_PRIVATE_EVIDENCE_DIR="$PWD/.build/verification/usdc-numeric-private-current" swift test --filter USDCPrivateCorpusTests
  ```

  Expected: no private-test skips; all five multisets match, total 59/Fender 10, originals unchanged, each CLI run returns 0 with complete requested native coverage, envelope 3/product 0.2.0, repeat reports/exits identical, peak RSS ≤268,435,456 bytes and elapsed ≤60 seconds. Fail on another Fender limit, discrepancy or missing measurement; do not silently widen scope. Preserve logs/manifests locally.
- [ ] **Step 6 — Commit/review.** Commit test source and non-sensitive provenance guidance only with `test: verify USDC semantic inventories on private originals`; complete sequential reviews. Never stage local manifests, raw receipts, originals or new oracle dependencies.

### Task 4: Actual-work resource matrix and containment [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security,performance]

**Acceptance criteria:** AC-02, AC-03, AC-04, AC-05, AC-08, AC-09, AC-11.

**Files:** Task 4 ownership above. Security risk: unchanged numerical ceilings do not prove that new maximum-admitted traversal remains bounded.

**Interfaces:** Preserve Python `binary_recipes()` row tuples and `validate_rows(rows)`/`check_expected_findings(name, findings)` contracts, the existing resource-tool CLI, and `USDCContainmentTests.testChildOnlyDenyPolicy() throws`. Extra synthetic containment inputs must be counted separately from the **27 genuine inputs/72 occurrences**, not relabeled as genuine evidence.

- [ ] **Step 1 — Write failing verifier and containment expectations.** Add required named rows for high/max opaque counts, compressed opaque arrays, repeated shared numeric leaves, aggregate layers, malformed headers, and nonexempt limits. Assert missing/skipped/wrong-reason/over-RSS/over-time rows cannot pass. For `usdc-work-over`, require `UVK-RES-001`/`usdcWork` from actual structural traversal; the old eight-array recipe is no longer valid. Extend contained-child expected inputs with extreme-count, shared numeric/asset-offset, unknown-flag and truncated-header cases, deriving expected outcomes independently before entering denial.
- [ ] **Step 2 — RED.** Run tool regressions and `swift test --filter USDCContainmentTests`. Expected: new required-row/receipt assertions fail until generators and synthetic child coverage exist; original controls remain intact.
- [ ] **Step 3 — Implement bounded resource recipes.** Replace `usdc-work-over` with iterated structure: a bounded dictionary of numeric leaves shared across live fields, with each dictionary ≤250,000 entries and normal nesting, so processed entries/relative edges/ValueRep visits exhaust work before another ceiling. Derive its expected work arithmetically from actual operations before running; retain Task 1's exact boundary proof. Use the independent literal metadata encoder and streamed archive writer, keeping each generator unit bounded. Add count variants without expanding numeric bodies; retain existing hostile metadata, mixed occurrence, large-layer and JSON/SARIF report-pressure rows. Pin each failure to its intended reason, not merely a nonzero exit. Refresh the resource-generator hash in the fixture manifest after final generator bytes.
- [ ] **Step 4 — Complete contained-child coverage.** Keep all six effective EPERM controls and zero forbidden reads; require unchanged semantic/finding/coverage results on the genuine corpus plus the separately identified synthetic cases. Keep real `FileSnapshot` range checks separate from post-bootstrap denial. Print actual input/occurrence/read counts, final live charges and failures; do not hard-code historical read count 1,951 or treat observed read-time live charges as a complete allocation high-water measurement.
- [ ] **Step 5 — GREEN.** Run tool regressions, focused sanitizer, fixture/reference/integration checks, and `make resources`. Expected: every expanded resource row and dedicated boundary test passes without opt-in skips; each complete measured process meets RSS/time, failure reasons remain correct, no source range violation, all six controls are EPERM, and storage returns to baseline. Store raw measurements and actual candidate executable hash. A measurement failure blocks acceptance even when counters pass.
- [ ] **Step 6 — Commit/review.** Commit explicit Task 4 files and generated resource report with `test: verify actual USDC work and containment under envelope 3`; complete sequential reviews. If tests uncover a defect outside the approved boundary, use the user's specification-change gates rather than expanding the fix.

### Task 5: Documentation, fresh acceptance and final review [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security,performance]

**Acceptance criteria:** AC-01, AC-02, AC-03, AC-04, AC-05, AC-06, AC-07, AC-08, AC-09, AC-10, AC-11.

**Files:** Task 5 ownership above. Security risk: stale policy or acceptance claims could misrepresent coverage, limits or compatibility. No new product behavior belongs to this task.

**Interfaces:** Consume completed Tasks 1–4, their review results and immutable raw receipts. Produce `docs/verification/usdc-numeric-v0-2.md` with criterion-to-evidence links, actual candidate/executable/input hashes, commands, host and unresolved limitations. Preserve `docs/verification/usdc-v0-2.md` as the historical envelope 2 gate.

- [ ] **Step 1 — Document the actual contract.** Explain the exact numeric exemption, eight-byte header checks, geometry exclusions, untouched numerical limits and actual work charges. Update current-policy links/headings to envelope 3, noting that strict old report schemas reject identity 3. Keep product 0.2.0/schema major 1/profile/identity meanings clear. Record five-original inventory evidence, oracle limitations and local-only provenance without raw authored/private details; keep untested platform rows explicit. Before measurements, mark pending results pending.
- [ ] **Step 2 — Final current-host gate.** Run `make format-check`, then the full current-host gate command from the catalogue in its fresh directory. Expected: all required steps PASS with retained logs, current reports/goldens/schema checks correct, dedicated CLI/resource checks contain no unexpected skips, debug/release/ASAN clean, dependencies unchanged, and all measured processes within limits. Ordinary opt-in private/installed-tool skips are disclosed; the separate Task 3 private run must have passed. Do not claim the historical 327-test/26-resource-row totals are current; report actual expanded totals. Preserve any failed attempt under its own directory.
- [ ] **Step 3 — Bind final evidence.** Confirm the executable hash used by the private measurements matches the final release executable: the release-test build can relink it. If different, rerun only the private verification against that final executable into a new evidence directory and explain the binding. Verify all final source/recipe/manifest hashes still match acceptance receipts; summarize observed resource maxima and all AC results. If a later source change invalidates a gate, refresh affected checks rather than reuse stale evidence. Documentation-only receipt links must not pretend to have been covered by an earlier source binding.
- [ ] **Step 4 — Commit and final sequential review.** Commit explicit final documentation/evidence summaries with `docs: record numeric-array envelope 3 acceptance`. Use `personal-workflows:code-review` for the required specification review followed by quality review on the amendment delta plus affected original contracts. Reference the already closed parent review as historical evidence; do not restart its completed task loop. Resolve only approved-scope findings and refresh affected verification. A final PASS requires all amendment criteria and parent invariants; otherwise report the precise blocker and retain local work.
- [ ] **Step 5 — Handoff.** Report changed behavior, actual tests/counts, five-original parity, containment/resource evidence and remaining unverified cases. Leave the branch local and unmerged. Do not push, tag, merge or start a release without a separate user request.

## Criterion traceability

| Amendment criterion | Owning tasks / decisive evidence |
| --- | --- |
| AC-01 | 1: exact version/type/flag and nested matrix; 5: final regression gate |
| AC-02 | 1: header/value-region negatives; 4: hostile contained/resource cases |
| AC-03 | 1: count-only read/work/charge comparisons; 4: extreme-count process rows |
| AC-04 | 1: exact repeated/cross-layer accounting; 4: actual-work exhaustion and reservations |
| AC-05 | 1: excluded-container and shared-offset boundaries; 4: retained resource matrix |
| AC-06 | 1/3: canonical/supplementary semantic multisets, ordering and duplicate-site controls |
| AC-07 | 3: five fingerprinted originals, 20+20+10+4+5 semantic occurrences, fresh default CLI runs |
| AC-08 | 4: effective six-control denial, genuine/synthetic receipts and real snapshot range checks |
| AC-09 | 3/4/5: private and expanded maximum-envelope complete-process measurements, final executable binding |
| AC-10 | 2/5: envelope 1/2/3 schema proof, independent goldens, fresh debug/release/ASAN/CLI gate |
| AC-11 | 2/3/4/5: independent recipes, provenance, local-only originals, hashes and current documentation |

**Self-review:** Every amendment AC has an owning task; interfaces preserve existing production seams; five review-focus inputs have explicit tests. Commands come from the current Makefile/release runner or documented specializations of their existing XCTest opt-in/filter form. Risks require full execution. No new architecture/format decision or material clarification remains. This plan does not implement or verify the candidate.

**Current gate:** This plan's content is approved, with the requested identical-basename correction applied. Stage 4 execution of this amendment is authorized in the existing checkout using the preserved sequential subagent method. No push, merge, tag or release is authorized.

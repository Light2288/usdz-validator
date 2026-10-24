# USDC v0.2 current-host verification

**2026-10-24: current-host test acceptance PASS.** The single fresh final-fix full gate exited **0**, with all **19/19 required steps PASS**, on local branch `feat/usdc-reference-coverage-v0-2`. Product **0.2.0** is unpublished, safety envelope is **2**, and report/config/catalogue schema major remains **1**. Final whole-branch review is separate and remains the controller's responsibility.

```sh
sh Scripts/verify-release.sh --evidence-dir .build/verification/usdc-v0-2-final
```

The destination was absent before execution; prior run directories were preserved. This run verifies the final-review correction that gives nonempty string clip templates the required `UVK-LIM-003`/`unsupportedReference` cause, alongside the layer-level `UVK-LIM-007` summary. The earlier `usdc-v0-2-current` run and its original receipts remain preserved as pre-fix evidence. Local evidence is in `.build/verification/usdc-v0-2-final/`: genuine `summary.json`, `environment.json`, `logs/`, unchanged `Package.resolved.before`, `exports/`, `checked-in/`, `compatibility-manifest.json`, copied `resource-results.md`, and supplemental `link-inputs/` inspection receipts. Every command, environment override, exit and stdout/stderr path is retained in the summary. No result was copied from an earlier release run.

| Required check | Observed result |
| --- | --- |
| Environment, strict formatting, resolve/unchanged lock, debug and release builds | PASS, each exit 0 |
| Debug, release and ASAN full suites | Each **326 XCTest cases, zero failures, nine explicit opt-in skips** (31 CLI + 293 validation + 2 library-only consumer cases) |
| Isolated CLI process gate | **22 tests**, zero failures/skips; covers compile-only process-hook paths |
| Offline schemas and verifier tools | **10 self-tests + 10 schema contracts + 15 verifier tests**, no failures/skips |
| Documented examples | **Five** exact native commands PASS |
| Golden/export compatibility | **Two** tests PASS; **81 actual exports + 21 reviewed documents = 102** validated files, bound to **155** final input hashes, version set exactly `["0.2.0"]` |
| Dedicated real-size resource gate | **Nine** tests, zero failures/skips, including its 26-case process matrix |
| Standalone final release resource measurements | **26/26 PASS**; maximum peak RSS **208,683,008 bytes <=268,435,456**, maximum elapsed **1.808 seconds <=60** |
| Vendored C/consumer linkage inspection | Six actual debug/release link-file lists include private LZ4 objects; release CLI/consumer dynamic dependencies list no host LZ4; the consumer links neither ArgumentParser nor TestSupport. Actual ASAN `lz4.o` contains load-check instrumentation. |

Ordinary full suites intentionally skip four compile-only process-hook cases, four expensive resource cases and the unrequested installed checker smoke. Dedicated CLI/resource gates run those required paths without skips. The smoke remains explicitly SKIPPED, not passed. Full log receipts preserve the skip messages. No compiler warnings, sanitizer diagnostics or unexpected failures were observed.

The final resource report measures complete release CLI invocations, including retained findings, report projection/encoding and atomic delivery. Corpus generation/hashing/report parsing are outside the timed child. JSON/SARIF pressure retains 9,990 findings; cap failures preserve the existing output and return operational exit 3. [The durable report](resource-results.md) records each actual corpus hash, command, expected/actual exit/reason/findings, output bytes, RSS/time and host storage. These measurements apply to this corpus and host, not a universal memory guarantee.

## Exact host and bindings

Mac17,6 / Apple M5 Max / **arm64** / **38,654,705,664 bytes RAM** / internal APFS SSD on Apple Fabric; **macOS 27.0.1 build 26A434**, **Xcode 27.1 build 27A9275**, **Swift 6.4 swiftlang-6.4.0.34.1 clang-2100.3.34.1**, target `arm64-apple-macosx27.0.0`. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, no inherited override; formatter `main`; runner and hash-locked schema venv **CPython 3.14.7**. Exact filesystem/version command output is in `environment.json` and `logs/environment.*`.

| Evidence/input | SHA-256 |
| --- | --- |
| Evidence `summary.json` | `244f7371b8e0b7571144ee694fcc8e37570835355ebfad0bff033cc6f21320f3` |
| Evidence `compatibility-manifest.json` | `f6c57dcc95795a0687463838d0343bf690450b85d2fa95942fd5da0aef028a57` |
| Evidence `resource-results.md` | `874835f24cd3768fd1cb692646e450b6d63b8e582e76e4c9e1b828e344c94380` |
| Evidence `environment.json` | `339447292e8c4946cab8a61e3ef024161a5c3fc275f007d3e9e43c7ae9875f7d` |
| Evidence `link-inputs/receipt.json` | `3f44a91cb628172a0d44a10d8651e004860cfa1cc190a960beee4946dc849112` |
| `Package.resolved` | `eaf09ea422bb561945aac9d7e4192f0d051d7c647e3cb1eb7ffa8d4f57b9b937` |
| `Tests/Fixtures/manifest.json` | `5d56d477a11e4e453956c34117793f3251a365942883a21e78dfe18e75796a0b` |
| `Tests/Schemas/manifest.json` | `4bc8a1f98993eb76b4f9ef3f7bc5e6a8d17c9c0c09f1be1cc473978aac63262f` |
| `Tools/README.md` | `395097d0a501ba9eafccd7575fc44e63e7affaa7891e233fdd53e0b66fe7e14d` |
| `Tests/Fixtures/USDC/inventory.json` | `99a93b6703cb2fb9714a3da13fbd644f031d59197f646790ff06223124b3f0bb` |
| `Tests/Fixtures/USDC/evidence/provenance.json` | `4d1f76a2f17ad2eda9559319dad206066d6ba959a09851b9da837ad992dbe390` |
| `Tests/Fixtures/USDC/evidence/independent-oracle.json` | `775d6403399b46e614dd8d565f3b59265cf276a4293605d3499ef56c49170f10` |
| `Scripts/verify-resources.py` | `9ed7f3b250092d43f1072b846ca724709d0866e14d0c5c600215b84449215ea8` |
| `Sources/USDZValidation/USDC/USDCInput.swift` | `2aa4be0572245d5069ecc2a15e35358f20107038d63140f2e5a17284571aa747` |
| `Sources/USDZValidation/USDC/USDCReporting.swift` | `ecd8269b34ccb1df70416da1261dd30570505f5c5a9e416b0ff5e960a55347d5` |
| `Sources/USDZValidation/USDC/USDCValues.swift` | `3fcf8e4507874be4841044f9bf406ba67781744ca80179956f1c1f170c14769d` |
| Final measured release executable | `a107684145a94459c2ed8e06d8b61ad117aa3e40a568db561df843f635fa9f25` |

The runner's earlier pre-release-test executable snapshot is `5b0bd12adfe48f2c7e529ec9994bac4ee1137da54cdb26dd690420972b4ed238`. The release-test build subsequently relinks the executable; the final measurement hash above matches the actual executable and resource report. Both original observations are preserved; the summary was not rewritten.

LZ4 **1.10.0**, tag `v1.10.0`, upstream revision `ebb370ca83af193212df4dcbadcc5d87bc0de2f0`, is privately compiled from unchanged source. [The source manifest](../../Sources/CUSDCCompression/source-manifest.json) pins URLs, byte counts and these actual SHA-256 values:

| Vendored input | SHA-256 |
| --- | --- |
| `lz4.c` | `9396f7de527bc8435de9c7569fb7998e56545a84b4f3c2d808c0235c01774539` |
| `include/lz4.h` | `26b82efc53d1570f3b54eef02e9c4764c1ad374ff03cac04e2ced5ea4d4c552f` |
| `LICENSE` | `8b58c446121a109ccf32edc094bba3010a3d85e4ee3702950db55e4d3e87736c` |

The complete BSD-2-Clause license is retained verbatim in the private target and [NOTICE](../../NOTICE). The compatibility manifest binds all product Swift/C/header sources, dependency license/source manifest and NOTICE. Independent post-run hashing confirmed all 155 input bindings still match; final bound docs/hashes preceded evidence capture. The nested independent resource-generator pin now matches actual script bytes and is checked by the native fixture binding test. No golden/expected bytes were captured from product encoders.

## Acceptance traceability

The full debug/release/ASAN suites execute these owning tests; `logs/test.*`, `logs/release-test.*` and `logs/address-sanitizer.*` are the fresh receipts. Earlier implementation reports under `.superpowers/sdd/2026-10-24-usdc-reference-coverage-v0-2/` preserve development RED/GREEN details, but are not substituted for this gate.

| Criterion | Actual proof and durable inputs |
| --- | --- |
| AC-01 automatic inspection | `USDCIntegrationTests.testEveryEligibleBinaryLayerIsInspected`, `testCompleteBinaryPackagesAndMixedTextNeedNoSwitch`; CLI binary/process tests and `logs/cli-test.*` |
| AC-02 exact versions | `USDCTableTests.testGenuineVersionsAndAuthoredStructuralJoins`, `testPatchFutureAndMajorVersionsAreUnsupported`; `USDCValueTypeTests.testGenuineTimeCodeAndPathExpressionForms`; original headers in `Tests/Fixtures/USDC` |
| AC-03 authored occurrences | `USDCReferenceTests.testAll71AuthoredOccurrencesAndSites`, shared-value sites and all-six-list-bucket tests; independent `Tests/Fixtures/USDC/inventory.json` |
| AC-04 new value types | `USDCValueTypeTests.testGenuineTimeCodeAndPathExpressionForms`, flag/version-negative cases; genuine writer-specific scalar/array/empty/sample originals |
| AC-05 resolution | `ReferenceResolverTests` binary anchors/safe prefixes, expression-byte classification, `USDCValueTypeTests.testClipTemplateStringCannotCertifyCoverage` and unrelated-string cases; `USDCIntegrationTests.testClipTemplateReportsUnsupportedReferenceWithoutSpeculativeFindings` pins the specific cause, partial coverage, no guessed targets/prefixes, default exit 2 and JSON/SARIF privacy |
| AC-06 completeness | `USDCIntegrationTests` mixed/uninspected/partial cases, sticky expression/prerequisite gaps; `NativeEngineTests.testCoverageCompletionNeverErasesGaps` |
| AC-07 failures | `USDCTableTests.testAmbiguousRepresentationIsNotCorruption`, `USDCIntegrationTests.testEarlierFindingSurvivesLaterStop` and `testEarlierValueSurvivesLaterCorruptionInSameLayer`; independent malformed/partial report goldens |
| AC-08 defensive decoding | `USDCCompressionTests`, `USDCInputTests`, `USDCTableTests`, `USDCValueTypeTests`, `AdversarialTests` and ASAN; typed arithmetic/index/topology/cycle/flag/frame mutations |
| AC-09 aggregate limits | `USDCResourceTests`, including exact cross-layer work 2,000,000/+1, 16 MiB block/+1, 32 MiB decode, 64 MiB live, 250,000 items/+1, depth 32/33, 4,096/4,097 UTF-8 bytes and shared 100,000 occurrences; pre-allocation throwing closures and released reservations |
| AC-10 package-local access | `USDCContainmentTests.testChildOnlyDenyPolicy` six EPERM controls and 27 genuine inputs/72 occurrences; `testRealSnapshotReadsOnlySuppliedInputRanges`; `ResourceBoundaryTests.testRealSizeBinaryLayerUsesOnlyBoundedMetadataReads` |
| AC-11 binary identities | `USDCReportingTests`, `USDCReportTests`, existing `GoldenCompatibilityTests` relocation/rename/repeat checks; independent fixed digest vectors and absent fictional regions |
| AC-12 reporting/gates | `USDCReportTests`, JSON/SARIF/privacy/gate/profile/external suites; `logs/export-schemas.*`, `exports/`, `checked-in/` and compatibility manifest (81 actual exports + 21 reviewed files); historical USDA vectors preserved |
| AC-13 fixtures | `USDCFixtureTests` original provenance/hash checks and 23 cases/71 expected occurrences, `FixtureTests` top-level and nested generator binding; `Tests/Fixtures/USDC/evidence/provenance.json` and `inventory.json` |
| AC-14 oracle limits | Committed `Tests/Fixtures/USDC/evidence/independent-oracle.json`, typed/raw unregistered textual exports and live-type records; semantic multiset comparison and omissions below |
| AC-15 process resources | Dedicated `logs/resource-tests.*`, `logs/resource-measurements.*`, copied `resource-results.md` and [durable measurements](resource-results.md); 26 complete timed release invocations include report rendering/delivery |
| AC-16 dependency/platform | Exact environment and source/license bindings above; actual link-file lists and dynamic dependencies inspected; library-only consumer tests pass; untested hosts remain UNVERIFIED |
| AC-17 documentation | [Inspection](../inspection-boundary.md), [security](../../SECURITY.md), [CLI](../cli.md), [reports](../report-compatibility.md), [fixtures](../fixtures.md), [release procedure](../releasing.md), [tools](../../Tools/README.md); product 0.2.0/envelope 2/schema major 1; `v0.1.0` tag retained |

## Scope, oracle limits and remaining uncertainty

[The inspection boundary](../inspection-boundary.md) defines conditional reference completeness. It is not USD/OpenUSD conformance, composed-dependency, geometry, scene or renderer validation. Expressions/template identifiers are preserved and never evaluated; their resolver gaps use `UVK-LIM-003`. A nonempty string clip `templateAssetPath` uses `UVK-LIM-003` with reason `unsupportedReference`; the layer-level `UVK-LIM-007` partial-inspection summary coexists. Its literal prefixes and targets are not checked, and empty/unrelated strings remain non-references. Raw unregistered values, unknown types/flags and unproved representations retain gaps. Earlier findings survive later stops. A zero-occurrence inventory does not establish completeness.

The committed development oracle compares semantic multisets of scene-path elements, field, container position and literal authored value, preserving duplicates. Its `ListInfoKeys` omits `arbitraryMetadata` and misses `wrapped.png`; retained typed/raw unregistered textual exports document that omission. `GetInfo("subLayerOffsets")` raises a converter TypeError; sublayer paths are still compared. Zero-versus-zero on the raw wrapper cannot certify absence. The two writers and separately executed oracle share OpenUSD lineage; they are not independent format implementations. Native fixture/scanner tests read committed independent expectations without a writer, Python, oracle environment, installed USD tool or download. The separately opted-in developer resource-measurement harness uses Python as recorded in the gate commands.

[The original bounded experiment](../deliverables/experiments/2026-10-24-usdc-bounded-feasibility-experiment.md) and [0.9/0.10 extension](../deliverables/experiments/2026-10-24-usdc-09-010-feasibility-experiment.md) remain unchanged historical conditional reports. Optional private Apple originals and their 59 historical occurrences were not rechecked in this gate. No new native or checker result for those assets is claimed; they are not redistributed. Installed-checker smoke was not requested and remains SKIPPED.

Source compatibility is pinned to OpenUSD commit `96c1989167d2aaab5bd34627f32a321a6b79866b`, with one-byte compression counts and four-byte signed chunk lengths. Published framing/PATHS discrepancies are not resolved by an authoritative erratum. No alternate-parser fallback is used; ambiguous one/two-count PATHS layouts remain unsupported. PATHS checks establish numeric structural provenance, not full SdfPath grammar or semantic equality. Tag 52 relative Value-wrapper support has pinned-source and independent synthetic evidence only: no writer-produced tag 52 exists in the 27 genuine originals. Natural multi-gigabyte multichunk writer compatibility remains unverified.

The current ASAN containment receipt records 27 genuine inputs, 72 occurrences (71 canonical plus one supplementary), 1,951 input read requests, zero forbidden input ranges and zero remaining charged working bytes. Read/stat/enumerate/connect/execute/write controls all returned EPERM=1. Actual FileSnapshot instrumentation is separate. These tests establish no additional required access after runtime/input bootstrap under denial; they do not audit silently ignored Foundation/runtime syscall attempts, install a product sandbox or enforce an OS memory limit. Allocation charges and empirical RSS acceptance are separate evidence.

**UNVERIFIED:** macOS 15 / Xcode 16.0 / Swift 6.0, other hosts/toolchains, actual cross-host byte equality and CPython 3.12. Deployment declarations, current-host repetition and the aggregate `releaseStatus: UNVERIFIED` do not establish those rows. No tag, publication, push or merge was performed. `v0.1.0` remains at commit `c4f1229187c8ee430d1d77cdf17abfcae0b6589a` as the historical baseline.

This is observed **current-host test acceptance**. Independent task review and the mandatory sequential whole-branch specification/quality review are the controller's separate gates; neither is claimed approved here.

# USDC numeric-array envelope 3 acceptance

**Created:** 2026-10-25
**Updated:** 2026-10-25

The amended native policy passes the **current-host verification gate** on source candidate `0548deaf59275b6b82dcb3e15ef5ef97d58ba814`. Product **0.2.0** remains local and unpublished; safety-envelope identity is **3**, report/configuration/catalogue schema major is **1**, and profile meanings, rule IDs and occurrence identities are unchanged. Final integrated [specification](../../.build/verification/usdc-numeric-v0-2-reviews/execution-workspace/final-spec-review.md) and [quality](../../.build/verification/usdc-numeric-v0-2-reviews/execution-workspace/final-quality-review.md) reviews **PASS**, with **no findings**, on frozen reviewed commit `c0d9a4d3b816bc2f899d3f3fb5e4ea581559e531` (gate `c22d5d09-85f6-4f42-950a-95021857a596`; package SHA-256 `ac4011f583d33e606f1a523418f310f8bafe1ba4aeeab8b634b151f9aafe51db`). This subsequent documentation-only closure records those receipts with operational hashes unchanged; it authorizes no release.

The [approved amendment](../superpowers/specs/2026-10-25-usdc-opaque-numeric-arrays-v0-2.md) and [separately approved plan](../superpowers/plans/2026-10-25-usdc-opaque-numeric-arrays-v0-2.md) have the stable identical basename and known Created/Updated date 2026-10-25. The [envelope 2 acceptance record](usdc-v0-2.md) remains unchanged historical evidence. Its 327-test/26-resource-row totals establish that earlier policy only. The closed parent review at `bf1f23ad934e133ff1e5d290aad93fb182f99f11` is retained in [its completion receipt](../../.build/verification/usdc-v0-2-reviews/completion.json); its task loop was not restarted. The `v0.1.0` tag remains available.

## Observed contract

Only arrays already admitted for exact crates **0.8.0, 0.9.0 and 0.10.0** are exempt: tags **1–9 and 13–30** with `0x80`, plus tags **3–9** with `0xa0`. Zero payload reads no header. Nonzero payload must point inside value data and contain a complete **eight-byte count header**. The header is read and discarded; its numeric element count does not become an item charge, proportional work charge, allocation, loop, stride product, body-range requirement or decompression request. Counts **0, 250,000, 250,001 and UInt64.max** have equal read/work/storage requirements when only that count changes. Omitted or malformed numeric bodies establish no geometry validity or reference gap; asset-looking numeric bytes invent no references. Archive integrity reads remain charged.

Every actual edge, ValueRep visit, read, allocation and metadata decode retains its charges. Repeated/shared numeric visits remain charged across layers. String/token and asset arrays, dictionaries, wrappers, sublayers, list operations, time-sample containers and tags 56/57 are excluded; an admitted numeric leaf can be exempt inside a supported container whose own checks remain intact. A shared numeric/asset offset cannot suppress the asset site's checks or multiplicity. Unknown versions/types/flags retain gaps and later supported assets remain inspectable.

Every numerical ceiling is retained: metadata blocks **16 MiB**, cumulative decode **32 MiB**, live USDC storage **64 MiB**, nonexempt table/container items **250,000**, actual structural work **2,000,000**, depth **32**, asset bytes **4,096**, and shared occurrences **100,000**, together with all [archive/read/finding/report limits](../inspection-boundary.md#fixed-safety-envelope-v3). Native inspection remains supplied-input, read-only and package-local with bounded metadata decompression as its sole decompression exception. There is no extraction, host reference resolution, network, native subprocess, plugin, composition or geometry decoding.

The updated report schema accepts identities **1/2/3** and rejects 0/4/boolean/string identities. Strict consumers retaining the old `[1, 2]` enum reject identity 3 and need the updated schema. [Report compatibility](../report-compatibility.md) explains the unchanged schema/profile/identity meanings. Independent recipes changed the 16 affected goldens and two examples only in envelope identity; expected bytes did not come from product encoders.

## Fresh commands and results

Commands ran in `/Users/davide/Personal/Projects/usdz-validator`, directly on local branch `feat/usdc-reference-coverage-v0-2`:

```sh
make format-check
sh Scripts/verify-release.sh --evidence-dir .build/verification/usdc-numeric-v0-2-current
UVK_USDC_PRIVATE_CORPUS_MANIFEST="$PWD/.build/verification/usdc-numeric-private-inputs.json" UVK_USDC_PRIVATE_EVIDENCE_DIR="$PWD/.build/verification/usdc-numeric-private-final" swift test --filter USDCPrivateCorpusTests
```

The standalone format check and full gate exited **0**. [Machine summary](../../.build/verification/usdc-numeric-v0-2-current/summary.json): **19/19 required steps PASS**, `currentHostStatus: PASS`, `releaseStatus: UNVERIFIED`; baseline, cross-host and Python 3.12 rows remain UNVERIFIED. Installed-checker smoke is **SKIPPED**, unrequested. Exact per-step commands, environments and stdout/stderr paths are in that summary.

| Gate | Observed result / retained evidence |
| --- | --- |
| Environment, format, immutable dependency lock, debug/release builds | PASS; [environment](../../.build/verification/usdc-numeric-v0-2-current/environment.json), lock before/after identical |
| Debug / release / Address Sanitizer | **338 cases each**: 31 CLI + 305 library + 2 consumer; zero failures, **11 documented opt-in skips** each; [debug](../../.build/verification/usdc-numeric-v0-2-current/logs/test.stdout), [release](../../.build/verification/usdc-numeric-v0-2-current/logs/release-test.stdout), [ASAN](../../.build/verification/usdc-numeric-v0-2-current/logs/address-sanitizer.stdout); no compiler warning or ASAN error |
| Dedicated CLI contracts | **22 tests**, zero failures/skips; [log](../../.build/verification/usdc-numeric-v0-2-current/logs/cli-test.stdout) |
| Schema self-test and schema contracts | **10 + 10 tests**, zero failures/skips; 21 checked-in documents validate locally; [self-test](../../.build/verification/usdc-numeric-v0-2-current/logs/schema-self-test.stderr), [contracts](../../.build/verification/usdc-numeric-v0-2-current/logs/schema-tests.stderr) |
| Verification tools | **16 tests**, zero failures/skips; [log](../../.build/verification/usdc-numeric-v0-2-current/logs/verification-tools.stderr) |
| Executable examples / independent goldens | Five documented commands PASS; **81 exports + 21 checked-in = 102** schema-valid, hash/native-ID-bound documents; [examples](../../.build/verification/usdc-numeric-v0-2-current/logs/examples.stdout), [exports](../../.build/verification/usdc-numeric-v0-2-current/compatibility-manifest.json) |
| Dedicated resource tests / measured release processes | **10 tests**, zero failures/skips; **40/40 required rows** in each of two matrices (**80 complete processes**), including reporting; [test log](../../.build/verification/usdc-numeric-v0-2-current/logs/resource-tests.stdout), [standalone rows](resource-results.md) |
| Private opt-in verification against final CLI | **3 tests**, zero failures/skips; five semantic inventories and **15 complete processes**; [test log](../../.build/verification/usdc-numeric-private-final/xctest.log), [summary](../../.build/verification/usdc-numeric-private-final/summary.json) |

Ordinary full-suite skips are exactly four compile-only CLI process-hook cases (`testBinaryCheckerRemainsExplicit`, `testEncodingCapPreservesExistingOutput`, `testHookScenariosExerciseFacadeAndGate`, `testOutputDestinationAndFailurePrivacy`), the installed-checker smoke, four streamed real-size resource cases (`testMaximumEnvelopeMeasurements`, `testRealReferenceReportCapIsOperational`, `testRealSizeArchiveLayerDirectoryAndHeaderBoundaries`, `testRealSizeBinaryLayerUsesOnlyBoundedMetadataReads`), and two private-original cases (`testPrivateOriginalReleaseMeasurements`, `testPrivateOriginalSemanticInventories`). Dedicated CLI/resource/private runs above have no skips. No installed tool was required for native acceptance.

The first full attempt stopped at examples with `missing heading: inspection-boundary.md#fixed-safety-envelope-v2` after debug/release/ASAN and schema checks had passed. Renaming the current section exposed a stale link in `docs/cli.md`; the verifier recognizes Markdown headings rather than the retained HTML compatibility anchor. The only fix was that current-policy link to v3, authorized by the controller as documentation consistency. The focused five-command examples check passed, then the complete gate was repeated in a fresh directory. The failed attempt is preserved under [current-attempt-1](../../.build/verification/usdc-numeric-v0-2-current-attempt-1/summary.json); original command strings still name its initial destination. No product/verifier change or failed receipt was overwritten. No broad suite was rerun after the successful final gate.

## Inventory and oracle evidence

The genuine fixtures retain the complete semantic multisets: **71 canonical occurrences plus one supplementary occurrence**. Value bytes, member bytes, authored path/field/container coordinates and duplicate multiplicity are compared independently; reordering is accepted while wrong values/sites/counts are rejected. Dictionaries, wrappers, list buckets, samples, duplicate/shared offsets, and assets before/after numeric values remain covered by the [reference tests](../../Tests/USDZValidationTests/USDCReferenceTests.swift) and [numeric boundary tests](../../Tests/USDZValidationTests/USDCNumericArrayTests.swift).

All five fingerprinted private originals have complete requested native coverage and default `general-v1` acceptance, without an external checker. Three reports per original have identical bytes and exit 0; hashes before/after match the frozen manifest. Inventories reconcile **20 + 20 + 10 + 4 + 5 = 59**, including Fender's full **10**. The table gives per-original maxima across its three final CLI invocations:

| Original | Occurrences | Original SHA-256 | Maximum RSS bytes | Maximum elapsed s |
| --- | ---: | --- | ---: | ---: |
| Seahorse | 20 | `f079e84eba0a3a5e3133e3700ce2da17db6d2dcc061e23648cf20ac5471653cf` | 8,912,896 | 0.143273 |
| Pancakes | 20 | `45f0d144138dcd3546b4d37132b91a7b00fb2bcf187f017342f4bc5a45f087b1` | 8,880,128 | 0.150546 |
| Fender | 10 | `3e0ee48cad8f03cb807cf4747be9c4a48023384a5450efbe269d8550bcf9f61e` | 8,847,360 | 0.150639 |
| Slide | 4 | `03c7d6786f73ce39b27e59091b370af8fa22c9affc5d8a09eb53ea996fe5eff2` | 8,699,904 | 0.090580 |
| Teapot | 5 | `44bb6d1dfe0e3e890f7b8f12a177b4ae9da385bc13fcec25819fc23eaebc055c` | 8,732,672 | 0.090636 |

The ignored manifest was frozen before candidate collection from historical independent `corpus-final.json`, reconciled with `oracle-final.json` and a fresh authored-Sdf oracle. [Freeze receipt](../../.build/verification/usdc-numeric-private-freeze/freeze-receipt.json) binds the source receipt hashes, five originals, counts and omission classifications. The manifest SHA-256 is `ece946a057390ec7ea3ca077694380a4ea91f4058b7fa4d059428805a4534022`. All **256** traversal omissions (**75/82/68/14/17**) were classified as target-path coordinates with no Python SdfSpec object/field and no matching serialized spec in the independent census; the fresh authored oracle reproduced them. These are not inferred extra authored assets. An empty API result alone was not treated as an empty inventory.

The originals' frozen sites are scalar USDC default fields with empty containers; unexpected container sites fail rather than receive guessed normalization. Exact member/value bytes and semantic coordinates are retained locally, without composition or host resolution. Known genuine raw-wrapper/oracle gaps, tag 52's synthetic-only evidence, numeric PATHS provenance rather than full SdfPath semantics, disputed layouts and untested natural multigigabyte chunking remain explicit limits. Neither this oracle nor complete reference coverage proves geometry, composed scene or renderer conformance. Originals, raw authored inventories, manifests and private reports stay ignored/local; no redistribution rights are assumed and no new oracle/native dependency was added.

## Actual work, containment and process limits

The count matrix covers **408 nonzero-header variants** (34 admitted forms × 3 versions × 4 counts), plus **102 zero-payload forms**. Count-only changes retain identical read events, work and live-charge receipts. Native direct-field work is independently derived as **109 + 138N**: 14,491 fields complete at **1,999,867**, while 14,492 would require **2,000,005** and fail `usdcWork` at **1,999,906** before a 96-slot reservation. The independently encoded 16-leaf shared dictionary costs **109 + 234N**: 8,546 fields complete at **1,999,873**; 8,547 require **2,000,107** and fail at **1,999,912** before the same reservation. Two layers of 4,273 fields accumulate **1,999,982**; 4,274 per layer exceeds work. Held-owner storage returns to its 17-byte baseline and then zero; these are accounting proofs, separate from RSS.

Current debug/release/ASAN containment receipts agree: **27 genuine inputs / 72 occurrences**, separately **12 synthetic inputs / 5 occurrences**, **4,563 input read requests** (2,652 package + 1,911 scanner), **zero forbidden input ranges**, zero working bytes after scans and `sandboxInit: 0`. All six effective denial controls—read/stat/enumerate/connect/execute/write—return **1 (EPERM)**; failures are empty. Real FileSnapshot range checks are separate from post-bootstrap denial. Private inventory metrics also show zero forbidden ranges and released scanner storage. These observations establish no additional required access on those inputs; they are not a product sandbox or universal syscall audit. [Raw containment receipts and binding](../../.build/verification/usdc-numeric-v0-2-current/final-binding.json) preserve the actual counts.

All **80 resource-matrix processes** and **15 final private processes** meet **268,435,456 bytes peak RSS / 60 seconds**. Across the two current resource matrices, maximum RSS is **208,830,464 bytes** and elapsed **2.095 seconds**. The standalone 40-row matrix maxima are **208,666,624 bytes / 2.095 seconds**. Private maxima are **8,912,896 bytes / 0.150639 seconds**. Resource receipts include the full CLI/report work, actual exit, expected typed failure reason, corpus hash, command, report size and raw `/usr/bin/time -l` output. Private receipts retain original/report fingerprints, commands, exits, RSS/time and per-run raw stdout/stderr. Missing/skipped/wrong-reason/over-RSS/over-time resource rows fail the verifier. Generation, hashing and report parsing remain outside the measured CLI; each run has a process-group deadline/kill/reap path. No counter or partial measurement substitutes for process acceptance.

## Source, executable and documentation binding

The [final binding receipt](../../.build/verification/usdc-numeric-v0-2-current/final-binding.json) rechecks **202** exact operational inputs (Sources, Tests, Scripts, Tools, Package.swift, Package.resolved and formatter configuration), plus every compatibility-manifest input and all 102 document/native-ID hashes. Its canonical sorted filename→SHA-256 map has SHA-256 `ef19ca3ba538d47f59a729dea20989840e168a1c3ba2bf542901ce0a9e86ec9a`. All match the accepted candidate; dependency pins, vendored source/licenses and numerical ceilings remain unchanged.

| Bound item | SHA-256 |
| --- | --- |
| Final release CLI / standalone resource CLI / 15 final private invocations | `068c09e750dd1adf50dcd82f02f71352fa69e9c3dc8f85152c790bfca8429787` |
| Runner's earlier release-build snapshot, before release tests can relink | `20a087a0d07c8e344e6add1f64c9020f99e1b8c3c3609fe4cd4f87d72ff99309` |
| Earlier Task 3 private CLI | `20a087a0d07c8e344e6add1f64c9020f99e1b8c3c3609fe4cd4f87d72ff99309` |
| Immutable Package.resolved | `eaf09ea422bb561945aac9d7e4192f0d051d7c647e3cb1eb7ffa8d4f57b9b937` |
| Fixture manifest | `b9897e8ed608863e4395cdea669b72251fc3527500d7b38723bdb5e5540b451d` |
| Schema manifest | `22ce4f78396520ee2eea24187fe52e54a13848157608694a246da64f32611728` |
| Resource measurement generator | `f67edc2f10d3e72f000ca9469342082314d6334eb90eb589ec50c1adeabe38a4` |
| Private test/measurement harness | `dde4a9f051c169bd9fe1a024973de05296b3272ea6771523fa1d91beb259380a` |
| Fresh gate summary | `0a0dc1d1ad6c0bd66f6a8b4f74a53ad25b0c53f8197e5167961d00ba98b760a6` |
| Compatibility manifest | `d125c740d88d2386ffd01c61a936f36a8e582d11c2c37bfdcb0391dc5e2af088` |
| Standalone resource report | `7ad96e7a2ea1b0d7bbb0e2cbc98a5b58490515484245b3e4e97ae2055cecf0d5` |
| Final private summary | `bd029e51b52cd77f33704d975776561d24864fdb33b3fe3c16477f04b696ae84` |

The runner records the executable immediately after release build; release-test/resource-test builds can relink it. Final measurements therefore bind the actual executable after the whole gate. Its hash differs from Task 3's earlier private run, so only the private verification was rerun into fresh `.build/verification/usdc-numeric-private-final/`; prior private evidence remains intact. Five measurement JSON receipts retain **15 individual process rows**, with per-run reports/stdout/stderr and unchanged original fingerprints. No later release build was run.

The independent fenced recipe source hashes remain JSON `37212792d037abf0efe9503be2165bcfb503a21833e7e6e167d6ecea016779c9`, SARIF `af02d095ebac9ffa3686ec818cc054e5cca890460735278a86ca755d0ac4f4a8`, and USDC `889876273096111527c4b5e4e116653af7378000e3abe3ced1fa09e9ad8aa8c6`; current schema tests replay them against independent goldens. Synthetic recipes, genuine-writer fixtures and oracle receipts remain distinct evidence.

Current-policy Markdown, generated resource observations and the approved pair's Created/Updated metadata are documentation-only edits. They do not change or invalidate the source binding above. Original documentation commit `c0d9a4d3b816bc2f899d3f3fb5e4ea581559e531` and its ten file hashes remain recorded in the original `.build/verification/usdc-numeric-v0-2-current/documentation-binding.json` gate receipt. This subsequent two-document review/archive closure is recorded separately in `.build/verification/usdc-numeric-v0-2-current/documentation-closure-binding.json`; later documentation bytes are not represented as part of the earlier compiled-source acceptance or frozen review package.

## Criterion-to-evidence map

| Criterion | Observed evidence |
| --- | --- |
| AC-01 Exact classification | Numeric 34-form × 3-version matrix, zero/nested forms and exclusions in [tests](../../Tests/USDZValidationTests/USDCNumericArrayTests.swift); final [debug](../../.build/verification/usdc-numeric-v0-2-current/logs/test.stdout)/release/ASAN pass |
| AC-02 Bounded header | Pointer/value-region/truncated eight-byte negatives, zero-payload no-read proof; contained malformed case and measured `usdc-truncated-numeric-header` in [resource rows](resource-results.md) |
| AC-03 Ignored counts | Exact read/work/storage comparisons for four counts and admitted compressed forms; eight extreme-count [process rows](resource-results.md) |
| AC-04 Actual accounting | Repeated/shared/cross-layer and exact native exhaustion tests in [USDCResourceTests](../../Tests/USDZValidationTests/USDCResourceTests.swift) and [ResourceBoundaryTests](../../Tests/USDZValidationTests/ResourceBoundaryTests.swift); measured near/over work rows |
| AC-05 Other limits | Nonexempt/shared-offset asset counts, enclosing limits, tags 56/57, depth/metadata/reservations; complete 40-row [matrix](resource-results.md) and ten dedicated resource tests |
| AC-06 Reference inventories | [71-plus-one semantic tests](../../Tests/USDZValidationTests/USDCReferenceTests.swift), duplicate-site/shared-offset controls and asset-looking opaque bytes; current full-suite passes |
| AC-07 Five originals | Independent frozen 59-occurrence multiset, Fender 10, before/after fingerprints, complete/default accepted results; final [private summary](../../.build/verification/usdc-numeric-private-final/summary.json) |
| AC-08 Containment | Six effective EPERM controls, genuine27/72 + synthetic12/5, zero forbidden reads/released storage and real snapshot ranges; [binding receipts](../../.build/verification/usdc-numeric-v0-2-current/final-binding.json) |
| AC-09 Resource acceptance | 80 resource + 15 final private complete-process receipts within RSS/time limits, actual final executable hash above; [resources](resource-results.md), [private](../../.build/verification/usdc-numeric-private-final/summary.json) |
| AC-10 Regression/compatibility | All 19 required current-host gates, 338 debug/release/ASAN cases, historical1/2/current3 schema proof, 81 independent exports and deterministic/privacy/gate checks; [gate summary](../../.build/verification/usdc-numeric-v0-2-current/summary.json) |
| AC-11 Durable evidence/docs | Independent recipes/provenance, manifest/source/executable hashes, local-only private evidence and current policy/schema guidance; this record and [Tools provenance](../../Tools/README.md#durable-independent-golden-provenance) |

Tasks 1–4 each received specification PASS and quality Approved with no findings. Their reports/reviews and the [frozen final review package](../../.build/verification/usdc-numeric-v0-2-reviews/execution-workspace/final-review-package.md) are retained under `.build/verification/usdc-numeric-v0-2-reviews/execution-workspace/`. The final integrated specification/quality PASS receipts above cover the amendment delta plus affected original contracts at the frozen reviewed commit. This documentation-only status closure uses those archived receipts and the actual gate/private evidence; it does not change the reviewed operational state or depend on a cleaned `.superpowers` path.

## Host and unresolved limits

Observed only: **Mac17,6 / Apple M5 Max, arm64**, macOS **27.0.1 build 26A434**, Xcode **27.1 build 27A9275**, Apple Swift **6.4** (`swiftlang-6.4.0.34.1`, `clang-2100.3.34.1`), internal APFS SSD; system/schema Python **3.14.7**. [Captured environment](../../.build/verification/usdc-numeric-v0-2-current/environment.json) records the selected developer directory, storage and tools. The macOS 15 deployment declaration and test-library target strings do not establish macOS 15 execution.

macOS 15 / Xcode 16 / Swift 6.0, CPython 3.12, other qualifying hosts and true cross-host byte equality remain **UNVERIFIED/deferred**. RSS/time observations apply only to the tested corpus and recorded host, not a universal or OS-enforced bound. Installed-checker smoke was not requested in this gate. Local ignored evidence may be absent in another checkout; absence must be reported rather than treated as an independent rerun. No push, merge, tag, publication or release was performed.

# USDZ Validation Kit release summary

## 0.2.0 — 2026-10-25

Release documentation for version **0.2.0** is dated for intended publication on **2026-10-25**. [GitHub releases](https://github.com/Light2288/usdz-validator/releases) records actual publication status. The following notes describe the merged implementation and its retained acceptance evidence. Publication requires a separate maintainer action under the [release policy](../releasing.md).

### Reference coverage and safety

Native inspection automatically reads conditional authored references in a bounded subset of exact USDC crates **0.8.0, 0.9.0 and 0.10.0**, using private pinned LZ4 metadata decoding. Access remains read-only and package-local: no extraction, host reference resolution, network access, native subprocesses, resolver plugins or stage composition. Unknown or unsupported representations retain explicit coverage gaps; the [inspection boundary](../inspection-boundary.md) defines the admitted subset.

Safety envelope **3** exempts only admitted opaque numeric element counts from item/proportional work charges. Bounded count headers, charges for actual traversal, reads, allocations and metadata decoding, and every numerical ceiling remain enforced. Numeric bodies are not decoded or validated. Complete reference coverage describes the supported authored-reference policy; it establishes no geometry validity, composed-scene validity, full OpenUSD conformance or exhaustive Apple compatibility.

### Compatibility

Product version is **0.2.0**; report/configuration/catalogue schema major remains **1**, with unchanged profile meanings, rule IDs and occurrence identities. The updated report schema accepts safety-envelope identities **1/2/3**, preserving validation of historical reports. Strict consumers retaining the earlier `[1, 2]` enum reject identity 3 and must update their schema. See [report compatibility](../report-compatibility.md) and the [envelope 3 acceptance record](usdc-numeric-v0-2.md).

### Retained verification — 2026-10-25

The recorded envelope 3 gate exited 0 with **19/19 required steps PASS**. Debug, release and ASAN each recorded **338 cases**, zero failures and **11 documented opt-in skips**. Dedicated runs recorded **22 isolated CLI tests**, **10 resource tests** and **3 private-corpus tests**, all without failures or skips. These results are retained implementation evidence; this release-preparation task does not repeat that full gate.

Five private originals independently match **59 semantic authored-reference occurrences** (20/20/10/4/5, including Fender's 10), with complete requested native coverage/default acceptance. Their **15 final-CLI invocations** pass with identical repeat reports. Each of two resource matrices contains **40 required process rows**. Across those **80 complete resource invocations**, maximum RSS was **208,830,464 bytes** and elapsed **2.095 seconds**, within 256 MiB / 60 seconds. Private maxima were **8,912,896 bytes / 0.150639 seconds**. Measurements apply only to the recorded host and corpus; they are not a universal or OS-enforced resource guarantee. Private Apple assets and raw inventories remain local and are not distributed.

The [acceptance record](usdc-numeric-v0-2.md) binds source, recipes, manifests and the actual final executable, preserves the first documentation-link failure, and discloses untested cases. Retained integrated [specification](../../.build/verification/usdc-numeric-v0-2-reviews/execution-workspace/final-spec-review.md) and [quality](../../.build/verification/usdc-numeric-v0-2-reviews/execution-workspace/final-quality-review.md) reviews PASS with no findings on frozen reviewed commit `c0d9a4d3b816bc2f899d3f3fb5e4ea581559e531`. Their identity remains bound to that implementation state; the subsequent bookkeeping closure recorded those receipts with operational hashes unchanged.

### Current support and remaining verification

Verified/supported: **macOS 27.0.1 build 26A434 / Xcode 27.1 build 27A9275 / Swift 6.4 (`swiftlang-6.4.0.34.1`), arm64**; schema tooling was verified with **CPython 3.14.7**. Machine status remains `currentHostStatus: PASS`, `releaseStatus: UNVERIFIED`. macOS 15 / Xcode 16.0 / Swift 6.0, CPython 3.12, other hosts and true cross-host equality remain **UNVERIFIED/deferred**, not current-host acceptance blockers under the existing policy. Installed-checker smoke remains **unrequested/SKIPPED**; native acceptance did not require an installed USD tool.

### Documentation verification — 2026-10-25

Release preparation updated the current notes and unreleased changelog, alongside the approved specification and plan. Focused checks passed: **10 schema self-tests**, **10 schema-contract tests** (21 checked-in documents validated), **16 verification-tool tests**, **five documented native commands**, local links, Markdown structure, historical-byte preservation and whitespace. [Local focused receipts](../../.build/verification/v0-2-release-preparation-2026-10-25/) record commands, outcomes and retained source/executable identity checks. Neither release document is manifest-bound; no compatibility exports or full release gate were regenerated. Earlier measurements, acceptance receipts and implementation-review identities remain unchanged. Local ignored evidence may be absent in another checkout; its absence is not a passing verification result.

The [2026-10-24 envelope 2 acceptance record](usdc-v0-2.md) remains historical: its resolver-accounting gate had 19/19 required gates PASS, 327 cases each in debug/release/ASAN, 22 isolated CLI cases, nine real-size tests and 26 measured release invocations. Its peak RSS was 208,683,008 bytes and longest invocation 2.092 seconds in `.build/verification/usdc-v0-2-accounting/`. Earlier and interrupted receipts remain preserved. The approved envelope 3 amendment retains its clip-template failure classification and conservative resolver-scratch accounting.

The `v0.1.0` tag remains available. The following v0.1 account is preserved as historical evidence; its counts, hashes, checker results and coverage conclusions describe that product and those runs. Current [resource results](resource-results.md) are generated anew; original reports remain in each named historical evidence directory.

## Historical 0.1.0 release summary

**Historical release documentation prepared on 2026-10-22.** The maintainer reviewed and approved the documentation on 2026-10-22 under the approved current-host verification policy. The final release-candidate command exited 0 with **20/20 gates PASS**: 19 required current-host gates and the requested installed-checker smoke. No product behavior changed in this follow-up.

## What v0.1 provides

A reusable Swift library and thin one-file CLI inspect bounded USDZ containers, supported lexical USDA references and configurable file/texture budgets. Text, versioned JSON and SARIF reports preserve stable finding codes, deterministic native ordering, separate coverage and gate decisions, and optional installed-checker provenance. Validation runs locally without a backend or cloud service.

The historical v0.1 [five local Apple asset tests](apple-assets.md) exercised real binary-USDC packages. That native inspection found no errors or budget warnings while retaining a binary-reference coverage gap; current envelope 3 results are recorded separately in [the amendment acceptance record](usdc-numeric-v0-2.md). Apple USD Tools (0.25.11) reported no failure on four originals and a material-subset failure on Fender. A read-only check confirmed 977 uncovered faces in Fender's declared material partition. All three deliberately damaged Slide copies returned exit 1 for their intended archive/checksum/path errors, including with `--allow-incomplete`. Apple models, derived copies and raw private diagnostics are not distributed.

The committed 469-byte USDA fixture has no visible geometry. It exercises the native inspection contract and is not a preview model or full-scene conformance oracle.

## Fresh release verification — 2026-10-21

```sh
sh Scripts/verify-release.sh --installed-checker-smoke --evidence-dir .build/verification/release-candidate
```

| Gate group | Observed result |
| --- | --- |
| Environment, formatting, dependency resolution/immutable lock, debug/release builds | PASS |
| Debug, release and Address Sanitizer suites | Each: 237 cases, zero failures, seven documented optional skips |
| Dedicated CLI contracts | 20 tests, zero failures/skips |
| Schema self-test, schema contracts and verification tools | Nine tests each, zero failures/skips |
| Executable examples and fixed golden reports | Five commands; one golden test; 73 exports + 13 reviewed documents validated and manifest-bound |
| Dedicated real-size resource suite | Eight tests, zero failures/skips |
| Independent release resource measurements | Nine cases PASS; peak **208,683,008 bytes RSS**, longest **1.777 seconds**, within 256 MiB / 60 seconds |
| Requested installed-checker smoke | One test, zero failures/skips; tool version and completed outcome recorded |

Ordinary suites deliberately skip opt-in process-hook, real-size resource and installed-tool paths; dedicated gates above ran those paths. The installed smoke test checks adapter completion, not fixture conformance: its tiny fixture produced `outcome=failureReported`. The separate Apple asset runs demonstrate both external success and failure. In that historical v0.1 run, native USDC reference coverage remained incomplete after an external success.

Machine statuses are **`currentHostStatus: PASS`**, **`matrix.current: PASS`**, **`installedCheckerSmoke.status: PASS`**, and **`releaseStatus: UNVERIFIED`**. The last value describes the broader deferred platform matrix; it is not a failed current-host gate or an asset validation status. It is retained unchanged under the approved verification amendment.

See the [release matrix](release-matrix.md) for command-level evidence and [resource results](resource-results.md) for exact measured cases. Local logs, environment capture, exports, manifest and immutable lock snapshot are in `.build/verification/release-candidate/`. Summary SHA-256: `58fa427340c1da4fa0d7b9aaf463c68277a3b5e295801a9d62531f53dc116e59`; compatibility-manifest SHA-256: `cbc9e674636356d0461234e97a558717e9901eb482cd3bea2a7c1dd85345f217`. The final measured executable SHA-256 is `f54fc70f44c3f9d5cfef7c3a8cddca34123e439c43799965ed82cae9698f7ffe`; the matrix separately records the runner's earlier pre-test relink snapshot.

After finalizing the documentation, the five executable examples and local documentation links were checked again. All nine changed/new Markdown documents have valid local links; whitespace checks pass. Comparing the new compatibility exports with the preserved `final-fix` run also passed for all 86 documents. This is repeated-run evidence on the same host, not a cross-host compatibility claim.

## Support and remaining limits

Verified/supported: **macOS 27.0.1 build 26A434 / Xcode 27.1 build 27A9275 / Swift 6.4 (`swiftlang-6.4.0.34.1`), arm64**. Hash-locked schema tooling is verified with **CPython 3.14.7**. macOS 15 / Xcode 16.0 / Swift 6.0, CPython 3.12 and true cross-host byte comparison remain **UNVERIFIED and deferred**. Deployment declarations do not establish minimum-target or future compatibility.

Exit 0 means the configured gate accepted the observed result; `--allow-incomplete` retains incomplete coverage. There is no full OpenUSD, renderer or exhaustive Apple compatibility guarantee, conversion, repair, editing, rendering, UI, backend or cloud service. The optional checker supports only the pinned installed version and is an explicit trusted-input exception with no external filesystem/network/RSS sandbox. The [security](../../SECURITY.md) and [inspection](../inspection-boundary.md) boundaries remain unchanged.

## Review state

Implementation branch: `feat/usdz-validation-kit-v0-1`. Reviewed product commit: `5729bad6b6832934751c179696248bea969c4ba9`, with 38 conventional commits. The original `main` was unborn and the remote empty; implementation was bootstrapped with `git switch --orphan feat/usdz-validation-kit-v0-1` before the approved documents and implementation were committed. No base/main history was invented, and no worktree was created.

All AC-01 through AC-30 and final product specification/quality reviews were previously recorded as PASS on that exact product commit. The verification follow-up changed Markdown documentation and generated resource observations only; source, tests, scripts, schemas, dependency lock, specification and plan are unchanged. The maintainer approved the documentation on 2026-10-22; implementation and verification documentation were subsequently merged into `main` in [PR #1](https://github.com/Light2288/usdz-validator/pull/1), merge commit `c6e98baaaa8524f669a6807eb5bb3340bb92ed33`. This release-preparation change dates the changelog and updates status wording only. Those historical publication actions were outside the verification run; the `v0.1.0` tag is now retained as the baseline.

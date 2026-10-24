# Manual release verification matrix

## Current v0.2 evidence

**2026-10-24 current-host test acceptance PASS:** the fresh `usdc-v0-2-final` run exited 0 with 19/19 required gates. Each debug/release/ASAN suite passed 326 cases with nine expected opt-in skips; dedicated CLI 22 and real-size resource nine tests had no skips. All 26 standalone resource rows passed (maximum 208,683,008 bytes RSS / 1.808 seconds); 81 exports plus 21 reviewed files bind 155 final inputs. The [v0.2 acceptance record](usdc-v0-2.md) records exact hashes, environment and source/dependency bindings. Final branch review remains separate. Current-host verification does not promote macOS 15 / Xcode 16 / Swift 6.0, cross-host byte equality or CPython 3.12: all remain **UNVERIFIED**. Installed-checker smoke is not part of the v0.2 native gate unless explicitly requested. The `v0.1.0` tag remains available.

## Historical v0.1 evidence

The observations below retain their original v0.1 counts, hashes and conditional coverage conclusions. Use the named preserved evidence copies for historical resource results; the current `resource-results.md` is refreshed by the latest release runner.

**User-approved verification-policy amendment — 2026-10-21:** Required current-environment v0.1 verification is **PASS**. The latest release-candidate run passed all 19 required gates plus the requested installed-checker smoke, **20/20 gates** in total; see the fresh evidence below and the [release summary](release-summary.md). Verified/supported scope is only macOS 27.0.1 build 26A434 / Xcode 27.1 build 27A9275 / Swift 6.4 (`swiftlang-6.4.0.34.1`) on arm64, with CPython 3.14.7 schema tooling. macOS 15+ / Xcode 16.0 / Swift 6.0 arm64 and CPython 3.12 remain intended, unverified targets, without automatic minimum/future support. Their absent rows and genuine cross-host comparison are deferred follow-up, not v0.1 acceptance blockers. A successful current-host run does not verify the minimum baseline. Publication remains for the maintainer after documentation review; no tag, publication, push or merge was performed by this verification.

| Evidence scope | Designated combination | Status | Observed evidence |
| --- | --- | --- | --- |
| Required current host (AC-02) | macOS 27.0.1 build 26A434, Xcode 27.1 build 27A9275, Swift 6.4 swiftlang-6.4.0.34.1, arm64 | PASS | 2026-10-21: release-candidate command below exited 0; all 19 required gates and requested smoke passed. |
| Deferred intended minimum host | macOS 15, Xcode 16.0, Swift 6.0, arm64 | UNVERIFIED | Host unavailable; no build or test result observed. |
| Deferred cross-host canonical bytes/native IDs (AC-22) | Same fixture/configuration/validator manifests and fixed external results | UNVERIFIED | No baseline exports; comparison has not run on two hosts. |
| Deferred intended schema-tool target | CPython 3.12, macOS arm64, committed hash lock | UNVERIFIED | Interpreter unavailable; CPython 3.14.7 cannot establish this row. |
| Required schema tooling | CPython 3.14.7, macOS arm64, committed hash lock | PASS | Original current-host schema self-test and contract tests passed with this interpreter; no CPython 3.12 execution is claimed. |
| Native resources (AC-15) | Documented current arm64 internal-SSD host, release binary | PASS | Eight resource tests with real-size opt-in and no skips; nine fresh independent release measurements, maximum RSS 208,683,008 bytes and maximum elapsed 1.777 seconds. |
| Installed checker smoke | Explicit opt-in; Apple USD Tools (0.25.11) | PASS | Release-candidate run: one test, zero failures/skips; adapter completed. The tiny fixture's checker outcome was `failureReported`; the test asserts completion, not fixture conformance. [Five separate local asset tests](apple-assets.md) cover both outcomes. |

Follow [the exact procedure](../releasing.md) on the verified host, and on a second qualifying host when available for deferred follow-up. Preserve `summary.json`, environment capture, stdout/stderr logs, original dependency lock, compatibility manifest, all 73 exports and 13 reviewed documents, and resource results. Record the actual `DEVELOPER_DIR`, OS/build, Xcode/build, Swift target, formatter, Python, hardware and storage; an unpinned “latest” row is not evidence. Current-host formatter lint remains authoritative; the baseline builds/tests without rewriting formatting. Resource acceptance is tied to [the measured internal-SSD host](resource-results.md).

The unchanged runner reports `currentHostStatus: PASS` for required current-environment v0.1 verification. Its `releaseStatus: UNVERIFIED` remains the honest aggregate of the broader optional matrix while baseline, exact two-host comparison and Python 3.12 evidence are absent. These statuses have separate meanings: deferred absent rows do not block v0.1 acceptance; a failed required current-host gate still does. A row may become PASS only from its observed command result. Missing evidence stays UNVERIFIED and optional unrequested smoke stays SKIPPED. Current-host repeated-run, relocation, fixed-adapter-result and independent-golden proof satisfies amended AC-22; self-comparison cannot prove cross-host equality.


## Observed current-host evidence — 2026-10-21

The following original full-run observations and hashes preceded the policy amendment and remain preserved verbatim. They describe that run, including its original manifest-bound document bytes; a focused provenance refresh, if any, is recorded separately.

Command: `make release-verify` (exit 0), delegating exactly to `sh Scripts/verify-release.sh --evidence-dir .build/verification/current`. Final machine-readable status: `currentHostStatus: PASS`, `releaseStatus: UNVERIFIED`; baseline, cross-host and Python 3.12 rows are all UNVERIFIED; installed smoke is SKIPPED (not requested).

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, selected from `xcode-select -p`; no inherited override was set.
- macOS 27.0.1, build 26A434; Xcode 27.1, build 27A9275.
- Apple Swift 6.4 (`swiftlang-6.4.0.34.1`, `clang-2100.3.34.1`), target `arm64-apple-macosx27.0.0`; architecture `arm64`.
- `xcrun swift-format --version`: `main` (recorded verbatim from the designated Xcode).
- Python and schema venv: CPython 3.14.7; Python 3.12 unavailable.
- Hardware: Mac17,6, Apple M5 Max, 38,654,705,664 bytes physical memory. Resource evidence records internal solid-state Apple Fabric storage on `/System/Volumes/Data`.

| Observed local gate | Result |
| --- | --- |
| Formatter lint, dependency resolution/immutable lock, debug and release builds | PASS |
| `swift test`, `swift test -c release`, `swift test --sanitize=address` | Each: 234 XCTest cases, zero failures; seven explicitly logged optional skips (three isolated-hook process cases, three real-size resource cases, one installed smoke). Dedicated gates below cover hook/resource skips. |
| `sh Scripts/test-cli.sh` | 20 tests, zero failures/skips; isolated compile-only hooks and release executable. |
| Schema self-test and separate schema contract tests | Nine tests each, zero failures/skips; 13 reviewed documents valid offline. |
| Verifier-tool tests | Nine tests, zero failures/skips; all five release-hook values have identical exit/stdout/stderr. |
| Documented executable examples | Five commands pass with exact expected bytes/defaults/profile IDs. |
| Golden export/schema/manifest | One compatibility test; 73 actual exports plus 13 reviewed documents; 86 documents bound to 75 input hashes, four effective configurations and validator 0.1.0. |
| Real-size resources and independent measurements | Eight tests, zero failures/skips; all nine measured cases PASS. See [resource-results.md](resource-results.md) for exact corpus hashes, commands, output sizes and measurements. |

Retained local evidence is in `.build/verification/current/summary.json`, `environment.json`, separate `logs/*.stdout` / `logs/*.stderr`, `compatibility-manifest.json`, `exports/`, `checked-in/`, `Package.resolved.before`, and `resource-results.md`. Summary SHA-256: `390a6f95200772cc8dd25aad0a01edd36efb9001d6b938bebc28cb4a3354b2d7`; compatibility manifest SHA-256: `16be78c78300cadd80803984372368568107ba520700f278c0202b21e2f028a9`; unchanged `Package.resolved` SHA-256: `eaf09ea422bb561945aac9d7e4192f0d051d7c647e3cb1eb7ffa8d4f57b9b937`.

`python3 Scripts/compare-compatibility.py .build/verification/current .build/verification/current` exited 0 and checked the 86-document manifest and bytes against themselves. This is a local integrity check; no baseline or cross-host comparison was performed. Earlier failed attempts remain separately preserved: `attempt-1-host-tabs` (host-version whitespace parser, corrected with a regression) and `attempt-2-asan-symbolizer` (test child omitted PATH and ASAN emitted a symbolizer warning; fixed using controlled PATH/LANG/LC_ALL and exact five-scenario comparisons, with the ASAN child retained).


## Focused amendment provenance refresh — 2026-10-21

After the approved documentation-only policy amendment, fresh evidence was created in `.build/verification/amended`: genuine `UVK_COMPAT_EXPORT_DIR="$PWD/.build/verification/amended/exports" swift test --filter GoldenCompatibilityTests` (one test, zero failures/skips), schema validation of 73 exports plus 13 reviewed documents, and the unchanged compatibility tool's `write_manifest` procedure. Schema self-test, separate schema-contract tests and verification-tool tests each ran nine tests with zero failures/skips. All commands exited 0; logs and exact command arguments are retained in `.superpowers/sdd/2026-10-20-usdz-validation-kit/amendment-logs/` and `amendment-command-results.json` alongside it.

Fresh compatibility-manifest SHA-256: `bd05bb146c2643d21a8beb5feb4d34c57d57424fa669d0ba1a1bd1ba4aeeff80`. This manifest binds the amended `Tools/README.md` and its refreshed inventory hash. The 86 document bytes/native IDs, configurations and validator versions match the original current-host corpus; the only changed input bindings are `Tools/README.md` and `Tests/Schemas/manifest.json`. Self-comparison of the fresh directory exited 0 as a local integrity check only. No second host, minimum-target or CPython 3.12 result is established.

This focused refresh is not a full release run and has no copied or fabricated `summary.json`. Original 19/19 current-host release evidence above remains preserved for unchanged product/test/script bytes. Broad Swift suites were not rerun for this documentation-only amendment. Final Task 27 review remains separate.


## Final I1 parser fix full-run evidence — 2026-10-21

This distinct full run verifies the product after the classic EOCD framing fix. Command: `sh Scripts/verify-release.sh --evidence-dir .build/verification/final-fix` (exit 0). The new directory preserves genuine environment capture, all per-step stdout/stderr, `summary.json`, immutable dependency-lock snapshot, 73 exports, 13 reviewed documents, compatibility manifest and resource measurements. Original `current` and focused `amended` evidence above remain preserved.

All **19/19 required current-host gates PASS**: environment, format-check, resolve, resolved-lock, build, test, cli-test, release-build, release-test, address-sanitizer, schema-self-test, schema-tests, verification-tools, examples, golden-export, export-schemas, export-manifest, resource-tests and resource-measurements. Every gate exited 0.

The observed host remains macOS 27.0.1 build 26A434 / Xcode 27.1 build 27A9275 / Swift 6.4 (`swiftlang-6.4.0.34.1`, target `arm64-apple-macosx27.0.0`) / arm64, with CPython 3.14.7, formatter `main`, `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (no inherited override), Mac17,6 Apple M5 Max, 38,654,705,664 bytes memory and internal Apple Fabric SSD. Validator version: **0.1.0**; safety envelope version: **1**. Relevant unchanged limits: archive 512 MiB, entry 256 MiB, directory 16 MiB, 10,000 entries, 64 KiB read chunks and 1,152 MiB cumulative native reads. Resource acceptance remains <=268,435,456 bytes RSS and <=60 seconds per measured native invocation.

| Fresh observed check | Result |
| --- | --- |
| Debug, release and Address Sanitizer full suites | Each: 237 XCTest cases, zero failures, seven explicit optional skips. Dedicated CLI/resource gates cover their optional cases; installed smoke remains unrequested. |
| CLI contracts | 20 tests, zero failures/skips. |
| Schema self-test, schema contracts, verification tools | Nine tests each, zero failures/skips; 13 reviewed documents validated offline. |
| Examples and golden corpus | Five documented native commands; one golden compatibility test; 73 exports + 13 reviewed documents = 86 bound documents, 75 input hashes, four configurations, validator 0.1.0. All PASS. |
| Real-size resource tests | Eight tests, zero failures/skips. |
| Independent release resource measurements | Nine cases PASS; maximum RSS 208,715,776 bytes; maximum elapsed 1.762 seconds. Exact corpus hashes, commands, exits and output sizes are in [resource-results.md](resource-results.md) and its preserved evidence copy. |
| Supported 412-byte payload-marker reproduction | Final measured release executable returns exit 0, complete requested native coverage, zero native findings and empty stderr. |

Evidence SHA-256:

- `summary.json`: `770dce27af560dc534a17de0b0db595fcbf27bf0348ca446ef21cfbc128afdbd`.
- `compatibility-manifest.json`: `cbc9e674636356d0461234e97a558717e9901eb482cd3bea2a7c1dd85345f217`.
- `resource-results.md`: `bd64248b644d8df5bc5ce918f212e268028f96c280221e79144293c32b9aa85b`.
- Unchanged `Package.resolved`: `eaf09ea422bb561945aac9d7e4192f0d051d7c647e3cb1eb7ffa8d4f57b9b937`.
- Updated fixture provenance manifest: `526e1bfa89bf2008605fbc4729b98243ce69a292a1dca0da05b4f61648082f8e`; every original fixture ID, metadata field, byte content and generator hash is preserved, with only nested in-test regression provenance added.
- Parser source: `bceca98cebb57654486f4605ed82472951f97ed04bee2beafc8ccbdf3812a30d`.

The runner captures release executable SHA-256 `30c1b8d069495c3940cffdaefaaf1cd4792d156fc7d88f20d6ed70d1c7faaea4` before the later `swift test -c release` build. That build relinks the same executable path (see `logs/release-test.stderr`); the final measured executable SHA-256 is `f54fc70f44c3f9d5cfef7c3a8cddca34123e439c43799965ed82cae9698f7ffe`, also independently confirmed against the current file and the supported 412-byte reproduction. Both observed hashes remain preserved without rewriting the runner summary.

Final machine statuses: `currentHostStatus: PASS`, `releaseStatus: UNVERIFIED`, `matrix.current: PASS`; baseline, crossHost and python312 stay `UNVERIFIED`; installed checker smoke stays `SKIPPED` because it was not requested. These observations apply the existing amended policy and do not establish deferred environments or final Task 27 acceptance.


## Release-candidate verification with installed checker — 2026-10-21

Command (exit **0**):

```sh
sh Scripts/verify-release.sh --installed-checker-smoke --evidence-dir .build/verification/release-candidate
```

All **20/20 gates PASS**: the 19 required current-host gates plus the explicitly requested installed-checker smoke. The runner's genuine `summary.json` records `currentHostStatus: PASS`, `matrix.current: PASS`, and `installedCheckerSmoke.status: PASS`. `releaseStatus: UNVERIFIED` and the baseline, crossHost and python312 rows remain unchanged and honest; no deferred environment was tested.

The environment was captured again: macOS 27.0.1 build 26A434 / Xcode 27.1 build 27A9275 / Swift 6.4 (`swiftlang-6.4.0.34.1`, target `arm64-apple-macosx27.0.0`) / arm64; CPython 3.14.7 for runner and hash-locked schema venv; formatter `main`; `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, no inherited override; Mac17,6 Apple M5 Max, 38,654,705,664 bytes memory, internal APFS/Apple Fabric SSD.

| Fresh observed check | Result |
| --- | --- |
| Format, dependency resolution and immutable lock, debug/release builds | PASS; lock unchanged. |
| Debug, release and Address Sanitizer full suites | Each: 237 cases, zero failures, seven explicit optional skips. Dedicated CLI/resource/smoke gates exercise those opt-in paths. |
| Isolated CLI process contracts | 20 tests, zero failures/skips. |
| Schema self-test, schema contracts, verifier-tool tests | Nine tests each, zero failures/skips. |
| Examples and golden exports | Five commands; one compatibility test; 73 exports plus 13 reviewed documents, 86 documents bound to 75 inputs and four configurations. PASS. |
| Real-size resources | Eight tests, zero failures/skips. Nine independent measured native cases PASS; maximum RSS **208,683,008 bytes**, maximum elapsed **1.777 seconds**, within 268,435,456 bytes / 60 seconds. |
| Installed checker smoke | One test, zero failures/skips; Apple USD Tools (0.25.11), `status=completed`, `outcome=failureReported` for the tiny fixture. This verifies adapter completion, not asset acceptance. |
| Supplemental manual assets | [Five Apple originals and three damaged copies](apple-assets.md); separate checker successes and a material-subset failure confirmed from authored data. These private samples are not ordinary-suite prerequisites or redistributed fixtures. |

Evidence remains in `.build/verification/release-candidate/`: environment, full command/status records, separate stdout/stderr logs, immutable lock snapshot, exports, reviewed documents, compatibility manifest, copied resource measurements and an index of private local-asset evidence. Old `current`, `amended` and `final-fix` runs remain intact. No summary was copied, fabricated or relabeled from an earlier run.

| Evidence file | SHA-256 |
| --- | --- |
| `summary.json` | `58fa427340c1da4fa0d7b9aaf463c68277a3b5e295801a9d62531f53dc116e59` |
| `compatibility-manifest.json` | `cbc9e674636356d0461234e97a558717e9901eb482cd3bea2a7c1dd85345f217` |
| `resource-results.md` | `eb00c18cf71b1450f25f305ab6feb7d9bb4ee12b17f4f6a81a37d0f31707c58a` |
| Unchanged `Package.resolved` | `eaf09ea422bb561945aac9d7e4192f0d051d7c647e3cb1eb7ffa8d4f57b9b937` |
| Final measured release executable | `f54fc70f44c3f9d5cfef7c3a8cddca34123e439c43799965ed82cae9698f7ffe` |

The runner's pre-release-test executable snapshot is `30c1b8d069495c3940cffdaefaaf1cd4792d156fc7d88f20d6ed70d1c7faaea4`. As in the earlier run, `swift test -c release` subsequently relinks the executable; the resource report binds the final measured hash above. The original runner summary is preserved unchanged. Source, tests, schemas and dependency lock are unchanged from product commit `5729bad6b6832934751c179696248bea969c4ba9`; this follow-up updates documentation and measured resource observations only. The earlier final product specification/quality reviews remain historical evidence for that commit. At the end of this verification run, documentation awaited maintainer review and no commit, tag, push, merge or publication had been performed. The maintainer subsequently approved the documentation and authorized its commit on 2026-10-22; publication remains separate.

Focused checks after the documentation update: the five executable examples pass again, all nine changed/new Markdown files have valid local links and heading fragments, and `git diff --check` passes. `python3 Scripts/compare-compatibility.py .build/verification/final-fix .build/verification/release-candidate` exited 0 with 86 exact matching documents. This compares two preserved runs on the same host; it does not establish the deferred cross-host row. The extra check logs and final documentation hashes are retained beside the genuine release-run evidence, separately from its unchanged 20-step summary.

# Manual release verification matrix

Release/support acceptance: **UNVERIFIED**. A successful current-host run does not verify the minimum baseline. This document records observations only; no tag, publication, push or merge is authorized.

| Required evidence | Designated combination | Status | Observed evidence |
| --- | --- | --- | --- |
| Current host | macOS 27.0.1, Xcode 27.1, Swift 6.4, arm64 | PASS | 2026-10-21: exact `make release-verify` exit 0; all 19 local required gates passed. |
| Minimum host (AC-02) | macOS 15, Xcode 16.0, Swift 6.0, arm64 | UNVERIFIED | Host unavailable; no build or test result observed. |
| Cross-host canonical bytes/native IDs (AC-22) | Same fixture/configuration/validator manifests and fixed external results | UNVERIFIED | No baseline exports; comparison has not run on two hosts. |
| Schema-tool baseline | CPython 3.12, macOS arm64, committed hash lock | UNVERIFIED | Interpreter unavailable; CPython 3.14.7 cannot establish this row. |
| Native resources (AC-15) | Documented current arm64 internal-SSD host, release binary | PASS | Eight resource tests with real-size opt-in and no skips; nine independent release measurements, maximum RSS 208,732,160 bytes and maximum elapsed 1.815 seconds. |
| Installed checker smoke | Explicit opt-in; Apple USD Tools (0.25.11) | SKIPPED | Not requested. Fixed fake checker tests remain required. |

Follow [the exact procedure](../releasing.md) on both hosts. Preserve `summary.json`, environment capture, stdout/stderr logs, original dependency lock, compatibility manifest, all 73 exports and 13 reviewed documents, and resource results. Record the actual `DEVELOPER_DIR`, OS/build, Xcode/build, Swift target, formatter, Python, hardware and storage; an unpinned “latest” row is not evidence. Current-host formatter lint remains authoritative; the baseline builds/tests without rewriting formatting. Resource acceptance is tied to [the measured internal-SSD host](resource-results.md).

The runner deliberately retains `releaseStatus: UNVERIFIED` until a human assembles both host results, a successful exact comparison and Python 3.12 evidence here. A row may become PASS only from its observed command result. Missing evidence stays UNVERIFIED, an optional unrequested smoke stays SKIPPED, and any failed required gate prevents release acceptance.


## Observed current-host evidence — 2026-10-21

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

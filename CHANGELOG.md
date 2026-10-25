# Changelog

## 0.2.0 — 2026-10-25

- Automatic native authored-reference inspection for a bounded subset of exact USDC crate versions **0.8.0, 0.9.0 and 0.10.0**, using private pinned LZ4 metadata decoding. Native inspection remains read-only and package-local, without extraction, host reference resolution, network access, subprocesses or stage composition.
- Safety envelope **3** exempts admitted opaque numeric element counts from item/proportional work charges. Bounded count headers, actual traversal charges and every numerical ceiling remain enforced; numeric bodies and geometry validity are not inspected.
- Report/configuration/catalogue schema major remains **1**. The updated report schema accepts safety envelopes **1/2/3**; strict consumers using the earlier `[1, 2]` enum must update their schema to accept envelope 3.
- Retained current-host verification records **19/19 required gates PASS**, **338 cases each** in debug/release/ASAN with zero failures and 11 documented opt-in skips, and five private originals with **59 independently reconciled authored-reference occurrences**, complete requested native coverage and default acceptance. Dedicated CLI/resource/private runs have no skips. These are recorded results for the tested host and corpus; complete reference coverage does not establish full OpenUSD or geometry conformance.

Release documentation is dated for intended publication on **2026-10-25**; see [GitHub releases](https://github.com/Light2288/usdz-validator/releases) for actual publication status. `currentHostStatus: PASS` and `releaseStatus: UNVERIFIED` retain their distinct meanings; baseline macOS, other hosts, CPython 3.12 and cross-host equality remain unverified/deferred under the existing policy. See the [release notes](docs/verification/release-summary.md#020--2026-10-25), [envelope 3 acceptance record](docs/verification/usdc-numeric-v0-2.md) and [support policy](docs/releasing.md). The `v0.1.0` tag remains available as the historical baseline.

## 0.1.0 — 2026-10-22

- Local macOS arm64 Swift library `USDZValidation` and one-file `usdz-validator` CLI.
- Bounded stored-ZIP, lexical USDA package-reference and encoded-byte/texture-header checks, with explicit coverage gaps and fixed safety ceilings.
- Default `general-v1` and warning-only `apple-portable-v1` profiles, strict warning-budget configuration, separate status/gate decisions and documented exits.
- Deterministic report/catalogue/config schema v1 and SARIF 2.1.0, stable rule/occurrence identities, privacy defaults and atomic report-file replacement.
- Explicit trusted-input adapter for the fixed installed checker version, separate from native coverage.
- Original MIT fixtures, independent golden contracts, adversarial/sanitizer checks and recorded arm64 resource measurements.

User-approved policy amendment, 2026-10-21: verified/supported v0.1 combination is macOS 27.0.1 build 26A434 / Xcode 27.1 build 27A9275 / Swift 6.4 (`swiftlang-6.4.0.34.1`) on arm64; schema tooling is verified with CPython 3.14.7. macOS 15+ / Xcode 16.0 / Swift 6.0 arm64 and CPython 3.12 are intended, unverified targets. Baseline and cross-host byte verification and Python 3.12 checks are deferred follow-up, not v0.1 acceptance blockers; no automatic minimum/future support or cross-host equality is claimed. Current-host required failures still block acceptance. The installed-checker smoke completed with Apple USD Tools (0.25.11); local Apple asset tests cover external success, external failure and preserved native USDC coverage gaps. See the [release summary](docs/verification/release-summary.md), [scope and verification evidence](README.md#verification-and-support-scope), [CLI contracts](docs/cli.md), and [security boundary](SECURITY.md). No release publication is implied by this entry.

# Changelog

## 0.1.0 — unreleased

- Local macOS arm64 Swift library `USDZValidation` and one-file `usdz-validator` CLI.
- Bounded stored-ZIP, lexical USDA package-reference and encoded-byte/texture-header checks, with explicit coverage gaps and fixed safety ceilings.
- Default `general-v1` and warning-only `apple-portable-v1` profiles, strict warning-budget configuration, separate status/gate decisions and documented exits.
- Deterministic report/catalogue/config schema v1 and SARIF 2.1.0, stable rule/occurrence identities, privacy defaults and atomic report-file replacement.
- Explicit trusted-input adapter for the fixed installed checker version, separate from native coverage.
- Original MIT fixtures, independent golden contracts, adversarial/sanitizer checks and recorded arm64 resource measurements.

User-approved policy amendment, 2026-10-21: verified/supported v0.1 combination is macOS 27.0.1 build 26A434 / Xcode 27.1 build 27A9275 / Swift 6.4 (`swiftlang-6.4.0.34.1`) on arm64; schema tooling is verified with CPython 3.14.7. macOS 15+ / Xcode 16.0 / Swift 6.0 arm64 and CPython 3.12 are intended, unverified targets. Baseline and cross-host byte verification and Python 3.12 checks are deferred follow-up, not v0.1 acceptance blockers; no automatic minimum/future support or cross-host equality is claimed. Current-host required failures still block acceptance. The installed-checker smoke completed with Apple USD Tools (0.25.11); local Apple asset tests cover external success, external failure and preserved native USDC coverage gaps. See the [release summary](docs/verification/release-summary.md), [scope and verification evidence](README.md#verification-and-support-scope), [CLI contracts](docs/cli.md), and [security boundary](SECURITY.md). No release publication is implied by this entry.

# Changelog

## 0.1.0 — unreleased

- Local macOS arm64 Swift library `USDZValidation` and one-file `usdz-validator` CLI.
- Bounded stored-ZIP, lexical USDA package-reference and encoded-byte/texture-header checks, with explicit coverage gaps and fixed safety ceilings.
- Default `general-v1` and warning-only `apple-portable-v1` profiles, strict warning-budget configuration, separate status/gate decisions and documented exits.
- Deterministic report/catalogue/config schema v1 and SARIF 2.1.0, stable rule/occurrence identities, privacy defaults and atomic report-file replacement.
- Explicit trusted-input adapter for the fixed installed checker version, separate from native coverage.
- Original MIT fixtures, independent golden contracts, adversarial/sanitizer checks and recorded arm64 resource measurements.

Minimum product baseline: macOS 15 / Xcode 16.0 / Swift 6.0; observed verification: macOS 27.0.1 / Xcode 27.1 / Swift 6.4. Baseline and cross-host byte verification, CPython 3.12 development-tool verification, and the opt-in installed-checker smoke remain unobserved. See [scope and verification evidence](README.md#verification-and-support-scope), [CLI contracts](docs/cli.md), and [security boundary](SECURITY.md). No release publication is implied by this entry.

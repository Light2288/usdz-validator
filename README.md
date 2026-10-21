# USDZ Validation Kit

A local Swift library and CLI for repeatable USDZ packaging, package-local reference, and delivery-budget checks. Native inspection runs without USD tools, extraction, or network access. Reports distinguish observed defects from incomplete checks; exit `0` means the configured gate accepted the result, not full USD, Apple-platform, or asset-security certification.

## Build and run

Verified/supported v0.1 combination: macOS 27.0.1 build 26A434 / Xcode 27.1 build 27A9275 / Swift 6.4 (`swiftlang-6.4.0.34.1`) on arm64. Intended compatibility is macOS 15+ / Xcode 16.0 / Swift 6.0 on arm64, currently unverified; the package keeps its macOS 15 deployment and Swift 6 tools/language declarations. No automatic minimum or future support is promised. Intel and non-macOS execution are outside v0.1 support.

```sh
swift build -c release --product usdz-validator
.build/release/usdz-validator validate Tests/Fixtures/valid-usda.usdz
```

The built executable is `.build/release/usdz-validator`; run it directly or copy it to a directory you manage on your `PATH`. The first build may fetch the only CLI dependency, Swift Argument Parser 1.5.0, pinned in [Package.resolved](Package.resolved). The library has no third-party dependencies and uses public macOS/Swift SDK facilities. No hosted upload or backend is used.

The original USDA fixture has complete native coverage and exits `0` with empty stderr. See [executable examples and all CLI options](docs/cli.md), [inspection and resource limits](docs/inspection-boundary.md), [report contracts](docs/report-compatibility.md), [security](SECURITY.md), and [fixture provenance](docs/fixtures.md).

## Use the library

Add this package to a Swift package and select `.product(name: "USDZValidation", package: "usdz-validator")` for your target. From a local package dependency, use `.package(path: "/path/to/usdz-validator")`.

```swift
import Foundation
import USDZValidation

let configuration = try ValidationConfiguration()
let report = try Validator().validate(
    fileAt: URL(fileURLWithPath: "/path/to/asset.usdz"),
    configuration: configuration)
let json = try ReportEncoder.encode(report, format: .json)
// Use report.exitCode and report.coverage to apply your gate.
```

Validation reads one stable regular file. Malformed asset content returns findings; configuration, operational, and internal failures throw `ValidationError`. The library writes no stdout/stderr and does not terminate your process. Callers may project a typed failure with `ValidationReport(failure:fileAt:configuration:)` when they need a report envelope.

## Verification and support scope

```sh
swift test
sh Scripts/test-cli.sh
python3 Scripts/verify-examples.py --executable .build/release/usdz-validator
```

Under the user-approved 2026-10-21 verification-policy amendment, current-host required gates must pass; unavailable minimum-target, cross-host and CPython 3.12 checks remain UNVERIFIED and are deferred follow-up, not v0.1 acceptance blockers. CPython 3.14.7 is the verified schema-tool environment; CPython 3.12 is intended and unverified. Repeated-run, relocation and fixed-adapter golden checks establish current-host determinism; no cross-host equality is claimed. The runner reports `currentHostStatus: PASS` for required current-environment verification and retains `releaseStatus: UNVERIFIED` for its broader optional matrix; failed current-host gates still block acceptance. See [the release matrix](docs/verification/release-matrix.md). [Recorded release resource measurements](docs/verification/resource-results.md) meet the 256 MiB RSS / 60-second targets for that corpus and host; they establish no universal memory guarantee. The opt-in installed-checker smoke test remains unobserved. Setup and exact schema checks are in [Tools/README.md](Tools/README.md).

v0.1 excludes complete USD parsing, composition/conformance and binary-USDC dependency parsing; editing, repair, conversion, normalization, rendering and preview; GUI/web/backend services; exhaustive Quick Look, RealityKit, visionOS, geometry, material, shader, animation or visual-quality validation; general decompression, image pixel decoding and recursive nested inspection; untrusted tools, `usdcat` conversion, custom rule/resolver plugins; Intel/non-macOS and batch operation; hosted SARIF upload, an external hard sandbox, product fixture generation, and extra executable products.

Original code, documentation, and project-authored fixtures are MIT, copyright 2026 USDZ Validation Kit contributors. Preserve [LICENSE](LICENSE) and applicable [NOTICE](NOTICE) material when redistributing. See [CHANGELOG.md](CHANGELOG.md) for v0.1 scope. Vulnerability reporting is described in [SECURITY.md](SECURITY.md).

<p align="center">
  <img src="assets/branding/usdz-validator.png" width="220" alt="Blue layered cube with a teal magnifying glass">
</p>

# USDZ Validation Kit

A local Swift library and CLI for repeatable USDZ packaging, package-local reference, and delivery-budget checks. Native inspection runs without USD tools, extraction, or network access. Version 0.2.0 automatically reads authored references in a bounded subset of exact USDC crate versions 0.8.0, 0.9.0 and 0.10.0; supported layers can achieve complete reference coverage. Reports distinguish observed defects from incomplete checks; exit `0` means the configured gate accepted the result, not full USD, Apple-platform, or asset-security certification.

## Build and run

Verified/supported current-host combination: macOS 27.0.1 build 26A434 / Xcode 27.1 build 27A9275 / Swift 6.4 (`swiftlang-6.4.0.34.1`) on arm64. Intended compatibility is macOS 15+ / Xcode 16.0 / Swift 6.0 on arm64, currently unverified; the package keeps its macOS 15 deployment and Swift 6 tools/language declarations. No automatic minimum or future support is promised. Intel and non-macOS execution are outside v0.2 support.

```sh
swift build -c release --product usdz-validator
.build/release/usdz-validator validate Tests/Fixtures/valid-usda.usdz
```

The built executable is `.build/release/usdz-validator`; run it directly or copy it to a directory you manage on your `PATH`. The first build may fetch the only CLI dependency, Swift Argument Parser 1.5.0, pinned in [Package.resolved](Package.resolved). The library privately compiles pinned LZ4 1.10.0 C source for bounded crate metadata decoding; no host-installed LZ4, Python, USD tool or OpenUSD runtime is needed. Source hashes and BSD-2-Clause terms are retained in [the dependency manifest](Sources/CUSDCCompression/source-manifest.json) and [NOTICE](NOTICE). No hosted upload or backend is used.

The original USDA fixture has complete native coverage and exits `0` with empty stderr. It contains no visible geometry and is a validation fixture, not a preview model. See [executable examples and all CLI options](docs/cli.md), [inspection and resource limits](docs/inspection-boundary.md), [report contracts](docs/report-compatibility.md), [security](SECURITY.md), and [fixture provenance](docs/fixtures.md).

## Logo-derived 3D example

The project illustration inspired a procedural 3D reconstruction of its layered cube, with the magnifying glass omitted. Explore the [USDZ model](Examples/layered-cube/model.usdz), [editable USD source](Examples/layered-cube/source/model.usda), and [saved native validation report](Examples/layered-cube/validation.json). The [example guide](Examples/layered-cube/README.md) records provenance, checks, and the command to reproduce the report. Artwork generation and viewing use separate tools; the kit validates the USDZ package.

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

Current-host required gates and their exact evidence are recorded in [envelope 3 verification](docs/verification/usdc-numeric-v0-2.md). The [envelope 2 acceptance record](docs/verification/usdc-v0-2.md) and [original release matrix](docs/verification/release-matrix.md) remain historical evidence. CPython 3.14.7 is the verified schema-tool environment; macOS 15, other host/toolchain combinations, true cross-host equality and CPython 3.12 remain **UNVERIFIED**. Current-host `PASS` does not promote those deferred rows. [Resource measurements](docs/verification/resource-results.md) test complete release CLI invocations against 268,435,456 bytes peak RSS and 60 seconds on the recorded host; they establish no universal memory guarantee. Offline schema setup is in [Tools/README.md](Tools/README.md).

Complete reference coverage describes the declared package-local authored-reference policy. It does not establish USD conformance, composed dependencies, geometry correctness or renderer compatibility. Admitted opaque numeric arrays require a bounded count header; their untouched element counts do not incur item or proportional work charges. Actual visits and enclosing containers remain charged. Expressions, clip templates, raw unregistered values, unknown representations and disputed layouts retain explicit gaps. ZIP entries remain stored-only; the sole decompression exception is bounded crate-internal metadata. See [the precise subset and envelope 3](docs/inspection-boundary.md).

v0.2 excludes complete USD parsing, composition/conformance and geometry or scene validation; editing, repair, conversion, normalization, rendering and preview; GUI/web/backend services; exhaustive Quick Look, RealityKit, visionOS, material, shader, animation or visual-quality validation; ZIP decompression, image pixel decoding and recursive nested inspection; untrusted tools, `usdcat` conversion, custom rule/resolver plugins; Intel/non-macOS and batch operation; hosted SARIF upload, an external hard sandbox, product fixture generation, and extra executable products.

For version 0.2.0 publication status, see [GitHub releases](https://github.com/Light2288/usdz-validator/releases). The `v0.1.0` tag remains available as the historical baseline; [the release summary](docs/verification/release-summary.md) preserves its original evidence and links the current verification. The [five local Apple sample results](docs/verification/apple-assets.md) describe historical v0.1 native gaps and separately opted-in checker results; they are not current v0.2 acceptance evidence.

Original code, documentation, project-authored fixtures, branding artwork, and the layered-cube example are MIT, copyright 2026 USDZ Validation Kit contributors. Preserve [LICENSE](LICENSE) and applicable [NOTICE](NOTICE) material when redistributing. See [CHANGELOG.md](CHANGELOG.md) for release history. Vulnerability reporting is described in [SECURITY.md](SECURITY.md).

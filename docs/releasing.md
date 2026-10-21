# Local release verification

Under the user-approved verification-policy amendment of 2026-10-21, v0.1 acceptance requires all current-host gates to pass on macOS 27.0.1 build 26A434 / Xcode 27.1 build 27A9275 / Swift 6.4 (`swiftlang-6.4.0.34.1`) on arm64, the only verified/supported combination. macOS 15+ / Xcode 16.0 / Swift 6.0 arm64 remains intended compatibility, unverified until tested; neither the deployment declaration nor a newer toolchain establishes minimum/future support. Baseline, two-host comparison and Python 3.12 checks remain UNVERIFIED and are deferred follow-up, not v0.1 acceptance blockers. [The manual matrix](verification/release-matrix.md) separates required current-host evidence from these optional rows. No tag, push, merge, release upload or hosted workflow is part of these commands.

Bootstrap the development dependencies once: `swift package resolve`, then the hash-locked venv installation in [Tools/README.md](../Tools/README.md). Schema verification needs that venv; a missing interpreter or dependency is a failed gate. CPython 3.14.7 is the verified developer-tool environment; CPython 3.12 is an intended, unverified target whose separate execution is deferred. Missing required current-host schema tooling still fails the gate. Verification does not install Python dependencies, retrieve schemas or download test assets. `swift package resolve` may fetch the pinned source dependency; the runner requires byte-for-byte unchanged `Package.resolved` and preserves the original lock in evidence.

Select the exact Xcode developer directory installed on each host and verify the actual versions before running. The current observed path is `/Applications/Xcode.app/Contents/Developer`. A baseline installation might be `/Applications/Xcode_16.0.app/Contents/Developer`; use its actual path, never infer the version from the filename. For example, on the current host:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift --version
xcodebuild -version
sw_vers
uname -m
xcrun swift-format --version
make release-verify
```

`make release-verify` runs `sh Scripts/verify-release.sh --evidence-dir .build/verification/current`. It requires an empty evidence directory. Preserve each completed or failed run before choosing a fresh path; existing evidence is never overwritten. A custom evidence path uses the same gates:

```sh
sh Scripts/verify-release.sh --evidence-dir .build/verification/baseline
```

The runner captures the exact developer directory, commands, Swift/Xcode/OS/formatter/Python versions, hardware and filesystem. The unchanged runner recognizes the documented current and intended-baseline arm64 combinations; only the actually tested current combination has verified support. The current host owns non-mutating formatter lint. During deferred baseline follow-up, that host records its formatter and explicitly skips lint but must run build/tests; never run `make format` there to rewrite current-host formatting.

The sequence is environment capture; formatter lint; dependency resolution and unchanged lock check; debug build/tests; normal and isolated-hook CLI process builds/tests; release build/tests; Address Sanitizer tests; offline schema and verifier-tool tests; documented examples; fixed golden export/schema checks and manifest construction; opt-in real-size resource tests and independent release measurements. Every required failure stops the run. Separate stdout/stderr logs and command/environment/status rows remain in `summary.json` and `logs/`; a suite reporting zero tests or a skipped required CLI/schema/resource/tool suite fails. Ordinary Swift suites explicitly skip expensive resources and real installed-tool smoke; the dedicated resource gate must subsequently run without skips. Address Sanitizer includes the deterministic adversarial suite. Use `make adversarial` to run that subset independently.

The Make targets expose the approved command catalogue:

| Target | Command |
| --- | --- |
| `make format` | `xcrun swift-format format --in-place --recursive --configuration .swift-format Sources Tests Package.swift` |
| `make format-check` | `xcrun swift-format lint --strict --recursive --configuration .swift-format Sources Tests Package.swift` |
| `make build` | `swift build --build-tests` |
| `make test` | `swift test` |
| `make cli-test` | `sh Scripts/test-cli.sh` |
| `make schemas` | `.venv/bin/python Scripts/verify-schemas.py --self-test`, then `.venv/bin/python -m unittest discover -s Tests -p 'test_schema_contracts.py'` |
| `make adversarial` | `sh Scripts/test-adversarial.sh` |
| `make resources` | `swift build -c release`, then `UVK_RUN_RESOURCE_TESTS=1 swift test -c release --filter ResourceBoundaryTests`, then `python3 Scripts/verify-resources.py --executable .build/release/usdz-validator --output docs/verification/resource-results.md` |

Resource verification measures native invocations with the checker disabled on the recorded internal SSD arm64 host. Each maximum-envelope release invocation must remain at or below 268,435,456 bytes peak RSS and 60 seconds. Fresh measurements update [resource-results.md](verification/resource-results.md) and are copied into run evidence. These measurements describe the designated host and corpus, not an OS-enforced or universal memory sandbox.

The hook build uses its own `.build/process-tests` scratch directory and `UVK_PROCESS_TESTING`; release builds never receive that define. `testReleaseHasNoHooks` compares the release process's exit, stdout and stderr with all five fixed scenario values (`internalFailure`, `checkerUnavailable`, `checkerSuccess`, `checkerFailure`, `encodingCap`). Executable paths are obtained with matching `swift build --show-bin-path` configurations.

Installed checker smoke is optional and never runs by default. To request it explicitly:

```sh
sh Scripts/verify-release.sh --evidence-dir .build/verification/with-smoke --installed-checker-smoke
```

This additionally runs `UVK_RUN_INSTALLED_CHECKER=1 swift test --filter InstalledCheckerSmokeTests`. Its logs record the exact observed version, status and outcome; unavailable or unsupported tools are `SKIPPED`, never passed. A failed requested test fails the run. The smoke test asserts adapter completion, not acceptance of its tiny fixture: `outcome=failureReported` can coexist with a passing smoke test. [Local Apple asset verification](verification/apple-assets.md) records separate successful and failing asset results. Real external results depend on the installed version and remain separate from compatibility exports, which use fixed fake checker results.

The latest [release summary](verification/release-summary.md) separates current-host acceptance, external asset results and deferred environments. Keep the version unreleased until the maintainer reviews the documentation and explicitly publishes it; verification does not commit, tag, push, merge or upload a release.

For deferred cross-host follow-up, once a second qualifying environment exists, copy only the complete evidence directories from the two hosts to a comparison machine. They contain 73 actual fixed Swift exports, exact copies of the 13 reviewed documents, and a compatibility manifest binding fixture/source/configuration/validator versions, file hashes and native occurrence IDs. The manifest checks the reviewed input hashes and never changes expectations. Do not edit the copied exports or manifests. Compare them with:

```sh
python3 Scripts/compare-compatibility.py PATH_TO_BASELINE PATH_TO_CURRENT
```

Success requires identical input/configuration/version manifests, the same file set, verified per-file hashes/native IDs and exact report/catalogue bytes. Comparison returns nonzero for missing exports or any difference. A compatibility PASS establishes byte equality only: for a cross-host claim, inspect both original `summary.json` files for passed gates and two actual qualifying environments. Self-comparison establishes local integrity only. Record future baseline, cross-host and CPython 3.12 observations separately; Python 3.12 must use the same hash lock and may not be inferred from CPython 3.14.7. Keep current-host formatter evidence and the documented resource-host measurement.

The two machine statuses have separate meanings under the amendment. Local runner exit 0 and `currentHostStatus: PASS` establish the required current-environment v0.1 verification. Failed required current-host gates still block acceptance. The unchanged `releaseStatus: UNVERIFIED` is an honest aggregate of the broader optional matrix while baseline/cross-host/Python 3.12 evidence is absent; it does not make those deferred rows v0.1 acceptance blockers. Leave them UNVERIFIED and limit support claims to the exact tested combination. Final acceptance still requires the remaining governing criteria and Task 27 review.

For a documentation-only amendment, preserve earlier full-run logs, observations and hashes. Run affected schema/provenance and verification-tool checks; if a manifest-bound document changes, generate genuine fresh golden exports, validate them and write a compatibility manifest in a new evidence directory. Such a focused refresh is not a new full release run and must not copy or fabricate a full-run summary. It cannot establish cross-host equality.

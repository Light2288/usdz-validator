# Local release verification

v0.1 release acceptance requires both designated Apple Silicon hosts: macOS 15 / Xcode 16.0 / Swift 6.0 and macOS 27.0.1 / Xcode 27.1 / Swift 6.4. A newer installed environment does not establish baseline support. [The manual matrix](verification/release-matrix.md) records observed results and unresolved gaps. No tag, push, merge, release upload or hosted workflow is part of these commands.

Bootstrap the development dependencies once: `swift package resolve`, then the hash-locked venv installation in [Tools/README.md](../Tools/README.md). Schema verification needs that venv; a missing interpreter or dependency is a failed gate. CPython 3.12 is the selected development baseline and must be exercised separately from the observed CPython 3.14.7. Verification does not install Python dependencies, retrieve schemas or download test assets. `swift package resolve` may fetch the pinned source dependency; the runner requires byte-for-byte unchanged `Package.resolved` and preserves the original lock in evidence.

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

The runner captures the exact developer directory, commands, Swift/Xcode/OS/formatter/Python versions, hardware and filesystem. Only the two designated arm64 combinations qualify. The current host owns non-mutating formatter lint; the baseline records its formatter and explicitly skips lint. Build and test still run on the baseline. Never run `make format` on the baseline to rewrite current-host formatting.

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

This additionally runs `UVK_RUN_INSTALLED_CHECKER=1 swift test --filter InstalledCheckerSmokeTests`. Its logs record the exact observed version, status and outcome; unavailable or unsupported tools are `SKIPPED`, never passed. A failed requested test fails the run. Real external results depend on the installed version and remain separate from compatibility exports, which use fixed fake checker results.

Copy only the complete evidence directories from the two hosts to a comparison machine. They contain 73 actual fixed Swift exports, exact copies of the 13 reviewed documents, and a compatibility manifest binding fixture/source/configuration/validator versions, file hashes and native occurrence IDs. The manifest checks the reviewed input hashes and never changes expectations. Do not edit the copied exports or manifests. Compare them with:

```sh
python3 Scripts/compare-compatibility.py PATH_TO_BASELINE PATH_TO_CURRENT
```

Success requires identical input/configuration/version manifests, the same file set, verified per-file hashes/native IDs and exact report/catalogue bytes. Comparison returns nonzero for missing exports or any difference. A compatibility PASS establishes byte equality only: inspect both `summary.json` files for passed host gates and matching designated environments, separately verify CPython 3.12 with the same hash lock, and record the observed comparison and environment rows in the manual matrix. Keep current-host formatter evidence and the documented resource-host measurement. Local runner exit 0 means local required gates passed; `releaseStatus` remains `UNVERIFIED` while baseline/cross-host/Python 3.12 evidence is missing. No v0.1 support or release acceptance claim is permitted until those gaps close.

# USDZ Validation Kit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a bounded, local macOS USDZ validation library and thin CI CLI with deterministic text, JSON v1 and SARIF reports.

**Architecture:** A synchronous Swift core opens one file descriptor, constructs a checked classic-ZIP index, scans supported stored payloads, and evaluates package-local rules. Reports and gate policy are shared by library and CLI. An explicitly requested, fixed-path `usdchecker` adapter has separate results and bounded subprocess handling.

**Tech Stack:** Swift tools/language 6.0, public macOS SDK, XCTest, CryptoKit SHA-256; ArgumentParser 1.5.0 only in the CLI; development-only pinned Python `jsonschema` for offline schema verification.

**Spec:** [2026-10-19-usdz-validation-kit-design.md](../specs/2026-10-19-usdz-validation-kit-design.md), AC-01–AC-30. Read the whole specification before execution; its detailed rule meanings and boundaries govern every task.

**Slug:** `usdz-validation-kit`
**Status:** APPROVED — explicit user approval in conversation; implementation authorized 2026-10-21.
**Date:** 2026-10-20
**Provenance:** Derived only from the user-selected specification above, its explicit approval in this conversation, repository/tool discovery on 2026-10-20, and native interactive planning clarification. No legacy artifacts were found. At planning discovery the specification still said DRAFT; conversational approval was authoritative, and that planning phase did not edit it. The approved lifecycle status and dated amendment now appear in the governing specification.
**Original approved specification SHA-256 (before the 2026-10-21 amendment):** `e834aba86d17e9f16cbfd2387057169c64dfb52b72d744c9d380fadfc46783cb`
**User-approved verification-policy amendment — 2026-10-21:** The user approved current-host-only v0.1 verified support and acceptance, with baseline, cross-host and CPython 3.12 verification deferred. The constraints, Tasks 26–27 and traceability below implement that amendment without product/test/script changes. Historical discovery and original approval hashes remain original observations; this amendment supersedes their earlier verification requirements.
**Execution tier:** full
**Implementation model role:** full
**Execution method:** Subagent-driven, explicitly selected during clarification; preserve task-level reviews and the final sequential specification/quality gate. Model roles resolve from the current managed routing configuration at execution time.

## Global Constraints

- Verified/supported v0.1 combination: macOS 27.0.1 build 26A434 / Xcode 27.1 build 27A9275 / Swift 6.4 (`swiftlang-6.4.0.34.1`) on arm64, with CPython 3.14.7 for development-only schema tooling. Require current-host build/native tests and all current-host gates. macOS 15+ / Xcode 16.0 / Swift 6.0 arm64 and CPython 3.12 remain intended, unverified targets; keep the package deployment/tools/language declarations. Baseline, cross-host and Python 3.12 verification are deferred follow-up, not v0.1 acceptance blockers. No automatic minimum/future support guarantee.
- AC-22 retains exact determinism/privacy guarantees: prove repeated runs, relocation, fixed-adapter results and independent golden equality on the verified host. Defer genuine two-host comparison until a second qualifying environment exists; self-comparison establishes local integrity only. Preserve the runner: `currentHostStatus: PASS` is required current-environment verification; `releaseStatus: UNVERIFIED` honestly aggregates the broader optional matrix. Failed required current-host gates still block acceptance.
- Products: library/module `USDZValidation`; executable `usdz-validator`. Core uses public SDK facilities only. CLI dependency: `apple/swift-argument-parser` 1.5.0, resolved revision committed in `Package.resolved`.
- One stable local regular file, opened read-only; no asset extraction, decompression, pixel decoding, host-filesystem reference resolution, implicit configuration discovery, or native network/tool execution.
- Classic single-disk stored ZIP inspection only. Unsupported ZIP64, descriptors, layouts, encodings, type semantics and nested packages cause explicit limitations; established malformed records remain errors. Accept only 1:1 stored sizes, including zero/zero; reject nonempty/zero claims before payload interpretation.
- Separate `archiveSpecification`, `appleCompatibility`, `policy`, and `validatorLimitation` from severity `error|warning|note`. Keep native and external findings, coverage and counts separate.
- Preserve all 32 initial native rule IDs and `USDCK-001`; never recycle IDs. Deterministic SHA-256 occurrence IDs, exact UTF-8 namespace identity, fixed discovery order, category/rule/name-byte/numeric-location/ID final order.
- Fixed safety envelope v1: archive 512 MiB; entries including directories 10,000; central directory 16 MiB; regular-entry declared bytes 256 MiB; aggregate declared uncompressed bytes 512 MiB; USDA layer 16 MiB; entry name/token 4 KiB; tokens 100,000; read chunk 64 KiB; texture header scan 1 MiB; cumulative native reads 1,152 MiB; findings 10,000 with final resource sentinel on truncation; message 1 KiB; each variable evidence string 4 KiB; config 64 KiB; encoded report 32 MiB. MiB = 1,048,576; KiB = 1,024 bytes.
- Release native resource target: at most 256 MiB peak RSS and 60 seconds per maximum-envelope invocation on the documented arm64 local-SSD host. Measure it; do not claim an OS-enforced or universal memory sandbox.
- Default warning budgets: `archiveBytes=104857600`, `fileBytes=26214400`, `fileCount=1000`, `textureBytes=20971520`, `totalTextureBytes=83886080`, `textureMaxDimension=4096`. Only `observed > threshold` warns; omitted keys default and explicit null disables only that warning check. Config cannot alter safety limits.
- Default profile `general-v1`; `apple-portable-v1` adds warning-only binary-layer and PNG/JPEG advice. It is a frozen advisory subset, without renderer certification or a universal single-layer requirement.
- Gate precedence: invalid invocation/config 64; internal failure 70; operational/report failure 3; blocking finding/resource/tool-reported failure 1; unaccepted native gap or unsuccessful requested checker 2; accepted gate 0. Native incomplete acceptance changes gate only, never coverage; it cannot override warnings selected by `--fail-on warning`, safety errors or an unsuccessful requested checker.
- JSON report/catalogue/config `schemaVersion: 1`; SARIF `2.1.0`. Default output is UTF-8 without BOM, deterministic keys/escaping, LF terminated, and contains no timestamps, durations, host/user IDs, random IDs, absolute local paths or raw external diagnostics. JSON unavailable fields are null, arrays empty; sensitive-only fields are omitted by default. SARIF follows its own omission rules.
- Optional tool: only `/usr/bin/usdchecker`, explicitly requested, exact supported version `Apple USD Tools (0.25.11)`. Probe: 5 seconds / 16 KiB; validation: 60 seconds / combined 1 MiB. Fixed args `--strict --rootPackageOnly --out stderr`, plus `--arkit` for Apple profile; absolute input as separate argument. Fixed environment `PATH=/usr/bin:/bin`, `LANG=C`, `LC_ALL=C`; input parent is working directory. No shell, downloads, PATH discovery, arbitrary executable/argument option, or promised external sandbox. Terminate, force-kill after at most one second, reap, and bound pipe draining.
- Original code and fixtures are MIT. Every fixture and generator has provenance, license, hash and reproducible recipe metadata; tests download no assets. Never treat a synthetic USDC header as a valid-scene oracle.
- Preserve v0.1 non-goals: complete USD/parser/conformance/composition or USDC dependency parsing; editing/repair/conversion/rendering/preview; GUI/web/backend; exhaustive Apple compatibility; untrusted tools/`usdcat` conversion; general decompression/nested inspection; Intel/non-macOS/batch support; rule/resolver plugins; hosted SARIF upload; external hard sandbox; extra executable products.

## Repository evidence, assumptions and command sources

Verified on 2026-10-20: unborn `main`, no commits or local refs; origin fetch/push is `https://github.com/Light2288/usdz-validator.git`. Git says `main...origin/main [gone]`. The only project artifact before this plan was the approved specification; incidental `.DS_Store` files exist at root, `docs/`, and `docs/superpowers/` and must be preserved. There is no package, test/build configuration, implementation, or existing plan.

Architecture map: `docs/architecture/map.md` **MISSING**; freshness cannot be established, HEAD SHA unavailable/unborn. Key-path checks found no `Sources/`, `Tests/`, `Package.swift`, or architecture directory. ADRs: none found, so there are no accepted decisions beyond the approved specification. Do not generate a map or ADR during planning.

Rechecked environment: macOS 27.0.1 (26A434), arm64; Swift 6.4 (`swiftlang-6.4.0.34.1`, driver 1.168.6); Xcode 27.1 (27A9275), selected `/Applications/Xcode.app/Contents/Developer`. This is the only installed Xcode. Both `/usr/bin/usdchecker` and `/usr/bin/usdcat` report `Apple USD Tools (0.25.11)`. `xcrun swift-format` is available (`--version`: `main`). Python `/opt/homebrew/bin/python3` is 3.14.7; `jsonschema` is absent. No dependencies were installed and no product commands were run.

`git ls-remote --symref origin HEAD refs/heads/main` failed DNS resolution. Remote emptiness is user-supplied, not independently verified. The plan assumes no remote main history, as instructed; recheck at execution and never invent a base commit or pull a nonexistent branch. The baseline macOS 15 / Xcode 16.0 host was unavailable at planning discovery. Verification was then required and unobserved; the 2026-10-21 user-approved amendment defers it, preserving its UNVERIFIED status.

Planning choices resolved natively: pinned development-only Python `jsonschema`; portable local verification scripts with a manual baseline/current matrix, hosted Actions deferred; subagent-driven implementation after plan approval. No unresolved design choice blocks this plan. The schema dependency's transitive versions/hashes and real resource measurements must be obtained during their owning tasks, not invented now.

Development-tool research used [PyPI jsonschema 4.25.1](https://pypi.org/project/jsonschema/4.25.1/) and its [tagged project metadata](https://github.com/python-jsonschema/jsonschema/blob/v4.25.1/pyproject.toml) for version, Python floor and MIT license. They are tool-selection evidence, not an installed dependency or verification result.

Command evidence: the specification's “Verification and Test Layers” supplies `swift package resolve`, `swift build --build-tests`, `swift test`, release builds/tests and Address Sanitizer. Read-only local help confirmed SwiftPM `--filter`, `--skip`, `--skip-build`, `--product`, `--show-bin-path`, configuration and sanitizer options, and `swift-format lint --strict --recursive --configuration` / `format --in-place --recursive --configuration`. XCTest suite filters below specialize those commands. All `Scripts/…`, Make targets, schema commands and process-test builds below are **new deliverables**, defined in this plan; they do not exist yet. Do not report planned commands as observed verification.

## Review Focus

1. A tiny archive declares huge counts/sizes or overlapping owners: reject before allocation/payload reads; distinguish unsupported layout from proven corruption (Tasks 4–7, 23).
2. Names differing only by case/Unicode form, or unsafe prefixes hidden in an unsupported expression: use exact bytes and reject established escapes without speculative missing-target results (Tasks 8–10).
3. Duplicate JSON keys, escaped-key aliases or huge numeric lexemes: reject configuration before opening the asset, regardless of permissive generic decoder behavior (Task 12).
4. Checker fills both pipes, ignores termination, or leaves a pipe open: finish within capture/deadline limits, force termination and reap; never hang the caller (Task 18).
5. A report aliases input through a hard link, or encoding/write fails with an old report present: refuse aliases and preserve the prior destination; hostile text never injects terminal controls (Tasks 15, 20–21).

## File responsibilities and shared conventions

All paths in task lists are repository-relative. Each task owns exactly its listed files; later modifications are explicit. Production is one library target and one CLI target, with internal seams only where tests require them. No public plugin/DI framework.

| Files / location | Responsibility |
| --- | --- |
| `Package.swift`, `Package.resolved`, `.gitignore`, `.swift-format` | Product/dependency/platform declarations and repeatable development settings |
| `Sources/USDZValidation/Models.swift`, `Configuration.swift`, `GatePolicy.swift`, `ValidationError.swift`, `Version.swift` | Public values, immutable validated configuration, gate and typed failures |
| `Sources/USDZValidation/RuleCatalogue.swift`, `FindingIdentity.swift`, `NativeDiagnostics.swift` | Descriptors, identity/order, bounded findings and coverage |
| `Sources/USDZValidation/FileSnapshot.swift`, `BoundedReader.swift`, `ResourceLedger.swift` | Safe descriptor ownership, checked ranges and all native-read accounting |
| `Sources/USDZValidation/Archive/ZIPDirectory.swift`, `ZIPIndex.swift`, `StoredPayload.swift`, `PackageNamespace.swift` | Checked classic ZIP, CRC, types and exact safe namespace |
| `Sources/USDZValidation/Rules/USDLayer.swift`, `USDALexer.swift`, `ReferenceResolver.swift`, `TextureHeaders.swift`, `BudgetRules.swift`, `BudgetConfiguration.swift` | Bounded content scanners and the three rule families |
| `Sources/USDZValidation/NativeEngine.swift`, `Validator.swift` | Fixed-order orchestration and public facade |
| `Sources/USDZValidation/Reporting/Privacy.swift`, `CappedBuffer.swift`, `TextReport.swift`, `CanonicalJSON.swift`, `JSONReport.swift`, `SARIFReport.swift`, `ReportEncoder.swift` | Shared disclosure policy, capped deterministic encodings |
| `Sources/USDZValidation/External/ProcessRunner.swift`, `USDCheckerAdapter.swift` | Bounded child lifecycle and fixed installed-tool contract |
| `Sources/USDZValidatorCLI/Command.swift`, `CommandDriver.swift`, `ReportDestination.swift`, `ProcessTestHooks.swift` | ArgumentParser surface, streams/exit codes, atomic destination, compile-only process-test seam |
| `Tests/USDZValidationTests/`, `Tests/USDZValidatorCLITests/`, `Tests/LibraryConsumerTests/` | Unit/fixture/adapter tests, executable contracts, import-only public consumer |
| `Tests/TestSupport/`, `Tests/Fixtures/`, `Tests/Goldens/`, `Tests/Schemas/` | Independent test builders, licensed originals, compatibility oracle and pinned schemas |
| `Schemas/`, `Examples/`, `Scripts/`, `Tools/`, `Makefile`, `README.md`, `SECURITY.md`, `LICENSE`, `NOTICE`, `docs/` | Published formats, runnable verification, support/security and release documentation |

Shared public model names are fixed in Task 1; only `Validator`, report encoding and catalogue are additional public entry points. Use `UInt64` for validated file offsets/sizes internally and checked conversions; JSON counts stay in signed-64-bit range. Internal scanner failures become findings/coverage, while I/O/change/configuration/unexpected failures remain typed errors. The public library neither prints nor exits.

Tests use XCTest. Suite names in `swift test --filter SuiteName` below are exact class names; each quoted test name is an XCTest method in that suite. Test-only builders operate independently of production readers. Small committed fixtures live outside SwiftPM test targets; `Fixtures.root` resolves them from the test source location. CLI tests launch the built executable directly, never `swift run`, so build chatter cannot pollute snapshots.

Assertion fragments show the exact expected values for the named test's arranged input; they are not additional helper APIs. Each RED step describes the complete case matrix as well as a representative assertion. Add meaningful tests for remaining rows rather than copying production logic into an expected-value calculator.

## Execution preflight — only after explicit plan approval

- [ ] Load `personal-workflows:spec-implement` and its selected subagent-driven base once. Re-read approvals, spec hash, plan, Git status and current managed roles. Stay in this checkout; no worktree.
- [ ] Recheck remote refs without mutating history. If remote main now exists, fetch and reconcile deliberately before branching; do not overwrite local artifacts or assume it equals an empty tree. If history remains absent as specified, do not run `git pull` or fabricate `origin/main`.
- [ ] For the still-unborn repository, use `git switch --orphan feat/usdz-validation-kit`. Preserve untracked files. Record only lifecycle approval metadata after written-plan approval, then explicitly stage the approved spec and this plan and create the initial `docs: record approved USDZ validation design and plan` root commit. No product stub/empty commit is needed. This establishes a real BASE SHA for the first implementation task. If a feature branch already exists, inspect and reuse only when appropriate; never reset it.
- [ ] Use explicit staging paths for every task; never `git add .`. Ignore, preserve and leave incidental `.DS_Store` files unstaged. Keep implementation commits on the feature branch. No push/merge without a further user request.
- [ ] Preserve the empty-tree baseline for the final whole-branch review so the root documentation commit and every product file are reviewed; a missing `main`, `HEAD~1`, or last-task diff is not a whole-branch base.

---

### Task 1: Public configuration, report values and gate policy [size: M | risk: other | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-01, AC-02, AC-16, AC-18, AC-19. **Depends on:** approved-plan preflight. **Risk:** wrong gate semantics can make CI accept a failed/incomplete asset.

**Files:** Create `Package.swift`, `.gitignore`, `.swift-format`, `Sources/USDZValidation/Models.swift`, `Sources/USDZValidation/Configuration.swift`, `Sources/USDZValidation/GatePolicy.swift`, `Sources/USDZValidation/ValidationError.swift`, `Sources/USDZValidation/Version.swift`, `Sources/USDZValidatorCLI/Command.swift`, `Tests/USDZValidationTests/ConfigurationTests.swift`, `Tests/USDZValidationTests/GatePolicyTests.swift`. Resolve/create `Package.resolved` during GREEN.

**Interfaces:** Produce public `ValidatorVersion.current: String = "0.1.0"`; `Profile` (`generalV1`, `applePortableV1` with specified raw IDs); `Severity`, `FindingCategory`, `WarningBudgets`, `GatePolicy`, `ExternalRequest` (`disabled`, `usdchecker`); `ValidationConfiguration.init(profile: Profile = .generalV1, budgets: WarningBudgets = .defaults, gatePolicy: GatePolicy = .default, includeSensitiveDetails: Bool = false, externalCheck: ExternalRequest = .disabled) throws`. Public `FailureThreshold` has only `error` and `warning`; `GatePolicy.init(failOn: FailureThreshold = .error, allowIncomplete: Bool = false)` and `GatePolicy.default` provide the CLI/native policy choices. `WarningBudgets.defaults` has the six exact defaults above; its six named fields are `Int64?` and non-null must be positive. Safety limits are not initializer arguments. Produce `ValidationError` with configuration, operational and internal-failure cases carrying safe reason codes, not raw error strings.

Produce immutable Equatable `RuleDescriptor`, `Finding`, `FindingLocation`, `Provenance`, `Coverage`, `ExternalCheck`, `ValidationReport`. Use the spec's fields and machine values. `Finding` properties: `ruleID`, `occurrenceID`, `category`, `severity`, `message`, `evidence`, `location`, `provenance`; evidence values are bounded string/integer/boolean/null (`EvidenceValue`). Location has entry name, archive byte offset, layer byte offset and line/column, all optional. `CoverageArea` cases: `containerStructure`, `entrySafety`, `references`, `byteBudgets`, `textureDimensions`, `appleAdvice`; each area result has `requested`, `state: CoverageState`, `reasons: [CoverageReason]` (rule/reason/location). Unselected areas are not completeness failures. `ExternalCheck` includes phase, availability, version, policy, status, outcome, exit/signal, diagnostic counts/presence, optional sensitive details and findings. `ValidationReport` uses the spec's required envelope. Produce internal `GatePolicy.evaluate(nativeFindings: [Finding], coverage: Coverage, externalCheck: ExternalCheck, operationalErrors: [ValidationError], internalFailure: Bool) -> GateResult` with status/decision/acceptedIncomplete/exitCode; callers never compute a second policy. Invocation/configuration 64 is handled before a report exists, using the same documented precedence in the driver.

- [ ] **RED:** Create the manifest/test harness first (no functional CLI yet). In `ConfigurationTests.testDefaultsAndInvalidBudgets`, assert the six exact defaults, both profile raw IDs, and rejection of `0`/negative budgets. In `GatePolicyTests.testPrecedenceAndAcceptance`, table-test report outcomes `70 > 3 > 1 > 2 > 0`, error/warning/note thresholds and `XCTAssertFalse(result.acceptedIncomplete)` for a failed gate. Task 20 tests invocation/configuration 64 preceding validation. Accepted native gap must give status `incomplete`, pass, exit `0`; requested tool unable/failure stays `2`/`1` with acceptance enabled.

  ```swift
  XCTAssertEqual(WarningBudgets.defaults.textureMaxDimension, 4096)
  XCTAssertEqual(acceptedGap.exitCode, 0)
  XCTAssertEqual(requestedUnavailable.exitCode, 2)
  ```

- [ ] Resolve the declared package dependency as harness setup with `swift package resolve`, then run `swift test --filter 'ConfigurationTests|GatePolicyTests'`; expect missing model/policy implementation or failed assertions, not a dependency/network failure counted as RED.
- [ ] **GREEN:** Implement those values/policy. Manifest: tools 6.0, `.macOS(.v15)`, Swift language 6, exact ArgumentParser 1.5.0 dependency on CLI only; core/test consumer never depends on CLI. Add only a minimal validator version command until Task 20. Pin formatter config schema v1, 2-space indentation, line length 100; ignore `.build/`, `.venv/`, `.DS_Store` and generated verification output.
- [ ] Run `swift package resolve`, `swift build --build-tests`, then the filtered tests; expect exit `0`. Inspect `swift package describe` for target dependencies and `Package.resolved` for the actual resolved revision; record failures separately from RED.
- [ ] Commit with explicit paths: `git add Package.swift Package.resolved .gitignore .swift-format Sources/USDZValidation/Models.swift Sources/USDZValidation/Configuration.swift Sources/USDZValidation/GatePolicy.swift Sources/USDZValidation/ValidationError.swift Sources/USDZValidation/Version.swift Sources/USDZValidatorCLI/Command.swift Tests/USDZValidationTests/ConfigurationTests.swift Tests/USDZValidationTests/GatePolicyTests.swift`; `git commit -m "feat: define validation models and gate policy"`.

### Task 2: Independent deterministic fixtures and provenance [size: M | risk: none | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-03, AC-04, AC-05, AC-29. **Depends on:** 1.

**Files:** Create `Tests/TestSupport/ArchiveRecipe.swift`, `Tests/TestSupport/Fixtures.swift`, `Tests/Fixtures/manifest.json`, `Tests/Fixtures/valid-usda.usdz`, `Tests/Fixtures/Sources/root.usda`, `Tests/Fixtures/Sources/pixel.png`, `LICENSE`, `Tests/USDZValidationTests/FixtureTests.swift`; modify `Package.swift` for a test-support target/resources only.

**Interfaces:** Test-only `ArchiveRecipe` describes ordered entries (`nameBytes: Data`, `payload: Data`, type/flags/method/declared-size/header overrides); `ArchiveRecipe.encode() throws -> Data` writes classic ZIP with deterministic timestamps, 64-byte payload alignment and independently computed CRC. `Fixtures.validUSDA() throws -> Data`, `Fixtures.root: URL`, `Fixtures.write(_:basename:in:) throws -> URL`; mutation helpers in `ArchiveRecipe` expose byte offsets of generated records. Default package has `root.usda` containing `#usda 1.0` and a safe `@Sources/pixel.png@` reference. Original PNG is a tiny valid original image, not just magic. No builder is shipped in the product.

- [ ] **RED:** `FixtureTests.testReproducibleOriginalPackage` asserts two encodings are equal, local payload offsets `% 64 == 0`, known CRC-32 vector `123456789 -> 0xcbf43926`, and committed bytes equal generated bytes. `testManifestCoversCorpusAndGenerators` asserts every fixture/generator has ID, purpose, source/author, MIT/license reference, obligations, hash, recipe and history; magic-only USDC cases must be labeled synthetic/nonconforming.

  ```swift
  XCTAssertEqual(try recipe.encode(), try recipe.encode())
  XCTAssertEqual(try Fixtures.validUSDA(), committedBytes)
  ```
- [ ] Run `swift test --filter FixtureTests`; expect absent builder/manifest assertions.
- [ ] **GREEN:** Implement independent test generation, write small original fixture/source files and original MIT license with `Copyright (c) 2026 USDZ Validation Kit contributors`. Record SHA-256 of exact files and generator sources in the manifest; keep the manifest's own hash outside itself. Large cases will be temporary recipes, never committed assets. Do not use a production parser to generate expected metadata.
- [ ] Run `swift test --filter FixtureTests`; expect byte-for-byte reproduction and complete manifest validation, no downloads.
- [ ] `git add Package.swift LICENSE Tests/TestSupport/ArchiveRecipe.swift Tests/TestSupport/Fixtures.swift Tests/Fixtures/manifest.json Tests/Fixtures/valid-usda.usdz Tests/Fixtures/Sources/root.usda Tests/Fixtures/Sources/pixel.png Tests/USDZValidationTests/FixtureTests.swift`; `git commit -m "test: add original deterministic USDZ fixtures"`.

### Task 3: Catalogue, finding identity and ordering [size: M | risk: data | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: data]

**Acceptance criteria:** AC-16, AC-17, AC-22. **Depends on:** 1–2. **Risk:** published identifiers/order are compatibility data.

**Files:** Create `Sources/USDZValidation/RuleCatalogue.swift`, `Sources/USDZValidation/FindingIdentity.swift`, `Tests/USDZValidationTests/FindingIdentityTests.swift`, `Tests/USDZValidationTests/RuleCatalogueTests.swift`, `Tests/Goldens/rule-catalogue-v1.json`; update `Tests/Fixtures/manifest.json` for any new generated fixture recipes only (report goldens are not asset fixtures).

**Interfaces:** Public `RuleCatalogue.descriptors(profile: Profile) -> [RuleDescriptor]`. Internal `FindingKey` contains `ruleID: String`, `entryNameBytes: Data?`, `entryOffset: UInt64?`, `contentOffset: UInt64?`, `discriminator: String`. `FindingIdentity.native(_ key: FindingKey) -> String`; `FindingIdentity.external(toolVersion: String, ruleID: String, outcome: String) -> String`; `FindingOrder.sorted(_ records: [(finding: Finding, key: FindingKey)]) -> [Finding]`. Retain raw keys internally beside findings until sorting; redacted display names cannot replace original identity/order bytes. Never serialize those raw keys by default.

- [ ] **RED:** `FindingIdentityTests.testLengthDelimitedIdentityAndExclusions` asserts ambiguous concatenations hash differently; nil differs from empty; renaming input, wording and threshold changes retain ID; different duplicate-entry offsets and token offsets do not. `testByteAndCategoryOrder` asserts category rank exactly matches spec, missing locations sort first, `A`/`a` and composed/decomposed Unicode use byte order, numeric 2 precedes 10. `RuleCatalogueTests.testPermanentDescriptors` asserts exact 32-ID set, categories/severities and profile selection; Apple advice appears only in Apple profile.

  ```swift
  XCTAssertEqual(FindingIdentity.native(originalKey), FindingIdentity.native(relocatedKey))
  XCTAssertNotEqual(FindingIdentity.native(originalKey), FindingIdentity.native(otherTokenKey))
  ```
- [ ] Run `swift test --filter 'FindingIdentityTests|RuleCatalogueTests'`; expect missing catalogue/hash/order behavior.
- [ ] **GREEN:** Implement stable English descriptors from the specification. Identity encoding v1: length-delimited UTF-8 fields and raw names, explicit absent/present tags, unsigned big-endian offsets, SHA-256 lowercase hex. Native namespace/version `uvk-occurrence-v1`; external namespace/version `uvk-external-occurrence-v1`. External tuple includes `usdchecker`, exact reported version, rule and outcome. Persist explicit test vectors in tests; no paths/messages/thresholds in tuple. SARIF fingerprint key will be `uvkOccurrence/v1`. Golden catalogue pins meanings, not a second detection engine.
- [ ] Run the filtered tests; expect exact vectors, no locale dependence, no ID reassignment.
- [ ] `git add Sources/USDZValidation/RuleCatalogue.swift Sources/USDZValidation/FindingIdentity.swift Tests/USDZValidationTests/FindingIdentityTests.swift Tests/USDZValidationTests/RuleCatalogueTests.swift Tests/Goldens/rule-catalogue-v1.json Tests/Fixtures/manifest.json`; `git commit -m "feat: stabilize rule catalogue and finding identity"`.

### Task 4: Bounded reads, file identity and deterministic resource stops [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security,performance]

**Acceptance criteria:** AC-04, AC-14, AC-27, AC-28. **Depends on:** 1–3. **Risk:** hostile declared sizes and special files must not drive reads/allocations. Finish this task before any archive parser implementation.

**Files:** Create `Sources/USDZValidation/FileSnapshot.swift`, `Sources/USDZValidation/BoundedReader.swift`, `Sources/USDZValidation/ResourceLedger.swift`, `Sources/USDZValidation/NativeDiagnostics.swift`, `Tests/USDZValidationTests/BoundedReaderTests.swift`, `Tests/USDZValidationTests/ResourceLedgerTests.swift`, `Tests/USDZValidationTests/FileSnapshotTests.swift`.

**Interfaces:** `FileSnapshot.open(_ url: URL) throws -> FileSnapshot`, descriptor-backed `read(offset: UInt64, count: Int) throws -> Data`, `verifyUnchanged() throws`, deterministic close. `BoundedReader.init(size: UInt64, ledger: ResourceLedger, readAt: @escaping (UInt64, Int) throws -> Data)` is an internal test seam; `read(offset: UInt64, count: Int) throws -> Data` checks range/chunk/accounting before calling it. `ResourceLedger` exposes immutable v1 limits, checked `consumeRead(_ bytes: UInt64) throws`, `consumeTokens(_ count: UInt64) throws`, `check(resource: SafetyResource, value: UInt64) throws` and `totalReadBytes: UInt64`. `SafetyResource` enumerates the fixed envelope; internal `InspectionFailure` distinguishes malformed ranges from resource stops, and callers map them to the specified findings. Descriptor I/O/change failures stay typed operational errors. `NativeDiagnostics` owns bounded identity-deduplicated findings, coverage reasons and resource stops; `emit(ruleID: String, message: String, evidence: [String: EvidenceValue], location: FindingLocation?, key: FindingKey)`, `limit(_ resource: SafetyResource, location: FindingLocation?)`, `mark(area: CoverageArea, state: CoverageState, reason: CoverageReason)`, `finish() -> ([Finding], Coverage)` are internal. No input-sized reservation.

- [ ] **RED:** `BoundedReaderTests.testCheckedRangesBeforeIO` asserts overflow, negative conversion, short reads and ranges beyond file fail before unsafe access; a counting source sees no call for rejected ranges. `testChunkAndCumulativeBoundaries` asserts 65,536 succeeds, 65,537 is never issued, 1,207,959,552 cumulative bytes succeeds and next byte produces resource stop. `ResourceLedgerTests.testEveryCounterBoundary` covers 512 MiB archive/aggregate, 256 MiB entry, 16 MiB directory/text, 10,000 entries, 4 KiB names/tokens and 100,000 tokens at/one above. `testFindingCap` permits exactly 10,000 unique findings; attempt 10,001 retains deterministic first 9,999 plus one `UVK-RES-001`, dedup doesn't consume slots, affected coverage is incomplete. `FileSnapshotTests` reject final symlink/FIFO/directory without blocking and detect truncation/replacement/change.

  ```swift
  XCTAssertThrowsError(try reader.read(offset: UInt64.max, count: 1))
  XCTAssertEqual(readCalls, 0)
  XCTAssertEqual(diagnostics.finish().0.count, 10_000) // after 10,001 unique emissions
  ```
- [ ] Run `swift test --filter 'BoundedReaderTests|ResourceLedgerTests|FileSnapshotTests'`; expect missing safety primitives/assertions.
- [ ] **GREEN:** Open with non-following/nonblocking flags, fstat regularity/size before content, then use checked descriptor reads and before/after metadata checks. Classify detectable changes as typed operational failures. Implement limits before buffers/counts; a resource stop never becomes an unchecked trap. Synthesize large logical inputs in tests without allocating them. Diagnostics use fixed discovery order; replacing the final slot on overflow must not change earlier IDs. Avoid unbounded raw error descriptions.
- [ ] Run filtered tests and `swift test --sanitize=address --filter 'BoundedReaderTests|ResourceLedgerTests|FileSnapshotTests'`; expect controlled failures, bounded counters, no crash or hang.
- [ ] `git add Sources/USDZValidation/FileSnapshot.swift Sources/USDZValidation/BoundedReader.swift Sources/USDZValidation/ResourceLedger.swift Sources/USDZValidation/NativeDiagnostics.swift Tests/USDZValidationTests/BoundedReaderTests.swift Tests/USDZValidationTests/ResourceLedgerTests.swift Tests/USDZValidationTests/FileSnapshotTests.swift`; `git commit -m "feat: bound input reads and resource accounting"`.

### Task 5: Checked EOCD and central-directory metadata [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security]

**Acceptance criteria:** AC-04, AC-06, AC-14, AC-28. **Depends on:** 4. **Risk:** untrusted lengths/counts control archive indexing.

**Files:** Create `Sources/USDZValidation/Archive/ZIPDirectory.swift`, `Tests/USDZValidationTests/ZIPDirectoryTests.swift`; modify `Tests/TestSupport/ArchiveRecipe.swift`, `Tests/Fixtures/manifest.json` for adversarial recipes.

**Interfaces:** `ZIPDirectory.read(from: BoundedReader, diagnostics: NativeDiagnostics) throws -> ZIPDirectory?`. Directory records expose original name bytes, flags, versions, method, CRC, sizes, disk, external attributes and local-header offset as checked values. Nil means no trustworthy supported mapping; I/O throws stay operational.

- [ ] **RED:** `ZIPDirectoryTests.testEOCDAndDirectorySafety` covers empty/non-ZIP, every fixed-field truncation, EOCD signature inside comment, bounded comment, exact directory end/count, overflow/out-of-range offsets, malformed extra fields and one-past ceilings; assert `UVK-ARC-001` for established truncation and zero payload reads. `testUnsupportedFeaturesAreLimitations` asserts ZIP64 locator/sentinel/extra, multi-disk, descriptors, required versions/flags and unsupported encoding produce `UVK-LIM-001`/incomplete, not a false universal ZIP error. Independently proven contradictions remain errors.

  ```swift
  XCTAssertNil(try ZIPDirectory.read(from: truncatedReader, diagnostics: diagnostics))
  XCTAssertEqual(diagnostics.finish().0.map(\.ruleID), ["UVK-ARC-001"])
  ```
- [ ] Run `swift test --filter ZIPDirectoryTests`; expect absent parser/tests failing.
- [ ] **GREEN:** Search only bounded EOCD tail with checked candidate validation; consume directory records incrementally under entry/CD/name/declared-size ceilings, including aggregate uncompressed sizes of rejected compressed members. Recognize unsupported interpretation before classic assumptions; accept bounded comments and unknown noninterpreting extras. Allocate only after validated counts/sizes. Do not inspect payloads.
- [ ] Run `swift test --filter ZIPDirectoryTests` and `swift test --sanitize=address --filter ZIPDirectoryTests`; expect precise error/limitation IDs and read bounds.
- [ ] `git add Sources/USDZValidation/Archive/ZIPDirectory.swift Tests/USDZValidationTests/ZIPDirectoryTests.swift Tests/TestSupport/ArchiveRecipe.swift Tests/Fixtures/manifest.json`; `git commit -m "feat: inspect bounded ZIP directory records"`.

### Task 6: Local headers and trustworthy physical ownership [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security]

**Acceptance criteria:** AC-04, AC-06, AC-14, AC-28. **Depends on:** 5. **Risk:** index confusion could expose arbitrary byte ranges to scanners.

**Files:** Create `Sources/USDZValidation/Archive/ZIPIndex.swift`, `Tests/USDZValidationTests/ZIPIndexTests.swift`; modify `Tests/TestSupport/ArchiveRecipe.swift`, `Tests/Fixtures/manifest.json`.

**Interfaces:** `ZIPIndex.build(directory: ZIPDirectory, reader: BoundedReader, diagnostics: NativeDiagnostics) throws -> ZIPIndex?`; `ZIPIndex.entries` are physical-order `ZIPEntry` values with validated record/payload ranges and original name/type metadata. Safe type interpretation and `defaultEntry` selection belong to Task 8. No namespace lookup yet.

- [ ] **RED:** `ZIPIndexTests.testHeaderAgreementAndOwnership` asserts field/name/CRC/size disagreements, duplicate ownership, overlap with headers/CD/EOCD and unindexed local members yield `UVK-ARC-002`; invalid local lengths yield `UVK-ARC-001`. `testRecordMappingBoundary` accepts aligned extras/directory-before-root, rejects established hidden members, and marks self-extracting prefixes/unrecognized layouts unsupported. Payload bytes containing ZIP signatures must not be mistaken for hidden members.

  ```swift
  XCTAssertNil(try ZIPIndex.build(directory: directory, reader: overlapReader, diagnostics: diagnostics))
  XCTAssertEqual(diagnostics.finish().0.map(\.ruleID), ["UVK-ARC-002"])
  ```
- [ ] Run `swift test --filter ZIPIndexTests`; expect missing index/ownership checks.
- [ ] **GREEN:** Map each local header once, compare all relevant local/CD fields, sort validated intervals, and walk the supported physical record layout. Skip known payload ranges rather than searching arbitrary payload bytes for signatures. Unknown gaps/layouts are limitations unless unindexed ownership is established. Stop dependent scans if trustworthy mapping is unavailable.
- [ ] Run `swift test --filter ZIPIndexTests`; expect no invalid payload range escapes and exact error/limitation distinctions.
- [ ] `git add Sources/USDZValidation/Archive/ZIPIndex.swift Tests/USDZValidationTests/ZIPIndexTests.swift Tests/TestSupport/ArchiveRecipe.swift Tests/Fixtures/manifest.json`; `git commit -m "feat: validate ZIP local record ownership"`.

### Task 7: Stored payload integrity and bomb rejection [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security,performance]

**Acceptance criteria:** AC-05, AC-14, AC-28. **Depends on:** 6. **Risk:** compressed/forged sizes must never reach inflation or payload interpretation.

**Files:** Create `Sources/USDZValidation/Archive/StoredPayload.swift`, `Tests/USDZValidationTests/StoredPayloadTests.swift`; modify `Tests/TestSupport/ArchiveRecipe.swift`, `Tests/Fixtures/manifest.json`.

**Interfaces:** `StoredPayload.check(entry: ZIPEntry, reader: BoundedReader, diagnostics: NativeDiagnostics) throws -> Bool` returns eligibility for content inspection; internal streaming CRC-32 accepts chunks, never whole-entry Data.

- [ ] **RED:** `StoredPayloadTests.testSeparateIntegrityRules` asserts IDs `UVK-ARC-003/004/005/006` for CRC, method/unequal sizes, encryption and payload misalignment respectively. `testBombMetadataNeverInterpreted` covers method 8, extreme ratios, zero compressed/nonzero expanded bytes, oversized declarations and checked aggregate overflow; `XCTAssertEqual(payloadReadCount, 0)` for ineligible entries. Zero/zero stored data is permitted; CRC/alignment checks have their defined applicability.

  ```swift
  XCTAssertFalse(try StoredPayload.check(entry: compressedEntry, reader: reader, diagnostics: diagnostics))
  XCTAssertEqual(payloadReadCount, 0)
  XCTAssertEqual(diagnostics.finish().0.map(\.ruleID), ["UVK-ARC-004"])
  ```
- [ ] Run `swift test --filter StoredPayloadTests`; expect absent integrity checks.
- [ ] **GREEN:** Validate flags/sizes/limits before content access. Stream eligible CRC in at most 64 KiB chunks, charge every read, compare to recorded CRC; check actual payload offset `% 64`. Emit distinct known violations without speculative content errors. No compression/image-decoder imports or subprocess calls.
- [ ] Run `swift test --filter StoredPayloadTests`; expect known CRC vectors, boundary reads and no decompression.
- [ ] `git add Sources/USDZValidation/Archive/StoredPayload.swift Tests/USDZValidationTests/StoredPayloadTests.swift Tests/TestSupport/ArchiveRecipe.swift Tests/Fixtures/manifest.json`; `git commit -m "feat: verify stored payload integrity without decompression"`.

### Task 8: Exact safe namespace and archive entry types [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security]

**Acceptance criteria:** AC-06, AC-07, AC-14, AC-27. **Depends on:** 6–7. **Risk:** names/types must not create traversal or ambiguous targets.

**Files:** Create `Sources/USDZValidation/Archive/PackageNamespace.swift`, `Tests/USDZValidationTests/PackageNamespaceTests.swift`; modify `Tests/TestSupport/ArchiveRecipe.swift`, `Tests/Fixtures/manifest.json`.

**Interfaces:** `PackageNamespace.build(index: ZIPIndex, diagnostics: NativeDiagnostics) -> PackageNamespace?`; exact-byte `regularEntry(namedUTF8: Data) -> ZIPEntry?`, `directoryExists(namedUTF8: Data) -> Bool`, physical-order validated entries, and `defaultEntry: ZIPEntry?` as the first regular entry. Never skip an unrecognized first regular entry to select a later layer; directories alone are skipped. Never use a filesystem URL as namespace identity.

- [ ] **RED:** `PackageNamespaceTests.testUnsafeNamesAndConstructs` covers empty/NUL/control, `/`, drive, UNC, backslash, empty/dot/dotdot components, invalid UTF-8, symlink/device/FIFO/socket and nonzero directories; assert `UVK-PATH-001/003` as applicable and no filesystem access. `testExactNamespaceConflicts` covers duplicate regular/directory names, `a` plus `a/b`, implicit-parent conflicts and separate duplicate physical offsets (`UVK-PATH-002`). Case and Unicode-normalization variants remain distinct. Unsupported encodings/unknown type-host semantics yield `UVK-LIM-001`, never assumed regular.

  ```swift
  XCTAssertNotNil(namespace.regularEntry(namedUTF8: Data("A.usda".utf8)))
  XCTAssertNil(namespace.regularEntry(namedUTF8: Data("a.usda".utf8))) // fixture has A only
  ```
- [ ] Run `swift test --filter PackageNamespaceTests`; expect missing namespace/type policy.
- [ ] **GREEN:** Validate raw bytes before decoding/display. Accept ASCII or declared valid UTF-8 only. Classify supported Unix type bits or supported DOS interpretation; build a bounded map keyed by `Data` to avoid Swift String canonical-equivalence behavior. Invalidate reference lookup for any unsafe/ambiguous namespace while preserving known diagnostics.
- [ ] Run `swift test --filter PackageNamespaceTests`; expect exact-byte lookup, safe names only, no extraction or case folding.
- [ ] `git add Sources/USDZValidation/Archive/PackageNamespace.swift Tests/USDZValidationTests/PackageNamespaceTests.swift Tests/TestSupport/ArchiveRecipe.swift Tests/Fixtures/manifest.json`; `git commit -m "feat: enforce safe exact archive namespaces"`.

### Task 9: USD recognition and bounded USDA lexical scanning [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security]

**Acceptance criteria:** AC-06, AC-09, AC-10, AC-14, AC-28. **Depends on:** 7–8. **Risk:** lexical state/length errors can cause unbounded reads or fabricated references.

**Files:** Create `Sources/USDZValidation/Rules/USDLayer.swift`, `Sources/USDZValidation/Rules/USDALexer.swift`, `Tests/USDZValidationTests/USDLayerTests.swift`, `Tests/USDZValidationTests/USDALexerTests.swift`; modify `Tests/TestSupport/ArchiveRecipe.swift`, `Tests/Fixtures/manifest.json`.

**Interfaces:** `MemberKind` classifies the spec's case-insensitive suffix catalogue; `MemberClassifier.kind(nameBytes: Data) -> MemberKind`. `USDLayer.identify(entry: ZIPEntry, reader: BoundedReader, diagnostics: NativeDiagnostics) throws -> LayerKind` (`usda`, `usdc`, `unrecognized`, `unsupportedEncoding`). `USDALexer.scan(entry: ZIPEntry, reader: BoundedReader, diagnostics: NativeDiagnostics, onToken: (AssetToken) -> Void) throws`; `AssetToken` has `rawValueBytes: Data`, `layerByteOffset: UInt64`, `line: UInt64`, `column: UInt64`, delimiter kind and literal/unsupported-expression classification. Callback consumption is synchronous; never retain every token.

- [ ] **RED:** `USDLayerTests.testMagicAndSuffixBoundary` asserts `#usda 1.0`/`PXR-USDC` recognition, `.usd` magic dispatch, obvious `.usda/.usdc` mismatch `UVK-ARC-007`, synthetic USDC reference limitation `UVK-LIM-002`, and nested package `UVK-LIM-006`. `USDALexerTests.testLiteralStatesAcrossChunks` uses both delimiters, documented delimiter escapes, single/double/triple quoted strings, comments, CRLF and delimiters split across 64 KiB chunks; only real asset tokens invoke callback, with exact byte/one-based text locations. Unterminated supported literal gives `UVK-PATH-007`; unsupported text encoding gives `UVK-LIM-004`; exact 16 MiB/4 KiB/100,000 boundaries pass and one above produces `UVK-RES-001` before extra allocation/read.

  ```swift
  XCTAssertEqual(tokens.map(\.rawValueBytes), [Data("Sources/pixel.png".utf8)])
  XCTAssertEqual(tokens[0].line, 2) // one real token on line 2; decoys in comments/strings
  ```
- [ ] Run `swift test --filter 'USDLayerTests|USDALexerTests'`; expect absent recognition/lexer behavior.
- [ ] **GREEN:** Implement streaming lexical state using the pinned OpenUSD source's asset-delimiter escaping rules; document the exact accepted escape vectors in tests. Recognize expressions/templates/UDIM/package identifiers without evaluating them. Keep memory to bounded read/token buffers. A header is recognition only, not a parsed scene; never parse composition or recursively visit references.
- [ ] Run filtered tests and `swift test --sanitize=address --filter 'USDLayerTests|USDALexerTests'`; expect exact locations, bounded token memory and no false string/comment tokens.
- [ ] `git add Sources/USDZValidation/Rules/USDLayer.swift Sources/USDZValidation/Rules/USDALexer.swift Tests/USDZValidationTests/USDLayerTests.swift Tests/USDZValidationTests/USDALexerTests.swift Tests/TestSupport/ArchiveRecipe.swift Tests/Fixtures/manifest.json`; `git commit -m "feat: scan bounded USDA asset literals"`.

### Task 10: Package-only dependency resolution [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security]

**Acceptance criteria:** AC-03, AC-08, AC-09, AC-10, AC-27. **Depends on:** 8–9. **Risk:** authored paths must never escape into the host resolver/filesystem.

**Files:** Create `Sources/USDZValidation/Rules/ReferenceResolver.swift`, `Tests/USDZValidationTests/ReferenceResolverTests.swift`; modify `Tests/TestSupport/ArchiveRecipe.swift`, `Tests/Fixtures/manifest.json`.

**Interfaces:** `ReferenceResolver.check(token: AssetToken, author: ZIPEntry, namespace: PackageNamespace, diagnostics: NativeDiagnostics)` performs lookup and emits findings/coverage; it returns no host URL. Default layer is the namespace's first regular entry only when recognized as USD; do not skip an invalid first regular entry. Without an established default layer, orchestration emits the standalone-policy failure and marks dependent lookup coverage notRun rather than inventing fallback targets.

- [ ] **RED:** `ReferenceResolverTests.testAuthorAndDefaultAnchors` asserts author-relative first, default-layer-directory fallback only for unanchored names, anchored `./`/safe `../` success, missing/directory target `UVK-PATH-006`, and root escape `UVK-PATH-005`. `testUnsafeAndUnsupportedPaths` asserts absolute/scheme/drive/UNC/backslash/control `UVK-PATH-004`; empty asset is unauthored; template/expression/package identifier gives `UVK-LIM-003` without missing-target speculation. Check established unsafe prefixes even for unsupported identifiers. `testExactIdentityAndNoHostFallback` covers case/normalization/percent-byte differences and a real host file outside the package; it must never satisfy lookup. Cyclic references scan each layer once; inactive metadata tokens remain lexical-policy checks.

  ```swift
  XCTAssertEqual(safeParentFindings.count, 0)
  XCTAssertEqual(rootEscapeFindings.map(\.ruleID), ["UVK-PATH-005"])
  XCTAssertFalse(expressionFindings.contains { $0.ruleID == "UVK-PATH-006" })
  ```
- [ ] Run `swift test --filter ReferenceResolverTests`; expect absent package resolution.
- [ ] **GREEN:** Normalize path components in package bytes only, with checked root depth, no tilde/environment expansion, percent decoding or URL normalization. Keep unsupported constructs partial, established unsafe literals errors. Do not run against an unsafe namespace. Evidence uses authored token locations and safe reason codes; raw paths remain subject to disclosure policy.
- [ ] Run `swift test --filter ReferenceResolverTests`; expect exact rule IDs, target selection and zero host-reference reads.
- [ ] `git add Sources/USDZValidation/Rules/ReferenceResolver.swift Tests/USDZValidationTests/ReferenceResolverTests.swift Tests/TestSupport/ArchiveRecipe.swift Tests/Fixtures/manifest.json`; `git commit -m "feat: resolve literal references inside package boundaries"`.

### Task 11: Bounded PNG and JPEG dimensions [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security]

**Acceptance criteria:** AC-11, AC-14, AC-28. **Depends on:** 7, 9. **Risk:** malformed lengths must not reach image decoders or escape entry ranges.

**Files:** Create `Sources/USDZValidation/Rules/TextureHeaders.swift`, `Tests/USDZValidationTests/TextureHeaderTests.swift`, `Tests/TestSupport/ImageRecipes.swift`; modify `Tests/Fixtures/manifest.json`.

**Interfaces:** `TextureHeaders.inspect(entry: ZIPEntry, kind: MemberKind, reader: BoundedReader, diagnostics: NativeDiagnostics) throws -> TextureDimensions?`; positive `TextureDimensions.width/height: UInt32`. The caller only invokes this for an enabled dimension budget. Nil means error/limitation already recorded, never zero dimensions.

- [ ] **RED:** `TextureHeaderTests.testPNGAndJPEGWithoutDecode` asserts original PNG IHDR and supported JPEG SOF dimensions; JPEG SOF0/SOF1/SOF2 are supported. Truncated PNG/signature/IHDR, zero dimensions, malformed supported JPEG marker lengths and missing required fields give `UVK-BUD-007`. `testUnsupportedAndScanCap` asserts unsupported JPEG SOF variants/valid unknown variants and EXR/AVIF give `UVK-LIM-005`; a SOF wholly inside the 1,048,576-byte boundary works and a header needing another byte is partial with no further read. Pixel payload is never decoded/read for dimensions. Fixtures include length overflow and marker prefixes split across chunks.

  ```swift
  XCTAssertEqual(dimensions?.width, 16) // original 16 x 8 JPEG recipe
  XCTAssertEqual(dimensions?.height, 8)
  XCTAssertLessThanOrEqual(headerBytesRead, 1_048_576)
  ```
- [ ] Run `swift test --filter TextureHeaderTests`; expect absent bounded header inspection.
- [ ] **GREEN:** Implement signature/IHDR and checked JPEG marker walk under entry/chunk/scan limits. Distinguish independently malformed supported records from unknown variants or cap exhaustion. Preserve byte-budget eligibility when dimensions are unavailable. Use original deterministic header/image recipes with manifest metadata.
- [ ] Run `swift test --filter TextureHeaderTests` and `swift test --sanitize=address --filter TextureHeaderTests`; expect bounded reads and precise error/coverage reasons.
- [ ] `git add Sources/USDZValidation/Rules/TextureHeaders.swift Tests/USDZValidationTests/TextureHeaderTests.swift Tests/TestSupport/ImageRecipes.swift Tests/Fixtures/manifest.json`; `git commit -m "feat: inspect texture dimensions without pixel decoding"`.

### Task 12: Strict bounded budget configuration [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security]

**Acceptance criteria:** AC-12, AC-13, AC-14, AC-27. **Depends on:** 1, 4. **Risk:** permissive JSON parsing can bypass the declared policy contract.

**Files:** Create `Sources/USDZValidation/Rules/BudgetConfiguration.swift`, `Tests/USDZValidationTests/BudgetConfigurationTests.swift`.

**Interfaces:** Public `BudgetConfiguration.decode(_ bytes: Data) throws -> WarningBudgets`. The decoder validates size before parsing and shares Task 1's native budget validation. CLI loads the explicit config file with the same 64 KiB read bound in Task 20.

- [ ] **RED:** `BudgetConfigurationTests.testStrictShapeAndNumbers` asserts exactly required top-level `schemaVersion` and `budgets`, version 1, positive signed-64-bit integers, omitted defaults and null disabling. Reject unknown/duplicate keys at both levels (including `fileBytes` and `file\u0042ytes` aliases), booleans, fractional/exponent numeric spellings, zero, negatives, integer overflow, malformed UTF-8 and trailing data. `testBoundedBeforeAsset` asserts 65,536-byte valid whitespace-padded config is accepted, 65,537 rejected, huge numeric lexemes do not allocate unbounded integers, and a spy asset opener/tool runner remains unused on failure. Config attempts to supply safety/profile/tool fields fail.

  ```swift
  XCTAssertThrowsError(try BudgetConfiguration.decode(duplicateEscapedKeyJSON))
  XCTAssertNil(try BudgetConfiguration.decode(nullDimensionJSON).textureMaxDimension)
  ```
- [ ] Run `swift test --filter BudgetConfigurationTests`; expect missing strict decoder/rejections.
- [ ] **GREEN:** Implement a small bounded JSON tokenizer for this fixed shape, decoding keys before duplicate detection and accepting integer lexical syntax only. No full JSON framework or new dependency. Return typed privacy-safe config errors, never generic OS/parser descriptions. Native/CLI effective values must match.
- [ ] Run `swift test --filter BudgetConfigurationTests`; expect all rejection classes and exact defaults/null behavior.
- [ ] `git add Sources/USDZValidation/Rules/BudgetConfiguration.swift Tests/USDZValidationTests/BudgetConfigurationTests.swift`; `git commit -m "feat: validate strict versioned budget configuration"`.

### Task 13: Budget and profile evaluation [size: M | risk: none | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-03, AC-11, AC-12, AC-17. **Depends on:** 9–12.

**Files:** Create `Sources/USDZValidation/Rules/BudgetRules.swift`, `Tests/USDZValidationTests/BudgetRulesTests.swift`, `Tests/USDZValidationTests/ProfileTests.swift`.

**Interfaces:** `BudgetRules.evaluate(archiveBytes: UInt64, entries: [ZIPEntry], dimensions: [UInt64: TextureDimensions], configuration: ValidationConfiguration, diagnostics: NativeDiagnostics)` uses physical local-header offset as dimension-map key. `ProfileRules.evaluate(entries: [ZIPEntry], layerKinds: [UInt64: LayerKind], profile: Profile, diagnostics: NativeDiagnostics)` lives in the same focused rule file. Byte counts derive from validated stored metadata; no content reads here.

- [ ] **RED:** `BudgetRulesTests.testEveryThreshold` tests below/equal/above all six exact defaults and custom thresholds, asserting `UVK-BUD-001…006` only for strict excess. Null disables only its budget; directories are excluded from file/texture counts; unreferenced PNG/JPEG/EXR/AVIF count once; checked totals cannot overflow. `ProfileTests.testFrozenAppleAdvice` asserts USDA `UVK-APL-001` and EXR/AVIF `UVK-APL-002` only for Apple profile, both warning-level; general profile and binary/PNG/JPEG cases have no Apple findings. Disabling dimensions removes only that requested coverage requirement.

  ```swift
  XCTAssertFalse(atThresholdFindings.contains { $0.ruleID == "UVK-BUD-006" })
  XCTAssertTrue(aboveThresholdFindings.contains { $0.ruleID == "UVK-BUD-006" })
  XCTAssertTrue(appleFindings.allSatisfy { $0.severity == .warning })
  ```
- [ ] Run `swift test --filter 'BudgetRulesTests|ProfileTests'`; expect missing evaluators/assertions.
- [ ] **GREEN:** Implement table-driven comparisons with fixed budget-key discriminators; thresholds/wording are evidence, not identity. Evaluate default-layer/suffix policies `UVK-POL-001/002` using Task 9 classifications. Keep recognized nested packages as limitations. Never imply actual GPU memory, material use or exhaustive Apple support.
- [ ] Run filtered tests; expect exact IDs/counts/profile applicability and no duplicate texture totals.
- [ ] `git add Sources/USDZValidation/Rules/BudgetRules.swift Tests/USDZValidationTests/BudgetRulesTests.swift Tests/USDZValidationTests/ProfileTests.swift`; `git commit -m "feat: evaluate budgets and frozen profile advice"`.

### Task 14: Native inspection orchestration [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security,performance]

**Acceptance criteria:** AC-03, AC-04, AC-06, AC-10, AC-14, AC-23, AC-27. **Depends on:** 4–13. **Risk:** prerequisite mistakes could scan unsafe content or erase coverage gaps.

**Files:** Create `Sources/USDZValidation/NativeEngine.swift`, `Tests/USDZValidationTests/NativeEngineTests.swift`.

**Interfaces:** `NativeEngine.inspect(snapshot: FileSnapshot, configuration: ValidationConfiguration) throws -> NativeResult`; `NativeResult` holds safe input metadata, `findings: [Finding]`, `coverage: Coverage`, and `containerSafeForExternal: Bool`. Use the one descriptor and shared ledger. Later Task 19 owns the public facade/report assembly.

- [ ] **RED:** `NativeEngineTests.testCompleteOriginalPackage` validates the committed fixture: empty blocking findings, selected coverage complete, no tool probes. `testPrerequisitesAndIndependentResults` asserts unsafe namespace/index stops reference scans without missing-target cascades; CRC/structure errors forbid external eligibility; byte budgets survive unavailable dimensions; USDC retains structure/byte results and reference partial even with incomplete accepted. `testInvalidFirstRegularNeverSkipped` puts a PNG before a valid layer and asserts `UVK-POL-001`, no later replacement default layer and no speculative reference failures. `testFixedDiscoveryAndChanges` repeats corpus/relocation results and tests detectable descriptor metadata change before return as operational error.

  ```swift
  XCTAssertTrue(result.findings.isEmpty) // complete original USDA fixture
  XCTAssertTrue(result.containerSafeForExternal)
  XCTAssertEqual(first.findings, relocated.findings)
  ```
- [ ] Run `swift test --filter NativeEngineTests`; expect missing engine integration.
- [ ] **GREEN:** Execute phases in fixed physical-entry order: validated config/file, directory/index, namespace/integrity, USD identification/lexical references, enabled texture headers, budgets/advice, diagnostics finalization. Gate scanners by explicit prerequisites; discover independent known findings without guessing. Stream layers and headers, retain metadata only, verify unchanged before returning. Native code has no subprocess reachability.
- [ ] Run `swift test --filter NativeEngineTests` then `swift test`; expect deterministic native suite, no USD tools invoked and correct partial/notRun reasons.
- [ ] `git add Sources/USDZValidation/NativeEngine.swift Tests/USDZValidationTests/NativeEngineTests.swift`; `git commit -m "feat: orchestrate native validation with explicit coverage"`.

### Task 15: Privacy-safe text and capped report output [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security,performance]

**Acceptance criteria:** AC-14, AC-20, AC-22, AC-27. **Depends on:** 3–4, 14. **Risk:** attacker-controlled strings can disclose paths, inject controls or expand output memory.

**Files:** Create `Sources/USDZValidation/Reporting/Privacy.swift`, `Sources/USDZValidation/Reporting/CappedBuffer.swift`, `Sources/USDZValidation/Reporting/TextReport.swift`, `Sources/USDZValidation/Reporting/ReportEncoder.swift`, `Tests/USDZValidationTests/PrivacyTests.swift`, `Tests/USDZValidationTests/TextReportTests.swift`, `Tests/USDZValidationTests/CappedBufferTests.swift`; modify `Sources/USDZValidation/NativeDiagnostics.swift` to enforce bounded messages/evidence before retention.

**Interfaces:** `Privacy.render(_ value: String, kind: DisclosureKind, sensitive: Bool) -> String` handles basename/member/reference/error/tool detail policies. `CappedBuffer.init(limit: Int = 33_554_432)`, `append(_ bytes: Data) throws`, `finish() -> Data`; production ceiling includes final LF and is never user configurable. Public `ReportFormat` (`text`, `json`, `sarif`), `ReportEncoder.encode(_ report: ValidationReport, format: ReportFormat) throws -> Data`; Task 15 implements text, subsequent tasks add formats. No report is emitted incrementally to stdout.

- [ ] **RED:** `PrivacyTests.testMaliciousNamesAndDisclosure` asserts ESC/newline/bidi/control display escapes, no raw absolute input/config/output/reference or tool paths by default, bounded basename, and opt-in sensitive strings still escaped/capped. `TextReportTests.testEquivalentMeaning` asserts category, severity, provenance, coverage, gate and external status remain visible. `CappedBufferTests.testExactLimits` covers message 1,024 and evidence 4,096 UTF-8 bytes at/above boundary with explicit truncation markers inside the cap, including multibyte/surrogate-sensitive boundaries; report exactly 33,554,432 succeeds and next byte throws operational encoding error without partial output.

  ```swift
  XCTAssertFalse(defaultText.contains("/Users/fixture-owner/"))
  XCTAssertFalse(defaultText.contains("\u{001b}"))
  XCTAssertThrowsError(try fullBuffer.append(Data([0x0a]))) // already exactly 32 MiB
  ```
- [ ] Run `swift test --filter 'PrivacyTests|TextReportTests|CappedBufferTests'`; expect missing disclosure/cap behavior.
- [ ] **GREEN:** Apply shared redaction before default serialization; retain identity from original bounded bytes separately. Use useful reason codes rather than leaking raw POSIX/Foundation text. Write stable English text order and a capped in-memory output buffer; no full-size intermediate string that bypasses the cap. Sensitive details affect presentation only, not native IDs or coverage.
- [ ] Run filtered tests; expect valid escaped text, preserved result meaning, exact byte ceilings and controlled encoding failure.
- [ ] `git add Sources/USDZValidation/Reporting/Privacy.swift Sources/USDZValidation/Reporting/CappedBuffer.swift Sources/USDZValidation/Reporting/TextReport.swift Sources/USDZValidation/Reporting/ReportEncoder.swift Sources/USDZValidation/NativeDiagnostics.swift Tests/USDZValidationTests/PrivacyTests.swift Tests/USDZValidationTests/TextReportTests.swift Tests/USDZValidationTests/CappedBufferTests.swift`; `git commit -m "feat: render bounded privacy-safe text reports"`.

### Task 16: Canonical JSON report and catalogue v1 [size: M | risk: data | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: data]

**Acceptance criteria:** AC-16, AC-17, AC-20, AC-21, AC-22. **Depends on:** 15. **Risk:** JSON shape/escaping are public compatibility contracts.

**Files:** Create `Sources/USDZValidation/Reporting/CanonicalJSON.swift`, `Sources/USDZValidation/Reporting/JSONReport.swift`, `Tests/USDZValidationTests/JSONReportTests.swift`, `Tests/Goldens/report-complete-v1.json`, `Tests/Goldens/report-incomplete-v1.json`, `Tests/Goldens/report-operational-v1.json`; modify `Sources/USDZValidation/Reporting/ReportEncoder.swift`, `Tests/Goldens/rule-catalogue-v1.json` only to encode the decided envelope (no rule-meaning changes).

**Interfaces:** Internal `JSONValue` supports object, array, string, signed/unsigned checked integer, bool and null; `CanonicalJSON.encode(_ value: JSONValue, into: CappedBuffer) throws`. `JSONReport.value(_ report: ValidationReport) -> JSONValue`. Public `CatalogueFormat` (`text`, `json`) and `ReportEncoder.encodeCatalogue(profile: Profile, format: CatalogueFormat) throws -> Data`. Catalogue envelope is `schemaVersion`, `tool`, `profile`, `rules`; descriptor fields follow Task 1. Report envelope follows the spec exactly.

- [ ] **RED:** `JSONReportTests.testCanonicalV1Envelope` asserts required keys/nulls/empty arrays, default sensitive-key omission, correct integer counts, native/external separation and compact UTF-8 plus exactly one LF. `testEscapingAndRelocation` asserts lexicographic UTF-8 object-key order, deterministic minimal quote/backslash/control escapes, no escaped solidus requirement, exact bytes across rerun/relocation with basename preserved, and stable native IDs after rename. Compare complete/incomplete/operational reports and catalogue to committed goldens; no timestamp/host/temporary path/raw external text.

  ```swift
  XCTAssertEqual(output, goldenBytes)
  XCTAssertEqual(output, relocatedOutput)
  XCTAssertEqual(output.last, 0x0a)
  ```
- [ ] Run `swift test --filter JSONReportTests`; expect absent encoder or golden mismatch.
- [ ] **GREEN:** Emit JSON directly into the capped buffer, not via platform-variable pretty-printing. Use unescaped valid non-control UTF-8, no floats, compact separators and sorted keys; cap all intermediates. Encode every declared field, null unavailable values, omit sensitive-only fields unless requested. Golden bytes are reviewed expected compatibility data; never blindly regenerate on test failure.
- [ ] Run `swift test --filter JSONReportTests`; expect exact document/golden bytes. Schema validation follows in Task 22 and is not yet claimed.
- [ ] `git add Sources/USDZValidation/Reporting/CanonicalJSON.swift Sources/USDZValidation/Reporting/JSONReport.swift Sources/USDZValidation/Reporting/ReportEncoder.swift Tests/USDZValidationTests/JSONReportTests.swift Tests/Goldens/report-complete-v1.json Tests/Goldens/report-incomplete-v1.json Tests/Goldens/report-operational-v1.json Tests/Goldens/rule-catalogue-v1.json`; `git commit -m "feat: encode deterministic JSON v1 reports"`.

### Task 17: SARIF 2.1.0 with real archive locations [size: M | risk: data | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: data]

**Acceptance criteria:** AC-16, AC-20, AC-21, AC-22, AC-26. **Depends on:** 16. **Risk:** misleading SARIF location/provenance makes downstream findings unusable.

**Files:** Create `Sources/USDZValidation/Reporting/SARIFReport.swift`, `Tests/USDZValidationTests/SARIFReportTests.swift`, `Tests/Goldens/native-v1.sarif`, `Tests/Goldens/external-unavailable-v1.sarif`, `Tests/Goldens/external-failure-v1.sarif`; modify `Sources/USDZValidation/Reporting/ReportEncoder.swift`.

**Interfaces:** `SARIFReport.value(_ report: ValidationReport) -> JSONValue` uses the same canonical encoder. First run is native; external run exists only when requested, even when unavailable. `$schema` is `https://docs.oasis-open.org/sarif/sarif/v2.1.0/os/schemas/sarif-schema-2.1.0.json`, pinned locally in Task 22. Package URI is percent-encoded relative basename; physical byte offsets are absolute archive offsets; layer lines/offsets belong in logical locations/properties, never ZIP physical line regions.

- [ ] **RED:** `SARIFReportTests.testRunsAndLocations` asserts version 2.1.0/OASIS schema URI, stable rules/levels/categories, `partialFingerprints["uvkOccurrence/v1"]`, actual byte regions, and no invented binary line numbers. `testInvocationAndCoverage` distinguishes native execution completion from check completeness, unsuccessful external invocation from completed asset failure, and no external run when disabled. Assert profile/evidence/coverage/gate/provenance properties and omission (not null) of SARIF-unavailable fields. Compare three goldens and result meaning to JSON/text.

  ```swift
  XCTAssertEqual(nativeOnlyRuns.count, 1)
  XCTAssertEqual(requestedUnavailableRuns.count, 2)
  XCTAssertEqual(output, goldenBytes)
  ```
- [ ] Run `swift test --filter SARIFReportTests`; expect absent SARIF encoder/golden differences.
- [ ] **GREEN:** Implement native/external descriptors/counts/invocations separately. Preserve external `USDCK-001` aggregate, safe diagnostic metadata and opt-in bounded raw diagnostics. Use schema-valid SARIF notification/invocation fields; defer claims of schema conformance until Task 22 validates locally.
- [ ] Run `swift test --filter SARIFReportTests`; expect stable golden bytes, native/external separation and real archive locations.
- [ ] `git add Sources/USDZValidation/Reporting/SARIFReport.swift Sources/USDZValidation/Reporting/ReportEncoder.swift Tests/USDZValidationTests/SARIFReportTests.swift Tests/Goldens/native-v1.sarif Tests/Goldens/external-unavailable-v1.sarif Tests/Goldens/external-failure-v1.sarif`; `git commit -m "feat: emit SARIF with separate provenance and coverage"`.

### Task 18: Bounded child lifecycle and concurrent pipe draining [size: M | risk: concurrency | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: concurrency,security]

**Acceptance criteria:** AC-24, AC-25, AC-28. **Depends on:** 1, 4, 15. **Risk:** child/pipe races can deadlock, leak a child or exceed capture limits. This task owns concurrency only; adapter policy follows separately.

**Files:** Create `Sources/USDZValidation/External/ProcessRunner.swift`, `Tests/USDZValidationTests/ProcessRunnerTests.swift`, `Tests/TestSupport/ProcessScenarios.swift`; modify `Tests/Fixtures/manifest.json` for helper-source provenance.

**Interfaces:** Internal `ProcessRequest` has executable URL, argument array, exact environment, working directory, timeout and `outputLimit: Int`. `ProcessResult` has `outcome` (`completed`, `launchFailed`, `timedOut`, `outputLimitExceeded`), exit code/signal, `stdout: Data`, `stderr: Data`, counts/presence, truncation and termination reason. `ProcessRunner.run(_ request: ProcessRequest) -> ProcessResult` returns controlled failures; no public arbitrary-executable API. Internal pipe capture exposes a bounded finish/cancel operation for testing pipes whose write end remains open after child exit; tests hold that extra writer themselves and close it in cleanup. The library facade remains synchronous.

- [ ] **RED:** `ProcessRunnerTests.testConcurrentPipesAndCombinedCap` fills both streams past pipe capacity; assert completion without deadlock and combined retained data at/below cap. `testTimeoutKillAndReap` uses short test deadlines and a shell-builtins-only controlled child that ignores TERM; assert forced termination begins within one second, child is reaped and drains finish within a bounded grace, including inherited/open-pipe simulation through the test seam. Test launch errors, abnormal signal, output overflow during probe/validation, exact capture boundary and simultaneous child exit/timer events. Tests may run fixed `/bin/sh` scripts composed solely of test constants; production adapter never invokes a shell and no new helper product is added.

  ```swift
  XCTAssertEqual(result.outcome, .timedOut) // TERM-ignoring child, short test deadline
  XCTAssertLessThanOrEqual(result.stdout.count + result.stderr.count, request.outputLimit)
  XCTAssertTrue(childReaped)
  ```
- [ ] Run `swift test --filter ProcessRunnerTests`; expect missing runner/lifecycle assertions. Each test has an outer XCTest deadline so failures cannot hang the suite.
- [ ] **GREEN:** Drain stdout/stderr independently, synchronize one combined counter and one terminal-state transition, stop retaining at cap, terminate then SIGKILL after at most one second, reap and close/cancel read handles under a finite drain deadline. Choose deterministic precedence for simultaneous observations: output overflow, timeout, then normal completion; do not let callback order select report state. Preserve separate stream bytes; do not promise reproducible cross-stream interleaving. Use Swift 6-safe synchronization with no data races.
- [ ] Run filtered tests repeatedly within the test's bounded scenario loop and `swift test --sanitize=address --filter ProcessRunnerTests`; expect no blocked pipe, double completion, orphan or unbounded wait. Do not add a timing-sensitive production report field.
- [ ] `git add Sources/USDZValidation/External/ProcessRunner.swift Tests/USDZValidationTests/ProcessRunnerTests.swift Tests/TestSupport/ProcessScenarios.swift Tests/Fixtures/manifest.json`; `git commit -m "feat: bound external process capture and termination"`.

### Task 19: Fixed checker adapter and reusable public validator [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security]

**Acceptance criteria:** AC-01, AC-03, AC-10, AC-19, AC-23, AC-24, AC-25, AC-26, AC-27. **Depends on:** 14–18. **Risk:** accidental execution, inherited environment or mixed provenance can violate the native boundary.

**Files:** Create `Sources/USDZValidation/External/USDCheckerAdapter.swift`, `Sources/USDZValidation/Validator.swift`, `Tests/USDZValidationTests/USDCheckerAdapterTests.swift`, `Tests/USDZValidationTests/ValidatorTests.swift`, `Tests/USDZValidationTests/InstalledCheckerSmokeTests.swift`, `Tests/LibraryConsumerTests/LibraryConsumerTests.swift`; modify `Package.swift` to add the separate library-only consumer test target.

**Interfaces:** Internal `USDCheckerAdapter.init(execute: @escaping (ProcessRequest) -> ProcessResult, isExecutable: @escaping (URL) -> Bool)` enables unit fakes; production initializer fixes these to the runner/filesystem check. `run(fileAt: URL, configuration: ValidationConfiguration, nativeEligible: Bool) -> ExternalCheck`. Public `Validator.init()` and `validate(fileAt: URL, configuration: ValidationConfiguration) throws -> ValidationReport`. Internal initializer can inject adapter/native execution only for tests. Public `ValidationReport.init(failure: ValidationError, fileAt: URL, configuration: ValidationConfiguration)` lets CLI render a typed operational/internal failure consistently. No public tool override.

- [ ] **RED:** `USDCheckerAdapterTests.testDisabledNeverProbes` asserts availability and executor call counts both zero. `testEveryAdapterState` fakes missing, unknown/version probe failure, exact supported version, unsafe skipped, launch/signal failure, probe/validation timeout/output cap, successful exit 0 and nonzero `USDCK-001`; assert all status/phase/availability/version/outcome combinations, intended args, environment, working directory, caps and provenance. Nonzero is one opaque aggregate; no diagnostic parsing. `ValidatorTests.testNativeSubtreesUnchanged` asserts native findings/coverage equality with adapter disabled/enabled and no USDC upgrade. Library consumer uses only `import USDZValidation` and asserts complete fixture gate `0`; package dependency graph excludes CLI. Installed smoke uses `XCTSkip` unless explicitly enabled; never call it in unit fakes.

  ```swift
  XCTAssertEqual(executorCalls, 0) // disabled request
  XCTAssertEqual(request.environment, ["PATH": "/usr/bin:/bin", "LANG": "C", "LC_ALL": "C"])
  XCTAssertEqual(enabled.nativeFindings, disabled.nativeFindings)
  XCTAssertEqual(enabled.coverage, disabled.coverage)
  ```
- [ ] Run `swift test --filter 'USDCheckerAdapterTests|ValidatorTests|LibraryConsumerTests'`; expect missing facade/adapter assertions, without touching installed USD tools.
- [ ] **GREEN:** Validate configuration before open/probe; native inspection and file-change checks precede optional tool eligibility. Disabled does not even check executable existence. Unsafe inputs are `skippedUnsafeInput` without a probe; otherwise fixed `/usr/bin/usdchecker --version` selects exact supported contract, followed by spec arguments. Keep raw capped diagnostics private by default and use Task 3 external identity. Build report through one gate policy; typed I/O errors propagate. Check detectable input changes after external execution too. Add opt-in `UVK_RUN_INSTALLED_CHECKER=1` smoke against the original valid fixture, recording observed version/outcome or explicit skipped/unsupported; do not use smoke as a native correctness oracle.
- [ ] Run filtered tests then `swift test`; expect native/fake-adapter suites pass, real-tool smoke clearly **skipped** by default. Explicit later smoke command: `UVK_RUN_INSTALLED_CHECKER=1 swift test --filter InstalledCheckerSmokeTests`; preserve actual version/status, never label skipped as passed.
- [ ] `git add Package.swift Sources/USDZValidation/External/USDCheckerAdapter.swift Sources/USDZValidation/Validator.swift Tests/USDZValidationTests/USDCheckerAdapterTests.swift Tests/USDZValidationTests/ValidatorTests.swift Tests/USDZValidationTests/InstalledCheckerSmokeTests.swift Tests/LibraryConsumerTests/LibraryConsumerTests.swift`; `git commit -m "feat: expose validator and explicit installed checker adapter"`.

### Task 20: CLI process contracts, streams and exit classes [size: M | risk: other | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-03, AC-13, AC-17, AC-18, AC-19, AC-20, AC-22, AC-23, AC-27. **Depends on:** 19. **Risk:** argument/stream/exit mistakes break CI integration even when the engine is correct.

**Files:** Modify `Sources/USDZValidatorCLI/Command.swift`, `Sources/USDZValidation/Validator.swift` (compile-only test constructor); create `Sources/USDZValidatorCLI/CommandDriver.swift`, `Sources/USDZValidatorCLI/ProcessTestHooks.swift`, `Tests/USDZValidatorCLITests/CLIArgumentTests.swift`, `Tests/USDZValidatorCLITests/CLIProcessTests.swift`, `Tests/TestSupport/CLIHarness.swift`, `Scripts/test-cli.sh`; modify `Package.swift` for CLI tests and `Tests/Fixtures/manifest.json` for test-helper provenance.

**Interfaces:** ArgumentParser commands `validate`, `rules`, help/version; add all spec options except report-destination integration (Task 21 owns `--output`). `CommandDriver.run(arguments: [String], streams: CLIStreams, validate: (URL, ValidationConfiguration) throws -> ValidationReport) -> Int32`; production injects `Validator.validate`, test driver injects fixed failures. `CLIStreams` supplies throwing byte writes for stdout/stderr. Test-only `CLIHarness.run(arguments: [String], environment: [String: String], executable: URL) throws -> CLIResult`; result has `stdout: Data`, `stderr: Data`, `exitCode: Int32`, with a bounded deadline. Standard executable path uses `.build/debug` or `.build/release` matching the suite, overridable only in test harness environment.

- [ ] **RED:** `CLIProcessTests.testInvocationAndExitMatrix` launches the actual executable for help/version/rules, zero/multiple input, `-`, URLs/directories, unknown options/profile/format, option-like path with `--`, arbitrary basename, each format and exit `0/1/2/3/64`. `testPrecedenceAndPureStreams` asserts 1 beats incomplete, warning/error threshold behavior, accepted gap retains incomplete status, invalid config has empty stdout, input I/O yields selected-format error report, and JSON/SARIF is one document plus LF with no stderr on normal asset outcomes. Test broken pipe returns 3 without SIGPIPE crash. A separately compiled test build supplies fixed internal failure for process exit 70 and fake checker unavailable/success/failure, asserting stdout/stderr and `--allow-incomplete` behavior for each. Normal release build ignores all seam environment values.

  ```swift
  XCTAssertEqual(invalidInvocation.exitCode, 64)
  XCTAssertTrue(invalidInvocation.stdout.isEmpty)
  XCTAssertFalse(invalidInvocation.stderr.isEmpty)
  XCTAssertEqual(injectedInternalFailure.exitCode, 70)
  ```
- [ ] Create `Scripts/test-cli.sh` as the test harness described below, then run `swift build --build-tests` and `swift test --filter 'CLIArgumentTests|CLIProcessTests'`; expect missing CLI options/contracts. Hook-only scenarios must explicitly skip until their test executable exists, not count as passing.
- [ ] **GREEN:** Implement parser/driver with usage/config errors 64, explicit typed error mapping and no raw error strings. Load only explicit bounded regular config before asset inspection, rejecting special files without blocking. Reject stdin/URLs/batch, allow `--` filenames, report findings only in report, suppress SIGPIPE termination and catch write failures. `ProcessTestHooks.swift` is wholly guarded by `#if UVK_PROCESS_TESTING`; test-only environment `UVK_CLI_TEST_SCENARIO` selects `internalFailure`, `checkerUnavailable`, `checkerSuccess`, or `checkerFailure`, with no arbitrary executable/args or production CLI option. Under the same compile guard only, `Validator.processTestScenario(_ scenario: String) throws -> Validator` constructs a facade using internal fixed adapter fakes (or a fixed internal failure), so process tests still exercise real orchestration/gating. Normal builds contain neither this constructor nor hook behavior. Script builds normal tests and an isolated `.build/process-tests` executable using `swift build --scratch-path .build/process-tests -Xswiftc -DUVK_PROCESS_TESTING --product usdz-validator`, exports harness-only `UVK_CLI_EXECUTABLE`/`UVK_CLI_TEST_EXECUTABLE`, and runs `swift test --skip-build --filter 'CLIArgumentTests|CLIProcessTests'`. Check `--scratch-path`/`-Xswiftc` on the intended baseline when available as deferred follow-up (current help verified).
- [ ] Run `sh Scripts/test-cli.sh`; expect all exit/stream classes actually exercised, no hook-case skips and no installed checker execution. Run `swift test --filter CLIArgumentTests` for the in-process parser/config opener spies. Script failure is not a golden-update instruction.
- [ ] `git add Package.swift Sources/USDZValidation/Validator.swift Sources/USDZValidatorCLI/Command.swift Sources/USDZValidatorCLI/CommandDriver.swift Sources/USDZValidatorCLI/ProcessTestHooks.swift Tests/USDZValidatorCLITests/CLIArgumentTests.swift Tests/USDZValidatorCLITests/CLIProcessTests.swift Tests/TestSupport/CLIHarness.swift Scripts/test-cli.sh Tests/Fixtures/manifest.json`; `git commit -m "feat: add CI CLI and process-level exit contracts"`.

### Task 21: Atomic safe report destinations [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security]

**Acceptance criteria:** AC-18, AC-20, AC-27. **Depends on:** 20. **Risk:** destination aliases or failed writes can corrupt the input/previous report.

**Files:** Create `Sources/USDZValidatorCLI/ReportDestination.swift`, `Tests/USDZValidatorCLITests/ReportDestinationTests.swift`; modify `Sources/USDZValidatorCLI/Command.swift`, `Sources/USDZValidatorCLI/CommandDriver.swift`, `Tests/USDZValidatorCLITests/CLIProcessTests.swift`, `Sources/USDZValidatorCLI/ProcessTestHooks.swift`.

**Interfaces:** `ReportDestination.write(_ completeReport: Data, to: URL, input: URL) throws` performs no report encoding; existing stdout path remains in driver. Internal filesystem-operation seam permits deterministic write/rename failures; no public arbitrary file-operation API. Add exact spec `--output PATH` option.

- [ ] **RED:** `ReportDestinationTests.testAliasesAndReplacement` rejects input by normalized path/opened device/inode, hard link, final symlink, directory/nonregular destination and missing parent; prior report/input bytes remain identical. A normal existing regular report is atomically replaced with a complete document. `testFailurePreservesDestination` injects temp-write/close/rename failures, detects races when metadata changes, removes owned temporary files and asserts old content preserved. CLI process tests assert `--output` means stdout empty, errors stderr/3, and encoding-cap failure leaves old output unchanged.

  ```swift
  XCTAssertThrowsError(try ReportDestination.write(reportBytes, to: hardLinkToInput, input: input))
  XCTAssertEqual(try Data(contentsOf: input), originalInput)
  XCTAssertEqual(try Data(contentsOf: failedDestination), previousReport)
  ```
- [ ] Run `swift test --filter ReportDestinationTests` and `sh Scripts/test-cli.sh`; expect missing safe destination implementation/contracts.
- [ ] **GREEN:** Encode and cap first, validate destination/input identities, create exclusive same-directory temporary report with safe permissions, write completely, close, recheck destination/identity and atomically rename. Do not follow symlinks or create parent directories. Clean up owned report temp files on failure; never create temporary asset files. Do not claim protection from an unrestricted malicious filesystem writer beyond detectable checks. Diagnostics redact destination/config paths.
- [ ] Run `swift test --filter ReportDestinationTests` and `sh Scripts/test-cli.sh`; expect complete replacements, unchanged old bytes on all pre-replacement failures and no leaked temps.
- [ ] `git add Sources/USDZValidatorCLI/ReportDestination.swift Sources/USDZValidatorCLI/Command.swift Sources/USDZValidatorCLI/CommandDriver.swift Sources/USDZValidatorCLI/ProcessTestHooks.swift Tests/USDZValidatorCLITests/ReportDestinationTests.swift Tests/USDZValidatorCLITests/CLIProcessTests.swift`; `git commit -m "feat: write reports through safe atomic replacement"`.

### Task 22: Offline schemas and golden compatibility verification [size: M | risk: data | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: data]

**Acceptance criteria:** AC-12, AC-13, AC-16, AC-17, AC-20, AC-21, AC-22, AC-26. **Depends on:** 16–17, 19–21. **Risk:** schema/model drift or casually updated goldens can break consumers.

**Files:** Create `Schemas/report-v1.schema.json`, `Schemas/catalogue-v1.schema.json`, `Schemas/budget-config-v1.schema.json`, `Tests/Schemas/sarif-2.1.0.schema.json`, `Tests/Schemas/manifest.json`, `Tests/Goldens/external-success-v1.json`, `Tests/Goldens/external-failure-v1.json`, `Examples/budgets.json`, `Examples/report-v1.json`, `Examples/catalogue-v1.json`, `Examples/report.sarif`, `Tools/requirements-schema.in`, `Tools/requirements-schema.lock`, `Tools/README.md`, `Scripts/verify-schemas.py`, `Tests/test_schema_contracts.py`, `Tests/USDZValidationTests/GoldenCompatibilityTests.swift`, `NOTICE`. Existing goldens eligible for reviewed corrections: `Tests/Goldens/report-complete-v1.json`, `Tests/Goldens/report-incomplete-v1.json`, `Tests/Goldens/report-operational-v1.json`, `Tests/Goldens/rule-catalogue-v1.json`, `Tests/Goldens/native-v1.sarif`, `Tests/Goldens/external-unavailable-v1.sarif`, `Tests/Goldens/external-failure-v1.sarif`.

**Interfaces:** `Scripts/verify-schemas.py --self-test` validates schemas, examples and goldens using pinned `jsonschema` with an explicit local registry, rejecting unresolved remote refs. Default invocation validates the checked-in corpus; `--directory PATH` additionally validates exported reports by documented filename/format. Swift golden suite exports fixed reports only when test-only `UVK_COMPAT_EXPORT_DIR` is set. Golden coverage includes each external state in JSON/SARIF as parameterized expectations, including null/omission/phase/invocation semantics; new committed bytes only for representative envelopes listed above.

- [ ] **RED:** `GoldenCompatibilityTests.testV1Compatibility` compares complete/incomplete/operational/external/canonical catalogue bytes and semantic text equivalence, rerun/relocation/rename identity invariants, special-character URI encoding and fixed fake external results. Python `SchemaContractTests` rejects missing required fields, wrong types, invalid enum/version, merged runs/provenance and schema-invalid SARIF locations; an extra optional JSON field/unknown rule ID is tolerated. `testNoRemoteResolution` proves any unregistered `$ref` fails without network. Config schema tests mirror strict values, while duplicate/trailing-data checks remain raw decoder tests (JSON Schema cannot detect those after parsing).

  ```python
  self.assertTrue(report_validator.is_valid(valid_report))
  self.assertFalse(report_validator.is_valid(report_missing_exit_code))
  self.assertFalse(sarif_validator.is_valid(report_with_invalid_byte_region))
  ```
- [ ] Run `swift test --filter GoldenCompatibilityTests`; expect missing compatibility suite/export or mismatches. Establish the hash-locked development venv using the setup below before the Python RED run, then run `.venv/bin/python -m unittest discover -s Tests -p 'test_schema_contracts.py'`; expect missing/incorrect schema or corpus-contract assertions. A package import/install failure is test-setup failure, not a behavioral RED. Once GREEN, invalid documents must be rejected and valid controls accepted.
- [ ] **GREEN:** Author Draft 2020-12 project schemas with IDs `urn:usdz-validation-kit:report:1`, `urn:usdz-validation-kit:catalogue:1`, and `urn:usdz-validation-kit:budget-config:1`; pin the published OASIS 2.1.0 SARIF schema locally, record exact source URL/SHA/license and preserve required redistribution notice. Verify license before copying. Pin `jsonschema==4.25.1` (MIT, Python >=3.9) and its entire resolved dependency graph with exact versions and artifact hashes in the lock, retaining artifacts for intended Python 3.12 and verified CPython 3.14.7 without treating wheel availability as Python 3.12 test evidence. Record dependency notices and lock-generation procedure; do not invent hashes. Install only into `.venv` with `python3 -m venv .venv` then `.venv/bin/python -m pip install --require-hashes -r Tools/requirements-schema.lock`. Schema resolution uses only locally registered resources; test execution downloads nothing. Product targets gain no Python/runtime dependency.
- [ ] Run `swift test --filter GoldenCompatibilityTests`, `.venv/bin/python Scripts/verify-schemas.py --self-test`, and `.venv/bin/python -m unittest discover -s Tests -p 'test_schema_contracts.py'`; expect valid corpus accepted, deliberately invalid corpus rejected, no remote resolution. Golden changes require explicit reviewed rationale and version/ID compatibility assessment.
- [ ] `git add Schemas/report-v1.schema.json Schemas/catalogue-v1.schema.json Schemas/budget-config-v1.schema.json Tests/Schemas/sarif-2.1.0.schema.json Tests/Schemas/manifest.json Tests/Goldens/external-success-v1.json Tests/Goldens/external-failure-v1.json Examples/budgets.json Examples/report-v1.json Examples/catalogue-v1.json Examples/report.sarif Tools/requirements-schema.in Tools/requirements-schema.lock Tools/README.md Scripts/verify-schemas.py Tests/test_schema_contracts.py Tests/USDZValidationTests/GoldenCompatibilityTests.swift NOTICE`; add any corrected existing golden by its exact filename, then `git commit -m "test: pin JSON and SARIF compatibility contracts"`.

### Task 23: Deterministic adversarial mutation corpus [size: M | risk: security | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: security]

**Acceptance criteria:** AC-04, AC-05, AC-06, AC-07, AC-09, AC-11, AC-14, AC-28, AC-29. **Depends on:** 14, 19, 22. **Risk:** interactions between individually tested parsers can expose unchecked reads.

**Files:** Create `Tests/TestSupport/MutationRecipes.swift`, `Tests/USDZValidationTests/AdversarialTests.swift`, `Scripts/test-adversarial.sh`; modify `Tests/Fixtures/manifest.json`. Fix production files only where a named failing regression demonstrates need; record each exact changed file in the task evidence/commit.

**Interfaces:** Test-only `MutationRecipes.cases(seed: UInt64) -> [MutationCase]` returns a bounded fixed set of mutations with stable IDs/recipes, not a runtime fuzzing framework. Seed `0x55564B01`; truncations at every structural field boundary plus targeted bit/length/range mutations in ZIP/USDA/PNG/JPEG. Script runs `swift test --sanitize=address --filter AdversarialTests`.

- [ ] **RED:** Create `Scripts/test-adversarial.sh` as the sanitizer test harness above. `AdversarialTests.testBoundedMutationCorpus` adds at least one interaction regression before any fix (e.g. name/extra truncation crossing a local-header boundary). Assert controlled findings/typed errors, no crash, per-case read/counter bounds, deterministic repeated output and expected unsupported-versus-malformed classification for labeled oracle cases. For mutation cases without a semantic oracle, assert invariants rather than pretending every random byte means a specific rule. No fixture writes outside temporary test directories, no extraction or tool invocation.

  ```swift
  XCTAssertEqual(first.nativeFindings, repeated.nativeFindings)
  XCTAssertLessThanOrEqual(ledger.totalReadBytes, 1_207_959_552)
  XCTAssertEqual(externalExecutionCount, 0)
  ```
- [ ] Run `sh Scripts/test-adversarial.sh`; expect the named regression to fail before its minimal fix; sanitizer/build/tool failure is not a behavioral RED. If existing code already passes all newly added cases, record that evidence and add coverage without inventing a defect.
- [ ] **GREEN:** Add the bounded mutation recipes and repair only demonstrated parser interactions, retaining checked reads/prerequisites. Manifest entries cover generator hash/license/seed/recipe and classification. Keep giant outputs/assets out of Git.
- [ ] Run `sh Scripts/test-adversarial.sh` and `swift test`; expect no crash/overread/hang and native/fake-adapter regressions passing.
- [ ] `git add Tests/TestSupport/MutationRecipes.swift Tests/USDZValidationTests/AdversarialTests.swift Scripts/test-adversarial.sh Tests/Fixtures/manifest.json`; explicitly add any regression-fixed source file, then `git commit -m "test: exercise deterministic hostile parser inputs"`.

### Task 24: Measured maximum-envelope resource acceptance [size: M | risk: other | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: performance]

**Acceptance criteria:** AC-14, AC-15, AC-28, AC-29. **Depends on:** 19–23. **Risk:** bounded individual buffers do not alone establish peak RSS/whole-invocation work.

**Files:** Create `Tests/TestSupport/ResourceRecipes.swift`, `Tests/USDZValidationTests/ResourceBoundaryTests.swift`, `Scripts/verify-resources.py`, `docs/verification/resource-results.md`; modify `Tests/Fixtures/manifest.json` and only measured bottleneck source files if necessary.

**Interfaces:** `ResourceRecipes` streams deterministic temporary files; no full-file buffer or committed large fixture. `Scripts/verify-resources.py --executable PATH --output PATH` generates cases, runs one native CLI process per case using `/usr/bin/time -l`, enforces a wall deadline, parses Darwin maximum RSS in bytes and records machine/SSD/OS/toolchain/command/corpus-hash/elapsed/RSS/exit. External checker remains disabled. ResourceBoundaryTests use `UVK_RUN_RESOURCE_TESTS=1`; otherwise explicit `XCTSkip` for expensive real-size cases, while synthetic counter boundary tests always run.

- [ ] **RED:** `ResourceBoundaryTests.testEverySafetyCeilingAtAndAbove` connects real fixtures and Task 4 instrumented sources: archive/CD/entry/aggregate/text/name/token/count/read/findings/message/evidence/config/report boundaries. Exactly-at succeeds only when other structure/limits permit; one-above stops before forbidden work. Test independent ledger/metadata boundaries separately where an exactly maximal payload plus ZIP overhead cannot fit the archive ceiling. `testMaximumEnvelopeMeasurements` covers near-512 MiB stored archive (each file <=256 MiB), 10,000 tiny entries, 16 MiB text/many tokens, header scanning and near-limit findings/report. Output-cap failure is operational with no partial report. Native cases must each stay <=268,435,456 RSS bytes and <=60 seconds on the documented host, including a controlled resource-limit rejection case.

  ```python
  assert measured_peak_rss_bytes <= 268_435_456
  assert measured_elapsed_seconds <= 60
  assert reads_after_rejected_range == reads_before_rejected_range
  ```
- [ ] Run `UVK_RUN_RESOURCE_TESTS=1 swift test -c release --filter ResourceBoundaryTests`; expect missing recipes/instrumentation or exposed resource regression. Measure the CLI separately so fixture-builder/XCTest memory is not attributed to validator RSS.
- [ ] **GREEN:** Implement streamed recipes and portable orchestration around Darwin measurements. Optimize only measured over-retention/redundant reads; no concurrency or relaxed limits to make a result pass. Capture actual measurement rows and host details; do not put timing/host fields in product reports. Hard-boundary tests must show no next read/allocation, not merely a final finding.
- [ ] Run `swift build -c release`, `UVK_RUN_RESOURCE_TESTS=1 swift test -c release --filter ResourceBoundaryTests`, then `python3 Scripts/verify-resources.py --executable .build/release/usdz-validator --output docs/verification/resource-results.md`; expect every documented target met or an explicit failed acceptance criterion. Never mark AC-15 verified based only on synthetic counters.
- [ ] `git add Tests/TestSupport/ResourceRecipes.swift Tests/USDZValidationTests/ResourceBoundaryTests.swift Scripts/verify-resources.py docs/verification/resource-results.md Tests/Fixtures/manifest.json`; explicitly add any measured source fix, then `git commit -m "test: measure native resource envelope on arm64"`.

### Task 25: User documentation, security boundary and examples [size: S | risk: none | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-02, AC-08, AC-09, AC-17, AC-19, AC-21, AC-24, AC-29, AC-30. **Depends on:** 22–24.

**Files:** Create `README.md`, `SECURITY.md`, `docs/cli.md`, `docs/inspection-boundary.md`, `docs/report-compatibility.md`, `docs/fixtures.md`, `CHANGELOG.md`, `Scripts/verify-examples.py`; modify `NOTICE`, `Examples/budgets.json`, `Examples/report-v1.json`, `Examples/catalogue-v1.json`, `Examples/report.sarif` only to match final reviewed behavior.

**Interfaces:** Documentation links the exact commands/schema/profile/ID contracts and published examples. `python3 Scripts/verify-examples.py --executable PATH` runs the documented complete fixture commands, validates exit/stream expectations and compares example bytes; it does not regenerate them silently.

- [ ] **RED:** Create `Scripts/verify-examples.py` as the executable example test harness first; it initially fails on missing/stale documents or output mismatch. Assertions: documented complete USDA example exits 0 without tools, JSON/SARIF parses once, catalogue profile IDs match, budget example matches defaults, all relative documentation/schema links resolve. Manual review checks that non-goals/support and the external trust exception are stated accurately; do not substitute a keyword-only test for editorial review.

  ```python
  assert complete_example.returncode == 0
  assert complete_example.stderr == b""
  assert complete_example.stdout == checked_in_example_bytes
  ```
- [ ] Run `python3 Scripts/verify-examples.py --executable .build/release/usdz-validator`; expect missing examples/docs or mismatch until authored.
- [ ] **GREEN:** Document install/build/library usage, exact CLI/options/exit precedence/stdout-stderr, lexical author/default-layer resolution and inactive-token scope, USDC gaps/incomplete acceptance, all hard/warning limits and null/default config, profile advice versus current Apple support, schema/ID versioning and relocation guarantees. Security notes cover final-symlink handling, stable-file assumption, no extraction/decompression/pixel decode, no full asset-security certification, external filesystem/network/RSS sandbox absence, fixed tool/version/env/timeouts, raw-diagnostic opt-in and private vulnerability reporting through repository owner contact. State exact current-host verified support, intended baseline and deferred verification gaps, fixtures/licenses/notices, no hosted upload/backend, and all v0.1 non-goals. Use project-contributor MIT attribution; verify notices against actual resolved materials.
- [ ] Run example verifier and `.venv/bin/python Scripts/verify-schemas.py --self-test`; manually compare documentation against AC-30/spec, expect accurate examples and no expanded compatibility claim.
- [ ] `git add README.md SECURITY.md docs/cli.md docs/inspection-boundary.md docs/report-compatibility.md docs/fixtures.md CHANGELOG.md Scripts/verify-examples.py NOTICE Examples/budgets.json Examples/report-v1.json Examples/catalogue-v1.json Examples/report.sarif`; `git commit -m "docs: explain validation scope and CI contracts"`.

### Task 26: Portable verification commands and manual release matrix [size: M | risk: other | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: performance]

**Acceptance criteria:** AC-01, AC-02, AC-15, AC-18, AC-20, AC-21, AC-22, AC-23, AC-25, AC-28, AC-30. **Depends on:** 25. **Risk:** a green current-host run must not masquerade as verified baseline support.

**Files:** Create `Makefile`, `Scripts/verify-release.sh`, `Scripts/compare-compatibility.py`, `docs/releasing.md`, `docs/verification/release-matrix.md`, `Tests/test_verification_tools.py`; modify `Scripts/test-cli.sh`, `Scripts/verify-schemas.py`, `Tools/README.md` for configuration/export integration only.

**Interfaces:** `make format`, `make format-check`, `make build`, `make test`, `make schemas`, `make cli-test`, `make adversarial`, `make resources`, `make release-verify` run the exact command catalogue below. Release script accepts `--evidence-dir PATH` and `--installed-checker-smoke` (opt-in only), records commands/status/skips/toolchain and exports canonical reports with `UVK_COMPAT_EXPORT_DIR`. `Scripts/compare-compatibility.py BASELINE_DIR CURRENT_DIR` requires identical fixture/config/validator version manifests, then compares exact default report bytes, catalogues and native IDs. No hosted workflow is introduced.

- [ ] **RED:** `VerificationToolTests` uses tiny temporary output directories to assert missing environment rows, differing manifests, mismatched bytes, nonzero verification steps or skipped required resource/schema/CLI suites cannot produce a release PASS. Real-tool smoke skipped is recorded as skipped. Missing baseline environment is `UNVERIFIED`, not passed. `testReleaseHasNoHooks` launches release executable with every fixed test-hook environment value and asserts normal behavior; hook-only build is isolated.

  ```python
  self.assertEqual(equal_exports.returncode, 0)
  self.assertNotEqual(mismatched_exports.returncode, 0)
  self.assertEqual(missing_baseline_status, "UNVERIFIED")
  self.assertEqual(normal_release.stdout, release_with_test_environment.stdout)
  ```
- [ ] Run `python3 -m unittest discover -s Tests -p 'test_verification_tools.py'`; expect missing scripts or failed evidence-policy assertions.
- [ ] **GREEN:** Preserve scripts/Makefile and their broader manual matrix. Required v0.1 verification/support is limited to macOS 27.0.1 build 26A434 / Xcode 27.1 build 27A9275 / Swift 6.4 (`swiftlang-6.4.0.34.1`) on arm64, with CPython 3.14.7 schema tooling. Record exact `DEVELOPER_DIR`, versions and hardware, not an unpinned “latest”; current-host formatter remains authoritative. Measure resource targets on the documented host and prove repeated/relocated/fixed-adapter/golden bytes there. macOS 15 / Xcode 16.0 / Swift 6.0 arm64, CPython 3.12 and two-host comparison stay UNVERIFIED and deferred. When a second qualifying host exists, run the same corpus/tests/schema lock, preserve its formatter without rewriting, and compare exports with fixed fake external results; record actual installed smoke separately. `currentHostStatus: PASS` is the required current-environment verification; unchanged `releaseStatus: UNVERIFIED` aggregates the broader optional matrix. Failed current-host gates block acceptance. No tag, release upload, push or merge is authorized.
- [ ] Run Python verifier-tool tests and `make release-verify`; require all current-host gates and preserve actual evidence. Keep unavailable baseline/cross-host/Python 3.12 rows UNVERIFIED without blocking v0.1 acceptance. Future two-host follow-up uses the documented same command and complete evidence/exports with `python3 Scripts/compare-compatibility.py PATH_TO_BASELINE PATH_TO_CURRENT`; claim equality only from two actual qualifying environments. Commit observed evidence, never fabricated rows. For a documentation-only policy amendment, rerun only affected schema/provenance/verifier checks and refresh changed compatibility bindings in fresh evidence; do not rerun unchanged broad Swift suites.
- [ ] `git add Makefile Scripts/verify-release.sh Scripts/compare-compatibility.py Scripts/test-cli.sh Scripts/verify-schemas.py Tools/README.md docs/releasing.md docs/verification/release-matrix.md Tests/test_verification_tools.py`; `git commit -m "chore: define reproducible release verification"`.

### Task 27: Final whole-branch specification and quality gate [size: M | risk: other | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-01, AC-02, AC-03, AC-04, AC-05, AC-06, AC-07, AC-08, AC-09, AC-10, AC-11, AC-12, AC-13, AC-14, AC-15, AC-16, AC-17, AC-18, AC-19, AC-20, AC-21, AC-22, AC-23, AC-24, AC-25, AC-26, AC-27, AC-28, AC-29, AC-30. **Depends on:** 26. **Risk:** reviewing only the last task can omit defects in an initially empty repository. No new product scope.

**Files:** Read all feature-branch files, approved spec and plan. Create one review package in scratch space only. Any permitted remediation must name its exact files and regression/criterion before editing; update `docs/verification/release-matrix.md` with observed rerun evidence or explicitly dated user-approved policy provenance, preserving historical observations/hashes. No standalone repository review artifact or architecture map is required.

**Interfaces:** Invoke `personal-workflows:code-review` once in integrated mode as the enclosing workflow's sole final whole-branch review seat. Preserve task-level SDD specification/quality checks. No generic equivalent final reviewer before/after this gate.

- [ ] **RED/review:** Verify clean intended tracked state and complete criterion table; required current-host resource/format/build/test evidence must pass, while baseline/cross-host/Python 3.12 evidence stays UNVERIFIED and deferred under the amendment. Build a single self-contained package containing complete governing spec/plan, complete empty-tree-to-reviewed-state diff (including root docs commit), changed-file list, necessary source contents, actual verification evidence or `unobserved`, integrated mode and enclosing fix-loop limit. Create `GATE_RUN_ID` and `REVIEWED_STATE_ID` in the package; compute its finalized SHA-256 out-of-band. Review cannot PASS with a missing required current-host input or an unsupported verification claim; deferred matrix rows are not missing required v0.1 acceptance evidence.

  Future baseline commands: `UVK_EMPTY_TREE=$(git hash-object -t tree --stdin -w < /dev/null)`, `git diff --binary "$UVK_EMPTY_TREE" HEAD`, and `git diff --name-status "$UVK_EMPTY_TREE" HEAD`. Record `git rev-parse HEAD` and verify no unstaged/untracked intended product file is omitted. These commands run only during approved implementation, never during planning.
- [ ] Dispatch `review-spec` with package path plus expected run/state/hash; verify echoed identities/hash. `MISSING`, `EXTRA`, or `BLOCKED` stops the gate, with evidence/remedies; missing reviewer is BLOCKED. Only a fresh `SPEC REVIEW: PASS` opens `review-quality` on the unchanged same hashed package plus complete spec report. Use skill-owned reviewer roles, never a substitute model or third final reviewer.
- [ ] **GREEN/remediation:** Assess feedback through the receiving-review discipline; add the smallest named failing regression before a code fix. Use only the enclosing SDD fix-loop allowance; do not start a fresh independent loop. Any changed reviewed state needs the applicable refreshed package/gate identity and targeted follow-up under that allowance. No code changes if both stages pass.
- [ ] Rerun only affected commands plus the required final release checks when changes warrant it. Report both stages and outstanding evidence honestly; unavailable baseline/cross-host/Python 3.12 checks do not block amended AC-02/AC-22 or v0.1 acceptance; claims remain limited to the exact tested combination. Do not change or reinterpret machine statuses as broader verification. If checks cannot complete, stop with the precise unmet criteria instead of calling the project fully verified.
- [ ] Commit only reviewed remediation/evidence with exact staging paths and a conventional message describing the actual fix. If unchanged, create no empty “review” commit. Present local branch/commits, observed verification and remaining external-host evidence to the user; do not push or merge.

## Verification command catalogue

These are implementation deliverables, not commands run during planning. Each Make target delegates to the commands here; scripts fail on nonzero required steps and preserve stdout/stderr separately. Bootstrap developer dependencies once through Task 1's `swift package resolve` and Task 22's venv/hash-locked installation. Native runtime and offline test execution do not download assets or schemas.

| Command / target | Defined behavior and successful result |
| --- | --- |
| `make format` | `xcrun swift-format format --in-place --recursive --configuration .swift-format Sources Tests Package.swift`; edits Swift only, using the designated current-toolchain formatter |
| `make format-check` | `xcrun swift-format lint --strict --recursive --configuration .swift-format Sources Tests Package.swift`; exit 0 and no lint errors; must not reformat during verification |
| `make build` | `swift build --build-tests`; exit 0, both products and test consumer compile |
| `make test` | `swift test`; native, fake-tool and ordinary CLI suites pass; expensive-resource/installed-tool skips explicitly identified |
| `make cli-test` | `sh Scripts/test-cli.sh`; normal and isolated fixed-scenario process builds, every CLI exit/stream class actually exercised |
| `make schemas` | `.venv/bin/python Scripts/verify-schemas.py --self-test` and `.venv/bin/python -m unittest discover -s Tests -p 'test_schema_contracts.py'`; schemas/goldens/examples accepted, invalid documents rejected, no remote refs |
| `make adversarial` | `sh Scripts/test-adversarial.sh`; sanitizer mutation corpus passes without traps/overreads |
| `make resources` | `swift build -c release`, `UVK_RUN_RESOURCE_TESTS=1 swift test -c release --filter ResourceBoundaryTests`, `python3 Scripts/verify-resources.py --executable .build/release/usdz-validator --output docs/verification/resource-results.md`; all boundary assertions and measured host targets pass |
| `make release-verify` | `sh Scripts/verify-release.sh --evidence-dir .build/verification/current`; complete current-host sequence below plus honest manual-matrix status, no publication |
| Optional installed smoke | `UVK_RUN_INSTALLED_CHECKER=1 swift test --filter InstalledCheckerSmokeTests`; exact installed version/result recorded; explicitly skipped/unsupported if it cannot run |
| Deferred manual cross-host comparison | `python3 Scripts/compare-compatibility.py PATH_TO_BASELINE PATH_TO_CURRENT`; equal manifests and canonical bytes, otherwise a nonzero compatibility failure |

`verify-release.sh` runs, in order: environment/architecture/version capture; non-mutating formatter lint on the designated formatter host; `swift package resolve` plus unchanged `Package.resolved` check; `swift build --build-tests`; `swift test`; CLI process script; `swift build -c release`; `swift test -c release`; `swift test --sanitize=address`; schema/tool self-tests; example verifier; golden export/schema verification; resource checks. Resource/installed smoke tests remain explicit as above; `swift test` alone does not count their skips as coverage. Formatter/build/test failures stop release verification. Baseline formatter is recorded but does not rewrite files or replace current-host lint evidence.

Use `swift build --show-bin-path` (with matching `-c release` or scratch path) when scripts need executable paths; the `.build/release/…` examples follow the specification's SwiftPM symlink convention. Honor `DEVELOPER_DIR` set by the verified host and any future intended-baseline follow-up host and record actual `swift --version`, `xcodebuild -version`, `sw_vers`, `uname -m` and `xcrun swift-format --version`. No hidden installed-tool requirement in `make test`, schema validation, CLI fakes or native release checks.

## Acceptance-criterion traceability

Every row identifies implementation ownership and the test/evidence that proves it. Task 27 audits all rows; it does not replace named current-host tests or turn unavailable-host checks into evidence. Baseline/cross-host/Python 3.12 checks remain documented deferred follow-up, not v0.1 acceptance blockers.

| Criterion | Tasks | Primary proof |
| --- | --- | --- |
| AC-01 | 1, 19, 26 | Package graph, `LibraryConsumerTests` importing library only, no process in default validation |
| AC-02 | 1, 25–26 | Exact tested current-host build/native tests; intended macOS 15+/Xcode 16.0/Swift 6.0 arm64 documented as UNVERIFIED/deferred; no automatic minimum/future support |
| AC-03 | 2, 10, 13–14, 19–20 | Original aligned fixture, complete engine/library/CLI gate 0 with zero probes |
| AC-04 | 2, 4–6, 14, 23 | Checked-range, directory/index ownership and adversarial regressions |
| AC-05 | 2, 7, 23 | Distinct integrity IDs, bomb metadata with zero payload interpretation |
| AC-06 | 5–6, 8–9, 14, 23 | Unsupported-feature/layout/encoding/nested limitations with incomplete coverage |
| AC-07 | 8, 23 | Exact-byte namespace, conflicts/type matrix, zero extraction/host access |
| AC-08 | 10, 25 | Author/default-layer tests, unsafe/root escape IDs and lexical policy docs |
| AC-09 | 9–10, 23, 25 | Lexer chunk/escape/location states, expressions versus missing-target tests |
| AC-10 | 9–10, 14, 19 | Synthetic binary coverage tests; accepted gap leaves provenance/coverage unchanged |
| AC-11 | 11, 13 | PNG/JPEG malformed/unsupported/cap tests and disabled-dimension applicability |
| AC-12 | 12–13, 22 | Six threshold matrices, omitted/null config semantics and schema examples |
| AC-13 | 12, 20, 22 | Raw strict config rejection, bounded config loads before asset opener/tool |
| AC-14 | 4–9, 11–12, 14–15, 23–24 | At/above every envelope value, read counters and deterministic sentinel |
| AC-15 | 24, 26 | Separate release-process RSS/time measurements and documented resource host |
| AC-16 | 1, 3, 16–17, 22 | Identity vectors/dedup/order, real offsets and relocation/rename goldens |
| AC-17 | 3, 13, 16, 20, 25 | Exact descriptors, selected catalogue and Apple-only warning tests |
| AC-18 | 1, 20–21, 26 | Actual-process argument/help/version/every-exit tests and release seam exclusion |
| AC-19 | 1, 19–20, 25 | Gate truth table and CLI incomplete/threshold/external precedence |
| AC-20 | 15–17, 20–22, 26 | Equivalent meaning, one-document stdout, empty output stdout, atomic failure tests |
| AC-21 | 16–17, 22, 25–26 | Versioned published schemas/examples, pinned OASIS schema, golden compatibility |
| AC-22 | 3, 15–17, 20, 22, 26 | Current-host repeated/relocation/fixed-adapter/independent-golden bytes and privacy fixtures; genuine two-host exports UNVERIFIED/deferred |
| AC-23 | 14, 19–20, 26 | Disabled availability/executor spies, enabled/disabled native subtree equality |
| AC-24 | 18–19, 25 | Every fake adapter status/phase/version/availability; trusted-input documentation |
| AC-25 | 18–19, 26 | Concurrent pipe/timeout/kill/reap tests, exact fixed request assertions, opt-in smoke |
| AC-26 | 17, 19, 22 | External aggregate/report goldens, no native upgrade, raw diagnostics opt-in |
| AC-27 | 4, 8, 10, 12, 14–15, 19–21 | File changes/special files, redaction/escaping, typed I/O and safe destination tests |
| AC-28 | 4–7, 9, 11, 18, 23–24, 26 | Deterministic parser mutations, bounded process tests and full Address Sanitizer run |
| AC-29 | 2, 23–25 | Manifest hash/recipe/license completeness, temporary large recipes, notices, no downloads |
| AC-30 | 25–26 | Manual spec-to-doc review, runnable examples, release/support evidence and non-goals |

## Plan self-review and approval boundary

Self-review checked all specification sections and AC-01–AC-30 against task ownership; five Review Focus conditions have named owning tests. Safety/read/count tests precede parser implementation; facade and CLI consume previously defined interfaces; report/gate policy is shared rather than reimplemented in CLI. Task routing selects full because security, compatibility data, concurrency and measured performance need the full workflow. Planned command entrypoints are separated from observed tool support.

At planning discovery, remaining execution evidence included resolved dependency hashes/revision, licensed pinned schema bytes, measured resource rows and baseline/current test outputs. Under the 2026-10-21 amendment, current-host proof remains required while baseline/cross-host/Python 3.12 verification is deferred; later observations live in the release matrix. No current-host observation proves the older environment. Whole-branch review uses an explicit empty-tree base for the repository's root history. The plan preserves the selected subagent execution method and both approval gates.

Historical planning boundary (2026-10-20, superseded by the recorded approvals and 2026-10-21 amendment): Only this plan is created in the planning phase. The specification remains unchanged; both artifacts remain uncommitted. No Swift/package/product files, implementation branch/worktree, dependencies, implementation, commits, push or merge are authorized before explicit written-plan approval. Stop and request that approval.

# USDZ Validation Kit v0.1

**Slug:** `usdz-validation-kit`
**Type:** feature
**Status:** APPROVED — explicit user approval in conversation; implementation authorized 2026-10-21
**Date:** 2026-10-19
**Provenance:** Original user request to start USDZ Validation Kit in this repository; repository and environment inspection on 2026-10-19; native interactive clarification and section-by-section design selections in this conversation. No legacy specification or implementation is a source.

This document is proposed for explicit written-specification approval. Interactive design selections authorize this DRAFT; they do not constitute approval of this written artifact or of an implementation plan.

## Problem

3D asset pipelines need a local, repeatable way to catch USDZ packaging defects, unsafe or missing package dependencies, and delivery-budget regressions before distributing assets. A useful CI validator must distinguish defects it observes from checks it cannot perform. It must handle malformed input with bounded work and controlled errors.

The project should also demonstrate careful Swift and spatial-computing engineering through a reusable library, a small CLI, explicit trust boundaries, stable diagnostics, adversarial fixtures, and documented compatibility contracts.

## Desired Outcome

A macOS Swift Package provides a reusable validation library and a thin CLI for one local USDZ asset per invocation. Three native rule families inspect archive/container structure, referenced paths, and file/texture budgets. Reports are available as human-readable text, versioned JSON, and SARIF 2.1.0.

Native inspection works without an installed OpenUSD runtime, external command execution, network access, or asset extraction. An explicitly requested, installed `usdchecker` is a separate trusted-input adapter. Neither a native coverage gap nor an unavailable requested checker is represented as successful validation.

## Verified Facts and Assumptions

### Verified repository and environment facts

The following were checked directly, rather than inferred from the earlier environment description:

| Item | Observation on 2026-10-19 |
| --- | --- |
| Repository | `/Users/davide/Personal/Projects/usdz-validator` |
| Working directory content before this document | Only `.git`; no tracked, untracked, or ignored project files were found |
| Git history | No commits; `main` is an unborn branch |
| Remote | `origin` fetch and push: `https://github.com/Light2288/usdz-validator.git` |
| Tracking metadata | Git reports `main...origin/main [gone]`; this does not establish the remote repository's current contents |
| OS and hardware | macOS 27.0.1, build 26A434, arm64 |
| Swift | Apple Swift 6.4; swiftlang-6.4.0.34.1; driver 1.168.6 |
| Xcode | 27.1, build 27A9275; selected developer directory `/Applications/Xcode.app/Contents/Developer` |
| USD tools | `/usr/bin/usdchecker` and `/usr/bin/usdcat` exist and are executable |
| Tool versions | Both report `Apple USD Tools (0.25.11)` |
| Checker interface | Installed help documents `--version`, `--strict`, `--rootPackageOnly`, `--out`, and `--arkit`; its ARKit help describes a RealityKit compatibility target as of 2023 |

No remote fetch, dependency installation, build, or product test was performed during specification discovery. The supported baseline below is a requirement to verify during implementation, not a claim that this machine verified older systems.

### User-selected design requirements

- Native bounded Swift core; no linked OpenUSD dependency.
- macOS 15+ with Swift 6.0+; Apple Silicon (`arm64`) only for v0.1.
- Encoded texture sizes plus bounded PNG/JPEG dimension inspection.
- Incomplete native coverage blocks the gate unless explicitly accepted.
- The bounded CI-asset safety envelope and balanced warning budgets defined below.
- An opt-in conservative Apple advisory profile, including binary-layer and PNG/JPEG recommendations.
- Installed `usdchecker` is an explicit trusted-input operation with bounded capture and timeout, without a promised process sandbox.
- Apple's Swift Argument Parser is the only third-party package dependency; the library has none.
- Strict, versioned JSON budget configuration; errors fail by default, with warnings optionally blocking.
- A requested checker that cannot complete always prevents exit `0`.
- MIT licensing for original project code and project-authored fixtures.

### Assumptions and limits of evidence

- Intended users are asset-pipeline engineers and Swift developers running local checks or macOS CI jobs.
- The input is a stable regular file during an invocation. Detectable concurrent modification is an operational error; adversarial concurrent writers are outside the snapshot guarantee.
- Runtime inspection has no network requirement. Building the package may initially require fetching its declared CLI dependency.
- The fixed warning budgets are project policy, not Apple hardware limits or format limits.
- Source documents inform the bounded checks below. No source or installed tool establishes exhaustive Quick Look, RealityKit, or visionOS compatibility.
- Availability and results of a remote CI service, baseline macOS hardware, and future toolchain combinations have not been verified in this specification phase.

## Architectural Approaches

| Approach | Advantages | Costs and limitations | Decision |
| --- | --- | --- | --- |
| Native bounded Swift reader and scanners | Small reusable core; deterministic checks; explicit allocation/read limits; no USD runtime or system-tool dependency for native results | Own the deliberately small ZIP reader and lexical scanner; no binary-USDC reference inspection or composed-stage semantics | Selected |
| Swift library linked to OpenUSD | Can inspect binary layers and use USD dependency semantics | C++ interoperability, runtime/plugin integration, build/distribution size, version support, and a larger hostile-input surface | Defer |
| System-tool-assisted core | Reuses installed tools for binary conversion or dependency inspection | Coverage and output depend on tool installation/version; subprocess and resolver behavior enter the core trust boundary | Reject as the core; retain only the optional checker adapter |

The selected approach is the smallest design that preserves a useful reusable core. It intentionally reports binary reference coverage as incomplete instead of attempting a partial USDC parser or silently converting assets with `usdcat`.

## Supported Platform and Package Boundary

- Supported runtime: macOS 15 or later on Apple Silicon.
- Minimum build baseline: Swift tools version 6.0, Swift 6 language mode, and Xcode 16.0. The observed Xcode 27.1 / Swift 6.4 combination is an additional required verification environment.
- A future macOS or Swift release is not automatically a verified combination merely because it satisfies the minimum version.
- Intel, Linux, Windows, iOS, and visionOS execution are outside v0.1 support. The package is a validator for assets used on spatial platforms, not an app running on those platforms.
- Library product/module: `USDZValidation`.
- Executable product: `usdz-validator`.
- The library depends only on public macOS/Swift SDK facilities. Do not link private USD frameworks, OpenUSD, ZIP packages, image decoders, or archive extraction utilities.
- The CLI uses `apple/swift-argument-parser`, initially version 1.5.0, with the resolved revision recorded in `Package.resolved`. This deliberately selected baseline declares Swift tools 5.7 and must still be tested with the project's Swift 6 mode. Upgrades require the same CLI contract tests.
- The core owns bounded reading, container indexing, native scanners, rule evaluation, report models/encoding, and the explicitly configured optional-tool adapter. The CLI owns argument/config loading, gate options, stdout/stderr, and report destinations.
- No custom-rule plugin system, resolver plugin system, dependency-injection framework, backend, or additional package products are required.

## Data Flow and Public Models

The library accepts a local file URL and an immutable validation configuration and returns a report. The conceptual entry point is `validate(fileAt:configuration:) throws -> ValidationReport`. Concrete naming may follow Swift API conventions without changing these semantics.

The flow is: validate configuration; open a regular file once; check size and bounded ZIP metadata; build a safe package index; inspect stored payloads and CRCs; scan supported USD text and texture headers; evaluate budgets/profile advice; optionally invoke the requested checker if eligible; sort and encode the report. Use the same native engine and report model for all CLI formats.

Do not load a USD stage, evaluate composition, extract files, or resolve a dependency against the host filesystem. Do not preallocate from untrusted counts or sizes before validating them.

| Model | Required semantics |
| --- | --- |
| `ValidationConfiguration` | Profile identifier, effective warning budgets, fixed safety-envelope version, gate policy (failure threshold and incomplete acceptance), sensitive-details choice, and explicit external-check request. The CLI parses these choices and passes them to the library; native callers can make the same choices. No implicit config discovery or tool probing. |
| `RuleDescriptor` | Permanent rule ID, one of the three native families where applicable, category, default severity, title, description, applicability, and documented rationale. Cross-cutting execution/coverage diagnostics may have no family. |
| `Finding` | Rule ID, deterministic occurrence ID, category, severity, message, bounded structured evidence, location when known, and provenance. No unbounded underlying error descriptions. |
| `FindingLocation` | Archive entry name when safe to display; archive byte offset when known; optional layer-relative byte offset and one-based line/column for text. Preserve entry identity for duplicates through physical offsets. Never invent a line number for binary data. |
| `Provenance` | `native` with validator version, or `usdchecker` with tool/version/invocation identity. External findings stay in a separate report section. |
| `Coverage` | Per requested check area: `complete`, `partial`, or `notRun`, with reason IDs and affected locations. Overall native coverage is complete only when all applicable selected checks complete. |
| `ExternalCheck` | Requested flag, availability, reported version or null, status, tool-reported outcome, optional exit code, bounded diagnostic metadata, and separate external findings. |
| `ValidationReport` | Report schema version, product/version, safe input identity, effective configuration, coverage, native findings, external-check record, operational errors, summary, validation status, gate decision, and intended CLI exit code. |

The library writes nothing to stdout/stderr and terminates no process. Malformed asset content returns findings. Configuration and operational failures use typed errors; the CLI renders those through the operational-error contract below. Never swallow an error or expose raw Foundation/POSIX error text containing local paths.

### Categories and severity

Categories are independent of severity and remain visible in every format:

| Machine category | Meaning |
| --- | --- |
| `archiveSpecification` | Observed ZIP structural defects or violations of the explicitly checked USDZ requirements |
| `appleCompatibility` | Advice from the selected, frozen Apple portability profile; never a renderer certification |
| `policy` | Package-local dependency/safety policy, standalone-asset policy, file-type policy, or performance budgets |
| `validatorLimitation` | A check could not be completed within the declared implementation boundary |

Severity is `error`, `warning`, or `note`. Safety violations and missing literal package targets are policy errors even when the authored path could be legal USD in another resolver environment. Budget excesses and Apple advice are warnings. Ordinary coverage limitations are warnings and independently affect completeness. A blocking resource-limit diagnostic is an error. Disabling an advisory budget cannot disable safety checks.

## Precise Native Inspection Boundary

### ZIP and USDZ container

Support classic, single-disk ZIP with stored regular-file entries, optional zero-length directory entries, and sizes/offsets representable without ZIP64. Parse EOCD, central-directory entries, and local headers with checked unsigned arithmetic. Validate signatures, field lengths, disk/count consistency, offsets, non-overlapping record/payload ranges, and agreement between corresponding local and central records. The directory must describe the inspected local entries without duplicate ownership or hidden unindexed members.

Accept a structurally bounded ZIP comment and bounded extra fields, including USDZ alignment padding; do not interpret unknown padding/vendor data as executable content. Detect ZIP64 requirements/records and unsupported interpretation-affecting flags before reading payloads under classic-ZIP assumptions.

For every supported stored regular entry:

- Compression method must be `0`, encryption must be absent, and stored and uncompressed sizes must agree.
- Payload starts at an offset divisible by 64. Check payload alignment, not header alignment.
- Stream the payload CRC-32 and compare with the recorded CRC. A CRC match does not validate the embedded file's complete format.
- Check entry range and size before reading. Never extract, decompress, or allocate an entry-sized buffer.

ZIP64, split/multi-disk archives, data descriptors, unsupported required ZIP versions/flags/encodings, self-extracting prefixes, and layouts outside the supported record mapping produce explicit coverage limitations. They are not labeled invalid ZIP merely because this reader does not support them. Truncated or contradictory records that can be established independently remain errors. Stop dependent checks when the index cannot be trusted.

The standalone-asset policy requires the first regular file in physical archive order to be a recognized native USD layer. This is the selected package-as-stage contract; the underlying USDZ default-layer requirement is conditional on using the package directly as a stage. Directory entries do not select a default layer.

The v0.1 member-suffix catalogue is case-insensitive for type classification: `.usd`, `.usda`, `.usdc`, `.usdz`, `.png`, `.jpg`, `.jpeg`, `.jpe`, `.jfif`, `.exr`, `.avif`, `.m4a`, `.mp3`, `.wav`. A member outside this catalogue is a project file-type policy error, not a universal claim about every possible future USDZ extension. Nested `.usdz` members are recognized but not recursively inspected and cause an explicit limitation.

Recognize text USD by its `#usda 1.0` header and binary USD by its `PXR-USDC` magic. Use these bounded checks to distinguish `.usd` content and detect obvious suffix/signature mismatches for `.usda`/`.usdc`. Do not claim that a recognized header establishes valid USD syntax, a supported crate version, or a valid scene.

### Archive entry names and constructs

- Resolve names in an in-memory package namespace; never turn them into extraction destinations.
- Accept ASCII names, or valid UTF-8 names declared as UTF-8. Other filename encodings are unsupported coverage; invalid declared UTF-8 is a malformed-name error.
- Reject empty names, NUL/control characters, absolute POSIX paths, drive-qualified/UNC paths, backslashes, and file names containing empty, `.` or `..` path components. Permit a trailing slash only for a directory entry.
- Reject duplicate exact names, including file/directory namespace conflicts and a regular file used as another entry's parent directory.
- Use case-sensitive, exact UTF-8 path identity. Never use host filesystem case folding, Unicode normalization, percent decoding, or search paths to select an entry.
- Reject entries declared as symbolic links, devices, FIFOs, sockets, or other non-regular constructs. Accept ordinary regular files and zero-length directories; absent Unix type bits may use the supported DOS file/directory interpretation. Unknown host/type semantics are a limitation rather than an assumed safe regular file.
- If a path/type violation prevents constructing an unambiguous safe namespace, do not run reference checks against a partially trusted index. Preserve the blocking findings and mark affected coverage incomplete.

### Referenced paths in USDA

Scan every recognized USDA layer at the top package level of inspection, including unreferenced layers and layers in archive subdirectories. This is a lexical package-dependency policy, not composed-stage dependency analysis.

The bounded lexer must distinguish comments, ordinary single/double/triple-quoted strings, and USD asset-path literals. Support `@...@`, `@@@...@@@`, and their documented delimiter escaping; track layer-relative byte offsets and line/column. Ignore apparent asset literals inside strings/comments. Report conclusively unterminated/invalid supported literals as lexical policy errors. Do not report the rest of USDA grammar as parsed or validated.

For literal, nonempty asset paths:

1. Check absolute, scheme-qualified, drive/UNC, backslash, NUL/control, and package-escape forms before lookup. Never expand `~`, environment variables, URIs, or a custom asset resolver.
2. Resolve an anchored `./` or `../` path relative to its authoring layer's directory. `..` is permitted only when normalization stays inside the package.
3. For an unanchored relative path, try its authoring layer's directory and then the default layer's directory. This is a bounded package-only lookup; do not perform the external resolver fallback used by a general USD runtime.
4. Match an exact safe regular entry. A missing target, or a directory used as a file target, is a package-local dependency policy error. Include the authored token location.

An empty asset value is treated as an unauthored value and does not require a target. Prim paths outside the asset delimiter are not filesystem references.

Variable expressions, template/UDIM expansion, resolver identifiers, and bracketed package-relative/nested-package identifiers are not evaluated. Mark their reference coverage partial, after any unsafe literal prefix that can be established has been checked. Do not turn an unevaluated expression into a speculative missing-file error. The scanner must recognize asset-path expression syntax as unsupported rather than treating it as an ordinary filename.

All binary USDC layers receive a reference-coverage limitation. Neither magic recognition nor a successful external check upgrades this native coverage. Scanning text authored in inactive variants or metadata can identify package-local tokens that are not active runtime dependencies; reports and documentation must explain this intentional lexical policy.

### File and texture budgets

Evaluate archive bytes from the opened file size, file count from regular entries, and per-file bytes from validated stored-entry sizes. Directory entries count toward security entry limits but not warning file-count or texture totals.

Treat members classified as PNG, JPEG, EXR, or AVIF as textures for encoded-byte budgets, regardless of whether a text layer references them. Count each regular entry once. Do not infer material use, GPU compression, mip levels, pixel formats, or actual runtime memory.

For PNG, validate the bounded signature/IHDR structure needed to read positive width and height. For JPEG, walk length-checked markers to a supported SOF record within the header-scan limit. Do not decode pixels or inspect compressed image data. Conclusively malformed supported headers are policy errors. A dimension that cannot be obtained because of an unsupported valid variant or the scan cap is a limitation, not an invented zero dimension or a successful dimension check.

EXR and AVIF still receive encoded-byte checks but have dimension coverage marked partial. If the dimension budget is disabled, skipping a dimension check does not by itself make requested coverage incomplete. No estimated decoded-memory budget is part of v0.1.

## Profiles, Rule Catalogue, and Finding Identity

### Profiles

- `general-v1` is the default. It selects native structure, safety, package-local dependency, and enabled budget checks.
- `apple-portable-v1` adds two advisory warnings: prefer binary USD layers for delivery, and prefer PNG/JPEG for this conservative portability baseline.
- The Apple profile is a project-defined, frozen advisory subset. It does not assert that USDA, EXR, or AVIF is universally unsupported on current Apple systems. It does not impose an outdated universal single-layer requirement.
- Profile IDs and their documented policies are versioned. Changing their recommendations or thresholds incompatibly requires a new profile ID. Selecting the Apple profile does not silently run a tool.

### Initial native descriptors

These IDs are permanent and must never be reassigned. Related instances share a rule ID and differ by occurrence ID/evidence.

| Rule ID | Condition | Category / severity |
| --- | --- | --- |
| `UVK-ARC-001` | Established malformed/truncated ZIP record or invalid field range | archiveSpecification / error |
| `UVK-ARC-002` | Contradictory local/directory records, overlapping ownership, or unindexed members | archiveSpecification / error |
| `UVK-ARC-003` | Stored payload CRC mismatch | archiveSpecification / error |
| `UVK-ARC-004` | Nonzero compression method or unequal stored/uncompressed sizes | archiveSpecification / error |
| `UVK-ARC-005` | Encrypted entry | archiveSpecification / error |
| `UVK-ARC-006` | Regular-file payload is not 64-byte aligned | archiveSpecification / error |
| `UVK-ARC-007` | Obvious USD suffix/signature mismatch | archiveSpecification / error |
| `UVK-POL-001` | First regular entry fails the standalone default-layer policy | policy / error |
| `UVK-POL-002` | Member outside the v0.1 suffix catalogue | policy / error |
| `UVK-PATH-001` | Unsafe/invalid archive member name | policy / error |
| `UVK-PATH-002` | Duplicate name or file/directory namespace conflict | policy / error |
| `UVK-PATH-003` | Symlink or prohibited non-regular member | policy / error |
| `UVK-PATH-004` | Absolute/external/unsafe literal asset path | policy / error |
| `UVK-PATH-005` | Reference normalization escapes package root | policy / error |
| `UVK-PATH-006` | Supported literal path has no regular package target | policy / error |
| `UVK-PATH-007` | Conclusively malformed supported asset literal | policy / error |
| `UVK-BUD-001` | Archive byte budget exceeded | policy / warning |
| `UVK-BUD-002` | Per-file encoded-byte budget exceeded | policy / warning |
| `UVK-BUD-003` | Regular-file-count budget exceeded | policy / warning |
| `UVK-BUD-004` | Per-texture encoded-byte budget exceeded | policy / warning |
| `UVK-BUD-005` | Total encoded texture-byte budget exceeded | policy / warning |
| `UVK-BUD-006` | Supported texture width or height exceeds the dimension budget | policy / warning |
| `UVK-BUD-007` | Conclusively malformed supported texture header | policy / error |
| `UVK-APL-001` | Text USD delivery advisory in Apple profile | appleCompatibility / warning |
| `UVK-APL-002` | EXR/AVIF outside the conservative PNG/JPEG Apple profile baseline | appleCompatibility / warning |
| `UVK-LIM-001` | Unsupported ZIP feature, layout, encoding, or type semantics | validatorLimitation / warning |
| `UVK-LIM-002` | Binary USD reference inspection unavailable | validatorLimitation / warning |
| `UVK-LIM-003` | Expression/template/package identifier cannot be resolved natively | validatorLimitation / warning |
| `UVK-LIM-004` | Recognized USD text cannot be scanned in its supported encoding | validatorLimitation / warning |
| `UVK-LIM-005` | Requested texture dimensions unavailable within the supported boundary | validatorLimitation / warning |
| `UVK-LIM-006` | Nested package content not inspected | validatorLimitation / warning |
| `UVK-RES-001` | Hard safety/processing ceiling exceeded, including findings truncation | policy / error |

Profile descriptors belong to the affected native family; cross-cutting resource diagnostics need no fourth product rule family. The rule catalogue must also explain applicability and skipped-check prerequisites. Do not emit cascades of speculative reference failures after a container failure makes them unknowable.

### Identity and ordering

- Rule IDs, categories, and documented meanings are stable. A materially different rule needs a new ID. Never recycle an ID.
- A finding occurrence ID is a SHA-256 digest of a versioned, length-delimited identity tuple: source namespace, rule ID, original entry-name bytes where available, physical entry offset, token/header offset where applicable, and a fixed rule-specific discriminator such as the budget key or limit reason.
- Do not include absolute input paths, input basenames, timestamps, message wording, observed duration, severity threshold, or budget threshold values in native occurrence identity. Identical archive bytes and the same rule occurrence retain identity across invocations and file relocation. No promise is made that byte offsets survive repackaging or authored edits.
- Deduplicate exact identity tuples. Preserve distinct offending tokens and distinct duplicate entries.
- Sort native findings by category rank (`archiveSpecification`, `appleCompatibility`, `policy`, `validatorLimitation`), rule ID, original entry-name UTF-8 bytes, physical location, then occurrence ID. Missing names/offsets sort before present ones. Compare bytes/numbers, never locale-dependent collation.
- Stable English templates, deterministic evidence ordering, and deterministic truncation are required. Discover findings in a fixed order, never task-completion order. Concurrency is unnecessary for v0.1.

## Resource and Security Contract

### Fixed native safety envelope v1

The following are upper bounds, not configurable warning budgets. MiB means 1,048,576 bytes; KiB means 1,024 bytes.

| Resource | Ceiling / behavior |
| --- | --- |
| Input archive bytes | 512 MiB; check before scanning |
| Archive entries, including directories | 10,000 |
| Central-directory bytes | 16 MiB |
| Declared bytes per regular entry | 256 MiB |
| Aggregate declared uncompressed entry bytes | 512 MiB; use checked summation even for rejected compressed entries |
| Text bytes per USDA layer | 16 MiB; reject exceeding this processing envelope without reading the layer |
| Entry name or asset-path token | 4 KiB |
| Asset-path token occurrences | 100,000 across the invocation |
| Read chunk | At most 64 KiB per payload read |
| Dimension header scan | At most 1 MiB per texture |
| Cumulative native input bytes read | At most 1,152 MiB, including repeated metadata/payload reads |
| Findings | At most 10,000 native findings; reserve the last slot for `UVK-RES-001` if discovery is truncated |
| Rendered message/evidence | Messages at most 1 KiB UTF-8; each variable evidence string at most 4 KiB, with explicit truncation markers |
| Configuration file | At most 64 KiB |
| Encoded report | At most 32 MiB, including permitted external details |
| Native peak resident memory | Release-mode acceptance target: no more than 256 MiB on the documented arm64 resource-test host |

Bounds must be enforced before allocations and reads. Peak RSS is a measured acceptance target, supported by bounded buffers and collections; it is not an OS-enforced per-process memory sandbox. The implementation must not claim an unmeasured universal RSS guarantee across all operating systems.

Once a hard processing ceiling is exceeded, emit `UVK-RES-001`, stop affected work, and mark affected coverage incomplete. It remains blocking even with `--allow-incomplete`. A texture header reaching its 1 MiB scan boundary without a conclusive dimension is the specific nonfatal coverage limitation described above; never continue reading beyond it. Report encoding that cannot fit the report ceiling is an operational report failure, not a partial JSON document.

### Compression and bomb resistance

No decompressor or image pixel decoder runs in the native path. The only accepted ZIP expansion ratio is exactly 1:1 for nonempty stored entries; a zero/zero stored entry has no expansion. Nonempty data declared with zero stored bytes, unequal stored sizes, any compression method, or sizes exceeding a hard ceiling is rejected before payload interpretation. This defines the compression-ratio policy without attempting to inflate a suspicious file. Internal PNG/JPEG image compression is not ZIP compression; dimension checks and the absence of pixel decoding bound that separate surface.

### File handling and privacy

- Open the input read-only, reject a symlink at the final input component and any non-regular input, and verify metadata through the opened descriptor before content reads. Avoid blocking on a FIFO/device during type checking.
- Use that descriptor for native reads; check for detectable file changes before returning. Do not promise a snapshot against a malicious writer that can alter bytes and restore metadata.
- No native filesystem reads for authored references, no extraction, no temporary asset files, and no writes to the input or its directory.
- Reject arithmetic overflow, invalid range conversions, truncated reads, and allocation requests beyond validated limits with controlled findings/errors; no unchecked indexing, force-unwrapping input-derived values, or fatal assertions on malformed input.
- Default reports use a bounded basename and safe archive-relative locations. Redact absolute/external reference values, unsafe member names that could reveal host paths, local configuration/output paths, and underlying OS error descriptions. Retain rule ID, entry/byte identity, and a useful reason.
- Escape control characters and terminal escape sequences in human output. JSON/SARIF must remain syntactically valid for malicious names and tool text.
- An explicit `--include-sensitive-details` permits absolute input/reference details and bounded raw tool output. Its effect must be documented; it does not disable terminal escaping or resource limits.

## Warning Budget Configuration

Use an explicit `--config PATH`; do not search the current directory, home directory, or environment. A missing config means the defaults below. The file is UTF-8 JSON with configuration `schemaVersion: 1` and a `budgets` object.

| Budget key | Default | Comparison |
| --- | --- | --- |
| `archiveBytes` | 104857600 (100 MiB) | Opened archive size |
| `fileBytes` | 26214400 (25 MiB) | Each regular entry |
| `fileCount` | 1000 | Regular entries |
| `textureBytes` | 20971520 (20 MiB) | Each texture entry |
| `totalTextureBytes` | 83886080 (80 MiB) | Sum of texture encoded bytes |
| `textureMaxDimension` | 4096 | Width or height for supported headers |

Only strictly greater values produce a budget warning; equality passes. Omitted keys use defaults. An explicit `null` disables only that warning budget. Present non-null values must be positive integers representable as signed 64-bit JSON integers; booleans, floats, negative values, zero, duplicate keys, unknown keys, unsupported schema versions, and trailing non-whitespace data are configuration errors. Require both top-level keys; unknown top-level keys are errors. No profile, tool command, filesystem search path, or safety-limit override can be supplied by a budget config.

Record the effective budgets in the report. Native and CLI callers use the same validation/defaulting semantics. Invalid configuration fails before any asset content or external tool is inspected.

Example configuration:

```json
{
  "schemaVersion": 1,
  "budgets": {
    "archiveBytes": 104857600,
    "fileBytes": 26214400,
    "fileCount": 1000,
    "textureBytes": 20971520,
    "totalTextureBytes": 83886080,
    "textureMaxDimension": 4096
  }
}
```

## CLI Contract

```text
usdz-validator validate INPUT
  [--format text|json|sarif]
  [--output PATH]
  [--profile general-v1|apple-portable-v1]
  [--config PATH]
  [--fail-on error|warning]
  [--allow-incomplete]
  [--usdchecker]
  [--include-sensitive-details]

usdz-validator rules
  [--profile general-v1|apple-portable-v1]
  [--format text|json]

usdz-validator --help
usdz-validator --version
```

- `validate` accepts exactly one local filesystem path. Reject URLs, stdin (`-`), directories, and multiple inputs; no recursive discovery, shell expansion, or batch mode. The filename need not end in `.usdz`; inspect content. Support `--` for option-like filenames.
- Defaults are text format, stdout destination, `general-v1`, built-in budgets, `--fail-on error`, incomplete coverage not accepted, no external execution, and sensitive details excluded.
- `rules` lists descriptors selected by the profile in stable rule-ID order; JSON has its own documented catalogue shape and `schemaVersion: 1`. It reads no asset and probes no tool. It lists coverage/resource descriptors as well as ordinary rules.
- Help and version write to stdout and return `0`. Version describes this validator, not the installed USD tools.
- Validation stdout is exactly one complete report followed by LF. No progress, banners, logs, ANSI color, or tool output appears beside a JSON/SARIF report. With `--output`, stdout is empty.
- Encode and size-check a report completely before emitting it. Treat a broken stdout pipe or write error as an operational failure without a SIGPIPE crash; a downstream write failure cannot guarantee delivery of a complete document.
- Stderr is reserved for concise invocation/configuration, operational, and report-destination diagnostics. Asset findings are part of the selected report, including text format.
- `--output` writes a complete report through an atomic same-directory replacement. Refuse a destination that is a symlink, non-regular existing file, or the input itself by path/file identity, including a hard link. Do not create missing parent directories. An ordinary existing report file may be replaced. Failure must not leave a truncated destination.
- Invalid invocation/configuration produces stderr and no report. Once invocation/configuration are valid, input I/O errors produce an operational-error report in the selected format if the destination is writable. A destination/encoding failure produces stderr and the operational exit code.

### Status and exit codes

The report keeps `validationStatus` (`passed`, `failed`, `incomplete`, `error`) separate from `gateDecision` (`pass`, `fail`) and `acceptedIncomplete`. Operational/internal errors give status `error`; blocking findings give `failed`; otherwise any native coverage gap or unsuccessful requested external check gives `incomplete`; the remaining outcome is `passed`. Set `acceptedIncomplete` true only when a native gap is explicitly accepted and the gate passes. An accepted native gap retains `validationStatus: incomplete`.

Evaluate outcomes in this precedence order:

| Exit | Meaning |
| --- | --- |
| `64` | Invalid invocation or configuration; no validation attempted |
| `70` | Unexpected internal failure; controlled error rather than a crash |
| `3` | Input I/O/change, output, or report-encoding failure |
| `1` | At least one native finding meets the selected failure threshold, a hard resource error occurred, or the external checker reported failure |
| `2` | No higher-priority failure, but native coverage is incomplete and unaccepted, or a requested checker was unavailable/unsupported/skipped/unable to complete |
| `0` | Gate accepted: all selected checks passed, or only explicitly accepted native coverage gaps/nonblocking findings remain |

`--fail-on warning` treats warnings and errors as blocking. Notes never block by severity. Limitations also affect completeness independently of this threshold. `--allow-incomplete` does not suppress limitation findings or override `--fail-on warning`, hard safety errors, or an unsuccessful requested external check.

When higher-priority findings produce exit `1`, still preserve incomplete coverage and external failure-to-run information. An exit code alone is not a full-conformance verdict.

## JSON and SARIF Compatibility

### Native JSON report schema v1

Provide a checked-in JSON Schema and example reports during implementation. The report envelope includes these required fields:

| Field | Contract |
| --- | --- |
| `schemaVersion` | Integer `1`, independent of product release version |
| `tool` | Validator name and semantic product version |
| `input` | Safe display name and byte size when available; absolute path only with sensitive-details opt-in |
| `configuration` | Profile ID, effective budgets, safety-envelope version, failure threshold, incomplete/sensitive-details choices, and external-check request |
| `coverage` | Per-area native completion and limitation reasons |
| `nativeFindings` | Deterministically ordered native findings |
| `externalCheck` | Always present, including `notRequested`; separate tool status/version/findings |
| `operationalErrors` | Typed, privacy-safe errors; empty when none |
| `summary` | Native counts by category/severity and external counts/outcome kept separate |
| `validationStatus`, `gateDecision`, `acceptedIncomplete`, `exitCode` | Explicit result/gate contract |

All declared report/model fields are present; use `null` for unavailable scalar values or locations and empty arrays for no findings/errors/reasons. The exception is sensitive-detail fields, which are omitted unless explicitly enabled. For example, an unreadable input has null byte size; an unprobed checker has null version/exit code and availability `unknown`. Availability otherwise is `available` or `unavailable`, independently of execution status. Apply this same representation in schemas and examples. Use integer byte counts, UTF-8 without BOM, LF endings, lexicographically ordered object keys, and deterministic escaping. Do not emit timestamps, durations, host/user identifiers, temporary paths, absolute working directories, or random invocation IDs in default reports.

Default report bytes are unchanged when the same asset is moved between directories with its basename preserved. Renaming the input may change its displayed basename and SARIF package URI, while native occurrence IDs and finding order remain stable. Sensitive-detail opt-in deliberately exposes location-dependent fields and is excluded from relocation-byte equivalence.

Within schema major version 1, retain required fields, field types, enum meanings, rule meanings, and category/severity interpretation. Additive optional fields and new rule IDs are allowed; consumers must ignore unknown optional fields and tolerate unknown rule IDs. Changing existing fields/types/enums or identity semantics incompatibly requires a new report-schema major version. Product semantic versioning remains separate; detection bug fixes can change findings, so byte reproducibility is promised for the same validator version/configuration/input and the same external result, not across arbitrary upgrades.

### SARIF

- Emit valid SARIF `version: 2.1.0` with the published OASIS schema URI. Validate against a pinned, locally available schema in tests; runtime validation performs no schema download.
- SARIF follows its own schema's omission rules for unavailable fields; the native JSON report's null convention does not override SARIF requirements.
- The first run is the native validator. Add a separate `usdchecker` run only when requested, including a failed/unavailable invocation when appropriate. Do not merge opaque external results into native rules or counts.
- Use stable rule IDs, descriptors, levels (`error`, `warning`, `note`), and `partialFingerprints` keyed by the documented occurrence-identity version.
- Preserve category, profile, evidence, native coverage, gate decision, and external provenance in SARIF properties.
- Physical locations identify the package using a safely encoded relative basename URI and an archive byte region when known. Put entry names and layer-relative locations in logical locations/properties; do not pretend USDA line numbers are lines in the binary ZIP file.
- For an unavailable/incomplete external invocation, `executionSuccessful` is false and an invocation notification explains why. A completed checker run that reports asset failures is still a completed tool invocation; its results and gate outcome express the failures.
- Native execution completion and native check coverage are distinct. A completed engine invocation may have partial coverage; record that explicitly in properties and limitation results. Operational failure sets invocation execution success false.
- General SARIF validity is required. No promise of acceptance by every hosted code-scanning product, source-line navigation into an archive, or automatic SARIF upload is part of v0.1.

Human-readable text has stable ordering and equivalent categories, provenance, coverage, and gate meaning. Its prose layout is not a machine compatibility interface.

## Optional Installed-Tool Adapter

- Disabled means no execution, including no `--version` probe. Do not use `usdcat` in the validator.
- `--usdchecker` explicitly selects the trusted-input path. Help/documentation must say that the installed tool has its own parsers/resolvers and can access resources beyond the native package-only boundary. Do not silently infer that its execution is sandboxed.
- Only `/usr/bin/usdchecker` is eligible. Do not search `PATH`, download tools, execute a path from the asset/config, or accept an arbitrary executable override in v0.1.
- Record availability separately from reported version and execution outcome. Initially support exactly the observed `Apple USD Tools (0.25.11)` adapter contract; unknown versions remain available-but-unsupported and prevent exit `0` when requested.
- Probe with an argument array and a 5-second timeout, at most 16 KiB captured output. Invoke supported validation with `--strict --rootPackageOnly --out stderr`, adding `--arkit` for `apple-portable-v1`, and the absolute input path as a separate argument. Do not invoke a shell or accept arbitrary extra arguments.
- The external `--arkit` policy remains that installed tool/version's policy, not the same claim as the native advisory profile. The observed tool describes a 2023 target; preserve this distinction.
- Require native container/safety prerequisites to complete without structural errors, unsafe paths/constructs, or hard-limit failures before passing the asset to the tool. Otherwise record `skippedUnsafeInput`. Native USDC reference limitations alone do not prevent this explicit trusted-input invocation.
- Use a minimal fixed environment, excluding inherited USD/plugin/Python resolver overrides, and a documented working directory equal to the input's parent. This improves repeatability but is not a filesystem/network sandbox.
- The fixed environment is `PATH=/usr/bin:/bin`, `LANG=C`, and `LC_ALL=C`; inherit no other environment variables. Record invocation arguments using the default path-redaction policy. Record phase `versionProbe` or `validation` for failed probes/execution so the same timeout/output statuses remain unambiguous.
- Limit validation to 60 seconds and combined stdout/stderr capture to 1 MiB. Drain both streams without deadlock. On timeout/output overflow, terminate the child, escalate to forced termination after at most one second if needed, reap it, and return an incomplete external status. Never wait indefinitely for output after termination.
- No hard external-process RSS, filesystem, or network-isolation guarantee is made. Such guarantees require a later isolated execution design. Native hostile-input guarantees do not transfer to the installed tool.
- External statuses are `notRequested`, `unavailable`, `unsupportedVersion`, `skippedUnsafeInput`, `completed`, `launchFailed`, `timedOut`, and `outputLimitExceeded`. Availability/version may be unknown if probing failed. An abnormal signal termination is `launchFailed` with a termination reason.
- For the supported adapter, exit `0` records `noFailureReported`; nonzero records `failureReported` and an opaque external aggregate finding `USDCK-001` with error severity and original exit status. Do not invent a cross-version parser for its human diagnostics or equate `noFailureReported` with complete native validation.
- Preserve bounded stdout/stderr capture as opaque tool diagnostics, separate from native findings. Default serialized reports include diagnostic presence/count metadata and an aggregate outcome; raw tool text is included only with `--include-sensitive-details`, escaped and capped. This avoids disclosing arbitrary local paths from an upstream diagnostic.
- Requested unavailable, unsupported, skipped, timed-out, output-limited, or failed-to-launch checks prevent exit `0`, even with `--allow-incomplete`. A completed tool-reported failure also blocks independently of the native threshold. The external adapter never upgrades native USDC/reference coverage.

External findings use separate IDs/provenance and SHA-256 of a length-delimited tuple containing identity version, `usdchecker`, reported tool version, external rule ID, and tool-reported outcome. Opaque message text and local paths do not define their identity. External text/order/outcomes are only as reproducible as the fixed installed tool and its accessible environment. The native findings and coverage subtrees must remain identical with the adapter disabled or enabled; overall configuration, external record, and gate fields can differ.

## Fixture Provenance and Licensing

Use small, original, deterministic fixtures as the default test corpus, licensed under MIT with original project code. Include valid USDA packages, small original PNG/JPEG headers/images, binary-header/USDC fixtures, and deliberately malformed archive byte sequences. Test-only archive builders may create alignment, CRC, count, overlap, and limit cases; they are not an asset-editing product feature.

Each committed fixture or fixture generator needs a manifest entry: stable fixture ID, purpose, author/source URL or `project-authored`, license identifier/text reference, attribution obligations, content SHA-256, generation recipe, and modification history. Tool-generated binary fixtures additionally record generator name/version/arguments and the original source's license. Tool output does not erase the source's license obligations.

Do not copy proprietary sample models or assume assets on an Apple/OpenUSD gallery are freely redistributable. Third-party assets require an explicit compatible redistribution license and necessary notices before inclusion. Offline tests must not download fixtures. Generate large/count/bomb-boundary cases in temporary test directories from deterministic recipes rather than committing huge assets. Deliberately nonconforming bytes must be labeled as such; a magic-only synthetic USDC fixture is not a valid-scene oracle.

## Verification and Test Layers

These are intended implementation/release checks, not commands already run in this specification phase.

1. **Unit tests:** checked binary reads, overflow/range handling, ZIP metadata consistency, exact path normalization, lexer states/escapes, budget boundaries/defaulting, stable identity/order, privacy escaping, and gate precedence.
2. **Fixture integration tests:** valid aligned stored containers; malformed/truncated/overlapping records; CRC, compression/encryption, ZIP64/descriptors and unsupported encodings; unsafe paths, duplicate/type conflicts; text/binary layers; missing references; PNG/JPEG headers and unsupported dimensions. Assert both findings and check coverage.
3. **CLI contract tests:** all formats, help/version/rules, every exit class, config rejection, stdout/stderr purity, report-file replacement safety, incomplete acceptance, and sensitive-detail opt-in. Run the built executable so build chatter cannot enter report snapshots.
4. **Schema/golden tests:** versioned JSON and SARIF schema validation, native/external separation, catalogue snapshots, same default report bytes across repeated runs and directory relocation with basename preserved, stable native occurrence IDs across renaming, and stable output across supported baseline/current CI combinations. Schema validators are development-only; any such dependency is pinned and licensed and is not linked into the product library.
5. **Adversarial/resource tests:** deterministic bounded mutations and truncation of each parser surface; malformed ZIP/image/USDA data never crashes. Test every safety ceiling at/beyond the boundary. Instrument input reads and allocation-driving counts; measure release-mode native peak RSS on arm64. For the documented local-SSD resource host, the maximum-envelope native corpus must finish within 60 seconds per invocation and at or below 256 MiB peak RSS. Record hardware/OS/toolchain and measurements; do not turn variable timings into report fields.
6. **Adapter tests:** use a test-only controlled process seam for missing/version/exit/timeout/output/deadlock cases; no arbitrary executable option in the public CLI. Run an explicitly enabled smoke test against the installed supported checker. A skipped real-tool smoke test must say skipped, never passed. All native tests must run with no USD tools installed or invoked.

Required verification commands once the package exists:

```sh
swift --version
xcodebuild -version
swift package resolve
swift build --build-tests
swift test
swift build -c release
swift test -c release
swift test --sanitize=address
```

CLI smoke examples using a future manifest-defined original valid USDA fixture:

```sh
.build/release/usdz-validator validate Tests/Fixtures/valid-usda.usdz
.build/release/usdz-validator validate Tests/Fixtures/valid-usda.usdz --format json
.build/release/usdz-validator validate Tests/Fixtures/valid-usda.usdz --format sarif
.build/release/usdz-validator rules --format json
/usr/bin/time -l .build/release/usdz-validator validate Tests/Fixtures/valid-usda.usdz
```

The same test suites must cover Swift 6.0 / Xcode 16.0 / macOS 15 on arm64 and the observed Swift 6.4 / Xcode 27.1 / macOS 27.0.1 arm64 environment. Pin the selected CI toolchains explicitly. If the baseline cannot be exercised, report that gap and do not claim the support requirement verified. The implementation plan must place the schema, resource, and opt-in adapter checks into runnable test targets/commands; passing only the smoke examples is insufficient.

## Acceptance Criteria

- **AC-01:** The Swift Package exposes `USDZValidation` and `usdz-validator`; a separate Swift test consumer can validate an asset without importing CLI code or invoking a process. Only the CLI has the Argument Parser dependency.
- **AC-02:** Build and native tests pass on the specified arm64 baseline and observed current toolchain. Unsupported architectures/platforms are documented without a support claim.
- **AC-03:** A manifest-defined aligned, stored, CRC-correct USDA package with safe existing references and within budgets yields complete selected native coverage, no blocking findings, and exit `0` without any USD tool execution.
- **AC-04:** Malformed signatures/lengths, truncation, overflow, inconsistent headers/directory metadata, overlap, and unindexed members produce the applicable stable error or established unsupported-boundary limitation without crashing or unsafe reads.
- **AC-05:** Compressed/encrypted entries, unequal stored sizes, misalignment, and CRC mismatch produce their separate documented IDs. No decompression occurs, including for extreme declared ratios or zero-byte compressed-size claims.
- **AC-06:** ZIP64, data descriptors, split archives, unsupported encodings/layouts, and nested packages never silently count as complete coverage or as universally invalid formats merely because unsupported.
- **AC-07:** Traversal/absolute/drive/UNC/backslash/control entry names, duplicate and file/directory conflicts, symlinks, and prohibited entry types are rejected without extraction or reference access outside the archive.
- **AC-08:** Literal USDA references resolve using the specified author/default-layer rules and exact package names. Missing/directory targets fail; safe internal `../` succeeds; root escapes and absolute/external paths fail with separate stable IDs.
- **AC-09:** The lexer handles both asset delimiters, escapes, comments, and quoted strings; it reports supported malformed tokens accurately. Expressions, UDIM/templates, package identifiers, and binary references produce limitations rather than fabricated missing-target findings.
- **AC-10:** A valid USDC package retains structural/byte-budget results but has incomplete native reference coverage. By default its unaccepted gap prevents exit `0`; `--allow-incomplete` changes only the gate, not coverage or finding provenance.
- **AC-11:** PNG/JPEG dimensions are obtained without pixel decoding; malformed headers, unsupported variants, scan-limit exhaustion, EXR, and AVIF follow the stated error/coverage contract. Disabling the dimension budget removes only that requested check.
- **AC-12:** Every warning budget is tested below, at, and above its threshold. Defaults, omitted keys, and explicit null disabling follow the schema; encoded texture totals count each classified entry once.
- **AC-13:** Configuration validation rejects unknown/duplicate keys, noninteger/invalid values, unsupported versions, oversized files, and trailing data before content inspection. Neither config nor CLI can relax hard safety ceilings.
- **AC-14:** Every fixed input/processing ceiling is exercised at and beyond its boundary. Reads remain within validated ranges/chunk/cumulative limits; findings truncation is deterministic, blocking, and explicit.
- **AC-15:** The maximum-envelope release resource corpus meets the documented 256 MiB RSS and 60-second native test-host targets. Measurements and host details are recorded; no giant fixture is committed.
- **AC-16:** Findings retain separate category, severity, rule/occurrence IDs, locations, and provenance. Repeated runs and relocation of identical archive bytes preserve native finding IDs/order; messages or thresholds do not define identity.
- **AC-17:** All profiles and selected rules are discoverable through `rules`. Apple advice appears only with `apple-portable-v1`, is warning-level, acknowledges broader current support, and makes no full renderer-compatibility claim.
- **AC-18:** CLI tests cover exactly-one-input handling, option-like paths, no stdin/URL/batch behavior, help/version, every exit class, and precedence when findings and incomplete coverage coexist.
- **AC-19:** Default error threshold, warning threshold, and incomplete acceptance behave exactly as specified. Safety failures and an unsuccessful requested checker never become exit `0` through `--allow-incomplete`.
- **AC-20:** Text/JSON/SARIF contain equivalent result meaning. JSON/SARIF stdout parses as exactly one complete document with no logging; `--output` leaves stdout empty and does not truncate an existing destination on failure or overwrite the input/hard link/symlink.
- **AC-21:** Versioned JSON reports/catalogues/configuration have checked-in schemas/examples and pass schema tests. SARIF validates as 2.1.0 and preserves categories, fingerprints, real byte locations, coverage, and distinct native/external runs.
- **AC-22:** Same input/configuration/validator version and fixed external results produce identical report bytes. Default reports contain no timestamps, random IDs, host/user identifiers, absolute local paths, or raw external output.
- **AC-23:** With external checks disabled, no tool is probed or executed and all native tests remain usable without USD tools. Enabling the adapter leaves native findings/coverage unchanged.
- **AC-24:** The adapter records availability, supported/unknown version, selected invocation policy, status, exit outcome, and separate finding provenance. Missing, unsupported, unsafe-skipped, failed-launch, timeout, and output-limit cases are explicit and never successful requested checks.
- **AC-25:** The supported checker uses only the fixed trusted executable and argument-array invocation, with the specified version/validation/output limits. Tests demonstrate concurrent stream draining and bounded termination rather than a hung child/pipe.
- **AC-26:** Checker failure is preserved as an external aggregate result without inventing native findings or upgrading USDC reference coverage. Raw opaque diagnostics are retained only within the bounded, explicit disclosure contract.
- **AC-27:** Input symlinks/non-regular files, detectable input changes, unreadable input/config, and unwritable outputs return controlled typed/report errors. Default human and machine diagnostics redact sensitive paths and escape malicious control sequences.
- **AC-28:** Deterministic adversarial parser fixtures and Address Sanitizer checks finish without crashes, unchecked overreads, or extraction. Unsupported content and malformed content are distinguished where evidence permits.
- **AC-29:** Every fixture/generator has the required provenance/license/hash/recipe metadata. Third-party material has explicit compatible redistribution rights and notices; offline tests download nothing.
- **AC-30:** User-facing documentation states the native inspection boundary, lexical-reference policy, profile scope, resource ceilings, warning configuration, schema/ID guarantees, exit semantics, and external trusted-input exception. It does not claim complete OpenUSD, Apple-platform, or asset-security certification.

## Edge Cases and Failure Propagation

- Empty/truncated/non-ZIP input: an established container error, no dependent reference scan, explicit incomplete coverage.
- Directories before the root layer: permitted; the first regular file determines the standalone default layer.
- `.usd` suffix: inspect the bounded magic; do not assume text. A valid-looking USDC magic is not a parsed crate.
- Valid absolute/custom-resolver USD paths: rejected by package-local policy, not labeled illegal USD syntax.
- Cyclic text references: no recursive composition/traversal is performed; each layer is scanned once, so cycles cannot create recursive work.
- Missing text target in inactive metadata/variant content: still a lexical-policy finding, with this scope disclosed.
- Limitations plus errors: preserve both coverage state and findings; apply exit precedence without speculative cascades.
- Large/damaged image: never decode pixels; preserve byte budgets even when dimensions are unavailable if the entry index is safe.
- Malicious terminal text or absolute paths authored inside the asset: escape/redact by default; hashed occurrence identity does not expose the original value.
- External checker pass with native USDC gaps: keep native coverage incomplete. Requested tool absence with accepted native gaps: still no exit `0`.
- External environment/version changes: preserve version/outcome/provenance and qualify reproducibility; do not attribute variation to native rules.

## Constraints and Out of Scope

Operate locally without a backend/cloud service. Validate one asset read-only. Enforce explicit resource bounds and maintain a reusable core. Original code and fixtures use MIT; all dependencies and third-party fixtures retain their applicable notices.

Non-goals for v0.1:

- A complete OpenUSD parser, composed-stage resolver, binary-USDC dependency parser, or full conformance guarantee.
- Editing, repair, conversion, normalization, preview, rendering, or a GUI/web/hosted product.
- Exhaustive Quick Look, RealityKit, visionOS, shader, material, animation, geometry, or visual-quality validation.
- Downloading/executing untrusted tools, automatic tool discovery, `usdcat` conversion, or arbitrary resolver plugins.
- ZIP64, data descriptors, recursive/nested-package inspection, general decompression, image pixel decoding, or every USD/Apple version.
- Intel/non-macOS support, batch/directory operation, hosted SARIF upload, or hard sandboxing of the optional installed checker.
- A public rule-plugin framework, speculative abstractions, product fixture generation, or a second executable helper.

## Notes, Sources, and Workflow Gate

Technical source boundaries used during design:

- [OpenUSD USDZ specification, version 1.3, pinned v26.08 source](https://github.com/PixarAnimationStudios/OpenUSD/blob/v26.08/docs/spec_usdz.rst): uncompressed/unencrypted storage, payload alignment, default-layer context, current member formats, package-local resolution concepts, and nested-package capability. This implementation deliberately supports a smaller inspection subset.
- [OpenUSD glossary, asset-path concepts](https://openusd.org/release/glossary.html): asset delimiters and the distinction between asset paths and prim paths.
- [PKWARE APPNOTE 6.3.10](https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT): ZIP record interpretation. Reference it without redistributing the document; implement only the explicitly selected subset.
- [Apple, Creating USD files for Apple devices](https://developer.apple.com/documentation/usd/creating-usd-files-for-apple-devices), consulted 2026-10-19: delivery-format and texture guidance. This evolving guidance is not a frozen certification matrix; the kit's profile is separately versioned.
- [OASIS SARIF 2.1.0](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html): report interoperability and invocation/result separation.
- [Swift Argument Parser 1.5.0 package manifest](https://github.com/apple/swift-argument-parser/blob/1.5.0/Package.swift): selected CLI dependency baseline.
- Installed `/usr/bin/usdchecker --help` and `--version`, and `/usr/bin/usdcat --version`: environment evidence, not evidence of asset validation.

The local repository had no prior specification candidates; this is the canonical new artifact at `docs/superpowers/specs/2026-10-19-usdz-validation-kit-design.md`.

Only this DRAFT specification is authorized in this phase. Leave it uncommitted. Do not scaffold Swift, install dependencies, create product files, update `main`, create a branch/worktree, write the implementation plan, commit, push, or merge. Stop after self-review and request explicit approval of this written specification. An approved specification would be followed by a separately approved implementation plan in a later phase.

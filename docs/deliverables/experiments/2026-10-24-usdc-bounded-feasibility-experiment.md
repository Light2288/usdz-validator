# Bounded USDC feasibility experiment — 2026-10-24

**Research spike; coverage PARTIAL; not a specification, implementation plan, architecture decision or production implementation.** This executes the initial questions in the [format/API research](../comparisons/2026-10-22-usdc-native-feasibility-research.md). The experimental code is disposable and remains outside the production build, in ignored `.verification/usdc-feasibility-2026-10-24/`. Nothing changes the validator's current USDC limitation, reporting or exit behavior.

**Result: conditional GO for a narrowly scoped native-reader direction; NO-GO for a release or a complete-USDC claim on this evidence.** An exact-0.8.0 reader recovered the expected authored values from small fixtures and useful reference inventories from three original packages while operating on bytes with host access denied. Two of the five original packages require newer crate versions. Correctness for every representation and the full memory envelope remain unproved.

## Evidence and reproducibility

The baseline is repository commit `c4f1229187c8ee430d1d77cdf17abfcae0b6589a`. No tracked file, production dependency, package target, specification or plan was changed. No branch, commit, push or merge was created.

Canonical local records, retained outside version control:

| Record | What it establishes |
| --- | --- |
| [summary.json](../../../.verification/usdc-feasibility-2026-10-24/summary.json) | Checked command exits, counts, repetition and measurement summaries |
| [census.json](../../../.verification/usdc-feasibility-2026-10-24/census.json) | Original package hashes, stored-member names, offsets, sizes, CRCs and header versions |
| [fixtures.json](../../../.verification/usdc-feasibility-2026-10-24/fixtures.json), [fixture-results.json](../../../.verification/usdc-feasibility-2026-10-24/fixture-results.json) | Original authored source expectations, generator commands/hashes and decoded occurrences |
| [compression-results.json](../../../.verification/usdc-feasibility-2026-10-24/compression-results.json), [oracle-results.json](../../../.verification/usdc-feasibility-2026-10-24/oracle-results.json) | Competing framing interpretations and pinned compression-source checks |
| [boundary-results.json](../../../.verification/usdc-feasibility-2026-10-24/boundary-results.json) | Deliberate malformed-input and budget stops |
| [containment-results.json](../../../.verification/usdc-feasibility-2026-10-24/containment-results.json) | OS denial controls, application audit events and the unreferenced-layer package case |
| [corpus-result.json](../../../.verification/usdc-feasibility-2026-10-24/corpus-result.json), `corpus-run-1.json` through `corpus-run-5.json` beside it | Per-layer authored occurrences, package lookup results and repeated measurements |
| [format-observations.json](../../../.verification/usdc-feasibility-2026-10-24/format-observations.json) | Additional byte-level PATHS and dictionary-key observations |
| [environment.json](../../../.verification/usdc-feasibility-2026-10-24/environment.json), [oracle-build.json](../../../.verification/usdc-feasibility-2026-10-24/oracle-build.json) | Actual tools, library/source hashes, compiler flags and harness limitations |

The local [run_experiment.py](../../../.verification/usdc-feasibility-2026-10-24/run_experiment.py) reproduces the checked run from the repository root:

```sh
python3 .verification/usdc-feasibility-2026-10-24/run_experiment.py
```

It requires the recorded local Apple samples, installed Apple USD Tools `0.25.11`, Python 3.14, clang and the recorded Homebrew LZ4 library. It installs nothing and downloads no assets. These ignored records include private local paths and asset references; they are local evidence, not distributed test prerequisites. Original sample redistribution rights remain unverified, as recorded in [apple-assets.md](../../verification/apple-assets.md). No sample member was extracted to disk.

The actual host was macOS 27.0.1 arm64, Python 3.14.7, Apple clang 21.0.0 and LZ4 1.10.0. This does not verify the project's minimum deployment target, Swift interoperability or another CI environment.

## Verified corpus census

The census read ZIP metadata and the USDC headers directly; it did not invoke a USD parser. All five packages contain one identified binary layer. All original fingerprints matched the earlier verification record before and after the experiment. Only stored ZIP payloads were read; ZIP decompression and extraction were not used. The decoder's corpus input was an in-memory copy of each inventoried layer, with its recorded CRC verified.

| Original | Crate header | Experimental outcome | Recovered nonempty authored occurrences |
| --- | --- | --- | ---: |
| `seahorse_anim_mtl_variant.usdz` | 0.9.0 | Unsupported at the exact-version gate | Not inspected |
| `pancakes_photogrammetry.usdz` | 0.10.0 | Unsupported at the exact-version gate | Not inspected |
| `fender_stratocaster.usdz` | 0.8.0 | Structural tables and selected authored values decoded | 10 |
| `slide.usdz` | 0.8.0 | Structural tables and selected authored values decoded | 4 |
| `teapot.usdz` | 0.8.0 | Structural tables and selected authored values decoded | 5 |

All 19 recovered nonempty paths matched regular members of their original package namespaces using the experimental literal path checker. This checker uses the original author member and default member; it constructs no host path. It is separate research code, not integration with the production [ReferenceResolver](../../../Sources/USDZValidation/Rules/ReferenceResolver.swift).

**Limit:** the three inventories have no independent exhaustive raw-field oracle for those original models. A successful package lookup proves that a recovered path has a package target, not that every authored occurrence was recovered. No composition, geometry or Fender subset-family validation was performed. Unsupported newer files were not rewritten or relabeled 0.8.0.

## Verified compression compatibility

Nine original USDA fixtures were converted to USDC with the installed Apple writer, without flattening or stage composition. Every generated header was 0.8.0. Their token blocks decoded with the **one-byte count** representation. The AOUSD document's eight-byte count interpretation failed on each tested token frame. The supplemental parser's one-byte count also works for these single-block cases, so those cases alone cannot settle chunk-size width.

A separate harness compiled the **unmodified pinned OpenUSD `fastCompression.cpp`** from commit `96c1989167d2aaab5bd34627f32a321a6b79866b`, with minimal declaration/diagnostic/namespace facades and the installed LZ4 library. It was built with AddressSanitizer and UndefinedBehaviorSanitizer. This is a compression-source harness, **not a full pinned OpenUSD runtime build**. The source hash was checked against the prior verified manifest; the exact build and facades are retained locally.

Nineteen checks passed with no sanitizer diagnostics:

- The pinned decompressor produced the same token bytes from all nine Apple-generated frames.
- The pinned compressor produced the same frames as the research compressor for those nine decoded token buffers.
- The pinned decompressor correctly consumed an independently constructed two-chunk frame with a one-byte count and four-byte signed lengths. One compressed chunk exceeds 255 bytes, making a one-byte size interpretation inadequate; the research decoder also matched the expected bytes.

The two-chunk frame is **synthetic**, not a naturally chunked output from an unmodified USD writer. The pinned writer only enters its chunked path above `LZ4_MAX_INPUT_SIZE`, approximately 1.97 GiB; producing that input would contradict this experiment's resource limits. All observed compression frames in the three decoded corpus layers had a zero count. Natural large chunked-crate compatibility remains untested.

**Conclusion supported by bytes and source:** choose one-byte/four-byte framing for compatibility with the tested deployed writer and pinned compression reader. No fallback between ambiguous framings was used during inventory decoding. **Still unresolved:** the published normative document continues to describe eight-byte/eight-byte fields; this experiment establishes observed implementation compatibility, not an authoritative erratum or AOUSD conformance.

Primary references: [AOUSD compression description](https://github.com/aousd/specifications-public/blob/2f9e746c4fbd7f48d6d2c9ac568133fe398bbfc0/core/1.0.1/core_spec.md#L10404-L10418), [pinned OpenUSD write/read code](https://github.com/PixarAnimationStudios/OpenUSD/blob/96c1989167d2aaab5bd34627f32a321a6b79866b/pxr/base/tf/fastCompression.cpp#L59-L116), [supplemental decoder](https://github.com/aousd/core-spec-supplemental-public/blob/1a4adb266a370f49ceedd2ce30442c2e7f457864/releases/1.0.1/file_formats/parsers/binary/compression.py#L27-L39).

## Demonstrated selective reference-reading subset

The approximately 240-line [probe.py](../../../.verification/usdc-feasibility-2026-10-24/probe.py) reads bootstrap/TOC, TOKENS, STRINGS, FIELDS, FIELDSETS, PATHS and SPECS, joins live spec fields and traverses selected typed values. It decompresses structural metadata and skips geometry value bodies. It is deliberately labeled experimental-partial on every result, even when no unsupported field was encountered.

Nine fixtures matched **41 expected authored asset/path occurrences**, including one empty asset literal, with distinct structural occurrence locators. Expectations were authored from the fixture source, not regenerated from decoder output.

| Case | Directly exercised evidence |
| --- | --- |
| Minimal mixed layer | Sublayers, references, payloads, scalar and array assets, duplicate values, customData, inactive prim, scalar time samples |
| Empty/reference-free layer | Numeric values and an asset-looking plain string produce zero occurrences |
| List operations | Explicit/add/prepend/append/delete/reorder occurrences retained; no application or deduplication of list operations; internal reference not treated as a missing file |
| Containers and variants | Nested dictionary asset arrays, selected and unselected variants, array time samples, empty asset array, empty asset literal |
| Reference customData | Both reference target and asset nested inside the reference's customData recovered |
| Unregistered dictionary | Nested asset recovered through an unregistered-value wrapper |
| Raw unregistered metadata | No invented parsed reference; an explicit unsupported reason retains incompleteness |
| Unsafe paths | Absolute, package-escaping and URI paths read as authored data without being opened; literal package target found separately |
| Explicit payload list | Two explicit payload items recovered from a PayloadListOp |

One important representation detail emerged: Apple's writer stores an explicit **single** payload as legacy scalar tag 47, while the two-item explicit payload fixture uses a list operation. Both forms were exercised; assuming every `payload` field is tag 55 would miss a real case.

A synthetic package with a reference-free root and an unreferenced binary layer yielded zero root occurrences and eleven from the unreferenced layer. The author directory remained `layers/` for its lookups. A separately injected unused asset-bearing FIELDS record produced zero occurrences, showing that this prototype follows the live joins rather than scanning interned assets indiscriminately.

Locators are original spec/path-index/field/container coordinates. Actual index offsets are retained where known; compressed ValueReps have no fabricated original byte or text position. Product occurrence IDs, privacy rules, JSON/SARIF output and exit semantics were not implemented or tested.

### Additional decoding-recipe observations

The small fixture's PATHS section has separate total-path and encoded-path counts before the compressed arrays, consistent with the [pinned OpenUSD reader](https://github.com/PixarAnimationStudios/OpenUSD/blob/96c1989167d2aaab5bd34627f32a321a6b79866b/pxr/usd/sdf/crateFile.cpp#L3872-L3899) and [compressed-path reader](https://github.com/PixarAnimationStudios/OpenUSD/blob/96c1989167d2aaab5bd34627f32a321a6b79866b/pxr/usd/sdf/crateFile.cpp#L3974-L3990). The [normative layout table](https://github.com/aousd/specifications-public/blob/2f9e746c4fbd7f48d6d2c9ac568133fe398bbfc0/core/1.0.1/core_spec.md#L10702-L10724) lists only one count.

Its dictionary keys index STRINGS: key index 0 identifies `note`, while TOKENS index 0 is `;-)`. This agrees with the [pinned dictionary/string reader](https://github.com/PixarAnimationStudios/OpenUSD/blob/96c1989167d2aaab5bd34627f32a321a6b79866b/pxr/usd/sdf/crateFile.cpp#L1240-L1262); the [normative dictionary prose](https://github.com/aousd/specifications-public/blob/2f9e746c4fbd7f48d6d2c9ac568133fe398bbfc0/core/1.0.1/core_spec.md#L11239-L11260) describes token indices. These are additional concrete points to reconcile, not a general rejection of the specification.

## Package-local containment evidence

The decoder takes bytes and in-memory package names. It loads no USD runtime, resolver or plugin. All runtime libraries and selected input bytes were loaded before applying a per-child macOS sandbox profile:

```text
(version 1)(allow default)
(deny file-read*)(deny file-write*)(deny network*)
(deny process-exec)(deny process-fork)
```

Six deliberate controls returned `EPERM`: host file read, host metadata read, host directory listing, outbound network connection, process execution and filesystem write. Decoding then completed for five containment fixtures and the unreferenced-layer package with zero recorded application I/O events. All five repeated corpus runs also applied this policy successfully and recorded zero prohibited decoder I/O events.

**Interpretation:** the exercised inventory computation can operate without further host filesystem/network access, after its runtime and bytes are supplied. The sandbox is a research-harness check, not a proposed production dependency or proof that an external OpenUSD resolver is contained. Python audit events are not exhaustive syscall tracing. No claim is made about adversarial memory corruption or every possible host configuration.

An initial attempt to deny data access during the Apple oracle's startup aborted before fixture conversion. The successful fixture writer used a narrower profile denying network access and user-file access except the research directory. The stronger deny-all-file-access policy was applied to the independent reader **after bootstrap**. Do not infer that the external Apple tool has been proved package-local.

## Boundedness and measured resources

The spike enforces experimental limits, not additions to the production ledger: 16 MiB per decoded buffer, 32 MiB cumulative reserved decode capacity, 250,000 table/container items, two million counted work units, nesting depth 32, 10,000 emitted occurrences and 4,096 characters per reference value. Python object sizes, Unicode byte sizes, locators and serialization are not comprehensively charged to those counters.

Twenty-nine focused checks passed. They cover forged table/TOC/container counts, declared expansion, truncated input/chunks, invalid LZ4, invalid token/field/path indices, invalid path jumps, a self-referential Value wrapper, excessive wrapper depth, cumulative decode/work/occurrence limits, unsupported version gating and unused-field exclusion. The forged token expansion was rejected before any decoded-buffer allocation. These cases do **not** establish exhaustive malformed-input handling, a complete type/flag validity matrix or an enforced whole-process memory ceiling.

Across five fresh corpus processes:

| Measurement | Observed range |
| --- | --- |
| Peak RSS for the complete Python corpus process | 55,033,856–55,083,008 bytes, approximately 52.5 MiB |
| Fender inventory computation | 1.79–1.89 ms |
| Slide inventory computation | 0.417–0.426 ms |
| Teapot inventory computation | 0.437–0.469 ms |

Decoded results were identical after excluding timing and RSS fields. The per-layer timers exclude initial file copying/hashing, sandbox setup, process startup and JSON serialization. RSS includes input loading and the Python runtime. The largest cumulative decoded-buffer capacity was 22,011 bytes for Fender; the small structural metadata explains why skipping geometry is useful on these files. This is a current-host feasibility observation, not a benchmark of a Swift implementation, worst-case USDC or the validator's end-to-end 256 MiB/60-second target.

## Licensing, build and separation

No new production dependency was added. The experiment used the already installed LZ4 1.10.0 library through `ctypes`; its BSD-2-Clause license was retained as `LZ4-LICENSE.txt`. The source harness retained OpenUSD's Tomorrow Open Source Technology License 1.0 as `OPENUSD-LICENSE.txt`. Forty-three prior primary-source files were copied unchanged into the ignored evidence directory only after SHA-256 verification against their pinned manifest; this retains the original specification/code notices. No supplemental parser was installed or imported, and no third-party model was copied into the research directory.

The full source-harness check requires clang and LZ4; fixture generation requires the installed Apple tool. These are research prerequisites, not verified shipping dependencies or portable CI instructions. This run does not resolve redistribution terms for Apple's binaries, a future Swift compression implementation's dependency choice, or minimum-platform/CI compatibility. The earlier research's licensing distinctions still apply.

## Decision and remaining uncertainty

**Verified:** an exact-0.8.0 selective reader can recover useful authored asset inventories on this corpus without composition or geometry decoding; package-only checking can operate on immutable bytes and names with further host I/O denied. The framing discrepancy is resolved for the tested implementation compatibility target, with a remaining normative-document mismatch. A 0.8-only tranche is relevant to three of these five samples.

**Hypothesis:** a maintainable native implementation can preserve those properties and cover the intended authored-reference semantics within the project's total resource envelope. The spike has not established this. It should not be reused as production code without a new approved scope and implementation workflow.

**GO:** retain limited native inspection as a viable candidate, with bounded internal USDC decompression explicitly distinguished from ZIP decompression or filesystem resolution. **NO-GO now:** claiming general modern-USDC coverage, treating recovered corpus counts as exhaustive, changing native completeness, or promising a release from these measurements.

The material unresolved questions are:

- Can version-specific 0.9/0.10 fixtures and the two remaining originals be inspected while correctly classifying TimeCode and PathExpression values? This is the most useful follow-up experiment before choosing whether v0.2 should target only 0.8.
- Can a complete type/flag/container classification and aggregate allocation/output model cover hostile inputs, including malformed strings, clip-template semantics and every valid wrapper form? Known numeric-body skipping is a research shortcut, not a full format-validation argument.
- Can raw authored-field traversal from a full, pinned development oracle independently confirm corpus inventories? The compression harness and expected fixture lists do not supply that exhaustive oracle.
- What authoritative clarification or versioned compatibility policy resolves the specification/source discrepancies? Large naturally chunked output was deliberately not produced.
- Can a later Swift implementation preserve truthful locations/identities, redaction and persistent partial-coverage behavior while meeting the actual minimum platform, CI, license and security maintenance obligations?

No specification, implementation plan or production integration was created by this experiment.

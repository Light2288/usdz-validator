# USDC 0.9.0 and 0.10.0 feasibility extension — 2026-10-24

**Disposable research experiment. All candidate results remain experimental-partial. This is not a specification, implementation plan, architecture decision or production integration.**

**Recommendation: conditional GO for a selective native authored-reference reader targeting exact crate versions 0.8.0, 0.9.0 and 0.10.0. NO-GO for declaring release readiness, general USDC support or complete native validation from this experiment.** The extension recovered 20 authored occurrences from seahorse and 20 from pancakes. Across all five Apple packages, all 59 recovered occurrences independently matched the development OpenUSD inventory by scene path, field, container position and literal value. Fourteen genuinely version-specific fixtures added 30 expected occurrences, all independently matched. Package-local decoding remained possible with further filesystem, network and process access denied.

The decisive qualification is that neither newer Apple sample actually contains a live TimeCode or PathExpression value. Their newer headers demonstrate structural compatibility; the generated fixtures supply evidence for those types. The Python oracle also has documented gaps, so its agreement is not a proof of universal completeness.

## Scope and retained evidence

Baseline HEAD: `c4f1229187c8ee430d1d77cdf17abfcae0b6589a`. All experimental code, dependencies, fixtures and raw results reside in ignored `.verification/usdc-feasibility-09-010-2026-10-24/`. The earlier experiment and research reports were preserved; SHA-256 checks confirmed all 143 previously fingerprinted experiment files unchanged. No production source, package manifest, tracked dependency or test changed. No branch, commit, push or merge was created.

Canonical local evidence:

| Record | Evidence supplied |
| --- | --- |
| [summary.json](/Users/davide/Personal/Projects/usdz-validator/.verification/usdc-feasibility-09-010-2026-10-24/summary.json) | Checked subprocess exits, environment, repetitions, measurements and input verification |
| [census.json](/Users/davide/Personal/Projects/usdz-validator/.verification/usdc-feasibility-09-010-2026-10-24/census.json) | Original hashes, versions, stored ZIP offsets, CRCs and package namespaces |
| [version-fixtures.json](/Users/davide/Personal/Projects/usdz-validator/.verification/usdc-feasibility-09-010-2026-10-24/version-fixtures.json) and [version-fixture-results.json](/Users/davide/Personal/Projects/usdz-validator/.verification/usdc-feasibility-09-010-2026-10-24/version-fixture-results.json) | Writer commands, actual headers, source/crate hashes, expected values and live new-type flags |
| [fixtures-final.json](/Users/davide/Personal/Projects/usdz-validator/.verification/usdc-feasibility-09-010-2026-10-24/fixtures-final.json) | All nine baseline and fourteen new fixture results under the candidate I/O policy |
| [corpus-final.json](/Users/davide/Personal/Projects/usdz-validator/.verification/usdc-feasibility-09-010-2026-10-24/corpus-final.json) | Candidate occurrences, live spec/field inventories and package checks; five separate run files are retained beside it |
| [oracle-final.json](/Users/davide/Personal/Projects/usdz-validator/.verification/usdc-feasibility-09-010-2026-10-24/oracle-final.json) and [oracle-comparison.json](/Users/davide/Personal/Projects/usdz-validator/.verification/usdc-feasibility-09-010-2026-10-24/oracle-comparison.json) | Independent authored inventory, semantic differences, actual spec reconciliation, API omissions and textual fallback evidence |
| [version-boundary-results.json](/Users/davide/Personal/Projects/usdz-validator/.verification/usdc-feasibility-09-010-2026-10-24/version-boundary-results.json) and [boundary-results.json](/Users/davide/Personal/Projects/usdz-validator/.verification/usdc-feasibility-09-010-2026-10-24/boundary-results.json) | 29 extension checks and 29 retained baseline checks |
| [containment-final.json](/Users/davide/Personal/Projects/usdz-validator/.verification/usdc-feasibility-09-010-2026-10-24/containment-final.json) | Six OS denial controls, zero candidate I/O events, unsafe paths and unreferenced-layer evidence |
| [oracle-wheel-pin.json](/Users/davide/Personal/Projects/usdz-validator/.verification/usdc-feasibility-09-010-2026-10-24/oracle-wheel-pin.json), [USD-CORE-LICENSE.txt](/Users/davide/Personal/Projects/usdz-validator/.verification/usdc-feasibility-09-010-2026-10-24/USD-CORE-LICENSE.txt) and [evidence-manifest.json](/Users/davide/Personal/Projects/usdz-validator/.verification/usdc-feasibility-09-010-2026-10-24/evidence-manifest.json) | Runtime provenance, retained license/notices and local evidence hashes |

The [local runner](/Users/davide/Personal/Projects/usdz-validator/.verification/usdc-feasibility-09-010-2026-10-24/run_experiment.py) reruns the checks from the repository root without downloads, installs or fixture rewriting:

```sh
python3 .verification/usdc-feasibility-09-010-2026-10-24/run_experiment.py
```

It requires the recorded original packages, existing fixtures, isolated oracle environment, installed Apple tools and Homebrew LZ4. Each child has a 60-second parent timeout and a 32 MiB limit on each output file. Those are harness controls, not a measured whole-process memory bound. Canonical records are the `*-final.json` files, five repeated corpus files and `summary.json`; earlier `*-initial.json` files retain exploratory results only.

## Verified corpus results

Original packages were hashed against the historical verification fingerprints before and after the run. Their identified USDC members were read directly from stored ZIP payloads into memory, checked by CRC and never extracted to disk. No ZIP inflation was needed.

| Apple sample | Crate | Authored occurrences | Actual candidate/OpenUSD specs | Package matches | Live tags 56/57 |
| --- | --- | ---: | ---: | ---: | --- |
| `seahorse_anim_mtl_variant.usdz` | 0.9.0 | 20 | 426 / 426 | 20 | Neither |
| `pancakes_photogrammetry.usdz` | 0.10.0 | 20 | 735 / 735 | 20 | Neither |
| `fender_stratocaster.usdz` | 0.8.0 | 10 | 432 / 432 | 10 | Neither |
| `slide.usdz` | 0.8.0 | 4 | 89 / 89 | 4 | Neither |
| `teapot.usdz` | 0.8.0 | 5 | 103 / 103 | 5 | Neither |

No unsupported live field was reported on these five files. Their semantic results were identical across five fresh candidate processes. All 59 occurrences matched regular members of their original package namespaces using only literal names, the author member and the default member. Package lookup remains separate from inventory reading; a successful lookup alone does not establish completeness.

All observed compression frames across these layers and the new fixture runs used the zero-count single-block form. The extension retained the earlier one-byte count/four-byte signed chunk-length decoder. The earlier pinned compression-source harness and synthetic two-chunk evidence remain applicable; they were not replaced by an assertion that newer headers imply a new framing. No natural multi-gigabyte chunked crate was generated. The normative-document discrepancy remains unresolved by an authoritative erratum; see the [earlier experiment](/Users/davide/Personal/Projects/usdz-validator/docs/deliverables/experiments/2026-10-24-usdc-bounded-feasibility-experiment.md).

## Genuine version-specific fixtures

Seven original USDA cases were independently exported using both installed Apple USD Tools `0.25.11` and the isolated upstream `usd-core==26.11` runtime. The writers naturally emitted the required headers; no version bytes were relabeled to produce positive fixtures. Every 0.9.0 fixture contains live tag 56, and every 0.10.0 fixture contains live tag 57.

| Authored case | Actual crate | Forms exercised | Expected occurrences per writer |
| --- | --- | --- | ---: |
| `tc09-scalars` | 0.9.0 | Scalar TimeCode, negative and precise values, layer metadata, ordinary assets | 2 |
| `tc09-arrays` | 0.9.0 | Nonempty/empty TimeCode arrays, scalar/array time samples, duplicate assets | 4 |
| `tc09-empty` | 0.9.0 | Numeric TimeCode values and misleading plain string; no assets | 0 |
| `pe10-mixed` | 0.10.0 | Scalar/array/empty PathExpression, expression references, layer metadata, TimeCode | 3 |
| `pe10-containers` | 0.10.0 | Nested metadata, selected/unselected variants, scalar/array expression samples, asset samples | 5 |
| `pe10-empty` | 0.10.0 | Scene property patterns, expression references and plain strings; no assets | 0 |
| `pe10-asset-expression` | 0.10.0 | PathExpression alongside an asset expression and expression variables | 1 |

All fourteen files matched their independently authored expectations: 30 occurrences total, including duplicates. The nine retained baseline files still matched their 41 expected occurrences, including one empty asset literal. Thus 23 fixture results cover 71 expected occurrences. The raw unregistered fixture deliberately remains unsupported despite yielding no parsed occurrences.

The minimum additional classification demonstrated here is:

- **TimeCode, tag 56:** numeric values introduced with crate 0.9.0. The candidate checks observed out-of-line scalar storage and array counts/ranges without treating them as assets. Genuine fixtures exercised flags 0 and 128, including empty arrays and values in time samples.
- **PathExpression, tag 57:** scene-path patterns and expression references, introduced with crate 0.10.0. The candidate bounds string-table indices and array counts, never evaluates expressions and emits no file references for them. Genuine fixtures exercised flags 0 and 128, including empty arrays and time samples.
- Existing asset-bearing containers still require traversal: dictionaries, asset arrays, references/payloads, all authored list-operation buckets, wrappers and time samples. The newer header cannot justify skipping these joins.

These conclusions agree with pinned OpenUSD [type tags](/Users/davide/Personal/Projects/usdz-validator/.verification/usdc-feasibility-2026-10-24/sources/openusd/pxr/usd/sdf/crateDataTypes.h:101), [writer version upgrades](https://github.com/PixarAnimationStudios/OpenUSD/blob/96c1989167d2aaab5bd34627f32a321a6b79866b/pxr/usd/sdf/crateFile.cpp#L1522-L1543), [reader representations](https://github.com/PixarAnimationStudios/OpenUSD/blob/96c1989167d2aaab5bd34627f32a321a6b79866b/pxr/usd/sdf/crateFile.cpp#L1264-L1269) and the [PathExpression API](https://github.com/PixarAnimationStudios/OpenUSD/blob/96c1989167d2aaab5bd34627f32a321a6b79866b/pxr/usd/sdf/pathExpression.h#L26-L55). Source commit: `96c1989167d2aaab5bd34627f32a321a6b79866b` (v26.11.1). The newly fetched headers have pinned URLs and checked hashes in the local source manifest.

**Authored asset expressions are a different case.** The expression fixture preserves the literal asset expression, including its backticks and variable reference. It does not substitute `textures/evaluated-must-not-replace-authored.png`. This verifies inventory preservation, not expression resolution. Feeding such expressions indiscriminately to a literal package checker could produce misleading missing-file findings; their target validation remains unresolved. PathExpression's scene references do not require that same file-resolution behavior.

## Independent authored-inventory cross-check

The isolated oracle uses `Sdf.Layer.FindOrOpen`, `Layer.Traverse`, `GetObjectAtPath`, `ListInfoKeys` and `GetInfo`. It opens each original through its package identifier, such as `original.usdz[member.usdc]`; it does not extract the member or open a `UsdStage`. It reads authored spec fields, all six list-op buckets, dictionaries, asset arrays, reference customData and samples. Asset values come from `Sdf.AssetPath.authoredPath`, preserving authored expressions rather than evaluated or resolved paths.

Comparison uses **multisets of scene-path elements, field name, container locator and literal value**, preserving multiplicity. It normalizes a legacy scalar single payload to the API's explicit-list position only for comparison. Candidate spec/path indices are independently translated to scene-path elements rather than assuming the two readers share table order.

Verified outcomes:

- All five corpus inventories agree: **59 occurrences** with zero semantic differences.
- All fourteen new inventories agree: **30 occurrences** with zero semantic differences.
- Eight of nine baseline inventories agree; the remaining fixture exposes the API omission below. Zero-versus-zero agreement on the raw unsupported fixture is not evidence of completeness.
- Actual authored-spec path sets agree for all 28 inputs. The five corpus traversals also yield 75, 82, 68, 14 and 17 target paths respectively without Python spec objects. Every one is identified by `IsTargetPath()`. Excluding those traversal-only paths exactly reconciles the actual spec sets; they were not silently discarded as missing fields.
- Comparing native live field names with the API's reported keys exposes only structural child fields (`primChildren`, `properties`, variant children) in the corpus/new fixtures, plus the deliberate unregistered metadata omissions in the baseline fixtures.

**Oracle limitations, independently observed:**

1. `ListInfoKeys` silently omits `arbitraryMetadata` in both unregistered fixtures. Consequently, the API inventory misses `wrapped.png`, which the candidate and authored source identify. `ExportToString` on these small fixtures independently preserves both the nested typed asset and the raw `@raw-unregistered.png@` metadata. This textual evidence is retained; it is not presented as a general raw-field API oracle. The candidate intentionally cannot certify the raw wrapper.
2. The baseline sublayer fixture's `GetInfo("subLayerOffsets")` raises a Python converter `TypeError`. Its `subLayers` paths are still compared, while the offset field remains an explicit API gap.
3. `GetInfo` can unpack numeric and geometry values even when the Python walker ignores their contents. The oracle is a trusted development tool with broader decoding behavior than the selective candidate. No bounded-allocation claim is made for that runtime.
4. The oracle wheel reports runtime `(0, 26, 11)`. It is a separately packaged implementation, not a build of the pinned v26.11.1 source commit and not Apple's runtime. Two writers and the oracle still share OpenUSD lineage; this is independent execution and expectations, not three independent format implementations.

These checks substantially strengthen the evidence over the earlier candidate-only corpus counts. They do not establish correctness for every legal authored representation or hidden/unregistered field.

## Package-local access and bounded decoding

The native candidate still receives only input bytes and in-memory namespace data. It loads no USD resolver, plugin or runtime. After bootstrap and input loading, the per-child policy denies all filesystem reads/writes, network access, process execution and process forks. All 23 fixture decodes and five repeated corpus processes complete with that policy active and no forbidden candidate I/O attempts.

The containment matrix includes genuine 0.9.0/0.10.0 files and the authored asset-expression fixture. Six negative controls return `EPERM`: host file read, host stat, directory listing, network connection, process execution and filesystem write. The retained synthetic package still yields zero occurrences in its root and eleven in an unreferenced binary member. Absolute paths, escaping paths and URI literals remain data and are checked against names without host access.

The oracle has a **different** policy: after warming its libraries and file formats, it can read only the exact 28 listed input files, plus ancestor metadata. Network, writes, execution and forks remain denied; unlisted host read and metadata controls are denied. This demonstrates the exercised development oracle run under restricted inputs, not a reason to ship OpenUSD or a proof of universal resolver containment. Fixture writers use the weaker research-directory policy and are not claimed to satisfy the candidate's boundary.

Experimental candidate limits remain 16 MiB per decoded buffer, 32 MiB cumulative reserved decode capacity, 250,000 table/container items, two million work units, depth 32, 10,000 occurrences and 4,096 characters per reference. Structural path reconstruction additionally enforces the same depth bound. Python objects, Unicode byte sizes, locators and serialization are not fully charged to these counters; there is no enforced aggregate RSS ceiling.

**58 focused checks passed:** the retained 29 malformed-input/budget/live-field checks plus 29 extension checks. The latter exercise unproved patch/future/major versions, newer tags under older headers, unsupported flags, bad scalar offsets, truncated scalar/array storage, forged TimeCode/PathExpression array counts, bad PathExpression string indices and path-depth limits. Synthetic corruptions exercise rejection; they are not positive version fixtures. No fuzz campaign, exhaustive type/flag validity matrix or adversarial allocator proof was performed.

Across the canonical five fresh corpus processes:

| Measurement | Observed range |
| --- | --- |
| Complete Python candidate-process peak RSS | 56,803,328–56,885,248 bytes, approximately 54.2 MiB |
| Seahorse inventory and namespace checks | 6.88–7.01 ms |
| Pancakes inventory and namespace checks | 4.47–4.60 ms |
| Fender inventory and namespace checks | 2.00–2.06 ms |
| Slide inventory and namespace checks | 0.512–0.523 ms |
| Teapot inventory and namespace checks | 0.526–0.541 ms |
| Largest cumulative reserved decode capacity | 39,078 bytes, seahorse |
| Trusted OpenUSD oracle peak RSS, one run | 93,814,784 bytes, approximately 89.5 MiB |

Candidate layer timers include path/spec evidence construction and package checking, but exclude input hashing/loading, sandbox setup, process startup and JSON serialization. Parent wall times and oracle timing are separately retained. These current-host observations do not prove the validator's complete resource target, a future Swift implementation's behavior or minimum-platform compatibility.

## Licensing and CI implications

No production dependency was added. The actual environment was macOS 27.0.1 arm64, Python 3.14.7, Apple USD Tools 0.25.11 and Homebrew LZ4 1.10.0. The project currently targets macOS 15 and Swift 6; that deployment target and either architecture's CI have not been exercised by this Python spike.

The oracle wheel is pinned as `usd_core-26.11-cp314-none-macosx_10_15_universal2.whl`, SHA-256 `24d8bdedc4696cdde55b31f7dcb934dcc2deab33f6f7aaa35db221cc4787cb4b`, verified against its PyPI record and installed locally with `--no-index --no-deps --require-hashes`. Its metadata requires Python `>=3.11,<3.15`. The retained wheel license identifies **Tomorrow Open Source Technology License 1.0**, with third-party notices including LZ4 and other components; it must not be summarized simply as Apache-2.0. No inference is made that every notice denotes a library linked into this particular wheel.

| Direction | Licensing consequence | Build/CI consequence and present evidence |
| --- | --- | --- |
| Selective native byte reader | An independent reader avoids shipping the full OpenUSD runtime; an LZ4 dependency still needs its BSD-2-Clause notices and an explicit dependency choice. Copying OpenUSD implementation code would introduce its license obligations. | Candidate fixtures can be original, small and checked in under a later approved scope. This spike used Homebrew LZ4 through Python; Swift interoperability, dependency packaging and macOS 15 remain untested. |
| Installed Apple tools | This experiment does not establish redistribution rights for Apple's executables. | Their local writer emitted genuine 0.9/0.10 files. Tool availability/versioning and startup I/O remain external prerequisites; candidate-level containment was not established for them. |
| Full OpenUSD dependency | The tested wheel carries TOST-1.0 plus bundled notices; a source/runtime distribution requires its own notice and dependency assessment. | The isolated wheel provides a practical development oracle without building all of OpenUSD. Shipping it would add a substantial binary/runtime/resolver surface. Wheel Python/platform availability is a development concern, not a Swift shipping solution. No portable CI or whole-runtime bounds were verified. |

Original Apple model redistribution rights remain unverified. They need not become a distributed fixture prerequisite: the version-specific fixtures are original authored cases. The archived local experiment contains package paths and authored inventories; it is evidence for this machine, not a ready-to-publish portable test suite.

## Recommended v0.2 scope and remaining uncertainty

**Recommended direction, not an approved specification:** investigate a selective native inventory reader for **exact 0.8.0, 0.9.0 and 0.10.0**, preserving package-local byte access and the existing resolver boundary. The demonstrated subset covers live structural joins and authored assets in the exercised dictionaries, arrays, references/payloads, list operations, variants, inactive prims, wrappers and samples. TimeCode and PathExpression should be classified as typed non-file values in their demonstrated representations. No stage composition, geometry validation, scene-expression evaluation, external resolution or automatic fallback to installed tools is needed for the evidence-backed benefit.

The evidence no longer supports choosing 0.8-only because the other two samples were uninspected: those samples now work experimentally and independently agree. It also does not support accepting arbitrary newer headers. Unknown versions, unsupported representations, raw unregistered values, budget exhaustion and unresolved asset-expression semantics need truthful incomplete outcomes. The spike's literal package checker is not ready to make target-validity claims for authored asset expressions.

**Verified:** the expanded subset recovers useful, independently corroborated authored inventories on this corpus under the candidate's I/O denial policy. New-type fixtures contain the actual version-specific types; they do not merely carry newer headers. The expected values, multiplicities and scene locations agree across readers in the stated cases.

**Hypotheses:** the same subset can become maintainable Swift code within the project's aggregate resource envelope; the observed corpus agreement generalizes to broader legal metadata; the source-compatible framing policy can remain stable as a long-term maintenance target. None is established by these measurements.

The remaining experiments that would materially reduce uncertainty are:

- Exercise the proposed allocation/output accounting on hostile bounded structural tables, long/multibyte strings, dense locators and nested containers; measure the complete process rather than only decoded buffers. The current counters omit real allocations.
- Expand representation and mutation evidence for unregistered list/wrapper forms, legal flag combinations and clip/template metadata; use an oracle capable of exposing unknown fields or retain explicit per-case source/text evidence. The current Python spec API cannot certify those fields exhaustively.
- Probe asset-expression and template-bearing metadata without evaluation or host resolution, establishing which cases can only be inventoried and which must remain incomplete for package-target validation. The current expression fixture establishes preservation only.
- Validate any eventual Swift/LZ4 dependency choice and sandbox-independent byte boundary on macOS 15 and intended CI architectures. This is still a feasibility question, not a production integration authorized here.

Naturally chunked huge crates remain deliberately outside this resource-bounded experiment. The normative/source discrepancies still require a documented compatibility interpretation or authoritative clarification. No further version expansion is justified by these results alone.

This extension ends with a **conditional GO for the native authored-reference direction and a wider exact-version candidate scope**, while retaining a **NO-GO for release/completeness claims**. No specification, implementation plan or production integration was created.

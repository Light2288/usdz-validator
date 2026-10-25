# USDC reference coverage v0.2

**Slug:** `usdc-reference-coverage-v0-2`
**Type:** feature
**Status:** APPROVED
**Date:** 2026-10-24
**Provenance:** User requests and native interactive selections in this conversation; the approved baseline `docs/superpowers/specs/2026-10-19-usdz-validation-kit-design.md`; feasibility evidence in `docs/deliverables/experiments/2026-10-24-usdc-09-010-feasibility-experiment.md`. Repository evidence was inspected directly under the user's earlier authorization. No legacy specification is a source.

**Approval record:** The user confirmed the scope and design with “yes it is ok”, then explicitly requested “write the spec only”. After the saved DRAFT specification was presented for Stage 2 review, the user replied “approved” on 2026-10-24. This is explicit specification approval and authorizes Stage 3 implementation planning only. Implementation remains unauthorized until the separate implementation plan has been presented and explicitly approved.

## Problem and desired outcome

### Current behavior

Currently, native inspection recognizes USDC signatures but marks every binary layer's reference coverage incomplete. It cannot identify missing or unsafe references inside those layers.

### Desired outcome

v0.2 will automatically inspect authored references in an explicitly supported subset of **exact crate versions 0.8.0, 0.9.0 and 0.10.0**. Supported cases may achieve complete reference coverage. Unsupported representations, unresolved reference semantics and processing stops retain explicit gaps.

“Complete reference coverage” means completion of this declared package-local authored-reference policy. It does not establish full USD validity, composed dependencies, geometry correctness or renderer compatibility.

User-selected decisions:

- Automatic native inspection, without a new option.
- Complete coverage permitted only for the verified subset.
- A small pinned LZ4 dependency is permitted.
- Conclusively malformed supported structures produce blocking errors.
- Full verification on the recorded current arm64 host is required. macOS 15 remains intended compatibility, explicitly unverified until tested.

## Supported behavior and architecture

### Native boundary

Inspect every eligible binary layer, including unreferenced layers and binary content classified through a `.usd` suffix. Preserve existing namespace, stored-payload, integrity and default-layer prerequisites.

The reader uses bounded ranges from the existing read-only snapshot. Its only decompression capability is bounded **crate-internal metadata decoding**. ZIP entries remain stored-only.

Native inspection must not extract files, resolve references against the host filesystem, access the network, execute tools, load resolver plugins, compose a stage or evaluate expressions.

Use an independent Swift crate reader and a private C target built from pinned upstream **LZ4 1.10.0** source. Record source hashes and retain its BSD-2-Clause license and notices. Shipping and native test execution must not depend on Homebrew, Python, installed USD tools or an OpenUSD runtime.

This approach preserves the selected boundary while accepting responsibility for maintaining the selective parser. An inventory that always remains partial was considered and declined. Installed-tool conversion and a full OpenUSD runtime remain outside the native design.

### Reference-reading subset

Read and validate the structural joins through bootstrap/TOC, TOKENS, STRINGS, FIELDS, FIELDSETS, PATHS and SPECS. Follow live spec fields; unused field records and asset-looking interned strings do not create occurrences.

Support the demonstrated forms of:

- Scalar and array assets, sublayers and nested dictionaries.
- Layer/prim metadata and reference customData.
- All six authored reference/payload list-operation buckets, without applying or deduplicating them.
- Legacy scalar payloads.
- Typed wrappers and unregistered dictionaries; supported unregistered list containers retain gaps for uninspectable contents.
- Scalar and array time samples.
- Selected and unselected variants and inactive prims.

Preserve occurrence multiplicity. Empty asset values require no target. Internal references and payloads with empty file paths do not create missing-file findings; reference customData is still inspected.

Binary string values are consumed as serialized UTF-8 bytes, without USDA delimiter unescaping. Lookup preserves exact bytes and existing author/default-directory rules.

Classify TimeCode tag 56 from 0.9.0 and PathExpression tag 57 from 0.10.0 in their demonstrated scalar, array, empty and sampled forms. They are not external asset references. Geometry and other proven non-asset bodies may be skipped only under an explicit version/type/flag classification.

Raw unregistered values, unknown types and unproved representations leave coverage incomplete. Ordinary strings are not guessed to be asset references. Known path-bearing string metadata, including nonempty clip `templateAssetPath`, must instead produce an explicit unsupported-reference gap when its semantics cannot be inspected.

Asset expressions, variables, UDIM/templates and bracketed package identifiers follow the existing unsupported-identifier policy: retain established unsafe-prefix findings, never evaluate them and never fabricate missing targets.

### Format compatibility and failure behavior

The compatibility target is the pinned OpenUSD implementation studied in the experiment: commit `96c1989167d2aaab5bd34627f32a321a6b79866b`, using one-byte compression counts and four-byte signed chunk lengths. Do not try alternate framings until one yields an inventory.

Document the published specification discrepancies. A failure that could arise from an unsupported or disputed representation is a limitation, not proof of format corruption.

Diagnostics:

| Condition | Behavior |
| --- | --- |
| Entire binary layer remains uninspected | Retain `UVK-LIM-002` |
| Binary inspection is partial | Add `UVK-LIM-007`, warning, `validatorLimitation`, reference family |
| Unsupported asset expression/template/identifier | Reuse `UVK-LIM-003` |
| Conclusively malformed inspected USDC structure | Add `UVK-USD-001`, error, `policy`, reference family; affected coverage remains partial |
| Hard processing ceiling exceeded | Reuse blocking `UVK-RES-001`; affected coverage remains incomplete |
| Established unsafe, escaping or missing literal target | Reuse existing reference-policy rules |

Stop dependent traversal when structural prerequisites fail. Preserve already established findings and continue independent work only when safe.

The external checker remains separately opt-in and cannot upgrade native coverage. Gate precedence and `--allow-incomplete` behavior remain unchanged.

## Resource and reporting constraints

Introduce **safety-envelope version 2**. Preserve existing ceilings and add these fixed, non-configurable USDC limits:

| Resource | Ceiling |
| --- | ---: |
| Each compressed or decoded metadata block | 16 MiB |
| Cumulative reserved decode capacity per invocation | 32 MiB |
| Charged live USDC working storage per invocation | 64 MiB |
| Items in each table or container | 250,000 |
| USDC structural work per invocation | 2,000,000 units |
| Value nesting and structural path depth | 32 |

USDA and USDC share the existing **4 KiB UTF-8 asset-value** and **100,000 occurrence** limits. Existing finding, read and report limits remain binding.

Charge checked sizes before allocation or expansion, including temporary copies, C buffers, decoded tables, retained strings, indexes, traversal state and reference scratch storage. Count work for processed table/container elements, graph edges, ValueReps and compression chunks; bulk byte processing is additionally bounded by read and decode quotas.

Process layers sequentially. Do not copy an entire large binary layer merely to inspect metadata. Release transient decoding storage before report rendering.

Acceptance still requires the complete release CLI process, including reporting, to meet **256 MiB peak RSS and 60 seconds** on the recorded current host. These are measured acceptance targets, not an OS-enforced memory sandbox. The proposed counters alone do not establish compliance.

Public compatibility:

- Keep report/config/catalogue schema major 1 and current profile meanings.
- Add no public CLI option, configuration switch or reference-inventory API.
- Update the product version to 0.2.0 without publishing a release.
- Preserve existing USDA occurrence identity semantics.
- Give binary occurrences stable structural discriminators so duplicates sharing a stored value remain distinct.
- Use existing location/evidence fields for bounded numeric structural coordinates. Do not invent line/column coordinates or physical offsets inside compressed data.
- Default reports disclose no raw authored paths, dictionary keys, scene names or host details.
- Preserve deterministic discovery, ordering, truncation, privacy and native/external separation.

## Acceptance criteria

- **AC-01 — Automatic inspection:** Every eligible binary layer is considered, including unreferenced members and binary `.usd` files, without executing or probing a USD tool.
- **AC-02 — Exact versions:** Genuine 0.8.0, 0.9.0 and 0.10.0 fixtures are supported within the subset. Unproved patch, future and major versions retain explicit limitations. Magic alone never establishes completeness.
- **AC-03 — Authored occurrences:** Demonstrated containers, list buckets, samples, variants and inactive prims preserve values, locations and multiplicity. Unused records produce no occurrences. Empty/internal-reference behavior follows the supported behavior above.
- **AC-04 — New value types:** Genuine TimeCode and PathExpression fixtures exercise their supported forms without producing false file references.
- **AC-05 — Resolution boundaries:** Literal paths use existing package-only rules. Expressions, templates and clip-template string metadata retain truthful limitations without speculative target findings.
- **AC-06 — Completeness:** Reference coverage becomes complete only after all relevant live fields across all requested layers have been inspected or safely classified. Mixed supported/unsupported layers remain partial.
- **AC-07 — Failure classification:** Established corruption produces `UVK-USD-001`; unsupported or ambiguous representations produce limitations. Previously established findings survive later gaps.
- **AC-08 — Defensive decoding:** Tests cover checked arithmetic, forged counts, malformed/truncated structures, invalid indices and UTF-8, topology errors, cycles, depth, flags, compression failures and allocation-driving expansions.
- **AC-09 — Aggregate limits:** Test every additional ceiling at and beyond its boundary, including limits accumulated across layers and the shared USDA/USDC occurrence count. Charges occur before allocation.
- **AC-10 — Package-local access:** Instrument native reads and verify the reader requires no additional filesystem/network/process access after supplied input/runtime bootstrap. On the verified host, exercise the six research containment controls without promising a product sandbox.
- **AC-11 — Binary identities:** Distinct occurrences remain distinct when values or compressed representations are shared. Repeated runs, relocation and input renaming preserve the applicable identity guarantees. No fictional source locations appear.
- **AC-12 — Reporting and gates:** JSON/SARIF schema checks, independent goldens, privacy tests, profiles, exit precedence and external-check separation pass. Existing USDA identity fixtures retain their semantics.
- **AC-13 — Independent fixtures:** Carry forward the nine baseline and fourteen version-specific authored cases, with their **71 expected occurrences**, through documented fixture provenance and independent expectations. Native tests require no writer, oracle or download.
- **AC-14 — Oracle limitations:** Development cross-checks compare semantic occurrence multisets and disclose unregistered-metadata/API omissions. An oracle's empty result is not treated as proof of reference absence.
- **AC-15 — Resource acceptance:** The expanded release resource matrix includes hostile structural metadata, cross-layer accumulation and report pressure. Full invocations meet the current-host RSS/time targets; failures block acceptance.
- **AC-16 — Dependency and platform evidence:** Retain the LZ4 pin, actual source hashes, license and notices; verify builds without a host-installed LZ4 dependency. Record exact tested hardware/OS/toolchain. Do not promote untested macOS 15 or cross-host compatibility.
- **AC-17 — Documentation:** Update inspection, security, resource and reporting documentation to describe the narrower decompression exception and conditional USDC completeness. Keep v0.1.0 available as the historical baseline.

## Notes, exclusions and approval boundary

This specification supersedes only the v0.1 clauses requiring blanket binary-reference incompleteness, forbidding all native decompression, excluding a library decoder dependency, and fixing the safety envelope at version 1. Other existing contracts remain binding.

The experiment establishes feasibility and corroborated inventories on its corpus. Maintainability, aggregate allocation accounting and production Swift behavior remain acceptance work.

The five Apple originals remain optional local regression evidence: their 59 recorded occurrences may be rechecked where available. They are not mandatory distributed test inputs, and redistribution rights must not be assumed.

Out of scope are full USD/OpenUSD conformance, geometry or scene validation, composition, expression/template expansion, external resolution, nested-package traversal, huge natural multichunk fixtures, broader platform support and immediate release publication.

The builder review of the proposed design found no consequential unresolved decisions. The numerical decoder limits and private vendored LZ4 packaging are proposed design defaults, subject to specification approval and subsequent verification.

**This specification's approval authorizes the implementation-planning stage only. The separate implementation plan requires its own explicit approval before implementation, branch creation or implementation commits. No release publication is authorized.**

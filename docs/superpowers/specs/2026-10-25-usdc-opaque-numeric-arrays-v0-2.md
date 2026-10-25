# Opaque USDC numeric arrays in v0.2 — specification amendment

**Slug:** `usdc-opaque-numeric-arrays-v0-2`
**Type:** feature
**Status:** APPROVED
**Date:** 2026-10-25
**Created:** 2026-10-25
**Updated:** 2026-10-25
**Paired artifact naming:** The specification and implementation plan use the identical basename `2026-10-25-usdc-opaque-numeric-arrays-v0-2.md` in their respective directories, per the user's standing naming preference.
**Provenance:** The user's direction “ok, keep it in 0.2 / proceed with the verifications and tests to go on”, followed by “i approve” for the narrow numeric-array scope and design. Parent specification: `docs/superpowers/specs/2026-10-24-usdc-reference-coverage-v0-2-design.md`. Investigation: `docs/deliverables/comparisons/2026-10-25-usdc-opaque-numeric-array-investigation.md`. Unchanged-reader evidence: `.build/verification/usdc-numeric-array-baseline-2026-10-25/report.md` and `.build/verification/apple-assets-v0-2-2026-10-24/report.md`. Repository evidence is used directly under the user's existing authorization; no legacy specification is a source.

**Approval record:** The first “i approve” confirmed Stage 1 scope/design: keep product 0.2.0; exempt proven numeric arrays from charges based on untouched elements; retain bounded headers, actual traversal accounting, metadata/reference-container limits and package-local access; require inventory, containment and resource evidence. After this saved DRAFT was presented with the Stage 2 handoff and proposed safety-envelope 3, the user replied “i approve”. That second, separate approval approves this specification and authorizes Stage 3 implementation planning only. The parent's approved plan does not authorize this amendment's implementation; its separate amendment plan must be presented and approved first.

## Problem and current behavior

The existing v0.2 reader admits an explicit version/type/flag representation, visits a numeric array's ValueRep, checks its value-data pointer, and reads its eight-byte count. It then applies the 250,000-item ceiling and charges the declared count against the two-million-unit work ceiling before returning without inspecting numeric elements. The declared count drives no numeric allocation, element iteration or decompression on that path. This behavior implements the parent's current resource contract.

Fresh unchanged-product runs passed Seahorse, Pancakes, Slide and Teapot with complete requested native coverage. Fender stopped at `usdcItems: 250000`, with incomplete references. A separate metadata census identified its first oversized numeric array as 449,937 declared items and its 39 top-level numeric arrays as 2,274,815 declared elements in total. These count sums explain why raising the item ceiling alone is insufficient; they are not measured candidate work or geometry validation.

The 14 unchanged-reader probes also show that some omitted numeric bodies already pass below the ceiling. Bounded reference inspection does not establish valid geometry. The fresh 45-test baseline passed, including containment on 27 genuine inputs with 72 occurrences; it verifies the unchanged reader only. No modified candidate has been built or tested, and Fender success and parity with the five originals' historical 59 occurrences remain unproven.

## Desired outcome and approaches

Allow an admitted numeric array to be classified as reference-free without treating its untouched declared elements as processed items or work. Preserve bounded inspection of everything actually read or traversed and the existing package-local authored-reference semantics.

| Approach considered | Tradeoff and disposition |
| --- | --- |
| Retain the current policy | Preserves envelope 2 behavior and Fender's resource stop. Does not address the observed coverage restriction. |
| Raise global item/work ceilings | Broadens admission for allocating and reference-bearing structures and requires wider resource justification. Not selected. |
| Exempt only explicitly admitted numeric arrays | Aligns charges with selective traversal while preserving other limits. Deliberately leaves numeric-body validity unexamined and requires fresh acceptance evidence. Selected in the approved scope. |

This is a focused amendment. The parent specification remains authoritative except for the clauses explicitly changed below. Its historical approval and verification evidence remain intact.

## Required behavior

### Exact exemption boundary

Apply the exemption only after the existing admission checks for exact crate versions **0.8.0, 0.9.0 and 0.10.0**, and only to these array representations:

| Numeric type tags | Admitted array flags |
| --- | --- |
| 1–2 and 13–30 | `0x80` |
| 3–9 | `0x80`, `0xa0` |

These are the parent's existing numeric types and array flags, including its existing compressed forms. The amendment adds no type, flag or version support. Scalar handling remains governed by the parent.

For an admitted numeric array:

- Preserve the zero-payload empty-array representation without reading a header.
- For nonzero payload, require its pointer to lie inside the established value-data region and the complete eight-byte unsigned count header to fit there. Read that header through the existing bounded input path.
- Do not apply `usdcItems` or count-proportional `usdcWork` charges to the declared numeric element count. Do not convert that count into an allocation size, host-sized index, loop bound, stride product, body-range requirement or decompression request. Counts through `UInt64.max` do not by themselves cause rejection on this path.
- Retain charges for every actual live traversal edge and ValueRep visit, normal input reads, and any actual storage or metadata decoding. Shared payload offsets do not make repeated live visits free.
- Do not inspect numeric element bytes for references. Archive integrity checks and their normal input-read charges still apply independently.

The exemption is independent of property names, scene paths, filenames and Apple sample identity. It applies equally when an admitted numeric ValueRep is reached through an already supported dictionary, wrapper or time sample; those enclosing containers keep all their own checks and charges.

String/token arrays, asset arrays, dictionaries, wrappers, sublayers, list operations and time-sample containers are outside the exemption. TimeCode tag 56 and PathExpression tag 57 remain outside it. Unknown or unproved representations retain existing limitations. A real asset-bearing value sharing an offset with numeric data must still be inspected according to its own type and occurrence site, with multiplicity preserved.

### Preserved safety and reporting behavior

Keep the supplied-input, read-only package boundary. Native inspection must not extract members, resolve against the host filesystem, access the network, execute tools, load resolver plugins, compose a stage or decode geometry. Existing bounded crate-metadata decompression remains the sole native decompression exception; dependency pins and licenses remain unchanged.

Retain every numerical ceiling: metadata blocks 16 MiB, cumulative decode capacity 32 MiB, live working storage 64 MiB, nonexempt table/container items 250,000, actual structural work 2,000,000, depth 32, and all existing archive/read/occurrence/finding/report limits. Retain checked admission before actual allocations or expansion, aggregate accounting across layers, and release on success and failure. Removing a charge for skipped elements must not remove charges for enclosing structures or actual traversal.

Out-of-range pointers and incomplete numeric count headers remain conclusively malformed inspected structures. Unknown versions/types/flags retain truthful gaps. Existing finding preservation, failure precedence and incomplete-acceptance behavior remain binding. Huge counts or missing/malformed numeric bodies alone do not establish a reference gap or geometry error once the required header checks succeed. “Complete reference coverage” continues to mean completion of the declared authored-reference policy, with no geometry-validity claim.

### Product and safety-policy compatibility

Keep product **0.2.0**. Use **safety-envelope version 3** for the amended policy. This identity is the author's proposed compatibility choice for approval: it distinguishes the changed counting policy without changing any numerical ceiling or publishing a release.

Retain report/config/catalogue schema major 1, existing fields, profile meanings, rule IDs, occurrence identity and public CLI/API surface. Extend the report schema's accepted safety-envelope identities to **1, 2 and 3**, preserving historical report validation. Strict validators using the earlier schema enum will reject envelope 3 and need the updated schema; document that consequence. Reports, SARIF properties, independent goldens and compatibility/resource documentation must consistently identify the amended policy. No new public reference-inventory endpoint is required for verification.

This amends the parent's blanket “Items in each table or container” charge and declared-element work policy only for the numeric representations above, and replaces its current-policy envelope identity 2 with 3. All other parent acceptance criteria remain binding. Old resource measurements are historical evidence, not proof for envelope 3.

## Acceptance criteria

- **AC-01 — Exact classification:** Version-specific fixtures exercise the exemption's admitted tags/array flags, ordinary and compressed forms, zero payload and nested supported sites. Excluded types/containers and unknown versions/flags retain their previous classification. No property- or sample-specific exception exists.
- **AC-02 — Bounded header:** Nonzero numeric payloads require a complete eight-byte header inside the value-data region. Truncation, pointers before that region or into metadata, and boundary/overflow cases retain malformed diagnostics. Zero-payload arrays perform no header read.
- **AC-03 — Ignored counts:** Numeric counts 0, 250,000, 250,001 and `UInt64.max`, including admitted compressed representations, do not trigger count-driven allocation, iteration, decoding, arithmetic overflow, item rejection or proportional work. Instrumentation shows that changing only this count leaves traversal read/work/storage requirements unchanged. Omitted or malformed numeric bodies do not become a claimed geometry check.
- **AC-04 — Actual accounting:** Repeated live numeric visits remain charged, including shared payloads and cross-layer traversal. The two-million work ceiling is still reachable and enforced through actual supported structural work. Required read, storage and decode reservations remain bounded, accumulate as specified and release correctly. Expected counter changes have independently explained values rather than copied implementation outputs.
- **AC-05 — Other limits:** Metadata tables, string/token and asset arrays, enclosing containers, references, occurrences and all other ceilings retain meaningful boundary/excess coverage. A shared-offset asset array still receives its own count checks and traversal; unknown numeric flags cannot activate the exemption.
- **AC-06 — Reference inventories:** Compare complete semantic authored-reference occurrence multisets against retained independent expectations for the genuine fixture corpus, preserving value, authoring site, container position and multiplicity. Retain the canonical 71 occurrences and supplementary genuine occurrence. Cover dictionaries, wrappers, samples, duplicates, shared offsets, and assets before/after numeric values. Asset-looking numeric bytes invent no references. Existing USDA identity behavior remains unchanged.
- **AC-07 — Five private originals:** Recheck the fingerprinted Seahorse, Pancakes, Fender, Slide and Teapot originals. Require complete requested native coverage and default native acceptance for all five, and reconcile full semantic occurrence inventories with the historical total of 59, including Fender's 10. Use independent expectations and practical oracle cross-checks, documenting omissions and how they were resolved. A pass report or an oracle's empty result alone is insufficient. Further Fender stops or unexplained inventory differences block acceptance rather than authorize broader changes.
- **AC-08 — Containment:** Refresh supplied-input read instrumentation and the existing six denial controls for read/stat/enumerate/connect/execute/write after runtime/input bootstrap. Require zero forbidden input ranges, effective denial and no additional required access on the exercised corpus. Disclose the tested corpus and host; this is not a product sandbox or universal syscall audit.
- **AC-09 — Resource acceptance:** Refresh complete release-process measurements, including reporting, for the private originals and a resource matrix covering extreme ignored counts, repeated/shared live visits, aggregate layers, hostile metadata, remaining limits and report pressure. Each invocation must meet **256 MiB peak RSS and 60 seconds** on the recorded current host. Existing ceiling values or unchanged-reader measurements cannot substitute for this evidence.
- **AC-10 — Regression and compatibility:** Refresh the relevant debug, release, sanitizer, schema, independent-golden, determinism/privacy and gate checks from the parent acceptance contract. New reports consistently use product 0.2.0/envelope 3; the updated schema still validates historical envelope 1/2 reports. Record commands, candidate revision, toolchain, host, outcomes and bounded local evidence. Do not infer untested macOS 15 or cross-host support.
- **AC-11 — Durable evidence and documentation:** Keep reproducible synthetic recipes and independently established expectations distinct from genuine-writer fixtures and oracle results. Document numeric-body exclusions, changed charging, safety identity and schema-consumer implications. Native builds/tests require no new dependency, installed USD tool, writer, oracle or network download. Private originals remain local, fingerprinted evidence; do not redistribute them or assume redistribution rights.

## Constraints, exclusions and remaining uncertainty

No full OpenUSD parser/runtime, geometry/composition validation, numeric decompression, larger global quota, new format support, fallback interpretation, resolver expansion, public inventory API, new profile, or production integration is authorized by this DRAFT. Keep v0.1.0 available. No push, merge, release tag or publication is part of this amendment.

The source-backed hypothesis is that untouched numeric counts can cease driving resource rejection while reference inventories and actual resource bounds remain correct. The existing probes support investigation of that hypothesis; they do not verify it. Acceptance requires evidence from the eventual approved candidate, especially Fender's full traversal, multiplicity preservation and the greater amount of live traversal permitted by removing count-proportional charges. If those checks reveal a need to broaden the approved boundary, return for renewed scope/specification review.

The short design records a focused policy amendment using the existing architecture; implementation details and task sequencing belong to the subsequent, separately approved plan. The local evidence directories are supporting receipts and may not be distributed with the repository. Their absence elsewhere must be reported, not treated as a successful independent rerun.

**Current gate:** This specification is approved. Stage 3 may produce the separate implementation plan. That plan requires its own explicit approval before product/test changes, a modified candidate, or production integration. No implementation approval is inferred from specification approval.

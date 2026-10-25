# Opaque USDC numeric arrays: exploratory comparison

**Non-authoritative — PARTIAL coverage.** This read-only investigation informs a possible later decision; it is not an ADR, specification, implementation plan, or release approval. The [evidence index] records the boundary and prior authorization to use repository evidence directly. No candidate was implemented or tested. The observed probes used the unchanged executable at HEAD bf1f23ad934e133ff1e5d290aad93fb182f99f11, SHA-256 91e071cfd13a90e68bd972ce3d699adc4d0f6fd2f584a274388be5b04529394f. [probe provenance]

**Conditional recommendation (analyst judgment): GO to narrow design consideration.** Consider exempting only explicitly admitted fixed numeric arrays from declared-element item and work charges. Retain bounded header/range checks and reference-bearing traversal limits. This does not establish a safe candidate or Fender success. Current rejection follows the approved contract; changing it is a material policy change requiring renewed scope, specification, and plan approvals. [approved contract]

## VERIFIED FACTS

The prior current-host check passed four of five fingerprinted Apple originals. Fender failed with usdcItems: 250000 and partial reference coverage. Its first oversized top-level numeric array declares 449,937 items; source and independent metadata traversal explain that stop without production field instrumentation. This is not evidence of malformed geometry. [original results] [Fender cause]

The new metadata census records 39 top-level Fender numeric arrays with declared sum **2,274,815**, maximum 449,937. Other sample sums are 620,599, 761,806, 52,917, and 779,793. These are direct count-header sums, not measured runtime work or complete nested totals. [census method] [Fender census] [Seahorse census] [Pancakes census] [Slide census] [Teapot census] With existing two-million work and count-proportional charging, raising the item cap alone cannot admit traversal of all those Fender numeric arrays. [resource ledger] [count charging]

The current path admits version/type/flags before dispatch, charges each ValueRep visit, checks the payload against the value-data region, reads an eight-byte unsigned count, applies the 250,000-item ceiling, and charges that count as logical work. For skipped numeric arrays it then returns: the count drives no element loop, geometry decode, or element allocation on this path. [admission] [ValueRep visit] [value cursor] [count charging] [opaque skip] [item admission] Existing tests deliberately pin repeated shared-body charges and exact cross-layer cumulative work. Those tests were inspected, not rerun here. [shared-body test] [cross-layer test]

All 14 original synthetic hostile probes matched expected current outcomes; all 14 emitted JSON reports passed the existing schema check. They are boundary recipes, not valid-scene or genuine-writer compatibility fixtures. [probe provenance] [probe checks] [schema checks] Grouped observations:

- Numeric count 250,000 with omitted element bytes passed; 250,001 and UINT64_MAX failed the item ceiling. Compressed numeric count 16 with no compressed body also passed. Present behavior therefore does not establish numeric-body completeness or compressed-body validity. [small count] [large count] [maximum count] [compressed omission]
- A seven-byte count header and pointers before the value region or into metadata produced malformed-range errors. Unknown flags retained a gap while a later actual asset still produced missingTarget. [truncated header] [early pointer] [metadata pointer] [unknown flags]
- Asset-looking numeric bytes invented no reference. An independently authored asset array sharing that body's offset still produced missingTarget. An oversized numeric array before an asset stopped later traversal; placing the asset first retained its finding. Actual asset arrays above the item limit failed; eight shared numeric edges declaring 250,000 each stopped at the work ceiling. [asset-looking bytes] [shared offset] [numeric first] [asset first] [asset limit] [repeated work]

## SOURCE-BASED INFERENCE

Locally pinned OpenUSD sources distinguish type, array, inline and compression bits in ValueRep. Tags **1–9 and 13–30** denote fixed primitive, matrix, quaternion and vector element types; AssetPath is tag 12, and recursive containers have separate types. PackArray/UnpackArray and type-indexed dispatch select those interpretations; classification does not require guessing from neighboring offsets or scanning geometry. [ValueRep bits] [type inventory] [array handling] [typed dispatch] These three source files match recorded SHA-256 and Git blob IDs at commit 96c1989167d2aaab5bd34627f32a321a6b79866b. This is local corroboration, not fresh upstream research. [source checks]

Under the admitted format, asset-shaped bytes inside a numeric array are numeric data, not authored asset occurrences. Forging a numeric tag changes declared typed semantics; it does not justify treating every matching byte sequence as an asset. This inference concerns the declared reference policy, not scene validity or every downstream consumer. Every independently reachable actual asset ValueRep must still be traversed, including shared payload offsets; offset-based deduplication must not erase authored multiplicity. [type inventory] [typed dispatch] [ValueRep visit] [shared offset] [occurrence identity]

Opacity avoids geometry interpretation/expansion while preserving the package-local boundary. It does **not** remove physical I/O: archive integrity/CRC checks still cover actual stored bytes under archive/read quotas before eligible payload inspection. No host resolution, parser fallback, external tool, new dependency, filename exception, or property-name exemption is needed for this reasoning. [integrity traversal] [archive boundary] [security boundary]

## Options and tradeoffs

Criteria are reference-policy preservation, bounded actual work/storage, diagnostic retention, and contract compatibility. They support qualitative comparison, not numerical scoring. [inspection boundary] [fixed envelope] [report compatibility]

| Option | Benefit and cost (analyst assessment) |
| --- | --- |
| Keep current behavior | Preserves documented envelope and pinned count/work expectations. Retain demonstrated four-of-five coverage and Fender limitation; this investigation does not establish a new implementation defect. [original results] [approved contract] [shared-body test] |
| Narrow numeric exemption | Remove only count-proportional work/item admission for admitted array forms of tags 1–9, 13–30 under exact existing versions/flags. Keep nonzero-payload pointer/value-region checks, bounded eight-byte header reads, and existing empty-array semantics. Retain per-live-edge/ValueRep work and metadata-table, reference/container, depth, read, decode and storage quotas. Aligns charging with actual selective work, but changes acceptance policy and needs candidate proof. [admission] [value cursor] [ValueRep visit] [opaque skip] [resource ledger] |
| Raise global item cap | Broadens admission for unrelated tables and allocating/traversed containers; Fender's numeric sum still exceeds existing work. Wider quota increases weaken additional boundaries without demonstrated necessity. [item admission] [count charging] [Fender census] [resource ledger] |
| Blanket skip non-asset-looking values | Lacks explicit typed proof and risks losing known string/clip semantics and recursive reference coverage. Unknown flags must remain gaps. Disfavored. [inspection boundary] [admission] |

The narrow option must leave string/token arrays, asset arrays, dictionaries, wrappers, sublayers, lists, samples, and tags 56/57 outside the exemption. Distinct dispatch paths and the clip-template gap justify an explicit boundary. [ValueRep visit] [container traversal] [special types] [inspection boundary] Returning without reading the numeric header would lose established truncated-header diagnostics; that more aggressive alternative is not recommended. [opaque skip] [truncated header]

The acceptance tradeoff is deliberate: removing numerical ceilings may accept absurd counts or truncated/malformed numeric bodies because geometry remains uninspected. Current behavior already accepts omitted bodies below the cap. Neither policy certifies geometry; these probes and source reasoning do not prove malformed compressed-body detection. [small count] [compressed omission] [opaque skip] [inspection boundary] Reverting a future exemption would restore stricter rejection but could break newly accepted inputs. Keeping the same numerical ceilings would not preserve prior empirical resource acceptance: removing declared-element work allows more ValueRep visits within two million units. Time/RSS and exact counter evidence must be refreshed. Report/golden expectations, resource evidence and safety-envelope identity therefore need explicit compatibility review. The accepted contract caps every table/container; schema major 1 currently permits only envelope identities 1 and 2. This report assigns no new version. [approved contract] [report compatibility] [schema envelopes]

## UNTESTED HYPOTHESES and decisive evidence

The hypothesis is that the narrow exemption can preserve full authored-reference results while actual work stays independent of numeric element counts. No modified candidate result exists. Fender may encounter another later restriction; neither full Fender success nor equality with the historical 59-occurrence inventory is established. Existing CLI pass reports do not independently export or verify successful-occurrence inventories. [evidence index] [inventory limitation]

This recommendation authorizes no code change or modified-candidate run now. If scope is approved, the decisive experiment is an isolated, nonproduction candidate compared with independent expectations or an oracle: compare **full semantic authored-occurrence multisets** across all genuine fixtures and five originals, retaining multiplicity. Include dictionaries, wrappers, samples, shared offsets and ordering; invalid flags/tags/versions/counts/offsets and truncated headers; and extreme numeric counts with actual bounded-read, work and live-storage instrumentation. Re-establish unchanged real-reference/table limits, OS-denial controls, and full-process RSS/time. These are proposed evidence requirements, not completed verification or an implementation-task breakdown. [occurrence identity] [approved contract] [security boundary]

Coverage remains PARTIAL. This report synthesizes selected local evidence, including current CLI probes and a bounded read-only metadata census of unchanged Apple originals. Existing test source was inspected without a full-suite rerun. No candidate was implemented, no build was run, and no ADR consultation or external research was performed for this investigation. Source comments and historical reports are attributed evidence, not universal proofs. Synthetic probes do not fill genuine-writer gaps, including tag 52. macOS 15 and additional hosts remain unverified; there is no new platform or release claim. [evidence index] [probe provenance] [census method] [original limitations] [inspection boundary] [platform limitation]

This direction introduces no proposed runtime dependency, external tool, or CI bootstrap requirement. Refreshed native corpus, adversarial, resource and containment verification is still necessary; no portable-CI claim is established. [approved contract] [security boundary] [original limitations]

[evidence index]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/evidence-index.json:2
[probe provenance]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/behavior-probes.json:2
[probe checks]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/behavior-probes.json:1221
[schema checks]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/schema-checks.json:2
[original results]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/apple-assets-v0-2-2026-10-24/report.md:15
[Fender cause]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/apple-assets-v0-2-2026-10-24/report.md:21
[census method]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/numeric-array-census.json:2
[Fender census]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/numeric-array-census.json:3237
[Seahorse census]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/numeric-array-census.json:7
[Pancakes census]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/numeric-array-census.json:337
[Slide census]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/numeric-array-census.json:3850
[Teapot census]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/numeric-array-census.json:4003
[resource ledger]: /Users/davide/Personal/Projects/usdz-validator/Sources/USDZValidation/ResourceLedger.swift:11
[count charging]: /Users/davide/Personal/Projects/usdz-validator/Sources/USDZValidation/USDC/USDCValues.swift:60
[admission]: /Users/davide/Personal/Projects/usdz-validator/Sources/USDZValidation/USDC/USDCFormat.swift:146
[ValueRep visit]: /Users/davide/Personal/Projects/usdz-validator/Sources/USDZValidation/USDC/USDCValues.swift:136
[value cursor]: /Users/davide/Personal/Projects/usdz-validator/Sources/USDZValidation/USDC/USDCValues.swift:35
[opaque skip]: /Users/davide/Personal/Projects/usdz-validator/Sources/USDZValidation/USDC/USDCValues.swift:337
[item admission]: /Users/davide/Personal/Projects/usdz-validator/Sources/USDZValidation/USDC/USDCStorage.swift:38
[shared-body test]: /Users/davide/Personal/Projects/usdz-validator/Tests/USDZValidationTests/USDCResourceTests.swift:221
[cross-layer test]: /Users/davide/Personal/Projects/usdz-validator/Tests/USDZValidationTests/USDCResourceTests.swift:318
[small count]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/behavior-probes.json:9
[large count]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/behavior-probes.json:41
[maximum count]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/behavior-probes.json:140
[compressed omission]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/behavior-probes.json:991
[truncated header]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/behavior-probes.json:239
[early pointer]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/behavior-probes.json:337
[metadata pointer]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/behavior-probes.json:435
[unknown flags]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/behavior-probes.json:533
[asset-looking bytes]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/behavior-probes.json:663
[shared offset]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/behavior-probes.json:695
[numeric first]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/behavior-probes.json:761
[asset first]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/behavior-probes.json:860
[asset limit]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/behavior-probes.json:1023
[repeated work]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/behavior-probes.json:1122
[ValueRep bits]: /Users/davide/Personal/Projects/usdz-validator/.verification/usdc-feasibility-2026-10-24/sources/OpenUSD/pxr/usd/sdf/crateFile.h:84
[type inventory]: /Users/davide/Personal/Projects/usdz-validator/.verification/usdc-feasibility-2026-10-24/sources/OpenUSD/pxr/usd/sdf/crateDataTypes.h:16
[array handling]: /Users/davide/Personal/Projects/usdz-validator/.verification/usdc-feasibility-2026-10-24/sources/OpenUSD/pxr/usd/sdf/crateFile.cpp:1772
[typed dispatch]: /Users/davide/Personal/Projects/usdz-validator/.verification/usdc-feasibility-2026-10-24/sources/OpenUSD/pxr/usd/sdf/crateFile.cpp:4360
[source checks]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/usdc-opaque-array-investigation-2026-10-25/pinned-source-checks.json:2
[occurrence identity]: /Users/davide/Personal/Projects/usdz-validator/docs/report-compatibility.md:21
[integrity traversal]: /Users/davide/Personal/Projects/usdz-validator/Sources/USDZValidation/NativeEngine.swift:111
[archive boundary]: /Users/davide/Personal/Projects/usdz-validator/docs/inspection-boundary.md:7
[security boundary]: /Users/davide/Personal/Projects/usdz-validator/SECURITY.md:5
[inspection boundary]: /Users/davide/Personal/Projects/usdz-validator/docs/inspection-boundary.md:29
[fixed envelope]: /Users/davide/Personal/Projects/usdz-validator/docs/inspection-boundary.md:45
[approved contract]: /Users/davide/Personal/Projects/usdz-validator/docs/superpowers/specs/2026-10-24-usdc-reference-coverage-v0-2-design.md:90
[report compatibility]: /Users/davide/Personal/Projects/usdz-validator/docs/report-compatibility.md:15
[schema envelopes]: /Users/davide/Personal/Projects/usdz-validator/Schemas/report-v1.schema.json:706
[container traversal]: /Users/davide/Personal/Projects/usdz-validator/Sources/USDZValidation/USDC/USDCValues.swift:167
[special types]: /Users/davide/Personal/Projects/usdz-validator/Sources/USDZValidation/USDC/USDCValues.swift:261
[inventory limitation]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/apple-assets-v0-2-2026-10-24/report.md:27
[original limitations]: /Users/davide/Personal/Projects/usdz-validator/.build/verification/apple-assets-v0-2-2026-10-24/report.md:33
[platform limitation]: /Users/davide/Personal/Projects/usdz-validator/docs/superpowers/specs/2026-10-24-usdc-reference-coverage-v0-2-design.md:29

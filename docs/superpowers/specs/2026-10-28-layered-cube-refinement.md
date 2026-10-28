# Layered cube refinement — specification, revision 2

**Slug:** `layered-cube-refinement`
**Type:** feature
**Status:** APPROVED
**Revision:** 2
**Created:** 2026-10-28
**Updated:** 2026-10-28

**Paired plan basename:** `2026-10-28-layered-cube-refinement.md`

**Provenance:** Revision of `docs/superpowers/specs/2026-10-28-layered-cube-refinement.md` as preserved at `da63a66cd707b41b14b2ddce610ae3f85af281f0`. The earlier approved specification and plan produced candidate-002. The user then requested a higher pyramid, thicker platforms and equal distances between the three internal elements. Through native clarification the user selected “Make it taller (Recommended).” The subsequent Stage 1 proposal specified a 76.3 mm pyramid, 12 mm platforms and 25 mm clear gaps; the user replied “approved,” authorizing this revised DRAFT only. Inspection began on clean `chore/layered-cube-refinement` at `da63a66`. Exact-slug resolution selects this specification and its existing matching plan as `NEW_ONLY`, with no legacy source or identity conflict. Their filenames and original creation dates remain stable.

## Problem and current behavior

The rounded cube is usable, but the user wants a taller pyramid, slightly thicker platforms and even vertical spacing. The current gaps are unequal, so increasing thickness alone will not produce the requested distribution.

The immediate comparison baseline is [candidate-002/model.usdz](/Users/davide/Personal/Images/usdz-validator/cube-model/candidate-002/model.usdz), SHA-256 `51e41708c1e2248b344b512101a3026bfa1e18847d9e5be086aa7e828892b7e8`. Its pyramid is 71.3 mm tall, with base Y 13.7 mm and tip Y 85 mm. Both platforms are 10 mm thick. The lower-to-middle gap is 35 mm; the grid-to-pyramid gap is 17.725 mm. It already has genuine rounded geometry, glossy materials and lightly translucent side panels.

Candidate-002 passed its 20-case artwork suite, USD load/package checks, independent Model I/O inspection and default native validation. Its actual Quick Look front view was observed by the assistant; the user freshly confirmed manual rotation/usability. Its final review remains incomplete: specification review blocked on contradictory task-completion records, which were subsequently reconciled; quality review did not run. These retained results describe candidate-002 and do not establish acceptance of a future revision. Preserve the [blocked review report](/Users/davide/Personal/Images/usdz-validator/cube-model/evidence/refinement-2026-10-28-001/final-review-blocked/specification-review.md) and its sealed package.

The earlier [candidate-001/model.usdz](/Users/davide/Personal/Images/usdz-validator/cube-model/candidate-001/model.usdz), SHA-256 `45a7d8bcde02ccabfba476e3d68f265e269e6997dad3728a61af9276302b7953`, remains preserved with its completed original review. Both candidates retain frozen sources, previews and evidence.

The preserved [reference PNG](/Users/davide/Personal/Images/usdz-validator/cube-model/reference.png), SHA-256 `74723d5ddd7017e0943882a3c9b35ef3aca4b137244007aaabbe4bc2804a256b`, remains the visual guide. Both candidate hashes and the reference-copy hash were rechecked during this revision's preparation.

## Desired outcome and selected increment

The wider direction remains a reusable 3D project illustration. This revision continues the current refinement increment, delivering another rotatable cube-only USDZ with taller/thicker contents and equal clear gaps. It includes editable sources, comparison previews against candidate-002, reproduction instructions and fresh verification/review evidence. Existing candidates and earlier approvals remain historical evidence at their original scopes.

Keep the pyramid base at Y 13.7 mm and raise its tip by 5 mm to Y 90 mm, producing a 76.3 mm height. Retain its horizontal footprint. Increase both platform bodies to 12 mm thick, retaining their existing widths/depths. Position them so each adjacent pair has 25 mm of clear vertical space.

Measure the lower gap from the lower platform's highest surface to the middle platform body's lowest surface. Measure the upper gap from the highest surface of the middle platform and its grid to the pyramid's lowest surface. The grid belongs to the middle visual element. Keep the grid raised safely above its supporting surface. Preserve a single pyramid with broad sloping faces, rounded ridges/base corners/tip and its existing closed underside; add no separate square blue plinth.

Preserve the existing rounded frame/joins, panel outlines and platform corners, together with the glossy blue/teal palette, lightly translucent sides, grid, pale-blue lower platform, open top and reconstructed rear geometry. Keep the overall 20 cm bounds, Y up and meters. The higher apex remains inside those bounds and must stay clear of actual frame surfaces. No requirement to remain below the nominal inner top-frame plane carries over from revision 1; its earlier 85 mm apex limit is replaced by the confirmed 90 mm target.

### Approaches and boundary rationale

The user selected a taller pyramid through native clarification. Translation of the existing pyramid was the other presented approach and would preserve its current height. Continue the existing procedural mesh and USD pipeline, changing proportions and deriving platform placement from the agreed clearances. This preserves editability and allows dimensions/gaps to be checked independently without new tooling.

Height, thickness and spacing form one coherent revision because each affects the perceived arrangement and available clearance. Fresh comparisons and actual-package viewing will establish whether the new proportions are readable and closer to the user's intended composition. Exact image recovery and identical rendering across viewers remain uncertain and are not promised. Further artwork or integration stays deferred.

## Acceptance criteria

- **AC-01 — Taller single pyramid:** Measured geometry has a 76.3 mm height, base Y 13.7 mm and tip Y 90 mm, each within 0.1 mm. Retain its 134 mm square footprint within the same tolerance, recognizable sloping faces and rounded apex. There is one pyramid, without an added slab or plinth. Record the comparison against candidate-002.
- **AC-02 — Thicker platforms:** Both platform bodies measure 12 mm thick within 0.1 mm, retaining their 154 mm widths/depths, teal/pale-blue identities and rounded edges/corners. Retain the modeled grid above the middle platform without unintended coplanar overlap or flicker.
- **AC-03 — Equal, separated arrangement:** Both clear vertical gaps, measured from actual geometry as defined above, are 25 mm within 0.1 mm and differ by no more than 0.1 mm. Independently record both gaps. Keep positive clearances from the actual frame and between all components intended to remain separate; distinguish intentional frame/grid joints. The reference-like view visibly shows even spacing.
- **AC-04 — Preserved rounded geometry:** Retain genuine geometric rounding on the frame/joins, panel outlines, platform edges/corners and pyramid ridges/base corners/tip. Silhouette and angled detail previews show the resulting rounded forms. Height/thickness changes introduce no holes, visible blocky joins, unintended intersections or lost component identity.
- **AC-05 — Preserved composition:** Retain the 20 cm outer bounds, Y-up/meter declaration, open top, four lightly translucent sides, glossy blue/teal finish, two separated platforms and consistent rear geometry. Contents remain visible from the reference-like view. The magnifying glass and exterior image halo remain absent.
- **AC-06 — Geometry and package integrity:** Deliver a self-contained USDZ that passes available USD load/package checks. Update focused tests and independent imported-geometry inspection for the new height, thicknesses and equal gaps, while retaining finite-position, valid-index/face, nondegeneracy, bounds, separation and malformed-input checks. Run the v0.2 validator with default native policy; require exit 0, complete requested native coverage and no findings or operational errors. Native acceptance supplements geometry and visual evidence.
- **AC-07 — Fresh visual and review evidence:** Save at least a reference-like view and a rotated view of the final package, plus comparable candidate-002 views and relevant detail previews. Bind sources, previews and verification to the final package hash. Inspect that package in Quick Look for readable contents, proportions, spacing and severe rendering artifacts, including rotation; attribute renderer/human observations accurately. Complete fresh sequential specification-then-quality review and resolve blocking findings within scope. Keep task/increment status in progress until its required review and closure finish. Earlier viewer acceptance, passing tests and blocked review receipts do not establish completion of this revision.
- **AC-08 — Preserved baselines and reproducibility:** Save each attempt in a fresh numbered candidate directory under `/Users/davide/Personal/Images/usdz-validator/cube-model/`. Deliver editable USD, matching generation/inspection sources, focused tests, instructions, final hashes and receipts. Preserve candidates 001 and 002 with their frozen sources/previews/evidence, the original and preserved reference PNGs, earlier workflow records and private Apple samples. Earlier approved artifact content remains preserved in Git history and sealed review evidence. Keep artwork outside validator product files and retain distinguishable failed attempts.

## Edge cases and limitations

The grid's small height above the teal body affects the upper clear gap and must be included in its measurement. Rounded silhouettes and perspective can make equal physical gaps look different; report measured equality and inspect the actual composition without silently substituting unequal gaps for a visual illusion.

A higher pyramid and thicker shelves can reduce available space. Check actual geometry and frame clearance; nominal frame-plane distances alone do not establish absence of intersections. Mesh count remains descriptive rather than a fixed acceptance requirement.

Quick Look automation previously failed on earlier models and an Apple control sample; candidate-002's rotation result came from the user's manual observation. Human-assisted inspection is acceptable if necessary, but must identify the new package and observed behavior. An unavailable or failed visual check remains unresolved.

The reference is a single illustration. Likeness is judged through comparisons and observed viewer behavior, without claiming exact hidden geometry, optics or lighting recovery.

## Constraints and out of scope

No validator runtime, product tests, schemas, dependencies, versions, public interfaces or README integration change. No installation, magnifying glass, animation, AR interaction, unrelated artwork, private-asset redistribution or publication is included. Artwork geometry tests remain local to the artwork tooling.

Keep this revised specification uncommitted until renewed specification approval and separate approval of the affected revised plan authorize the next Git/execution steps. Do not update `main` or create an implementation branch during specification/planning. Preserve existing local branches, completed original work and candidate-002's incomplete-review history. No push, merge, tag or release action is authorized.

## Approval state and handoff

**Historical approvals:** Revision 1's specification and plan were presented separately and each received “approved,” authorizing the work that produced candidate-002. Those approvals and their results remain preserved at their original scope.

**Stage 2 approval — revision 2:** After this revised DRAFT specification was saved and presented, the user separately replied “approved,” authorizing **Stage 3 revision of the matching implementation plan only**. This approval is distinct from the earlier Stage 1 scope/design approval. The [matching plan](../plans/2026-10-28-layered-cube-refinement.md) is being revised as revision 2 and requires separate plan approval before execution. No revision-2 artwork changes are authorized yet.

**Execution endpoint:** Deliver the revised cube-only USDZ with the taller pyramid, thicker platforms and equal gaps, editable sources, comparison previews and instructions; complete geometry/package/native/viewer verification and sequential final review; report evidence and limitations; then stop before further artwork or integration.

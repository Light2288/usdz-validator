# Layered cube refinement — specification

**Slug:** `layered-cube-refinement`
**Type:** feature
**Status:** APPROVED
**Created:** 2026-10-28
**Updated:** 2026-10-28

**Paired plan basename:** `2026-10-28-layered-cube-refinement.md`

**Provenance:** The user requested thicker internal shapes and closer spacing after viewing the completed model, then requested rounded corners on every element. Native clarification established a slightly taller pyramid, with no separate square base beneath it, and thicker versions of both platforms. The user confirmed the combined Stage 1 proposal with “i confirm this combined refinement.” This authorizes this DRAFT specification only. Repository context: `chore/layered-cube-usdz-model` at `213cf0bc6d2577fde9ecffd0a6713b6f65a3f75b`, initially clean. Exact-slug and candidate-path resolution found no existing refinement specification or plan; no legacy artifact is a source. The completed [original specification](2026-10-27-layered-cube-usdz-model.md) and [original plan](../plans/2026-10-27-layered-cube-usdz-model.md) remain unchanged.

## Problem and current behavior

The completed cube is usable, but its internal shapes look thinner and more widely separated than the reference. The frame and shelves have existing bevels, while the pyramid has sharp ridges and a sharp tip. The user wants a softer, fuller interpretation of the same composition.

The baseline is [candidate-001/model.usdz](/Users/davide/Personal/Images/usdz-validator/cube-model/candidate-001/model.usdz), SHA-256 `45a7d8bcde02ccabfba476e3d68f265e269e6997dad3728a61af9276302b7953`. It has a 20 cm outer cube, Y up, meters declared as the unit, a 62 mm tall pyramid and two 6 mm thick platforms. Its frozen sources and evidence remain the comparison baseline.

The preserved [reference PNG](/Users/davide/Personal/Images/usdz-validator/cube-model/reference.png), SHA-256 `74723d5ddd7017e0943882a3c9b35ef3aca4b137244007aaabbe4bc2804a256b`, remains the visual guide. Both hashes were rechecked during specification preparation.

## Desired outcome and selected increment

The wider direction remains a reusable 3D project illustration. This increment delivers one refined, rotatable cube-only USDZ with fuller internal shapes, a more compact vertical arrangement and visibly rounded geometry. It includes editable sources, comparison previews, reproduction instructions and verification/review evidence.

The confirmed proportions use a pyramid approximately 15% taller, extending downward while its tip stays clear of the upper frame, and both platforms approximately 10 mm thick. Remaining vertical gaps may be reduced modestly to approach the reference while preserving separation. These are modeling targets; small adjustments within this treatment may follow visual inspection. Exact rounding radii and final positions belong to planning and implementation.

Use genuine geometric rounding on the outer frame and its joins, side-panel outlines, platform edges/corners, and pyramid ridges, base corners and tip. Keep the pyramid recognizable, with broad sloping faces and a softened apex. Its closed underside is part of the pyramid; no separate square blue plinth is added.

Keep the glossy blue/teal palette, lightly translucent side panels, teal grid, pale-blue lower platform, open top and reconstructed rear geometry. Preserve the overall 20 cm scale and declared coordinates/units.

### Approaches and boundary rationale

The selected approach extends the existing procedural mesh and USD pipeline, using the installed tools without dependency installation. It preserves editability and makes changed dimensions and geometry independently checkable. A shading-only treatment cannot round silhouettes or correct proportions. A separate manual-modeling workflow would introduce additional tooling and reproduction work for this focused refinement.

Thickness, spacing and rounding form one visual increment because each affects the apparent volume and clearance of the others. Evaluating the final package will establish whether this combination is closer to the reference and remains readable in Quick Look. Exact image recovery and identical rendering across viewers remain uncertain and are not promised.

## Acceptance criteria

- **AC-01 — Taller single pyramid:** Increase the pyramid's height modestly toward the approximately 15% target, primarily downward. Keep its tip below the upper frame and its base visibly separated from the gridded platform. Retain one recognizable pyramid with no added base slab or plinth. Record final dimensions against the baseline.
- **AC-02 — Thicker platforms:** Increase both platforms from 6 mm toward approximately 10 mm thickness. Preserve their teal/pale-blue identities and the modeled grid on the middle platform. The grid remains above its supporting surface without unintended coplanar overlap or flicker.
- **AC-03 — Compact, separated arrangement:** The reference-like comparison view shows a fuller, more compact internal stack. Record positive clearances between the pyramid, grid, platforms and frame where those components are intended to remain separate. Avoid unintended intersections; document intentional frame/grid joints separately.
- **AC-04 — Rounded geometry:** Actual meshes produce softer frame edges and coherent corner joins, panel outlines following the rounded openings, rounded platform edges/corners, and softened pyramid ridges, base corners and tip. Silhouette and angled close-up previews demonstrate the rounding; smooth normals alone do not satisfy it. Avoid visible blocky joins, missing surfaces or excessive rounding that obscures component identity.
- **AC-05 — Preserved composition:** Retain the 20 cm outer bounds, Y-up/meter declaration, open top, four lightly translucent sides, glossy blue/teal finish, two separated platforms and consistent rear geometry. Contents remain visible from the reference-like view. The magnifying glass and exterior image halo remain absent.
- **AC-06 — Geometry and package integrity:** Deliver a self-contained USDZ that passes available USD load/package checks. Update focused geometry checks and independent inspection for the refined topology: finite positions, valid indices/face counts, nondegenerate faces, sensible bounds and intended arrangement. Run the v0.2 validator with default native policy; require exit 0, complete requested native coverage and no findings or operational errors. Native acceptance supplements geometry and visual evidence.
- **AC-07 — Fresh visual and review evidence:** Save at least a reference-like view and a rotated view of the final package, plus comparable baseline views. Bind previews and verification to the final package hash. Inspect that package in Quick Look for readable contents, rounding, separation and severe rendering artifacts, including rotation. Attribute renderer and human observations accurately. Complete sequential specification-then-quality review and resolve blocking findings within scope. Baseline viewer acceptance does not substitute for fresh refinement evidence.
- **AC-08 — Preserved baseline and reproducibility:** Save each attempt in a fresh numbered candidate directory under `/Users/davide/Personal/Images/usdz-validator/cube-model/`. Deliver editable USD, matching generation/inspection sources, focused tests, instructions, final hashes and receipts. Preserve `candidate-001`, its frozen sources/previews/evidence, the original and preserved reference PNGs, earlier workflow records and private Apple samples. Keep artwork outside validator product files and retain distinguishable failed attempts.

## Edge cases and limitations

Thicker shapes and wider rounding can reduce clearances or distort thin panels. Check the resulting geometry and actual viewer output rather than assuming the parameter changes preserve separation. Mesh count may change; the baseline's mesh count is not an acceptance requirement.

Quick Look automation previously failed on both the baseline model and an Apple control sample. The baseline rotation result came from the user's manual observation. Human-assisted inspection is acceptable again if necessary, but it must identify the refined package and observed behavior. An unavailable or failed visual check remains unresolved.

The reference is a single illustration. Likeness is judged through comparisons and observed viewer behavior, without claiming exact hidden geometry, optics or lighting recovery.

## Constraints and out of scope

No validator runtime, product tests, schemas, dependencies, versions, public interfaces or README integration change. No installation, magnifying glass, animation, AR interaction, unrelated artwork, private-asset redistribution or publication is included. Artwork geometry tests remain local to the artwork tooling.

Do not update `main`, create the next implementation branch or commit these workflow artifacts before separate specification and plan approvals. Preserve the existing local branch and its completed increment; no push, merge, tag or release action is authorized.

## Approval state and handoff

**Specification approval:** After this specification was presented separately, the user replied “approved.” This authorizes **Stage 3 implementation planning only**, using the same basename in `docs/superpowers/plans/`. The specification remains uncommitted until the separately approved plan authorizes implementation-branch creation. The matching plan was subsequently presented and separately approved with “approved,” authorizing Stage 4 execution within this specification.

**Execution endpoint:** Deliver the refined cube-only USDZ, editable sources, comparison previews and instructions; complete geometry/package/native/viewer verification and sequential final review; report evidence and limitations; then stop before further artwork or integration.

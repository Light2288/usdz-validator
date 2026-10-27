# Layered cube USDZ model — DRAFT specification

**Slug:** `layered-cube-usdz-model`
**Type:** feature
**Status:** APPROVED
**Created:** 2026-10-27
**Updated:** 2026-10-27

**Paired plan basename:** `2026-10-27-layered-cube-usdz-model.md`

**Provenance:** The user requested a real 3D reconstruction of the cube and its internal shapes from the reference image, with the magnifying glass omitted. Through the native interactive control, the user selected “Glossy and translucent” for the first model. The user subsequently replied “confirmed” to the Stage 1 scope/design proposal; this authorizes this DRAFT specification only. Repository context was inspected on clean `main` at `dad53f0e5c2853424db3e91c7de234083d409209`. Exact-slug and candidate-path resolution found no existing specification or plan; no legacy artifact is a source.

## Problem and current behavior

The project illustration exists as a PNG. Its rendered depth, reflections and transparency do not provide editable geometry or a rotatable object. The user wants a genuine USDZ model based on the cube and its contents, rather than the image mapped onto a flat surface.

The visual reference is [Magnifying Glass Over Blue Layered Cube.png](</Users/davide/Downloads/Magnifying Glass Over Blue Layered Cube.png>). Its inspected SHA-256 is `74723d5ddd7017e0943882a3c9b35ef3aca4b137244007aaabbe4bc2804a256b`. Preserve this original; its exterior halo and magnifying glass are not model components.

## Desired outcome and selected increment

The wider direction is a reusable 3D project illustration. This first increment delivers one self-contained, rotatable USDZ containing:

- A beveled blue cube frame with lightly translucent side panels.
- A blue pyramid in the upper section.
- A teal middle platform with a restrained grid.
- A pale-blue lower platform.
- Consistent geometry on the hidden sides, reconstructed from the visible reference.

The model should retain the reference's recognizable proportions, vertical separation, blue/teal palette and glossy appearance. It is an interpretation of a single image; unseen dimensions and surfaces are reconstructed rather than recovered. The internal shapes must remain visible from the reference-like viewing angle.

The proposed approach uses procedural geometry and the installed Apple USD tools. The model's geometry, materials and editable source are authored locally. The first increment includes the generation script, packaging, previews, documentation and verification needed to assess the actual USDZ, not only a source file or an isolated rendering.

The main uncertainty is how convincingly the translucent materials and overlapping surfaces render in Quick Look. The increment resolves this through an actual viewer inspection. Exact reproduction of the PNG's illumination, reflections or appearance in every viewer is not promised.

## Deliverables and boundaries

Save artwork deliverables under `/Users/davide/Personal/Images/usdz-validator/cube-model/`:

- The rotatable `.usdz` model.
- Editable USD source with identifiable frame, panels, pyramid and platform components.
- A generation script and concise local reproduction/viewing instructions.
- Preview images, including a reference-like view and another angle that demonstrates depth.
- Verification evidence identifying the generated files, checks and observed viewer behavior.
- A byte-identical local reference-image copy, so future work does not depend on the Downloads location.

The USDZ must contain its required assets and require no external file lookup. Keep artwork generation separate from the validator product. No new modeling application or dependency installation is authorized by this scope. If an unforeseen prerequisite makes the agreed result infeasible, report it before changing the approach materially.

## Acceptance criteria

- **AC-01 — Genuine 3D contents:** The delivered USDZ contains modeled cube-frame, panel, pyramid and platform geometry with depth. Rotation exposes consistent side/rear geometry; a textured billboard alone does not satisfy this criterion. The magnifying glass is absent.
- **AC-02 — Reference likeness:** A reference-like view clearly shows the blue frame and upper pyramid, teal gridded middle platform and pale-blue lower platform in their agreed arrangement. The frame has visible bevels. The model includes no exterior image halo, text or unrelated symbols.
- **AC-03 — Materials and visibility:** Use glossy blue/teal materials and lightly translucent side panels. Inspect the actual USDZ in Quick Look to establish that the main contents are visible and that unintended opaque faces or severe transparency artifacts do not obscure them in the reference-like view. Record material/rendering differences honestly.
- **AC-04 — Self-contained, loadable package:** The final USDZ loads through the available USD tooling and opens in Quick Look. Its required scene/material assets are package-local. Record the final file's hash and the tool identities used. No missing-dependency result is accepted as a finished deliverable.
- **AC-05 — Geometry integrity:** Check finite coordinates, valid mesh indices and face counts, consistent declared units/up axis and sensible model bounds. Check intended component placement and investigate visible unintended intersections or missing surfaces. These checks are separate from the validator's native reference/packaging coverage.
- **AC-06 — Editable, repeatable sources:** Deliver the generation script, editable USD and instructions sufficient to reproduce the agreed model locally. Preserve any existing files instead of overwriting them silently. The original PNG and retained private Apple assets remain unchanged.
- **AC-07 — Verification and previews:** Run the project's v0.2 validator on the final package with the default native policy, recording its version, exit code, findings and coverage. Require an accepted result with complete requested native coverage. Independently perform the USD-load, geometry and Quick Look checks above; validator acceptance alone does not establish geometry or visual correctness. Save at least two actual model previews and the verification/review results. An unavailable or failed visual check remains unresolved, never reported as passed.
- **AC-08 — Scope preservation:** Keep deliverables local and separate from the validator's runtime source, tests, schemas, dependencies, version, release and README. Complete the approved increment, its verification and review, report the working result and limitations, then stop. No subsequent increment starts automatically.

## Edge cases and limitations

The reference does not determine exact depth, hidden-side details or physical scale. Use consistent reconstructed geometry, declare the chosen units/scale, and document interpretation choices rather than implying exact recovery.

Gloss, translucency and overlapping surfaces can render differently across viewers. Quick Look is the visual acceptance target for this increment; no broader renderer or AR compatibility claim follows from it. If the agreed translucent treatment cannot be made usable, present that limitation rather than silently replacing the approved finish with solid materials.

Keep earlier generation attempts and failed verification observations distinguishable from the final candidate. Missing tools, malformed packages or unusable previews must be reported explicitly.

## Constraints and out of scope

The magnifying glass, animation, physically exact optics, photorealistic matching, AR placement/interaction, model optimization for a specific engine, SVG work, README/site integration and release publication are deferred. This is a separate artwork deliverable, not a new validator capability or a new certified fixture corpus.

Only this specification is being created in Stage 2. It remains uncommitted until the separately approved plan authorizes implementation-branch creation. No branch update, implementation, push, merge, tag or publication is authorized by scope confirmation or specification approval.

## Approval state and handoff

The user confirmed the scope/design on 2026-10-27, then explicitly approved this specification with “spec approved.” The matching implementation plan was subsequently presented separately and approved by the user's “PLEASE IMPLEMENT THIS PLAN” message containing that complete plan. Stage 4 native execution is authorized within the approved scope. Preserve these separate approvals; no push, merge, tag or publication is authorized.

**Execution endpoint:** Deliver the working cube-only USDZ, editable sources, previews and reproduction instructions; complete geometry/package/native/viewer verification and review; report observed results and limitations; then stop before the magnifying glass, further artwork or integration.

# Layered Cube USDZ Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` through `personal-workflows:spec-implement`. Steps use checkbox syntax.

**Slug:** `layered-cube-usdz-model`
**Status:** APPROVED
**Created:** 2026-10-27
**Updated:** 2026-10-28
**Execution tier:** full
**Implementation model role:** full
**Execution method:** Native, selected through the interactive control.
**Spec:** [Approved specification](../specs/2026-10-27-layered-cube-usdz-model.md)

**Approval record:** The user approved the specification with “spec approved,” then separately approved the complete plan with “PLEASE IMPLEMENT THIS PLAN.” This saved plan preserves the approved scope and records those approvals after return to Default mode.

**Goal:** Deliver a rotatable, glossy blue cube and its internal shapes as a self-contained USDZ, with editable sources and verified previews.

**Architecture:** Generate explicit mesh geometry and USD Preview Surface materials using a local Python script. Convert and package with installed Apple USD tools. Inspect the actual package through Quick Look, with additional views rendered through the installed SceneKit/Model I/O frameworks.

**Tech Stack:** Python standard library, Apple USD Tools 0.25.11, Swift, Model I/O, SceneKit and Quick Look. No dependency installation.

**Provenance:** Repository HEAD at planning was `dad53f0e5c2853424db3e91c7de234083d409209`. Specification resolution was `NEW_ONLY`; the matching plan was `MISSING`. No architecture map or ADR directory was found. Installed-tool help confirms conversion, packaging and thumbnail commands; a read-only SDK probe confirmed USDZ/USDA import and an available Metal device.

## Global constraints

- Artwork lives under `/Users/davide/Personal/Images/usdz-validator/cube-model/`; validator product files remain unchanged.
- Include the blue beveled frame, translucent side panels, upper pyramid, gridded teal platform and pale-blue lower platform.
- Omit the magnifying glass.
- Preserve the reference PNG and private Apple samples.
- Retain separate generation attempts; never silently overwrite existing deliverables.
- No installation, README integration, product changes, push, merge, tag or publication.
- Native validation supplements geometry and visual checks; it does not replace them.

### Modeling defaults

The reference provides no physical dimensions. Use a **20 cm outer cube**, centered horizontally, with **Y up** and meters declared as the unit.

Use a frame approximately 12 mm thick with visibly beveled edges. Reconstruct all four sides consistently, leaving the top open. Place a square-based blue pyramid above the teal middle platform, with the pale-blue platform below it. Keep platforms separated and inside the frame.

Use modeled grid lines rather than image textures. Start with glossy solid frame/platform materials and side-panel opacity of approximately 0.10. Adjust material parameters within the approved glossy/translucent finish after inspecting Quick Look.

## Review focus

1. The result contains real depth and consistent rear geometry.
2. Transparent faces do not conceal the internal shapes in Quick Look.
3. Beams, grid lines and platforms avoid visible unintended intersections or flickering.
4. The package contains its required scene data and loads without missing dependencies.
5. Previews and verification identify the final package; failed attempts remain distinguishable.

## Task 1: Build and verify the cube-only artwork [size: M | risk: none | mechanical: false | clear_pattern: false | objectively_verifiable: false | concerns: none]

**Acceptance criteria:** AC-01–AC-08.

**Files and responsibilities:**

- Commit the matching specification/plan pair as workflow artifacts.
- In the artwork folder, create `generate_model.py` for geometry, materials and USD authoring; `inspect_model.swift` for independent mesh inspection and preview rendering; and focused geometry tests.
- Deliver editable USDA, packaged USDZ, a preserved reference PNG, two previews, reproduction instructions and verification receipts.

**Interfaces:** The generator consumes fixed modeling parameters and writes into a fresh candidate directory. The inspection helper consumes the resulting USDZ and produces geometry-check results and rendered previews. Neither changes validator behavior.

- [x] **Step 1: Save approved artifacts and prepare the branch.**

  After plan approval and return to Default mode, save this plan and record specification approval without changing its scope or creation date.

  Preserve local artifacts, fetch upstream, fast-forward `main` safely and create `chore/layered-cube-usdz-model`. Reassess unexpected upstream changes before continuing.

  Commit only the approved pair with `docs: record layered cube model specification and plan`.

  Expected: the dedicated branch contains both artifacts; no existing changes were discarded.

- [x] **Step 2: Preserve inputs and establish generation safeguards.**

  Create the artwork folder only after checking for existing contents. Copy the reference PNG and verify SHA-256 `74723d5ddd7017e0943882a3c9b35ef3aca4b137244007aaabbe4bc2804a256b`.

  Record interpreter, USD-tool and renderer versions. Require fresh numbered candidate directories. Source scripts and instructions remain beside the candidates.

  Expected: the original image is unchanged, the local copy matches, and existing outputs cannot be overwritten accidentally.

- [x] **Step 3: Establish focused geometry checks.**

  Add tests for finite coordinates, valid face/index counts, nondegenerate faces, declared scale, expected component names and positive three-dimensional bounds. Include deliberately invalid mesh inputs to prove the checks reject them.

  Run these checks before implementing the generator; confirm failures concern the missing implementation. Then implement generation and require the same checks to pass.

  Expected: geometry checks exercise meaningful invalid cases and the generated model; zero failures remain.

- [x] **Step 4: Generate editable geometry and materials.**

  Construct beveled frame beams, thin translucent side panels, the upper pyramid and two separated platforms. Add a restrained modeled grid above the teal platform without coplanar overlapping surfaces.

  Author identifiable components beneath one default model root. Use procedural materials with no external textures, cameras or lights required by the asset.

  Expected: the editable USDA contains every agreed component and no magnifying glass or image billboard.

- [x] **Step 5: Convert and package the candidate.**

  From the fresh candidate directory, use the installed tool interfaces:

  ```sh
  /usr/bin/usdcat model.usda -o model.usdc
  /usr/bin/usdcat --loadOnly model.usdc
  /usr/bin/usdzip model.usdz model.usdc
  /usr/bin/usdcat --loadOnly model.usdz
  ```

  Expected: successful exits and load checks reporting success. Inspect the package listing: it contains the intended root layer and no unintended files.

- [x] **Step 6: Inspect the final package independently.**

  Implement the Swift helper using Model I/O to inspect geometry loaded from the USDZ. Check finite positions, valid indices, nondegenerate bounds and the expected component arrangement.

  Run the existing CLI validation interface documented in `docs/cli.md`:

  ```sh
  .build/release/usdz-validator validate "$candidate_dir/model.usdz" --format json
  ```

  Expected: validator version 0.2.0, exit `0`, complete requested native coverage and no operational errors. Retain stdout/stderr and the independent geometry results.

- [ ] **Step 7: Inspect appearance and save previews.**

  Open the actual USDZ in Quick Look and inspect the reference-like view plus rotation toward the rear. Check bevel visibility, component separation, transparency and unintended intersections.

  Generate a Quick Look thumbnail using its documented interface:

  ```sh
  /usr/bin/qlmanage -t -s 1024 -o "$preview_dir" "$candidate_dir/model.usdz"
  ```

  Use the Swift helper to render another angle from the same package. Label each preview's renderer. Rendering setup may add viewing cameras and lights, but must not silently replace asset materials.

  Refine geometry or material parameters within the approved scope until the model is usable. Preserve attempts and repeat affected checks after changes.

  Expected: two readable previews of the actual model and successful Quick Look inspection. Unavailable or failed visual inspection remains unresolved.

- [ ] **Step 8: Document, review and complete the increment.**

  Save reproduction/viewing instructions, final file hashes, commands, results, renderer observations and limitations. Identify the final candidate explicitly.

  Complete the integrated sequential specification-then-quality review required by `personal-workflows:spec-implement`. Supply the approved artifacts, complete repository diff and the external artwork sources, previews and hash-bound evidence.

  Resolve blocking findings within scope, preserve review receipts and commit workflow completion records on the implementation branch. Keep artwork local.

  Expected: no unresolved blocking findings; report the USDZ/source locations, previews, verification and remaining visual limitations.

## Traceability and approval handoff

| Criteria | Implementation and evidence |
|---|---|
| AC-01, AC-02 | Geometry generation, independent inspection and rotated previews |
| AC-03 | Material iteration and actual Quick Look inspection |
| AC-04, AC-05 | USD load/package checks and independent geometry checks |
| AC-06 | Preserved reference, editable source, scripts and instructions |
| AC-07 | Native report, two previews and verification/review receipts |
| AC-08 | External artwork location, constrained branch changes and completion report |

The specification and plan have separate explicit approvals. This plan is saved for Stage 4 execution; no push, merge, tag or publication is authorized.

**Execution endpoint:** Deliver the verified cube-only USDZ, editable sources, previews, instructions and review evidence; report the result and limitations; then stop before further artwork, the magnifying glass or integration.


## Execution progress — 2026-10-28

Steps 1–6 are verified. Candidate `candidate-001/model.usdz` and editable sources are saved under the approved external artwork folder. Package SHA-256: `45a7d8bcde02ccabfba476e3d68f265e269e6997dad3728a61af9276302b7953`. Twelve geometry tests pass; Apple USD load/package checks pass; Model I/O independently checks 25 meshes (14,118 triangles) and 20 cm bounds. Validator 0.2.0 exits 0 with complete requested native coverage, no findings and no operational errors.

Step 7 is partial: the remote Quick Look thumbnail and two SceneKit views were generated from that package and visually inspected. The initial SceneKit viewing lights overexposed the first images; corrected directional viewing lights preserve the imported materials. All attempts remain distinct. Direct thumbnail generation timed out; the documented `qlmanage -x` service option succeeded.

Interactive Quick Look opening/rotation remains **UNRESOLVED**: native desktop observation reports that the Mac is locked and automatic unlock failed. Manual unlock is needed before that check can continue. This is not a completed visual-acceptance or final-review claim.

Reproduction instructions and hash-bound verification are retained in the artwork folder (`INSTRUCTIONS.md`, `evidence/candidate-001-verification.json`, `evidence/file-manifest.json`). Step 8's integrated sequential final review and completion commit remain pending; no task completion or final review PASS is recorded. No product files, private samples, push, merge, tag or publication were changed.


### Resumed viewer check — 2026-10-28

After manual unlock, the exact candidate was selected in Finder and opened with Space. The actual Quick Look window rendered the frame and internal contents clearly; a screenshot is retained locally in the artwork evidence directory. Rotation is still **UNRESOLVED**: automation did not produce a rotated view, and the viewer exposes `Failed to load configuration` accessibility text. The unchanged retained Apple teapot control exposes the same text; its automated drag returned `AXError.illegalArgument`. This suggests shared viewer/automation behavior without establishing a root cause. A manual rotation check was requested from the user. All 12 geometry tests passed again; no geometry or materials changed. Final review remains pending that check.

# Layered Cube Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` through `personal-workflows:spec-implement`. Steps use checkbox (`- [ ]`) syntax for tracking.

**Slug:** `layered-cube-refinement`
**Status:** APPROVED
**Created:** 2026-10-28
**Updated:** 2026-10-28
**Execution tier:** full
**Implementation model role:** full
**Execution method:** Native, preserving the method selected for the original cube-model work.
**Spec:** [Approved specification](../specs/2026-10-28-layered-cube-refinement.md)

**Goal:** Deliver a softer, fuller version of the existing cube-only USDZ, with thicker platforms, a taller pyramid, closer spacing and genuine rounded geometry.

**Architecture:** Extend the existing local procedural mesh generator and independent Model I/O inspector. Keep the baseline immutable, generate each refinement into a fresh candidate directory, and verify the packaged model through geometry checks, native validation, matching renders and Quick Look.

**Tech Stack:** Python standard library, installed Apple USD Tools 0.25.11, Swift 6.4, Model I/O, SceneKit, Metal and Quick Look. No installation.

**Provenance and approval:** The user confirmed the combined refinement, then separately approved its saved specification with “approved.” At planning time this plan was the next approval artifact and implementation had not begun; its later separate approval is recorded below. Inspection HEAD is `213cf0bc6d2577fde9ecffd0a6713b6f65a3f75b` on `chore/layered-cube-usdz-model`. Specification resolution is `NEW_ONLY`; plan resolution was `MISSING`, including exact-slug and canonical/legacy-path checks. No architecture map or ADR directory exists, so there is no map freshness SHA or applicable ADR status to record. Key paths checked: the existing generator, tests, Swift inspector, instructions, baseline sources and verification receipts. No architecture artifact will be generated.

## Global constraints

- Artwork stays under `/Users/davide/Personal/Images/usdz-validator/cube-model/`; validator product files remain unchanged.
- Preserve the 20 cm outer bounds, Y up, meters, glossy blue/teal materials, lightly translucent sides, open top, grid and consistent rear geometry.
- Refine the single pyramid; add no separate square base or plinth. Omit the magnifying glass.
- Preserve `candidate-001` and all its frozen sources/previews/evidence, the reference PNGs, earlier approved workflow records and private Apple samples.
- Keep attempts distinct, including failed candidates. Refuse existing output directories.
- No installation, product source/tests/schema/dependency/version/interface changes, README integration, push, merge, tag or publication.
- Use the existing checkout. Create `chore/layered-cube-refinement` only after separate specification and plan approvals; keep both new workflow artifacts uncommitted until then.
- Native validation supplements independent geometry/package and actual viewer inspection.

## Review focus

1. Thicker shelves and the taller pyramid remain separated; moved grid bars stay above the teal surface. Step 3 tests measured clearances; Step 8 checks flicker and appearance.
2. Rounding changes silhouettes and frame joins without holes or blocky overlapping caps. Steps 3–4 test geometry and seams; Step 8 inspects angled close-ups.
3. Thin panels have rounded outlines without disappearing or becoming opaque. Steps 3–4 test independent outline/edge radii; Step 8 inspects actual transparency.
4. Independent inspection accepts changed topology while still rejecting missing contents, invalid geometry and wrong dimensions. Step 6 exercises valid and deliberately invalid inputs.
5. Previews, receipts and source snapshots identify the final package; baseline files and failed attempts remain distinguishable. Steps 2 and 9 verify preservation and hashes; Step 8 requires fresh viewer evidence.

---

## Task 1: Refine and verify the complete local artwork [size: M | risk: none | mechanical: false | clear_pattern: false | objectively_verifiable: false | concerns: none]

**Acceptance criteria:** AC-01, AC-02, AC-03, AC-04, AC-05, AC-06, AC-07, AC-08.

One cohesive task keeps thickness, spacing, rounding and actual-package appearance in the same verification cycle. Full execution is required because likeness and usable rounding need visual judgment.

**Files and responsibilities:**

- Repository: save/commit only this matching specification/plan pair and their execution records.
- Modify external `generate_model.py`: geometry, modeling parameters, USD/material authoring and measured geometry receipt.
- Modify external `test_model.py`: meaningful geometry, arrangement and preservation regressions.
- Modify external `inspect_model.swift`: independent imported-geometry checks and renderer-labelled package previews.
- Update external `INSTRUCTIONS.md`: final-candidate identification and reproducible commands, retaining baseline instructions/history.
- Create fresh `candidate-NNN/` containing editable USDA, USDC, USDZ, matching `sources/`, inspection outputs and Quick Look preview.
- Create fresh `evidence/refinement-YYYY-MM-DD-NNN/` containing logs, comparison previews, hashes, preservation checks, final receipt and review archive. Do not rewrite earlier evidence or its manifest.

All external paths above are relative to the artwork root. `candidate-002` is currently unused; execution must recheck and choose the next unused number.

**Interfaces:** Preserve `scene_meshes() -> list[Mesh]`, `validate_mesh(mesh)`, `stage_text(meshes)` and `generate_candidate(output) -> Path`, including `--output` and existing-directory refusal. Add only geometry helpers needed by this model: `rounded_slab(name, group, material, center, size, corner_radius, edge_radius) -> Mesh`, `rounded_pyramid(base_y, apex_y, half_extent, radius) -> Mesh` and `rounded_frame(outer_edge, thickness, radius) -> list[Mesh]`. Keep inspection CLI `inspect_model <model.usdz> <fresh-output-directory>`, producing `independent-geometry.json` and SceneKit front/rear previews. Inspection must derive geometry from the package rather than trust generator receipts.

- [x] **Step 1: Prepare the approved branch and record the pair.**

  Load `personal-workflows:spec-implement`; identify the saved specification, this plan and their separate approving messages. Record plan approval without altering scope. Check status and preserve both uncommitted files.

  After approval, fetch origin, switch to `main` and fast-forward it safely. Preserve the completed local branch at `213cf0b`. Confirm updated `main` remains an ancestor of that branch before creating `chore/layered-cube-refinement` from the completed-artwork branch. This retains the original increment's local records. If ancestry, local changes or upstream inputs differ, reassess without discarding work or merging branches automatically.

  Expected: the new branch contains the completed baseline and both new artifacts, with no lost changes. Commit only the new pair with `docs: record layered cube refinement specification and plan`.

- [x] **Step 2: Freeze the baseline and establish fresh destinations.**

  Recheck reference SHA-256 `74723d5ddd7017e0943882a3c9b35ef3aca4b137244007aaabbe4bc2804a256b` and baseline package SHA-256 `45a7d8bcde02ccabfba476e3d68f265e269e6997dad3728a61af9276302b7953`. Inventory/hash `candidate-001`, existing evidence, the current artwork sources/instructions and available original inputs before edits. Retain a source snapshot in the new evidence directory; leave baseline directories untouched. Check private originals against their existing relocation receipt without copying them into delivery/review packages.

  Record current Python, Swift, USD-tool, OS and renderer identities and retained validator identity. Select unused evidence/candidate destinations and use exclusive creation. Expected: any hash mismatch or destination collision is reported before generation, and preservation has a comparison record independent of later outputs.

- [x] **Step 3: Add failing refinement regressions.**

  Extend `test_model.py` before changing geometry. Use measured vertex bounds, not generator parameter values, to assert:

  - `test_refined_pyramid_height_and_no_plinth`: height approximately 0.0713 m (0.0005 m tolerance), apex no higher than 0.085 m, one named pyramid, no added slab underneath.
  - `test_both_platforms_are_thicker`: each shelf thickness 0.010 m within 0.00025 m; teal/pale-blue materials and grid retained.
  - `test_refinement_reduces_gaps_without_intersections`: positive lower-to-middle, middle-to-grid and grid-to-pyramid gaps; the shelf-to-shelf and grid-to-pyramid gaps are smaller than independently recorded baseline values (0.045 m and approximately 0.034 m respectively).
  - `test_rounded_silhouettes_and_closed_seams`: pyramid has genuine curved-edge/tip samples beyond the old five vertices; slab outlines recede from sharp corners; coincident-position seam welding yields closed, consistently oriented boundaries on each intended closed surface. Include a missing-face/reversed-face control so the check proves it can reject bad geometry. Frame checks must allow its concave overall shape.
  - `test_thin_panel_rounding_is_independent_of_thickness`: all four panels retain positive thickness, rounded in-plane corners and finite nondegenerate triangles. Invalid dimensions/radii raise contextual errors.

  Retain existing invalid-coordinate/index/face, bounds, materials, raised-grid and refusal-to-overwrite coverage. Apply the old convex-center winding test only to convex parts; it is invalid for a connected concave frame.

  Core dimension assertions belong in the existing `ModelTests` class, for example:

  ```python
  def test_both_platforms_are_thicker(self):
      meshes = self.model().scene_meshes()
      for group, material in (("MiddlePlatform", "Teal"),
                              ("LowerPlatform", "PaleBlue")):
          parts = [m for m in meshes if m.group == group]
          self.assertEqual(len(parts), 1)
          self.assertEqual(parts[0].material, material)
          heights = [v[1] for v in parts[0].vertices]
          self.assertAlmostEqual(max(heights) - min(heights),
                                 0.010, delta=0.00025)

  def test_refined_pyramid_height_and_no_plinth(self):
      parts = [m for m in self.model().scene_meshes()
               if m.group == "Pyramid"]
      self.assertEqual(len(parts), 1)
      self.assertEqual(parts[0].name, "BluePyramid")
      heights = [v[1] for v in parts[0].vertices]
      self.assertAlmostEqual(max(heights) - min(heights),
                             0.0713, delta=0.0005)
      self.assertLessEqual(max(heights), 0.085 + 1e-9)
  ```

  From the artwork root run the existing command from `INSTRUCTIONS.md`:

  ```sh
  python3 -m unittest discover -s . -p 'test_model.py' -v
  ```

  Expected: new refinement cases fail against baseline proportions/geometry; existing applicable checks pass. Save the actual failing output. Do not treat unrelated import/tool failures as the intended red result.

- [x] **Step 4: Implement the refined geometry and pass the tests.**

  Extend the existing procedural helpers without external dependencies. Starting modeling values, chosen within the specification's visual tuning allowance:

  | Element | Initial refined values |
  |---|---|
  | Pyramid | Base Y 0.0137 m, apex Y 0.085 m, half-width/depth 0.067 m; approximately 3 mm ridge/tip rounding |
  | Middle platform | Center Y −0.010 m; dimensions 0.154 × 0.010 × 0.154 m |
  | Lower platform | Center Y −0.055 m; same dimensions |
  | Platform rounding | Approximately 6 mm in-plane corners and 2.5 mm edge rounding |
  | Frame | Retain approximately 12 mm members and 20 cm outer bounds; increase edge rounding toward 4.5 mm with matching rounded junctions |
  | Panels | Retain approximately 1 mm thickness/0.10 opacity; approximately 6 mm outline corners with separate small edge rounding |

  Implement rounded slabs with independent in-plane and thickness radii. Build the rounded pyramid as a closed convex surface with flat face regions, tessellated ridge arcs and softened vertex patches; keep neighboring patches on shared boundaries and normalize resulting bounds to the recorded height/width targets. Create frame members and matching junction surfaces with coherent rounded joins; remove hidden coincident caps where parts meet. Preserve top/bottom openings. Use shared boundary positions, adequate curve sampling and consistent normals/winding rather than shading sharp silhouettes.

  Reposition grid bars relative to the new teal top using the existing small offsets between directions. Keep imported materials and default root/group identities. Extend `geometry.json` with actual dimensions, radii, measured gaps and baseline comparison. Do not hard-code a new total mesh count.

  Run Step 3's suite again. Expected: zero failures, including malformed-input and seam controls. Record actual counts. Parameter adjustments may follow Step 8 within the approved modest treatment; update tests/receipts to the chosen values without weakening separation or integrity checks.

- [x] **Step 5: Generate and package a fresh candidate.**

  From the artwork root, use the generator interface documented in `INSTRUCTIONS.md`, substituting the verified unused number:

  ```sh
  python3 generate_model.py --output candidate-002
  ```

  Stop on any failure before packaging. From that new candidate directory, use the existing instructions/original approved plan commands:

  ```sh
  /usr/bin/usdcat model.usda -o model.usdc
  /usr/bin/usdcat --loadOnly model.usdc
  /usr/bin/usdzip model.usdz model.usdc
  /usr/bin/usdcat --loadOnly model.usdz
  ```

  Expected: all successful exits, load success, and a self-contained package with only the intended `model.usdc` root layer. Inspect the ZIP inventory using Python's standard library and retain it; no external texture, camera/light dependency or unexpected file is admitted. Snapshot matching generator/test/inspection sources with the candidate. Preserve stdout/stderr and hash the package before downstream verification.

- [x] **Step 6: Update and exercise independent inspection.**

  Remove the Swift helper's hard-coded total of 25 meshes and per-group beam-count assumptions. Retain required groups, four panels, one pyramid, both shelves, grid identity, finite transformed positions, valid triangular indices/areas, 20 cm bounds and separation. Derive dimensions and gaps independently from Model I/O vertices; check the Step 3 height/thickness tolerances and reduced gaps without reading `geometry.json` as expected truth. Retain clear failures for missing components and unexpected content. Preserve the baseline camera and lights for comparable rendering.

  Compile/run using the existing `INSTRUCTIONS.md` interfaces from the artwork root:

  ```sh
  xcrun swiftc inspect_model.swift -o inspect_model
  ./inspect_model candidate-002/model.usdz candidate-002/inspection
  ```

  Expected: independent geometry PASS and front/rear PNGs from the same package, without material replacement. Use disposable malformed/missing-component USD inputs through this same interface to verify rejection. Keep those inputs/output separate from the candidate; a failed inspection cannot receive a PASS receipt. For baseline comparisons, use its frozen `candidate-001/sources/inspect_model.swift`, compiled separately into the new evidence directory, with that helper's existing two-argument interface and a fresh output destination. Its camera/lights match the refined renderer, and its earlier geometry checks remain appropriate for the unchanged baseline. Do not relax refined acceptance to render the baseline.

- [x] **Step 7: Run default native validation.**

  From the repository, use the interface in `docs/cli.md` and the original plan:

  ```sh
  .build/release/usdz-validator validate "$candidate_dir/model.usdz" --format json
  ```

  Here `candidate_dir` is the absolute path to the generated candidate. Expected: validator 0.2.0, exit 0, complete requested native coverage, no findings or operational errors; external checker remains unrequested. Retain stdout/stderr, report, executable identity and package hash. This is an artwork check, not another validator release run.

- [x] **Step 8: Inspect comparisons and the actual package.**

  Use matched SceneKit views to compare baseline/refinement proportions and round silhouettes, including frame junctions, panel corners and pyramid tip. Save front/rear comparisons and angled detail crops with renderer labels and package hashes. Inspect the actual final USDZ in Finder Quick Look, opening with Space and rotating toward the rear; verify contents, separation, rounding and absence of severe flicker.

  Generate the thumbnail through the documented remote service that succeeded previously:

  ```sh
  /usr/bin/qlmanage -x -t -s 1024 -o "$preview_dir" "$candidate_dir/model.usdz"
  ```

  `preview_dir` must be fresh. Expected: a readable actual-package thumbnail plus successful fresh interactive inspection. Attribute human rotation evidence if automation fails again; never reuse baseline acceptance or represent a thumbnail as interactive rotation. A blocked viewer check remains unresolved. Within-scope tuning gets a new candidate and repeated affected geometry/package/native/visual checks; never replace earlier attempts silently.

- [ ] **Step 9: Document, review and complete the increment.**

  Update `INSTRUCTIONS.md` with final dimensions/radii/gaps, candidate/source locations, fresh-destination reproduction commands, before/after preview paths and renderer/viewer limitations. Recheck the new-source suite after any final edits. Save a final candidate receipt and SHA-256 inventory covering sources, package, previews and evidence; compare all protected baseline files and private-original hashes with Step 2. Keep previous evidence manifests unchanged.

  Run focused workflow-document link checks with the repository's `verify_links(path)` helper in `Scripts/verify-examples.py`, then `git diff --check`. Expected: valid links, no whitespace errors and no validator product diff. Commit only the pair's execution records with `docs: record verified layered cube refinement`.

  Complete `personal-workflows:spec-implement`'s single integrated, sequential specification-then-quality final review, using `personal-workflows:code-review`. Supply the approved pair, full branch diff against the recorded baseline, external source changes, exact package/previews and hash-bound checks. Preserve both review receipts before cleanup. Resolve blocking findings within scope and refresh affected evidence/review; unrelated future artwork stays deferred. Commit the final workflow completion record if necessary.

  Expected: no unresolved blocking findings, clean local implementation branch, identified final USDZ/editable sources and an honest evidence/limitations report. Artwork stays local; nothing is pushed, merged or published.

## Traceability and command evidence

| Criteria | Steps and evidence |
|---|---|
| AC-01 | 3–4 measured pyramid regression; 6 independent bounds; 8 comparison |
| AC-02 | 3–4 shelf/grid regressions; 6 imported dimensions; 8 visibility |
| AC-03 | 3–4 gap checks; 6 independent clearances; 8 actual viewer |
| AC-04 | 3–4 silhouette/seam tests; 8 rounded detail views |
| AC-05 | 3–6 scale/component/material checks; 8 Quick Look |
| AC-06 | 3–7 geometry, USD loading, package inventory and native report |
| AC-07 | 6, 8–9 matched previews, fresh viewer evidence and sequential reviews |
| AC-08 | 1–2, 5, 9 baseline preservation, snapshots, instructions and hashes |

Test/generator/compiler/inspection commands come from the external `INSTRUCTIONS.md` and current source interfaces. USD conversion/load/package and native commands are also retained in the original approved repository plan; native behavior is documented in `docs/cli.md`. Remote thumbnail flags were rechecked with installed `qlmanage -h`. Documentation-link checking uses the existing repository helper. These commands are planned checks; none is represented as freshly passed during planning.

## Approval handoff and execution endpoint

**Stage 4 approval:** The specification was presented and separately approved with “approved.” After this implementation plan was presented, the user separately replied “approved.” Both saved artifacts authorize execution of this refinement only, with the preserved native method and required final review. No push, merge, tag or publication is authorized.

**Execution endpoint:** Deliver the refined cube-only USDZ, editable sources, comparison previews and instructions; complete geometry/package/native/viewer verification and sequential final review; report evidence and limitations; then stop before further artwork or integration.


## Execution evidence — 2026-10-28

Steps 1–8 are verified. The local refinement branch preserves the completed baseline branch; `main`/`origin/main` remain at `dad53f0`. The refined package is `candidate-002/model.usdz` under the external artwork root, 530,905 bytes, SHA-256 `51e41708c1e2248b344b512101a3026bfa1e18847d9e5be086aa7e828892b7e8`. Matching generator, tests, inspector and instructions are frozen with that candidate.

The initial refinement suite recorded six expected failures against the baseline; all 20 current artwork cases now pass, including invalid geometry and broken-seam controls. Apple USD conversion/package/load checks pass. Model I/O independently confirms 14 meshes, 35,694 triangles, 20 cm bounds, a 71.3 mm pyramid, two 10 mm shelves and reduced positive gaps. Independent baseline-proportion, missing-platform and malformed-input controls are rejected. Validator 0.2.0 exits 0 with complete requested native coverage, no findings or operational errors; no external checker or new full product release run is claimed.

Matched front/rear comparisons and detail crops show the real packaged geometry using unchanged viewing cameras/lights/materials. The Quick Look remote thumbnail succeeded. The assistant observed/captured the actual Quick Look front view; the user freshly answered “Yes, it rotates and looks usable” for this refined candidate. Automated rotation was not established, and the configuration/accessibility/capture issues remain recorded rather than reported as fixed.

Protected baseline/reference/evidence checks and all five private-original hashes pass. Earlier receipts/manifests and the original approved pair remain unchanged. New evidence is in `evidence/refinement-2026-10-28-001/`; no private assets were copied into the model or distributed.

**Execution ruling:** The frame uses a subdivided exposed union boundary rather than separate beam caps, producing one continuous closed surface with coherent joins. Its 4.5 mm support radius describes construction rather than a constant circular fillet; visual inspection checks the resulting softness. Pyramid/slab rounding follows the planned geometry treatment. Nominal frame-plane clearances in the generator receipt are distinguished from conservative frame triangle-box clearance bounds in the dedicated evidence.

Step 9 documentation and closing checks are verified, but the integrated sequential final review remains pending. The first specification review returned BLOCKED because the task-done helper marked Task 1 complete while Step 9 remained unchecked. That completion marker was retracted; Task 1 remains in progress until the review and closure finish. The original sealed package, ledger and report are preserved in `evidence/refinement-2026-10-28-001/final-review-blocked/`. The quality reviewer was not dispatched, and no review PASS or increment-completion claim is made. A fresh review package with consistent execution status is required. No push, merge, tag, publication or product integration was performed.

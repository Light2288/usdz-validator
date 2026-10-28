# Layered Cube Refinement Implementation Plan — revision 2

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` through `personal-workflows:spec-implement`. Steps use checkbox (`- [ ]`) syntax for tracking.

**Slug:** `layered-cube-refinement`
**Status:** APPROVED
**Revision:** 2
**Created:** 2026-10-28
**Updated:** 2026-10-28
**Execution tier:** full
**Implementation model role:** full
**Execution method:** Native, preserving the selected execution method.
**Spec:** [Approved revision-2 specification](../specs/2026-10-28-layered-cube-refinement.md)

**Goal:** Deliver a taller pyramid, two thicker platforms and equal clear gaps in a fresh, verified cube-only USDZ, preserving the previous models.

**Architecture:** Adjust existing procedural dimensions and derive platform/grid placement from the approved gaps. Independently inspect imported geometry and actual-package appearance; retain the existing rounded mesh algorithms, materials and rendering setup.

**Tech Stack:** Python standard library, installed Apple USD Tools 0.25.11, Swift 6.4, Model I/O, SceneKit, Metal and Quick Look. No installation.

**Provenance and approval:** Revises this same plan as preserved at `da63a66cd707b41b14b2ddce610ae3f85af281f0`, on `chore/layered-cube-refinement`. The user separately approved the revised scope/design and then the saved revision-2 specification, each with “approved.” The latter authorizes this planning stage only. Exact-slug resolution selects the existing specification and plan as `NEW_ONLY`, with a matching Spec reference and no legacy/identity conflict. Original filenames and Created dates remain unchanged. Revision-1 execution evidence is retained verbatim below and in Git history; its checkboxes do not establish revision-2 progress. `docs/architecture/map.md` and ADR directories are absent; no architecture artifact is generated. Key paths inspected: generator, tests, Swift inspector, instructions, candidate-002 frozen sources and preserved verification/review records.

## Global constraints

- Artwork root: `/Users/davide/Personal/Images/usdz-validator/cube-model/`. Only workflow artifacts/records change in the validator repository.
- Pyramid: height **76.3 mm**, base Y **13.7 mm**, apex Y **90 mm**, footprint **134 × 134 mm**. Both platform bodies: **154 × 12 × 154 mm**.
- Both clear gaps: **25 mm ±0.1 mm**; their difference is **≤0.1 mm**. Other specified dimensions/coordinates have **0.1 mm** tolerance. Count the grid as part of the middle visual element.
- Preserve the 20 cm outer bounds, Y up/meters, open top, rounded geometry, glossy palette, four translucent panels, modeled grid and consistent rear geometry. One pyramid; no extra plinth or magnifier.
- Preserve candidates 001/002, frozen sources/previews/receipts, reference PNGs, private Apple originals and old workflow/review evidence. Fresh exclusive candidate/evidence destinations; no silent overwrite.
- Existing checkout only. Renewed plan approval precedes Git preparation and artwork changes. No installation, product changes, integration, push, merge, tag or publication.
- No old 85 mm apex ceiling or requirement to stay below the nominal inner top-frame plane. Require positive actual frame clearance and inspect the taller tip.
- Native validation supplements independent geometry/package/viewer evidence. Keep the task/increment in progress until required reviews and closure finish.

## Review focus

1. Omitting the grid makes the upper gap wrong: Step 3 measures its highest vertex and pins a control calculation that fails if the grid is omitted.
2. A 90 mm apex crosses the nominal 88 mm plane without necessarily hitting the open frame: Step 7 checks actual frame geometry, including a contact control, rather than rejecting a plane distance.
3. Thickness changes can leave grid bars embedded or platforms misplaced: Steps 3/7 independently check raised grid, exact dimensions/gaps, separation and footprint.
4. Old candidate acceptance or stale task completion can masquerade as new verification: Steps 2/12 bind fresh state, viewer evidence and reviews to the new candidate hash; old review remains BLOCKED.
5. Equal physical gaps may look unequal in perspective, or revised rounding may show artifacts: Step 10 compares matched front/rear/detail views and requires fresh actual-package inspection.

---

## Task 1: Revise and verify the complete local artwork [size: M | risk: none | mechanical: false | clear_pattern: true | objectively_verifiable: false | concerns: none]

**Acceptance criteria:** AC-01, AC-02, AC-03, AC-04, AC-05, AC-06, AC-07, AC-08.

This is one coherent visual revision. Full execution reflects the judgment needed for likeness, rounded appearance and viewer usability; dimensions alone cannot establish acceptance.

**Files and responsibilities:**

- Repository: revise/commit this specification/plan pair and scoped execution records only.
- External `generate_model.py`: dimensions, derived placement and measured receipt; retain existing rounded geometry/material algorithms.
- External `test_model.py`: revised dimension/spacing regressions and retained integrity controls.
- External `inspect_model.swift`: independent imported dimensions/gaps, frame-clearance evidence and unchanged SceneKit views.
- External `INSTRUCTIONS.md`: final-candidate identification, dimensions, reproduction and limitations, preserving earlier history.
- Fresh `candidate-NNN/`: editable USDA, USDC, USDZ, frozen matching sources, inspection and previews. `candidate-003` is currently unused; recheck at execution.
- Fresh `evidence/refinement-r2-YYYY-MM-DD-NNN/`: pre-edit inventory/snapshot, logs, comparisons, manifests, viewer observations and sequential review receipts. Never modify the old sealed review package.

External paths are relative to the artwork root. Preserve interfaces `scene_meshes() -> list[Mesh]`, `validate_mesh(mesh)`, `stage_text(meshes)`, `generate_candidate(output) -> Path`, `generate_model.py --output <fresh-directory>` and `inspect_model <model.usdz> <fresh-output-directory>`. Retain `rounded_frame`, `rounded_slab` and `rounded_pyramid`; no new geometry framework is needed. The inspector derives measurements from package vertices, not the generator's receipt.

- [ ] **Step 1: Prepare the approved revision branch and record the pair.**

  Load `personal-workflows:spec-implement` and its selected native base once. Identify the saved revision-2 specification, this plan and their separate approving messages. Only after separate plan approval, record approval and inspect status/HEAD/upstream. Preserve the current branch and tracked artifact edits: use a scoped stash of only the pair if needed, recording and verifying its exact identity; never include/discard unrelated changes. Fetch origin, safely fast-forward `main`, then return to the preserved refinement branch. Confirm updated `main` is an ancestor before creating `chore/layered-cube-refinement-r2` from the preserved refinement branch and restoring the exact pair. On divergence or restoration conflict, preserve all states and reassess; do not force or merge automatically.

  Expected: renewed branch retains earlier local work and only the approved pair's intended edits. Commit the pair with `docs: record layered cube refinement revision 2 specification and plan`. Do not create a worktree or change branches during planning.

- [ ] **Step 2: Establish preservation evidence and fresh execution state.**

  Recheck candidate-002 SHA-256 `51e41708c1e2248b344b512101a3026bfa1e18847d9e5be086aa7e828892b7e8`, candidate-001 `45a7d8bcde02ccabfba476e3d68f265e269e6997dad3728a61af9276302b7953` and reference `74723d5ddd7017e0943882a3c9b35ef3aca4b137244007aaabbe4bc2804a256b`. Inventory/hash protected files and snapshot working sources/instructions into a fresh revision-2 evidence directory. Check private-original hashes against their relocation receipt without copying those files into the package. Record tool/OS/renderer and retained validator identities. Choose unused candidate/evidence names with exclusive creation.

  Preserve revision-1 scratch/ledger/review state before initializing revision-2 execution state under the same artifact identity; use the loaded workflow's supported initialization method and do not delete sibling evidence or reuse an old completion marker. Record revision 2, pending review and task in progress explicitly. Expected: recoverable old state, fresh revision-specific progress and a pre-edit preservation manifest; any mismatch is resolved before generation.

- [ ] **Step 3: Add measured revision-2 regressions before changing generation.**

  Update the existing pyramid/thickness/gap/receipt tests, retaining all finite-coordinate, index/face, closed/oriented seam, missing/reversed-face, invalid-radius, bounds, materials, panel and fresh-output-refusal controls. Use vertex bounds, not parameter values. Pin these exact assertions (meters):

  ```python
  self.assertAlmostEqual(pyramid_max_y - pyramid_min_y, 0.0763, delta=0.0001)
  self.assertAlmostEqual(pyramid_min_y, 0.0137, delta=0.0001)
  self.assertAlmostEqual(pyramid_max_y, 0.0900, delta=0.0001)
  self.assertAlmostEqual(platform_max_y - platform_min_y, 0.012, delta=0.0001)
  lower_gap = middle_min_y - lower_max_y
  upper_gap = pyramid_min_y - max(middle_max_y, grid_max_y)
  self.assertAlmostEqual(lower_gap, 0.025, delta=0.0001)
  self.assertAlmostEqual(upper_gap, 0.025, delta=0.0001)
  self.assertLessEqual(abs(lower_gap - upper_gap), 0.0001)
  self.assertGreater(abs((pyramid_min_y - middle_max_y) - 0.025), 0.0001)
  ```

  Apply thickness to each platform and footprint bounds to X/Z: pyramid 0.134 m, each platform 0.154 m within 0.0001 m. Retain one pyramid/no plinth and positive middle-to-grid clearance. Receipt assertions must agree with measured new geometry and identify candidate-002 as baseline. The final assertion above proves ignoring the grid would fail the upper-gap tolerance. Never weaken the earlier integrity controls to accommodate new dimensions.

- [ ] **Step 4: Establish the expected failing result.**

  From the artwork root run `python3 -m unittest discover -s . -p 'test_model.py' -v`. Expected: revised targets fail against candidate-002 generation while applicable existing checks pass; save actual output/counts. An import/tool error is not the intended failure.

- [ ] **Step 5: Adjust dimensions and derive platform/grid placement.**

  In `scene_meshes()`, keep pyramid base 0.0137 m and half-extent 0.067 m; raise apex to 0.0900 m. Increase both bodies to 0.012 m thick. Derive placement from actual middle/grid extent and the two 0.025 m gaps, retaining existing grid-bar height 0.00035 m and grid-center offsets of 0.0004/0.0008 m above the middle top. This gives middle top −0.012275 m, center −0.018275 m and bottom −0.024275 m; lower top −0.049275 m, center −0.055275 m and bottom −0.061275 m. Grid centers follow the new middle top, rather than old absolute coordinates.

  Retain platform 6 mm outline/2.5 mm edge rounding, pyramid 3 mm rounding and existing frame/panel construction/materials. Update `generate_candidate()` measurements and baseline comparison to candidate-002 (71.3 mm pyramid, 10 mm bodies, 35/17.725 mm gaps). Remove misleading nominal-plane clearance claims from new receipts or label them explicitly as nominal diagnostics; never edit old receipts. Actual frame clearance is established in Step 7.

- [ ] **Step 6: Verify the generator and package a fresh candidate.**

  Repeat Step 4's command; expected zero failures with all meaningful controls retained. Then use `python3 generate_model.py --output candidate-003`, substituting the unused name established in Step 2. From that candidate directory run sequentially:

  ```sh
  /usr/bin/usdcat model.usda -o model.usdc
  /usr/bin/usdcat --loadOnly model.usdc
  /usr/bin/usdzip model.usdz model.usdc
  /usr/bin/usdcat --loadOnly model.usdz
  ```

  Expected: successful exits/load checks and ZIP inventory containing only the intended `model.usdc`, without external texture/viewing dependencies. Stop after any failure. Freeze matching sources and hash the package before subsequent checks; preserve every failed attempt.

- [ ] **Step 7: Independently inspect dimensions, equal gaps and actual clearance.**

  Update the existing Swift inspector's imported-vertex checks to Step 3 values/tolerances, including base/apex, X/Z footprints, both gaps, gap difference and raised grid. Retain required identities/groups, valid indices/areas/positions, bounds and missing/malformed-input rejection; do not fix acceptance to total mesh count. Preserve viewing cameras/lights/materials.

  Establish a conservative positive lower bound between actual frame triangles and intended separate contents/panels, extending the earlier triangle-box clearance method to the new imported geometry. Overlapping boxes are inconclusive: refine the bound or check triangle distances before accepting. Test this check with a disposable frame-contact/intersection control as well as the valid package. Record method/tolerance and distinguish intended joints; a negative nominal 88 mm-plane distance alone is not a collision. If separation cannot be established, leave AC-03 unresolved.

  From the artwork root compile `xcrun swiftc inspect_model.swift -o inspect_model`, then run `./inspect_model candidate-003/model.usdz candidate-003/inspection` with the chosen candidate. Expected: independent geometry PASS with measured targets/positive actual clearances and front/rear PNGs. Run disposable candidate-002-proportion, missing-platform, malformed-input and frame-contact controls through the same inspection interface into distinct destinations; expected nonzero rejection with no PASS receipt.

- [ ] **Step 8: Run default native validation on the identified package.**

  From the repository run `.build/release/usdz-validator validate "$candidate_dir/model.usdz" --format json`, with `candidate_dir` set to the absolute chosen path. Expected: retained validator version 0.2.0, exit 0, complete requested native coverage and no findings/operational errors; external checker remains unrequested. Preserve report/stdout/stderr, executable identity and package hash. This is fresh artwork validation, not a full validator release run.

- [ ] **Step 9: Produce comparable baseline and revised views.**

  Compile candidate-002's frozen `sources/inspect_model.swift` separately in the fresh evidence directory and invoke its existing two-argument interface on unchanged candidate-002 into a fresh output directory. Its old proportion checks remain appropriate there. Use Step 7's new views for the new package; never relax new acceptance to render the baseline. Save labelled matched front/rear comparisons and frame/pyramid/platform detail crops with both package hashes. Expected: comparable viewing setup and visible increased height/thickness, equal spacing and retained rounding.

- [ ] **Step 10: Inspect the actual new package in Quick Look.**

  Open the identified new USDZ in Finder Quick Look and inspect front and rotation toward the rear for contents, even spacing, tip/frame clearance, rounded silhouettes, transparency and severe flicker. Generate an actual-package thumbnail with `/usr/bin/qlmanage -x -t -s 1024 -o "$preview_dir" "$candidate_dir/model.usdz"`, using a fresh preview directory. Save observations and renderer labels, tied to the new hash. If automation cannot rotate, request fresh human observation of this exact candidate; earlier acceptance and thumbnails cannot establish rotation. An unavailable/failed check stays unresolved. Any within-scope adjustment gets a fresh candidate and affected checks repeated; dimensions/tolerances remain approved constraints.

- [ ] **Step 11: Document and verify the reviewed candidate inputs.**

  Update `INSTRUCTIONS.md` with final dimensions, gap definitions, new candidate/source paths, fresh-output reproduction commands, comparison previews and limitations; preserve earlier history. Rerun Step 4 after final source edits. Freeze final matching sources/instructions and create a candidate/evidence manifest. Compare Step 2 protected inventories, including old review receipts and private-original hashes. Run the repository's existing `verify_links(path)` helper in `Scripts/verify-examples.py` for both workflow artifacts and `git diff --check`. Expected: all focused checks pass and repository diff contains workflow records only. Save these as **verification PASS**, keeping task/increment in progress and review pending.

- [ ] **Step 12: Complete sequential review and close the increment.**

  Commit scoped pre-review records with `docs: record layered cube revision 2 verification`, explicitly retaining pending-review status. Run the single integrated `personal-workflows:code-review` gate required by `personal-workflows:spec-implement`: fresh specification review, then quality review only after specification passes. Supply the approved pair, complete branch diff, external source changes, exact new package, previews, preservation manifest and fresh verification/viewer receipts. Use new review identities and preserve receipts before cleanup; do not reuse the revision-1 BLOCKED report as acceptance. Resolve blocking findings within scope and refresh affected checks/reviews.

  Keep review closure distinct from pre-review verification. Invoke any task-completion helper only after the task's required review actually passes; ensure checkbox/progress/ledger records agree. Commit final scoped completion records with `docs: complete layered cube refinement revision 2`. Expected: no unresolved blocking findings, a clean local branch and final hash-bound deliverable/evidence; no artwork or private assets committed to the repository.

## Traceability and command evidence

| Criterion | Steps and evidence |
|---|---|
| AC-01 | 3–7 measured/imported pyramid targets; 9–10 comparisons/viewer |
| AC-02 | 3–7 platform footprints/thickness and raised grid; 9–10 appearance |
| AC-03 | 3–7 exact equal gaps and actual frame clearance; 9–10 composition |
| AC-04 | 3/6 retained seam/rounding controls; 9–10 silhouette/detail checks |
| AC-05 | 2–7 preserved scale/material/component checks; 9–10 visibility |
| AC-06 | 3–8 test controls, imported geometry, USD package and native report |
| AC-07 | 7–12 fresh matching previews, viewer evidence and sequential reviews |
| AC-08 | 1–2/6/11–12 preserved history, sources, reproduction and manifests |

Commands are grounded in current external `INSTRUCTIONS.md`, generator/inspector interfaces, the original [cube-model plan](2026-10-27-layered-cube-usdz-model.md), repository [CLI documentation](../../cli.md) and `Scripts/verify-examples.py`. Thumbnail flags and the triangle-box clearance approach have retained revision-1 evidence. Git/execution initialization follows the loaded workflow and user Git rules. Expected results are planned acceptance checks, not fresh passing claims. No full product/release test run is warranted for this external artwork-only revision.

**Self-review:** AC-01–AC-08 are covered; exact dimensions/gap definitions match the approved specification. Interfaces stay unchanged, preservation and new review status are explicit, and the old apex-plane restriction is replaced by actual clearance evidence. No unresolved material design decision remains.

## Approval handoff and execution endpoint

**Stage 4 approval — revision 2:** The revised specification was separately presented and approved with “approved.” After this revised plan was saved and presented at Stage 3, the user separately replied “approved,” authorizing execution of revision 2 using the preserved native method. This approval includes safe Git preparation, the fresh candidate, verification and sequential final reviews; it does not authorize push, merge, tagging, publication or integration.

**Execution endpoint:** Deliver the verified revised cube-only USDZ, editable sources, comparison previews, instructions and review evidence; report dimensions, results and limitations; stop before further artwork, magnifier or integration. No push, merge, tag or publication is authorized.

## Historical revision-1 evidence

The following retained execution record concerns candidate-002 and revision 1 only. Its numbered steps refer to the earlier plan at `da63a66`, not the unchecked revision-2 steps above. It is preserved verbatim and does not establish revision-2 completion.

## Execution evidence — 2026-10-28

Steps 1–8 are verified. The local refinement branch preserves the completed baseline branch; `main`/`origin/main` remain at `dad53f0`. The refined package is `candidate-002/model.usdz` under the external artwork root, 530,905 bytes, SHA-256 `51e41708c1e2248b344b512101a3026bfa1e18847d9e5be086aa7e828892b7e8`. Matching generator, tests, inspector and instructions are frozen with that candidate.

The initial refinement suite recorded six expected failures against the baseline; all 20 current artwork cases now pass, including invalid geometry and broken-seam controls. Apple USD conversion/package/load checks pass. Model I/O independently confirms 14 meshes, 35,694 triangles, 20 cm bounds, a 71.3 mm pyramid, two 10 mm shelves and reduced positive gaps. Independent baseline-proportion, missing-platform and malformed-input controls are rejected. Validator 0.2.0 exits 0 with complete requested native coverage, no findings or operational errors; no external checker or new full product release run is claimed.

Matched front/rear comparisons and detail crops show the real packaged geometry using unchanged viewing cameras/lights/materials. The Quick Look remote thumbnail succeeded. The assistant observed/captured the actual Quick Look front view; the user freshly answered “Yes, it rotates and looks usable” for this refined candidate. Automated rotation was not established, and the configuration/accessibility/capture issues remain recorded rather than reported as fixed.

Protected baseline/reference/evidence checks and all five private-original hashes pass. Earlier receipts/manifests and the original approved pair remain unchanged. New evidence is in `evidence/refinement-2026-10-28-001/`; no private assets were copied into the model or distributed.

**Execution ruling:** The frame uses a subdivided exposed union boundary rather than separate beam caps, producing one continuous closed surface with coherent joins. Its 4.5 mm support radius describes construction rather than a constant circular fillet; visual inspection checks the resulting softness. Pyramid/slab rounding follows the planned geometry treatment. Nominal frame-plane clearances in the generator receipt are distinguished from conservative frame triangle-box clearance bounds in the dedicated evidence.

Step 9 documentation and closing checks are verified, but the integrated sequential final review remains pending. The first specification review returned BLOCKED because the task-done helper marked Task 1 complete while Step 9 remained unchecked. That completion marker was retracted; Task 1 remains in progress until the review and closure finish. The original sealed package, ledger and report are preserved in `evidence/refinement-2026-10-28-001/final-review-blocked/`. The quality reviewer was not dispatched, and no review PASS or increment-completion claim is made. A fresh review package with consistent execution status is required. No push, merge, tag, publication or product integration was performed.

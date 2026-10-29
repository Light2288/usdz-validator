# Branding and layered-cube example — specification

**Stage:** 4 — implementation authorized
**Slug:** `branding-and-layered-cube-example`
**Type:** chore
**Status:** APPROVED
**Created:** 2026-10-29
**Updated:** 2026-10-29

**Paired plan basename:** `2026-10-29-branding-and-layered-cube-example.md`

**Provenance:** The user confirmed the asset structure, README branding, and documented validation example in point 3 of their scope-confirmation message. Native clarification selected the repository’s MIT license for the PNG, USDZ, and USDA assets. Artifact lookup found no existing specification or plan for this slug. The complete DRAFT was presented in chat in Plan mode on 2026-10-29. The user then left Plan mode and sent “PLEASE IMPLEMENT THIS PLAN” with that complete specification; under the supplied AGENTS.md approval interpretation, this explicitly approves the presented specification and authorizes Stage 3 planning only. It does not approve an implementation plan that has not yet been presented.

**Storage:** Both separately approved artifacts are saved and committed on the implementation branch. The matching plan records verification and final-review status.

## Purpose and delivery boundary

The repository currently provides CLI/library documentation and small validation fixtures, but no project logo or visible example model.

This increment adds the project illustration and an existing logo-derived model, then connects them through a documented validation example. It establishes canonical assets and evidence that the personal website can reuse later.

The model is a procedural interpretation of the illustration’s cube and internal shapes. It omits the magnifying glass and exterior glow. This increment integrates the accepted candidate without changing its geometry or materials.

The principal verification is that the copied model remains identical to candidate-003 and produces the documented report with the repository’s release executable.

## Assets and documentation

Use this structure:

```text
assets/
  branding/
    usdz-validator.png

Examples/
  layered-cube/
    README.md
    model.usdz
    validation.json
    source/
      model.usda
```

Copy the original PNG from `/Users/davide/Downloads/Magnifying Glass Over Blue Layered Cube.png`.

Copy `model.usdz` and `model.usda` from `/Users/davide/Personal/Images/usdz-validator/cube-model/candidate-003/`.

Preserve all original external files. Do not copy intermediate USDC files, previous candidates, inspection executables, screenshots, or the historical evidence collection.

The main README will:

- Display the PNG above the existing title, approximately 220 pixels wide, preserving its aspect ratio and transparency.
- Retain the existing general project information.
- Add a concise example section explaining the logo-to-model connection and linking to the example, model, source, and saved report.
- Preserve the distinction between the original geometry-free fixture and this visible model.

The example README will explain the illustration’s role, procedural reconstruction, cube-only boundary, editable source, package contents, MIT terms, and validation limitations. It will record source provenance, file hashes, observed packaging-tool identity, validator version, and the policy used.

Document this command from the repository root:

```sh
.build/release/usdz-validator validate Examples/layered-cube/model.usdz --format json
```

The saved report must be actual CLI output under the default native policy. Keep the existing report schema unchanged; place explanatory metadata in the example README.

## Acceptance criteria

- **AC-01 — Asset integrity:** The committed PNG, USDZ, and USDA are byte-identical to their selected sources. The USDZ remains 530,905 bytes with SHA-256 `89ee36e574d27275387367e67199a24ab7b4d356325f2b5f1fdfa60f1f2297a3`. All three hashes are recorded in the example documentation.
- **AC-02 — README branding:** The logo appears above the existing title, has descriptive alternative text, and remains readable on light and dark backgrounds without dominating the introduction.
- **AC-03 — Discoverable example:** The main README links to the example. Its documentation identifies the cube-only reconstruction, omitted magnifier, editable source, and reproduction command without implying that model generation is a validator feature.
- **AC-04 — Observed validation:** The release executable accepts the committed model with exit `0`, empty stderr, complete requested native coverage, no native findings, and no operational errors. The external checker remains unrequested. Its JSON output matches `validation.json` exactly.
- **AC-05 — Provenance and licensing:** Documentation records actual asset identities, creation/packaging provenance, validation version and policy, and application of the repository’s MIT license. It contains no required links to private local paths.
- **AC-06 — Accurate claims:** Documentation distinguishes packaging/reference/budget acceptance from geometry, visual quality, USD conformance, security certification, and renderer compatibility. It notes that this model contains no textures or external dependencies.
- **AC-07 — Preserved boundaries:** Existing product behavior, interfaces, schemas, dependencies, fixtures, release records, and external artwork remain unchanged.

## Verification and constraints

Verify source/copy hashes, the package’s single `model.usdc` entry, JSON schema compatibility, exact report reproduction, documentation links, README presentation, and whitespace integrity. Run the existing documented-example verifier to detect regressions in existing examples.

Use focused checks for this documentation-and-assets change. Do not introduce an automated sample-verification system or rerun the full release matrix solely for this increment.

The public example includes editable USDA, but does not promise a distributed procedural generation pipeline. Historical geometry and viewer evidence must be attributed as earlier observations unless freshly repeated.

No new product APIs, configuration, or runtime dependencies are introduced.

Deferred work includes website changes, GLB conversion, browser viewing, blog authoring, AR enhancements, budget-failure demonstrations, automated sample monitoring, artwork refinement, and publication.

## Approval and execution endpoint

Scope/design confirmation and separate specification approval are recorded in Provenance. The matching [implementation plan](../plans/2026-10-29-branding-and-layered-cube-example.md) was subsequently presented in full at Stage 3. The user then separately sent “PLEASE IMPLEMENT THIS PLAN” with that implementation plan, authorizing Stage 4. Native execution was selected through the native clarification control. Both artifacts are saved before implementation begins.

The earlier specification approval authorized Stage 3 planning only; the later, separate plan approval now authorizes implementation of this approved increment. Neither approval authorizes push, merge, publication, or website work.

Keep artifacts uncommitted until the approved Git workflow creates the implementation branch. Preserve existing work; do not push or merge.

**Execution endpoint:** Integrate the agreed assets, README branding, and documented example; complete focused verification and required review; commit on the authorized implementation branch; report results and limitations; stop before website work or another increment.

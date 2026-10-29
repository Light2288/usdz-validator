# Branding and layered-cube example — Implementation Plan

> **For agentic workers:** Use `personal-workflows:spec-implement` with the selected `superpowers:executing-plans` workflow. Steps use checkboxes for tracking.

**Goal:** Add the project logo and accepted cube model as a documented, reproducible validation example.

**Architecture:** Copy the existing artwork without modification, capture an actual native validation report, and connect the assets through the main and example READMEs. Product code and existing verification tooling remain unchanged.

**Tech Stack:** Markdown/HTML, existing Swift CLI, existing Python schema tools, bundled Pillow for visual checks.

**Spec:** [Approved specification](../specs/2026-10-29-branding-and-layered-cube-example.md)

**Slug:** `branding-and-layered-cube-example`
**Created:** 2026-10-29
**Updated:** 2026-10-29
**Status:** APPROVED
**Execution method:** Native, selected through native clarification
**Execution tier:** full
**Implementation model role:** full

Full tier is selected because documentation and visual assessment require judgment. Native execution does not switch the parent model.

**Location:** `docs/superpowers/plans/2026-10-29-branding-and-layered-cube-example.md`

**Provenance and approval:** The specification was separately approved by the user's earlier “PLEASE IMPLEMENT THIS PLAN” message containing the complete DRAFT specification. This implementation plan was then presented separately in full at Stage 3. The user subsequently left Plan mode and sent another “PLEASE IMPLEMENT THIS PLAN” message containing this implementation plan, explicitly approving it and authorizing Stage 4. Native execution was selected through the native clarification control. Saving changes only storage, lifecycle, and approval metadata from the presented plan; its scope and task requirements are preserved.

**Storage:** Saved locally before implementation. Keep both approved artifacts uncommitted until the implementation branch is prepared.

## Global constraints

- Use the exact asset structure in the approved specification; preserve source bytes and all external originals.
- Apply MIT to the PNG, USDZ, and USDA.
- Preserve general README information and existing product behavior, interfaces, schemas, dependencies, fixtures, and release records.
- Keep the model cube-only, with its current geometry and materials.
- Use focused verification; add no automated sample-verification system.
- Defer website work, conversion, browser viewing, artwork changes, and publication.
- Work in the existing checkout. After plan approval, safely update `main` and create `chore/branding-and-layered-cube-example`.
- Preserve the existing artwork branch. Do not push or merge.

## Review focus

These conditions are covered by the task’s verification:

1. Source files have changed since inspection: compare against the recorded hashes before copying.
2. A saved report is stale or hand-edited: reproduce it and require exact output equality.
3. Transparency makes the logo unreadable: inspect it at 220 pixels on light and dark backgrounds.
4. Public documentation depends on private filesystem paths: check relative links and inspect the example’s provenance text.
5. Report acceptance is presented as geometry or renderer certification: review wording and the absence of textures/external dependencies.

## Task 1: Integrate branding and the documented example [size: M | risk: none | mechanical: false | clear_pattern: true | objectively_verifiable: false | concerns: none]

**Acceptance criteria:** AC-01, AC-02, AC-03, AC-04, AC-05, AC-06, AC-07.

**Files:** The approved specification/plan pair, main README, logo PNG, and the four files under the approved layered-cube example directory.

**Interfaces:** Consume the approved external PNG, candidate-003 USDZ/USDA, and existing CLI/report contract. Produce canonical repository assets and documentation; introduce no public API changes.

- [x] **1. Save the approved plan and record approval evidence.**
  Preserve the presented scope, filenames, and creation dates. Update lifecycle prose in the specification to identify the separately approved plan.
  **Expected:** Both approved artifacts exist before implementation begins.

- [x] **2. Prepare the implementation branch safely.**
  Record the starting branch and commit. Preserve the approved artifacts with a scoped stash if necessary, fetch `origin`, switch to `main`, update only by fast-forward, and create `chore/branding-and-layered-cube-example`. Restore the exact preserved artifacts. Retain the existing artwork branch and unrelated local changes.
  **Expected:** A new branch based on safely updated `main`, with both approved artifacts intact. A non-fast-forward update or conflicting work remains unresolved rather than overwritten.

- [x] **3. Commit the approved workflow pair.**
  Commit only those two artifacts with `docs: record branding and layered cube example plan`.
  **Expected:** Approved scope and plan are recorded on the implementation branch.

- [x] **4. Verify source identities before copying.**
  Recheck these observed SHA-256 values:

  | Asset | SHA-256 |
  |---|---|
  | PNG | `74723d5ddd7017e0943882a3c9b35ef3aca4b137244007aaabbe4bc2804a256b` |
  | USDZ | `89ee36e574d27275387367e67199a24ab7b4d356325f2b5f1fdfa60f1f2297a3` |
  | USDA | `802c1a05ee68ecc5fc5c1b716a19a5dd1e2a69161bd512a10da981dd1e8ca1c3` |

  **Expected:** All match; the USDZ remains 530,905 bytes. Record an inventory of the external originals for the closing preservation check.

- [x] **5. Copy the three approved assets.**
  Create their specified destinations and copy without transformation. Copy no intermediate files or historical evidence collection.
  **Expected:** Source and destination hashes match exactly.

- [x] **6. Build the release executable.**

  ```sh
  swift build -c release --product usdz-validator
  ```

  **Expected:** Exit `0`; the executable is available. Record its reported version.

- [x] **7. Capture the actual report.**

  ```sh
  .build/release/usdz-validator validate Examples/layered-cube/model.usdz --format json --output Examples/layered-cube/validation.json
  ```

  **Expected:** Exit `0`, empty stdout/stderr, and one JSON report. Require complete requested native coverage, no native findings or operational errors, and an unrequested external checker.

- [x] **8. Write the example README.**
  Explain the illustration-to-model connection, procedural reconstruction, omitted magnifier, editable source, single-entry package, and MIT terms. Record all three hashes, the observed validator version/default policy, and historical packaging provenance: Python generation followed by Apple USD Tools 0.25.11 conversion and packaging. Attribute prior geometry/viewer checks as historical observations.
  Include the specification’s exact stdout reproduction command and relative links to the logo, model, source, report, and license. State that the example contains no textures or external dependencies.
  **Expected:** Readers can inspect, download, and validate the example without private filesystem links or a promised generation pipeline.

- [x] **9. Update the main README.**
  Place the logo above the existing title using an HTML image with `width="220"` and descriptive alternative text. Add “Logo-derived 3D example” after “Build and run,” linking to the example, model, source, and report. Extend the licensing sentence to include the artwork/example. Retain the existing information and geometry-free fixture distinction.
  **Expected:** Branding and the example are discoverable without implying new validator capabilities.

- [x] **10. Verify report reproduction and package integrity.**
  Run the documented stdout command, compare its bytes with the saved report, and parse it using the existing strict JSON-document helper in `Scripts/verify-examples.py`. Check the required fields, version, input size, default policy, and absence of sensitive details. Independently inspect the ZIP inventory.
  **Expected:** Exact report equality, empty stderr, exit `0`, and exactly one stored entry named `model.usdc`.

- [x] **11. Run existing compatibility checks.**
  Copy the saved report into a dedicated ignored schema directory as `report-layered-cube.json`, keeping other evidence outside that directory.

  ```sh
  .venv/bin/python Scripts/verify-schemas.py --directory .verification/branding-layered-cube/schema --expected-export-count 1
  python3 Scripts/verify-examples.py --executable .build/release/usdz-validator
  git diff --check
  ```

  **Expected:** The current 21-document schema corpus plus the new report validates locally; all five existing documented commands pass; no whitespace errors. Do not modify schema manifests or existing verifiers.

- [x] **12. Check documentation presentation and preservation.**
  Use the existing `verify_links()` helper for both READMEs and workflow artifacts; separately verify the HTML image target. Use bundled Pillow to create scratch previews of the copied PNG at 220 pixels on white and dark backgrounds, then inspect them with the image viewer. Review the surrounding README text and all scope/coverage claims. Recheck external source identities and the changed-file allowlist.
  **Expected:** Readable logo, working links, accurate claims, unchanged originals, and only the approved files changed.

- [x] **13. Commit the implementation.**
  Commit the six branding/example files with `docs: add logo and layered cube validation example`. Record focused verification in the execution ledger.
  **Expected:** Implementation task complete; overall increment remains pending final review.

## Final review and delivery

At the native workflow’s final-review boundary, invoke `personal-workflows:code-review` exactly once in integrated mode: specification review first, then quality review after specification passes. Supply the approved pair, complete branch diff, asset identities, report comparison, schema/example results, visual previews, and preservation evidence.

Resolve blocking findings within the approved scope and refresh affected checks. Preserve review receipts before scratch cleanup. Record final closure only after the review gate passes; commit any resulting workflow-status changes.

**Execution endpoint:** Deliver the committed branding and example with verification/review evidence, report limitations and the working command, and stop with the branch local. No push, merge, or website work.

## Evidence, assumptions, and approval

Planning inspected HEAD `0d11f4883635ae1f3819c1c3eea18490a4528271`. No architecture map or ADR set was found; none will be generated. Commands and helper behavior come from the README, CLI documentation, offline-tools documentation, and existing verification scripts.

Observed planning checks: the model passed default native validation; all five documented examples passed; the current 21-document schema corpus passed. Bundled Pillow is available for scratch visual previews. These observations do not replace post-change verification.

Self-review found AC-01–AC-07 covered by the task and final gate. No unresolved design decisions remain.

**Current stage:** 4 — separately approved specification and plan saved; implementation authorized. The latest user message explicitly approves this presented plan. No push, merge, publication, or website work is authorized.

## Execution evidence — 2026-10-29

Task 1 implementation is complete; the increment remains in progress pending the integrated final review. Steps 1–13 are verified. The existing checkout was safely branched from up-to-date main at `dad53f0e5c2853424db3e91c7de234083d409209`; the prior artwork branch at `0d11f4883635ae1f3819c1c3eea18490a4528271` is preserved. Approved artifact commit: `8a1c9d3`. Implementation commit: `e0ade79e033758842f0d366c78ab81cdce99df6a`. The approved-artifact stash is retained as `5fa257c03868d00c6bdb96016066fdcb3464d553`.

All three copied assets match the pinned source hashes. Fourteen protected external files retain their initial identities. Release build passed; validator 0.2.0 captured the saved report with exit 0 and empty stdout/stderr. A separate stdout run matched its bytes exactly, with complete requested native coverage, no native findings or operational errors, and the external checker unrequested. The package contains only stored `model.usdc`. Offline schema verification accepted 22 documents; all five existing documented commands passed. Both READMEs and both workflow artifacts passed link checks; the HTML image target exists. Local 220px logo compositions were inspected on white and dark backgrounds and remain readable above the original title/intro; this does not claim a hosted GitHub render. Removing the approved README additions and license expansion restores the baseline README exactly. The eight-file change allowlist passed. No runtime code, test code, schema, dependency, fixture, release record, or website file changed.

Focused verification evidence is retained locally under `.verification/branding-layered-cube/`. Final review remains pending; no increment completion or review PASS is claimed here.

# README Restructuring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Enter through `personal-workflows:spec-implement`; native execution is recommended for this single documentation task, pending user choice.

**Goal:** Restructure the entire root README with a branded opening and clear technical navigation while preserving its substantive facts and contracts.

**Architecture:** Edit only the root README, reusing the existing project illustration and existing canonical guides. Keep the current onboarding/library examples and inbound heading anchors; group dense material into coherent sections without changing product behavior.

**Tech Stack:** GitHub-compatible Markdown/HTML, conventional Shields.io badges, existing Swift release executable, existing Python documented-example verifier.

**Spec:** [Approved README restructuring specification](../specs/2026-11-05-readme-restructure.md)

**Slug:** `readme-restructure`
**Created:** 2026-11-05
**Updated:** 2026-11-05
**Status:** APPROVED
**Execution tier:** full
**Implementation model role:** full
**Execution method:** Native, approved at the Stage 3 handoff.
**Provenance:** The Stage 1 proposal and saved Stage 2 specification each received a separate “approved” reply in this chat. This saved plan was then presented at Stage 3 with the question “Do you approve the plan and this execution method?” and a recommendation of native execution; the user separately replied “approved”, authorizing Stage 4 implementation, verification, review, and local commits.

Full tier is selected because editorial preservation and presentation require judgment: this task is not wholly mechanical or objectively verifiable. Native execution retains the current parent model; no model switch or savings is claimed.

## Global Constraints

- One centered H1: `USDZ Validation Kit`, with no emoji. Use plain section headings without decorative emoji.
- Reuse `assets/branding/usdz-validator.png` at approximately 220 pixels, preserving its bytes, aspect ratio, and descriptive alternative text.
- Preserve substantive README facts and qualifications, existing examples/API usage, MIT attribution, third-party notices, and historical evidence distinctions.
- Retain exact USDC versions `0.8.0`, `0.9.0`, and `0.10.0` with the bounded-subset qualification. Keep native coverage, gate acceptance, and conformance/certification distinct.
- Preserve anchors `build-and-run`, `use-the-library`, `logo-derived-3d-example`, and `verification-and-support-scope`.
- Do not change product code, assets, dependencies, schemas, fixtures, historical records, or documentation outside the root README and this workflow pair.
- Keep both workflow artifacts uncommitted until their separate approvals and implementation branch creation. Use the existing checkout; no worktree, push, merge, or publication.

## Review Focus

1. Images fail to load: project identity, subtitle, badge meaning, and links remain understandable through text/alternative text; inspect the header with images omitted.
2. Badges overstate support or publication: use `Swift tools 6.0` and `MIT` badges with meaningful alternative text and relevant links; compare labels against `Package.swift` and `LICENSE`.
3. Inbound links land incorrectly: retain the existing four headings and keep non-goals within `Verification and support scope`; check inbound fragments and surrounding meaning.
4. Reordering removes qualifications: compare every original paragraph and code block with the result, including the numeric-array charging policy, resource measurements, exclusions, and current/historical evidence distinctions.
5. HTML escapes the Markdown verifier: inspect HTML `src` and `href` targets separately and inspect a rendered preview, including header balance and the existing icon on light/dark backgrounds.

## Repository Evidence and Artifact Resolution

- Planning HEAD: `6a9e488aa75e82bffe31167c3d5e114b08547183`, branch `main`, remote `https://github.com/Light2288/usdz-validator.git`. Only this increment's untracked specification was present at discovery.
- Specification resolution: `NEW_ONLY`, `docs/superpowers/specs/2026-11-05-readme-restructure.md`; explicit Stage 2 approval is recorded above. Plan resolution before creation: `MISSING`; use the specification's exact basename. No legacy same-slug artifacts were found.
- `docs/architecture/map.md` and an ADR set were not found in the inspected repository documentation. Map freshness/recorded HEAD therefore cannot be assessed; do not generate a map during this chore. Key paths `README.md`, `Package.swift`, `LICENSE`, `NOTICE`, `SECURITY.md`, `assets/branding/usdz-validator.png`, `docs/cli.md`, `docs/inspection-boundary.md`, `docs/report-compatibility.md`, and `Examples/layered-cube/README.md` were inspected or confirmed by existing links.
- `README.md` is the content-preservation baseline. `Package.swift` declares Swift tools/language 6, macOS 15, the library/CLI products, and Argument Parser 1.5.0; those declarations do not establish verified minimum compatibility.
- Build command source: current `README.md`, “Build and run”. Existing verification command and exact expected proof line: `Scripts/verify-examples.py`, also documented in the README and `docs/cli.md`. The verifier checks five native commands, outputs, defaults, profile IDs, and Markdown links, but not HTML attributes.
- `git diff --check`, the helper-based link procedure, and scratch light/dark icon inspection follow the existing `2026-10-29-branding-and-layered-cube-example.md` plan. No new permanent test or verification tool is needed for this editorial change.
- Canonical technical references: `docs/cli.md`, `docs/inspection-boundary.md`, `docs/report-compatibility.md`, `docs/verification/usdc-numeric-v0-2.md`, `CHANGELOG.md`, and `SECURITY.md`. No material product-design decision remains unresolved. Execution-method choice is deferred to the plan handoff and does not change this task's scope.

## Task 1: Restructure and verify the complete README [size: M | risk: none | mechanical: false | clear_pattern: true | objectively_verifiable: false | concerns: none]

**Acceptance criteria:** AC-01, AC-02, AC-03, AC-04, AC-05, AC-06, AC-07, AC-08.

**Files:** Modify `README.md`; maintain lifecycle/approval/completion records only in this specification/plan pair. Read existing assets, guides, and verifier without modifying them.

**Interfaces:** Consume the approved specification, original README content, existing logo and local documentation targets, and `.build/release/usdz-validator`. Produce one GitHub-compatible README retaining its existing heading-anchor and example contracts. Introduce no runtime interface.

- [ ] **Step 1: Confirm separate approvals and prepare the branch.** Record the messages approving the specification and this plan, plus the selected execution method. Recheck checkout status. Preserve local work and both workflow artifacts, fetch `origin`, update `main` only by fast-forward when possible, and create `docs/readme-restructure`. Never discard work or force an update; resolve any conflicting upstream change before proceeding. Record the resulting branch base and preserve its README as the comparison baseline. If upstream changes materially invalidate the approved scope/plan, return through the applicable approval gate.
  **Expected:** The approved pair exists before implementation; the implementation branch uses safely updated `main` and preserves unrelated work.

- [ ] **Step 2: Commit the approved workflow artifacts.** Mark this plan approved only from its separate approval message; retain the original creation dates, shared slug, and specification reference. Commit only the pair with `docs: record README restructuring specification and plan`.
  **Expected:** Both approved artifacts are recorded on the implementation branch before the README changes.

- [ ] **Step 3: Build the branded opening.** Keep the existing image/alternative text and use a centered HTML H1. Add a concise subtitle, two linked badges labeled `Swift tools 6.0` and `MIT`, and centered quick links to the CLI guide, inspection boundary, library section, and example section. Point the Swift tools badge to `Package.swift` and MIT badge to `LICENSE`. Follow the supplied reference READMEs' compatible HTML style.
  **Expected:** AC-01 is met; the opening communicates identity without claiming release publication or a verified minimum platform.

- [ ] **Step 4: Reorganize the entire body.** Use the specification's reading order: About, Features, Build and run, Use the library, Logo-derived 3D example, Documentation, Verification and support scope, Release history, Security, License. Use subsections for verification evidence, inspection limits, and exclusions; retain the existing anchors by preserving their headings. Make the documentation index a compact table or list of existing guides. Keep the core acceptance limitation near the top.
  **Expected:** Readers can move from overview to first use and then detailed evidence. All original substantive information, examples, pinned dependencies/notices, support qualifications, and artwork distinctions remain represented.

- [ ] **Step 5: Check content preservation and the five review-focus conditions.** Compare the baseline and revised README paragraph by paragraph and compare all fenced code blocks for unchanged commands/API usage. Check feature and badge claims against the cited canonical files; verify the current-host/intended-host and current/historical evidence distinctions. Confirm license/security links and copyright wording. Inspect the HTML header as text with image content omitted. Check inbound README fragments from the CLI, security, inspection-boundary, changelog, and example documents; keep historical line citations untouched.
  **Expected:** AC-02 through AC-07 are met with no lost qualification, misleading badge, broken heading destination, or contract change. Record the comparison evidence in scratch space for final review.

- [ ] **Step 6: Run existing build and example checks.** From the repository root:

  ```sh
  swift build -c release --product usdz-validator
  python3 Scripts/verify-examples.py --executable .build/release/usdz-validator
  git diff --check
  ```

  **Expected:** All commands exit `0`; the release executable is built; the verifier prints `PASS: 5 documented native commands; exact examples, defaults, profile IDs, and local links`; the whitespace check produces no errors. Record exact commands, exit statuses, and decisive output. The README may retain broader development test commands without rerunning the entire release matrix for this editorial change.

- [ ] **Step 7: Check links, rendering, and scope.** Reuse `verify_links()` from `Scripts/verify-examples.py` for the workflow pair and README, then separately inspect HTML attributes: resolve local `src`/`href` paths and fragments; check Shields.io image URLs and their badge labels/alternative text. Inspect a rendered Markdown preview using available local tooling with temporary outputs kept in scratch space, including heading hierarchy, lists/tables, code blocks, header balance, and icon readability on light/dark backgrounds. Report any unavailable rendering or remote-image checks explicitly; source inspection alone must not be reported as observed rendering. Check the complete changed-file list against the three-file allowlist.
  **Expected:** Working local destinations and preserved anchors, appropriate GitHub-compatible presentation, unchanged artwork, and changes limited to `README.md` and the approved pair. No new permanent tests, dependency setup, or generated repository artifacts.

- [ ] **Step 8: Commit the verified README.** Commit only `README.md` with `docs: restructure project README`; preserve the validation evidence for final review.
  **Expected:** The documentation change is committed locally and ready for the required final review; completion is not yet claimed.

## Criterion Traceability

| Criteria | Task 1 implementation and evidence |
| --- | --- |
| AC-01 | Steps 3, 5, 7: branded opening, truthful badges, alternative text, rendered header |
| AC-02 | Steps 4, 5, 7: complete organization, content comparison, presentation |
| AC-03, AC-05 | Steps 4–5: canonical-reference and qualification/evidence comparison |
| AC-04 | Steps 4–6: preserved code blocks/contracts, release build and five example checks |
| AC-06 | Steps 3–7: retained headings, inbound fragments, Markdown/HTML destinations |
| AC-07 | Steps 4–5, 7: attribution, original/third-party distinction, license/security links |
| AC-08 | Steps 1–2, 5–8 and final gate: scope, verification, recorded evidence, review, local commits |

## Final Review and Delivery

At the selected execution workflow's whole-branch review boundary, invoke `personal-workflows:code-review` once in integrated mode as the sole final review seat. Supply the approved pair, complete branch diff and changed-file list, baseline/content comparison, exact verification results, and presentation evidence. Run specification review first; run quality review only after specification review passes, following the adapter's package identity/hash contract. Handle findings within the enclosing workflow's fix-loop policy and rerun only affected checks.

Record observed verification and review outcomes in this plan's execution record, preserve review receipts, and commit completion metadata after the gate passes. Report the README result, verification, limitations, local branch/commits, and any unobserved checks. Do not push or merge or start later documentation work.

**Self-review:** AC-01–AC-08 are assigned to the single coherent task and final gate. All five review-focus conditions have explicit checks; the task has no new function/type/API names to reconcile. Scope, file paths, commands, and expected output are grounded in the approved specification and inspected repository. No implementation or project verification was performed during planning.

**Current stage:** 4 — separate specification and plan approvals received; native implementation is in progress.

**Execution endpoint:** Deliver the approved README restructuring with focused verification and sequential final review completed, commit locally on the implementation branch, report evidence and limitations, and stop before any later increment, push, merge, or publication.

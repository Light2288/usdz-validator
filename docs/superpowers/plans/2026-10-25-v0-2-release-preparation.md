# v0.2 Release Preparation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` for the selected native execution method. Steps use checkbox syntax.

**Slug:** `v0-2-release-preparation`
**Status:** APPROVED
**Created:** 2026-10-25
**Updated:** 2026-10-25
**Execution tier:** full
**Implementation model role:** full
**Execution method:** Native, selected through the interactive control.
**Spec:** [Approved specification](../specs/2026-10-25-v0-2-release-preparation.md)

**Goal:** Prepare accurate, unpublished v0.2 release documentation using retained verification evidence.

**Architecture:** Update the existing changelog and current release-summary section. Preserve historical sections and link to authoritative acceptance and inspection records.

**Tech Stack:** Markdown, existing Python documentation/schema verifiers, retained release executable.

**Provenance:** Approved specification and repository inspection at `79d1aa839c340ed35964cd2438c62bfcbabefe7d`. No existing plan matches this slug. No architecture map or ADRs were found; no architecture artifact will be generated. No legacy artifact is a source.

**Approval record:** The specification was separately approved when the user submitted it with “PLEASE IMPLEMENT THIS PLAN” and was subsequently saved. The user selected native execution through the interactive control. This complete implementation plan was then presented in chat; the user's subsequent, separate “PLEASE IMPLEMENT THIS PLAN” message quoting this plan approves Stage 3 and authorizes Stage 4 implementation. The plan is now saved in Default mode before release-document edits. Specification and plan share basename `2026-10-25-v0-2-release-preparation.md`.

## Global constraints

- Product **0.2.0**, safety envelope **3**, schema major **1**.
- Only release documentation changes; no public API, schema, dependency or runtime changes.
- Preserve unpublished status, historical evidence and recorded support limitations.
- Use the existing checkout and branch `docs/v0-2-release-preparation`, created only after plan approval.
- Keep artifacts uncommitted until that branch exists. Do not push, merge, tag or publish.

## Review focus

The final review will explicitly check these conditions:

1. Supported-subset coverage is not presented as full USD or geometry validation.
2. Earlier strict schemas require updating to accept envelope 3.
3. Current-host PASS does not imply verified deferred environments or publication.
4. Test counts distinguish opt-in skips and dedicated runs; retained results are not described as fresh runs.
5. Historical text, measurements, hashes and review identities remain preserved.

## Task 1: Prepare and verify release documentation [size: S | risk: none | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-01, AC-02, AC-03, AC-04, AC-05, AC-06, AC-07.

**Files:** Modify `CHANGELOG.md` and `docs/verification/release-summary.md`. Save and commit the matching specification/plan pair as workflow artifacts.

**Interfaces:** Consumes existing acceptance records, inspection/compatibility documentation and release policy. Produces release prose and focused verification receipts; no software interface changes.

The full tier reflects the editorial judgment needed to preserve evidence qualifications. This is one cohesive documentation task; no new tests are needed.

- [ ] **Step 1: Prepare the approved branch and artifacts.**

  After approval and return to Default mode, save this plan with its approval record. Recheck repository status, preserve the uncommitted specification and plan, then run:

  ```sh
  git fetch origin
  git merge --ff-only origin/main
  git switch -c docs/v0-2-release-preparation
  ```

  Expected: a dedicated branch without discarded changes. If upstream changes invalidate the plan's evidence, reassess before editing. Commit only the two approved artifacts with `docs: record v0.2 release preparation specification and plan`.

- [ ] **Step 2: Add the unreleased changelog entry.**

  Insert `## 0.2.0 — Unreleased` above v0.1.0. Summarize bounded USDC coverage, private pinned LZ4 metadata decoding, envelope-3 accounting and schema compatibility. Link to the current release summary and acceptance record. Keep the complete existing v0.1.0 entry unchanged.

- [ ] **Step 3: Refine the current release summary.**

  Organize its current opening into concise unreleased notes covering coverage, safety, compatibility and verified results. Include exact admitted versions, unchanged numerical ceilings, retained traversal charges, envelopes 1/2/3 and the earlier-schema caveat.

  Preserve the recorded 19/19 gates, 338-case suite results and skip qualifications, five-original/59-occurrence evidence, resource qualifications, current-host status, deferred environments and unrequested checker status. Preserve the envelope-2 paragraph and all following historical content unchanged.

- [ ] **Step 4: Run focused verification and record its results.**

  Use existing commands from the Makefile and release runner:

  ```sh
  make schemas
  python3 -m unittest discover -s Tests -p 'test_verification_tools.py'
  python3 Scripts/verify-examples.py --executable .build/release/usdz-validator
  git diff --check
  ```

  Expected: successful exits, zero test failures, no skipped verification-tool cases, and the examples verifier's five-command PASS result.

  Also invoke the existing `verify_links(path)` helper from `Scripts/verify-examples.py` on the release summary and both workflow artifacts; the default examples verifier already covers the changelog. Check heading structure and compare the preserved historical portions against the branch baseline.

  Confirm neither changed release document has become manifest-bound. At the inspected revision neither is bound, so no manifest refresh or new exports are required.

  Keep command output in a fresh ignored evidence directory and add a dated documentation-verification note to the current summary. Describe these as focused checks; preserve earlier full-run receipts.

- [ ] **Step 5: Commit and complete the final review.**

  Commit the two release documents with `docs: prepare unreleased v0.2 notes`. Use `personal-workflows:spec-implement` with native execution and its single integrated, sequential specification-then-quality review gate. Include all ACs, the complete diff and observed verification evidence.

  Expected: no unresolved blocking findings. Preserve review receipts before execution-workspace cleanup. Finish with a clean local branch and report commits, checks and any remaining limitations.

## Assumptions and approval state

The retained executable and acceptance evidence remain available; verify their identity before relying on them. Missing evidence must be reported explicitly. Broader testing is warranted only if a new failure or changed input requires it.

This plan has been separately approved and saved. Stage 4 implementation of this documentation scope is authorized. No push, merge, tag or publication is authorized.

# v0.2 Release Finalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` through `personal-workflows:spec-implement`. Steps use checkbox syntax.

**Slug:** `v0-2-release-finalization`
**Status:** APPROVED
**Created:** 2026-10-25
**Updated:** 2026-10-25
**Execution tier:** full
**Implementation model role:** full
**Execution method:** Native, selected through the interactive control.
**Spec:** [Approved specification](../specs/2026-10-25-v0-2-release-finalization.md)

**Goal:** Finalize v0.2 release documentation and prepare a reviewed source release, with publication separately authorized.

**Architecture:** Update the three existing release-facing documents and prepare the GitHub body locally. Bind publication to the reviewed, merged commit and exact release text.

**Tech Stack:** Markdown, existing Python verifiers, Git and GitHub CLI. No API, schema or runtime changes.

**Provenance:** Repository inspection at `0eb2fae2210edd9b733e1a0db21f251f34cdce5c`. No matching plan exists. `docs/architecture/map.md` and ADR directories are absent; none will be generated. No legacy artifact is a source.

**Approval record:** The user separately submitted the complete DRAFT specification with “PLEASE IMPLEMENT THIS PLAN”, approving that specification and authorizing planning only. The user selected native execution through the interactive control. This complete implementation plan was subsequently presented in chat, and the user's later, separate “PLEASE IMPLEMENT THIS PLAN” message quoting this plan approves Stage 3 and authorizes the repository-finalization work in Stage 4. Both approved artifacts are saved before release-document edits. Task 2 remains conditional on explicit publication authorization and a reviewed, merged candidate; this approval authorizes no push, merge, tag creation or publication.

## Global constraints and review focus

- Preserve product **0.2.0**, envelope **3**, schema major **1**, support limits and historical evidence.
- Use the existing checkout and branch `docs/v0-2-release-finalization`; preserve uncommitted artifacts.
- Keep `v0.1.0`. Upload no binaries, private assets or diagnostics.
- Plan approval does **not** authorize push, merge, tag creation or publication.
- Use the Europe/Rome day of finalization as the intended publication date; refresh it before tagging if publication moves.

Final review will check premature publication claims, incorrect tag targets, date drift, expanded support/schema claims, and historical evidence or private-data leakage.

## Task 1: Finalize and review the local release candidate [size: S | risk: none | mechanical: false | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-01–AC-05; AC-07 for repository-phase reporting.

**Files:** Modify `README.md`, `CHANGELOG.md` and `docs/verification/release-summary.md`. Save the matching specification/plan pair.

**Interfaces:** Consumes retained acceptance evidence and release policy. Produces committed documentation, a reviewed release-body file and verification receipts.

The full tier reflects editorial judgment rather than mechanical substitution.

- [ ] **Step 1: Save the approved plan and prepare the branch.**

  After approval and return to Default mode, save this plan with its approval record. Preserve the specification, inspect local changes, then run:

  ```sh
  git fetch origin
  git merge --ff-only origin/main
  git switch -c docs/v0-2-release-finalization
  ```

  Expected: a dedicated branch without discarded changes. Reassess any upstream changes affecting the approved scope. Commit the two approved artifacts with `docs: record v0.2 release finalization specification and plan`.

- [ ] **Step 2: Finalize dates and publication-neutral wording.**

  Record the intended publication day. Replace the current v0.2 `Unreleased` headings with that date and update affected links.

  Replace current “local and unpublished” statements with neutral release-documentation wording and a link to GitHub's release listing. Do not claim publication before it occurs. Preserve historical snapshot statements, verification dates, support qualifications and the existing v0.1/envelope-2 sections.

- [ ] **Step 3: Prepare the release body.**

  Save `release-notes.md` in a fresh ignored evidence directory, initially `.build/verification/v0-2-release-finalization-2026-10-25/`; preserve any existing directory and use a fresh sibling.

  Prepare the title **“USDZ Validation Kit v0.2.0”** and concise notes covering bounded USDC inspection, envelope-3 accounting, schema compatibility, retained verification and remaining limits.

  Link to public documentation under `blob/v0.2.0/`. Validate those document paths against the candidate tree before tagging. Include no local paths or private diagnostics. Record the body's SHA-256 and include its exact contents in the final review package.

- [ ] **Step 4: Run focused verification.**

  Commands come from the Makefile and existing release runner:

  ```sh
  make schemas
  python3 -m unittest discover -s Tests -p 'test_verification_tools.py'
  python3 Scripts/verify-examples.py --executable .build/release/usdz-validator
  git diff --check
  ```

  Expected: successful exits, zero failures, no skipped verification-tool cases, and five documented commands PASS.

  Use the existing `verify_links(path)` helper for the release summary and workflow artifacts. Check headings, changed anchors, dates, publication wording, release-body consistency and preserved historical bytes.

  Recheck retained operational-input/executable hashes and manifest membership. None of the three release documents is currently manifest-bound; regenerate exports only if the existing focused-refresh policy requires it. Preserve logs in the new evidence directory without claiming another full release run.

- [ ] **Step 5: Commit and review the repository phase.**

  Commit the three release documents with `docs: finalize v0.2 release documentation`. Run the required integrated specification-then-quality review over the branch and exact local release body.

  Expected: no unresolved blocking findings and a clean local branch. Report the reviewed commit, intended date, release-body path/hash and observed checks. Mark publication **pending**, not complete. Wait for explicit push/merge and publication authorization.

## Task 2: Publish the reviewed release after authorization [size: S | risk: other | mechanical: true | clear_pattern: true | objectively_verifiable: true | concerns: none]

**Acceptance criteria:** AC-02–AC-07.

**Risk:** Publication creates public version identifiers that may be immutable.

**Interfaces:** Consumes Task 1's reviewed documents/body and an explicitly authorized, merged `main` candidate. Produces the remote tag, regular GitHub release and publication receipt.

- [ ] **Step 1: Verify publication prerequisites.**

  Proceed only after the documentation is merged and the user explicitly authorizes tagging and publishing.

  Record the exact remote `main` commit as `release_candidate_commit` and the reviewed body path as `release_body_file`. Confirm its tree matches the reviewed candidate, retained operational identities still match, and the body hash is unchanged.

  Recheck the Europe/Rome date immediately before publication. If the date changes, return to document/date/link verification and review before tagging. Inspect existing local/remote tags and releases; report conflicts without overwriting them.

- [ ] **Step 2: Create the tag and regular release.**

  Using the verified values:

  ```sh
  git tag -a v0.2.0 "$release_candidate_commit" -m "USDZ Validation Kit v0.2.0"
  git push origin refs/tags/v0.2.0
  gh release create v0.2.0 --verify-tag --latest \
    --title "USDZ Validation Kit v0.2.0" \
    --notes-file "$release_body_file"
  ```

  These commands follow the installed Git/GitHub CLI help. No draft, prerelease or asset-upload arguments are used. If an operation partially succeeds, inspect and report the actual state; retain any correct tag and never recreate or retarget it blindly.

- [ ] **Step 3: Verify publication and report completion.**

  ```sh
  git ls-remote --tags origin 'refs/tags/v0.2.0' 'refs/tags/v0.2.0^{}'
  gh release view v0.2.0 --json tagName,name,isDraft,isPrerelease,publishedAt,body,assets,url
  ```

  Expected: the peeled tag points to the approved candidate; the title/body match; `isDraft` and `isPrerelease` are false; publication time is present; uploaded `assets` is empty. Confirm version-pinned public documentation links work and `v0.1.0` remains available.

  Save the observed publication receipt and report the release URL. Only then mark publication complete.

## Traceability and approval state

| Criteria | Task 1 | Task 2 |
|---|---|---|
| AC-01 | Finalize wording and links | — |
| AC-02 | Record intended date | Recheck before publication |
| AC-03 | Preserve contracts and limits | Verify candidate identity |
| AC-04 | Review and hash release body | Publish exact body |
| AC-05 | Focused checks and receipts | Candidate/date/hash checks |
| AC-06 | Prepare guarded procedure | Authorized tag and release |
| AC-07 | Report publication pending | Verify and report publication |

The plan has been separately approved and saved. Repository-finalization work is authorized. Push, merge, tagging and publication still require their separate explicit authorization.

# v0.2 release finalization — specification

**Slug:** `v0-2-release-finalization`
**Type:** chore
**Status:** APPROVED
**Created:** 2026-10-25
**Updated:** 2026-10-25

**Paired plan basename:** `2026-10-25-v0-2-release-finalization.md`

**Provenance:** The user approved the release-finalization scope, then selected the publication-date policy through the interactive control. Repository evidence: `README.md`, `CHANGELOG.md`, `docs/verification/release-summary.md` and `docs/releasing.md`, inspected on clean `main` at `0eb2fae2210edd9b733e1a0db21f251f34cdce5c`. The DRAFT specification was presented in chat while Plan mode prohibited saving it. The user subsequently submitted that complete specification with “PLEASE IMPLEMENT THIS PLAN”; under the mandatory separate-gate workflow, this approves the specification and authorizes Stage 3 implementation planning only. No legacy artifact is a source.

## Problem and current behavior

The v0.2 implementation and release-preparation documentation are merged. Current documentation still labels v0.2.0 unreleased or unpublished. No `v0.2.0` tag or GitHub release exists.

Product version is already **0.2.0**, safety envelope is **3**, and schema major remains **1**. Accepted runtime evidence and completed reviews remain available; publication does not require new product functionality.

## Desired outcome and approach

Finalize the existing release documentation and prepare reviewable GitHub release text. After the documentation is merged and publication is separately authorized, publish a regular source release.

Reuse the README, changelog and release summary. Prepare the GitHub body from their current v0.2 content without introducing another maintained release-notes document.

The distribution follows v0.1: source archives, with **no attached binaries or private Apple assets**.

## Acceptance criteria

- **AC-01 — Consistent release documentation:** Finalize v0.2 date/status wording in the README, changelog and current release-summary section. Update affected heading links. Before actual publication, use wording that does not falsely claim the release is already published.
- **AC-02 — Publication-date policy:** Use the intended publication date in v0.2 changelog and release-summary headings. If publication is delayed to another day, refresh those dates and affected links before tagging. Preserve original verification dates, historical release dates and artifact creation dates.
- **AC-03 — Preserved contracts and limits:** Keep product 0.2.0, envelope 3, schema major 1, exact USDC-version support, package-local boundaries, numeric-body exclusions and earlier-schema compatibility guidance unchanged. Preserve current-host support qualifications, `currentHostStatus: PASS`, `releaseStatus: UNVERIFIED`, deferred environments and unrequested checker status.
- **AC-04 — Reviewable GitHub text:** Prepare a locally saved release body for **“USDZ Validation Kit v0.2.0”**. Summarize the USDC improvement, compatibility implications, retained verification and remaining limits. Link to public documentation at the intended version tag; do not expose local evidence paths or private diagnostics.
- **AC-05 — Focused verification:** Check changed-document links, headings, whitespace, release-text consistency and historical-content preservation. Recheck manifest membership and retained source/executable identity. Apply the existing focused-refresh policy if necessary. Clearly distinguish fresh documentation checks from retained runtime/private-corpus results; do not fabricate another full release run.
- **AC-06 — Publication safeguards:** After explicit publication authorization, create `v0.2.0` at the reviewed, merged `main` commit and publish a regular, non-prerelease GitHub release using the approved text. Recheck the candidate and date immediately beforehand. An existing tag or conflicting release must be inspected and reported; never silently retarget or overwrite it.
- **AC-07 — Honest completion:** Report repository finalization and publication separately. Publication is complete only after verifying the remote tag target, public release state, body and absence of uploaded binaries/private assets. Preserve `v0.1.0` and all prior acceptance/review receipts.

## Constraints and exclusions

No product code, tests, schemas, dependencies, numerical ceilings or public interfaces change. No version bump, binary packaging, new platform support, new Apple-compatibility claim or private-asset redistribution is included.

Push, merge, tag and publication remain subject to separate explicit authorization. Earlier specification or plan approval must not be represented as permission for these external actions.

If the publication candidate's operational inputs change, the retained evidence must be reassessed before publication.

## Approval state

The specification is separately approved and saved. Approval authorizes Stage 3 implementation planning only. A matching-name implementation plan must be presented and explicitly approved before release-document changes begin. Keep this specification uncommitted until plan approval permits creating the implementation branch. No push, merge, tag or publication is authorized by this specification approval.

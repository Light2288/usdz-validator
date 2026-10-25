# v0.2 release preparation — specification

**Slug:** `v0-2-release-preparation`
**Type:** chore
**Status:** APPROVED
**Created:** 2026-10-25
**Updated:** 2026-10-25

**Paired plan basename:** `2026-10-25-v0-2-release-preparation.md`

**Provenance:** User-approved Stage 1 documentation scope; repository evidence from `CHANGELOG.md`, `docs/verification/release-summary.md`, `docs/verification/usdc-numeric-v0-2.md` and `docs/releasing.md`. The user's “approved” confirmed scope and authorized the DRAFT specification. The DRAFT was presented in chat while Plan mode prohibited saving it. The user subsequently submitted that complete specification with “PLEASE IMPLEMENT THIS PLAN”; under the mandatory separate-gate workflow, this approves the presented specification and authorizes Stage 3 planning only. No separate implementation plan has been presented or approved, and no implementation gate is waived. No legacy artifact is a source.

## Problem and current behavior

The v0.2 implementation is merged into `main`, but the changelog contains only v0.1.0. The existing release summary records v0.2 verification alongside historical evidence; it needs a concise account suitable for release preparation.

Product version is already **0.2.0**, safety envelope is **3**, and schema major remains **1**. The version remains **local and unpublished**.

## Desired outcome and approach

Add an unreleased changelog entry and refine the current section of the existing release summary so maintainers and prospective users can understand the changes, compatibility implications and verified limits.

The approved approach reuses those two documents. This keeps release information connected to its evidence and avoids maintaining a separate release-notes document. Publication remains a separate maintainer action.

## Acceptance criteria

- **AC-01 — Unreleased changelog:** Add `0.2.0 — Unreleased` above the existing v0.1.0 entry. Preserve the historical entry and its release date.
- **AC-02 — Coverage and boundary:** Describe bounded authored-reference inspection for exact USDC versions **0.8.0, 0.9.0 and 0.10.0**, including private pinned LZ4 metadata decoding. Preserve the package-local, read-only boundary and supported-subset limitations. Complete reference coverage must not imply geometry validation, stage composition or full OpenUSD conformance.
- **AC-03 — Compatibility:** Explain safety envelope **3** and its narrow numeric-array accounting change. State that schema major remains **1**, the current report schema accepts envelopes **1/2/3**, and strict consumers using the earlier `[1,2]` schema must update it.
- **AC-04 — Verified results:** Cite the retained current acceptance record accurately: **19/19 required gates PASS**; **338 cases each** in debug, release and ASAN with zero failures and 11 documented opt-in skips; five private originals with **59 independently reconciled reference occurrences** and complete requested native coverage/default acceptance. Preserve the distinction between suite skips and dedicated runs without skips.
- **AC-05 — Support and status:** Retain `currentHostStatus: PASS`, `releaseStatus: UNVERIFIED` and unpublished status. Limit support claims to the recorded tested environment. Baseline macOS, other hosts, Python 3.12 and cross-host equality remain unverified/deferred under the existing policy. Do not present the unrequested installed-checker smoke as passed.
- **AC-06 — Historical evidence:** Keep v0.1 and envelope-2 observations clearly historical. Preserve earlier receipts, hashes, measurements and review identities; do not rewrite them as new verification or redistribute private Apple assets.
- **AC-07 — Focused verification:** Check changed-document links, Markdown structure, whitespace and consistency with the acceptance record and release policy. Confirm whether affected documents are manifest-bound and follow the existing focused-refresh policy if necessary. Record checks as documentation verification, without representing them as another full release run.

## Constraints and exclusions

Product source, tests, schemas, dependencies, versions and public interfaces remain unchanged. No new fixtures, feature work, tags, push, merge or release publication are included.

The documentation must preserve measured-resource qualifications and make no broader platform, conformance or security guarantees.

## Approval state

The specification is approved and saved. Approval authorizes Stage 3 implementation planning only. A separate matching-name implementation plan must be presented and explicitly approved before implementation. Keep this artifact uncommitted until that approval permits creating the implementation branch, following the user's Git workflow.

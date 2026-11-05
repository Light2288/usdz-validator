# README restructuring

**Slug:** `readme-restructure`
**Type:** chore
**Status:** APPROVED
**Created:** 2026-11-05
**Updated:** 2026-11-05
**Provenance:** User request to restructure the USDZ validator README using `/Users/davide/Personal/Projects/lightstimulus-static-site-nextjs/README.md` and `/Users/davide/Personal/Projects/a11y-journey-evidence/README.md` as references, with no emoji in the title. The Stage 1 scope/design proposal was presented in this chat and the user replied “approved”, authorizing the DRAFT specification only. The saved DRAFT was subsequently presented at Stage 2; the user separately replied “approved”, approving this specification and authorizing implementation planning only.

## Problem and current behavior

The root README already displays `assets/branding/usdz-validator.png` above the project title. Its opening paragraph combines purpose, implementation detail, version-specific coverage, and acceptance limitations. Its final section combines verification commands, compatibility evidence, exclusions, publication status, security, and licensing. Readers must work through dense paragraphs to find capabilities and setup guidance.

The Light Stimulus reference supplies a branded opening with an icon, subtitle, and badges. The A11y Journey Evidence reference supplies a centered title, quick links, concise About/Features sections, and careful separation of onboarding, limitations, and verification. These are structural references; their product claims, artwork, technology choices, and commands do not transfer to this project.

## Desired outcome and delivery boundary

The wider direction is clearer project documentation for the existing local Swift library and CLI. This increment delivers a complete restructuring of the root README, including its opening and all current content, with a coherent path from project overview to first use and detailed evidence.

The work is one bounded documentation chore. There is no material technical uncertainty to resolve; reviewing the resulting document will establish its readability and navigability. The change must preserve technical meaning, qualifications, executable examples, and existing heading links.

Necessary safeguards are factual comparison against the current README and canonical documentation, local link and fragment checks, presentation inspection, and the existing documented-example verification. No new product capability, documentation site, artwork, or release work is included.

## Approach and design

A header-only refresh would improve presentation but leave the dense body identified during review. The confirmed approach restructures the entire README, adapting the branded opening from Light Stimulus and the technical organization from A11y Journey Evidence. The existing icon is reused without modification.

Use this reading order:

1. **Centered opening:** The existing illustration at approximately 220 pixels wide, preserving aspect ratio and descriptive alternative text; one centered H1 reading `USDZ Validation Kit`; a short purpose-oriented subtitle; a small row of factual technology/license badges with alternative text; and quick links to useful existing documentation. Use GitHub-compatible Markdown/HTML. Badge wording must distinguish package declarations from verified compatibility, and must not imply an unverified release publication or CI result.
2. **About:** A concise introduction to the local Swift library and CLI. Explain near the top that gate acceptance and complete declared coverage do not establish full USD conformance, Apple-platform compatibility, or asset-security certification.
3. **Features:** A short, scannable list covering packaging checks, bounded package-local USDA/USDC reference inspection, delivery budgets, report formats, and library integration. Retain the exact supported USDC versions and bounded-subset qualification in the document. Native inspection and any explicitly opted-in external checker must remain distinct.
4. **Build and run:** Clearly labeled prerequisites and the existing release-build and first-validation commands. Keep the recorded verified host/toolchain separate from intended, unverified compatibility. Retain executable location, dependency/bootstrap details, and the geometry-free fixture explanation.
5. **Use the library:** Retain the Swift package dependency/product guidance, current Swift example, and findings-versus-thrown-error contract, including the optional typed-failure report envelope.
6. **Logo-derived 3D example:** Retain the model, editable source, saved report, and example-guide links; explain the omitted magnifier and separate artwork/viewing tools.
7. **Documentation, verification, and limitations:** Provide a compact index of canonical guides. Make verification commands, evidence, resource/inspection limits, and exclusions individually scannable. Preserve the `Verification and support scope` section as the destination for existing support/non-goals links; use subsections as needed.
8. **Release history, security, and license:** Give publication/history guidance, vulnerability reporting, and licensing explicit destinations, preserving the historical-versus-current evidence distinction and applicable third-party notices.

Use plain section headings without decorative emoji. Keep authoritative technical detail in existing linked guides, while retaining the current README's substantive facts and qualifications. Restructure or tighten prose without silently removing constraints.

## Acceptance criteria

- **AC-01 — Branded opening:** The README has one centered `USDZ Validation Kit` H1 with no emoji, the existing locally referenced icon with descriptive alternative text, a short subtitle, a small factual technology/license badge row, and quick documentation links. Each badge has meaningful alternative text and an appropriate link destination.
- **AC-02 — Complete organization:** The reading order follows the confirmed design, including About, Features, onboarding, library integration, the 3D example, documentation, verification/limitations, release history, security, and license. The entire existing README is evaluated and reorganized rather than only its opening.
- **AC-03 — Truthful scope:** Packaging, bounded authored-reference inspection, delivery budgets, and report capabilities match the repository. Exact USDC versions `0.8.0`, `0.9.0`, and `0.10.0`, coverage gaps, gate-versus-conformance distinctions, stored-only ZIP handling, and bounded crate-metadata decompression remain explicit. Native operation is not conflated with optional external checking or artwork generation/viewing.
- **AC-04 — Preserved onboarding and API contract:** Existing build, first-validation, library, and verification examples retain their commands/API usage and meaning. The executable path, possible initial dependency fetch, pinned Argument Parser and private LZ4 details, fixture limitations, and library error behavior remain available.
- **AC-05 — Preserved evidence and support policy:** Recorded current-host verification remains separate from intended/unverified environments and historical results. Resource observations do not become universal guarantees; complete reference coverage does not become geometry, composition, renderer, or security certification. Publication status remains referred to GitHub releases rather than asserted from the version number.
- **AC-06 — Navigation and assets:** All local README link and image targets exist, new fragments resolve, and existing section anchors `build-and-run`, `use-the-library`, `logo-derived-3d-example`, and `verification-and-support-scope` remain valid. The icon, model, source, report, and provenance links remain discoverable. Historical line-number citations in other documents remain untouched.
- **AC-07 — Licensing and security:** The README retains MIT attribution for original project material, links to `LICENSE`, `NOTICE`, and `SECURITY.md`, and the distinction between original material and bundled third-party license obligations.
- **AC-08 — Bounded change and verification:** Apart from the required specification/plan artifacts, changes are limited to the root `README.md`. Focused link/fragment, content-preservation, presentation, whitespace, and existing documented-example checks pass; failures or unavailable checks are reported accurately. No runtime, asset, schema, dependency, fixture, or historical-record changes are introduced.

## Edge cases and constraints

- GitHub-compatible HTML must keep the centered opening readable and links usable. Plain text and meaningful alternative text must communicate project identity and badge meaning when images do not load. Badge images may use conventional Shields.io URLs; the project illustration stays repository-local.
- A Swift tools declaration or macOS deployment target is not proof of verified host compatibility. Avoid support badges or wording that erase the current policy's distinctions.
- Reorganization must not break inbound heading links from the CLI guide, security policy, inspection-boundary guide, changelog, or example guide. Preserve the existing headings where they supply those anchors.
- The original fixture is geometry-free; the layered-cube asset is the visible example. Retain that distinction.
- Shorter paragraphs and lists may replace dense prose, but coverage limitations, exclusions, current/historical evidence, dependency notices, and release qualifications must retain their substantive meaning.

## Out of scope

New artwork or model changes; runtime features or fixes; new dependencies or tests mirroring editorial structure; repository-wide documentation changes; website work; new compatibility or release certification; changing approved historical artifacts; push, merge, and publication. Later documentation expansion remains provisional and is not authorized by this increment.

## Approval and execution endpoint

Stage 1 scope/design confirmation and separate Stage 2 specification approval are recorded in Provenance. This specification is APPROVED. The matching implementation plan was subsequently presented at Stage 3; the user's separate “approved” reply approved that plan and the recommended native execution method, authorizing Stage 4 implementation, verification, review, and local commits. Push, merge, and publication remain unauthorized.

Keep this specification uncommitted until both this specification and a separately presented implementation plan receive explicit approval and the implementation branch is created under the supplied Git workflow. Use the existing checkout; do not create a worktree or push/merge.

**Execution endpoint:** Complete the approved README restructuring, verify links and presentation, finish required review, commit on the authorized implementation branch, report the working result and limitations, and stop before any later increment.

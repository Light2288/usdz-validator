# Report compatibility

Native JSON reports, rule catalogues and budget configuration use independent `schemaVersion: 1` contracts: [report schema](../Schemas/report-v1.schema.json), [catalogue schema](../Schemas/catalogue-v1.schema.json), [budget schema](../Schemas/budget-config-v1.schema.json). Their stable schema IDs are `urn:usdz-validation-kit:report:1`, `urn:usdz-validation-kit:catalogue:1`, and `urn:usdz-validation-kit:budget-config:1`. SARIF uses `2.1.0` and the [pinned OASIS schema](../Tests/Schemas/sarif-2.1.0.schema.json). [Examples](cli.md#complete-native-examples) are executable fixture expectations; [independent model goldens and durable recipes](../Tools/README.md#durable-independent-golden-provenance) remain separate expectations.

## Meaning and privacy

Report status is `passed`, `failed`, `incomplete`, or `error`. `gateDecision` and `exitCode` express the selected CI gate; accepted native gaps retain incomplete status/coverage. Read [exit precedence](cli.md#exit-codes-and-gate-policy) before treating exit `0` as success.

Categories (`archiveSpecification`, `appleCompatibility`, `policy`, `validatorLimitation`) describe meaning independently of severity (`error`, `warning`, `note`). Native findings/coverage/counts and optional external findings/provenance/counts remain separate. The external record is always present, including `notRequested`; a tool pass never makes native gaps complete.

JSON declares all model fields, using null for unavailable scalars/locations and empty arrays for no items; sensitive-only fields are omitted by default. Default reports contain no timestamps, durations, host/user IDs, random IDs, absolute local paths or raw tool diagnostics. They use integer byte counts, deterministic escaping, lexicographically ordered keys, UTF-8 without BOM, and a final LF. [Sensitive-details opt-in](cli.md#optional-installed-checker) deliberately changes privacy and relocation properties.

## Versioning and identity

Within schema major 1, required fields, types, enum meanings, category/severity interpretation and identity semantics remain compatible. Additive optional fields and new rule IDs may appear; consumers should ignore unknown optional fields and tolerate unknown rule IDs. Breaking changes require a new schema major. Budget configs deliberately reject unknown keys. Product semantic versions and profile IDs are separate: incompatible profile-policy changes require a new profile ID. Detection fixes can change findings between product releases.

The 32 initial native rule IDs and external aggregate `USDCK-001` are permanent and never recycled. [Catalogue JSON](../Examples/catalogue-v1.json) carries title, description, applicability, rationale, family, category and default severity. `rules` selects 30 general or 32 Apple-profile descriptors.

Native occurrence IDs are SHA-256 over a versioned, length-delimited identity tuple (`uvk-occurrence-v1`): source/rule, original name bytes when available, physical entry offset, token/header offset when applicable, and a fixed rule discriminator. Basename, absolute paths, prose, duration and threshold values do not define identity. Distinct tokens/duplicate physical entries retain distinct IDs; exact identities deduplicate. Repacking/editing may change offsets and IDs.

Findings sort by category (`archiveSpecification`, `appleCompatibility`, `policy`, `validatorLimitation`), rule ID, original name UTF-8 bytes, numeric physical location, then occurrence ID; absent names/offsets precede present ones. Discovery and truncation are deterministic.

The same validator version, input bytes, configuration and fixed external result produce identical default bytes. Moving the asset with its basename preserved retains report bytes. Renaming may change display name/package URI, while native occurrence IDs/order remain stable. External text/results also depend on the fixed installed tool and accessible environment. Cross-host baseline/current byte equivalence remains an unobserved verification requirement, not an established result.

External identity uses `uvk-external-occurrence-v1`, `usdchecker`, reported version, rule ID and tool-reported outcome; opaque text/local paths do not define it. Native coverage/findings remain unchanged when the adapter is enabled.

## SARIF and text

The native run comes first; a separate checker run appears only when requested, including unsuccessful invocations. SARIF uses `partialFingerprints["uvkOccurrence/v1"]` for occurrence IDs in each separate native or external run; their versioned identity tuples remain distinct. Properties retain configuration/profile, category/evidence, coverage, provenance, counts and gate results. SARIF follows its own omission rules for unavailable fields rather than JSON's null convention.

Physical locations identify the relative, safely URI-encoded package basename and actual archive byte regions when known. Entry names and layer byte/line/column coordinates use logical locations/properties, never fictional source lines in the ZIP. Incomplete native coverage differs from failed execution. Unavailable/incomplete checker invocations set `executionSuccessful: false` and provide notifications; completed tool-reported asset failure still represents completed execution.

General SARIF validity does not promise every hosted code-scanning platform will accept it, source navigation into archives, or automatic upload. Human text preserves result meaning and ordering; its prose layout is not a machine interface. [Offline verification](../Tools/README.md#setup-and-verification) validates local schemas without runtime downloads.

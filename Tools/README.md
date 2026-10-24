# Offline compatibility tools

The Swift products have no Python runtime dependency. These tools validate the checked-in report, catalogue and budget schemas, examples and independent golden expectations. They use no network during tests. All project-authored tools, recipes, expectations and examples are MIT; preserve the copyright and permission notice in `../LICENSE`. Third-party schema/dependency notices are in `../NOTICE`.

## Setup and verification

**CPython 3.14.7 on macOS arm64** is the verified development-tool environment. **CPython 3.12 on macOS arm64** remains an intended, unverified target; it was **not available or tested**. Under the user-approved 2026-10-21 policy amendment, its absent matrix row stays UNVERIFIED and verification is deferred follow-up, not a v0.1 acceptance blocker. The Swift 6.0 / Xcode 16.0 / macOS 15 arm64 product target is likewise intended and unverified; only the exact tested combination in [the release matrix](../docs/verification/release-matrix.md) is verified/supported. No Xcode-bundled Python version or automatic minimum/future support is assumed.

From the repository root:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install --require-hashes -r Tools/requirements-schema.lock
swift test --filter GoldenCompatibilityTests
.venv/bin/python Scripts/verify-schemas.py --self-test
.venv/bin/python -m unittest discover -s Tests -p 'test_schema_contracts.py'
```

Installation may download only hash-locked artifacts; test execution downloads nothing. For deferred testing of the intended Python 3.12 target, create the venv with an explicitly installed `python3.12 -m venv .venv` instead. Do not infer baseline success from wheel resolution. The lock covers universal Python wheels and the two macOS arm64 CPython 3.12 / 3.14 `rpds-py` wheels. Other interpreters/platforms require a reviewed lock extension.

To validate actual fixed Swift exports without changing golden files:

```sh
UVK_COMPAT_EXPORT_DIR="$PWD/.verification/compat" swift test --filter GoldenCompatibilityTests
.venv/bin/python Scripts/verify-schemas.py --directory .verification/compat
```

The export environment variable is read only in the test target. Without it the test writes no exports. The directory option adds validation to the checked-in corpus; it accepts immediate files named `report*.json`, `external*.json`, or `state*.json` as native report v1; `catalogue*.json` or `rule-catalogue*.json` as catalogue v1; `budget*.json` or `config*.json` as budget config v1; and `*.sarif` as SARIF 2.1.0. Unsupported names and empty/missing directories fail. Use a dedicated export directory. The release runner also uses `--expected-export-count 81` to reject a missing portion of the fixed corpus. The 81 actual Swift exports are validated alongside 21 reviewed checked-in documents (102 bound files). The immutable manifest includes every product Swift/C/header source, the vendored dependency license/source manifest and NOTICE. Reviewed vendored input bytes and missing/extra C/header or export files must fail validation. See [the release procedure](../docs/releasing.md) for immutable evidence manifests and exact cross-host byte/native-ID comparison; none of these commands regenerate independent golden expectations.

## Contract boundaries

Project schemas use Draft 2020-12 and stable IDs `urn:usdz-validation-kit:report:1`, `urn:usdz-validation-kit:catalogue:1`, `urn:usdz-validation-kit:budget-config:1`. Report/catalogue objects allow additive optional fields and unknown rule IDs within v1. Declared required fields, types, versions and enum meanings remain checked. The budget configuration rejects unknown top-level and budget keys. Omitted budgets default; null disables only that warning. JSON Schema cannot distinguish lexical `1.0` from `1`, detect duplicate keys after parsing, or enforce raw byte ceilings. `BudgetConfigurationTests` covers those decoder requirements, including trailing data; the verification reader also rejects duplicate keys and trailing data.

The published OASIS schema remains byte-for-byte unchanged and uses Draft 7. Both its own `$id` and the emitted OASIS `$schema` URL are registered explicitly from the local file. All unregistered references, including remote/file URIs, fail; no fallback retrieval exists. OASIS permits an unknown-byte sentinel of -1. UVK's additional semantic checks require actual nonnegative archive offsets and keep layer coordinates out of physical ZIP line regions. OASIS property bags cannot express UVK's custom invariants, so separate checks preserve native-first ordering, one requested checker run, independent provenance/counts, fingerprints, coverage and invocation success/notification/process metadata. Unavailable SARIF fields omit; JSON fields use null. Typed evidence nulls and disabled budget nulls remain meaningful in both formats.

## Schema source and license review

`Tests/Schemas/sarif-2.1.0.schema.json` is the published OASIS SARIF 2.1.0 schema, fetched from:

<https://docs.oasis-open.org/sarif/sarif/v2.1.0/os/schemas/sarif-schema-2.1.0.json>

Its exact SHA-256 is `ad6db49878699b091f3eeb765b6e29e92a34bad4da88664d000c923b549c3a25`. The original CRLF bytes are preserved. Before copying it into the repository, the complete Notices section of <https://docs.oasis-open.org/sarif/sarif/v2.1.0/os/sarif-v2.1.0-os.html> was inspected. It permits copying with the copyright and complete notice retained; the complete notice is reproduced in `NOTICE`. It is not relabeled MIT. The repository's general OASIS IPR page alone was not treated as a redistribution grant. `Tests/Schemas/manifest.json` records source, hash, license, obligations and reproduction metadata.

## Dependency lock reproduction

Exact graph: `jsonschema==4.25.1` (MIT, Python >=3.9), `attrs==26.1.0` (MIT, >=3.9), `jsonschema-specifications==2025.9.1` (MIT, >=3.9), `referencing==0.37.0` (MIT, >=3.10), `rpds-py==2026.9.1` (MIT, >=3.11), and `typing_extensions==4.15.0` (PSF-2.0, >=3.9) only when Python <3.13, as required by referencing. The full PSF distribution license is retained verbatim, including its historical notices. Their declared Python floors permit the intended Python 3.12 target and verified CPython 3.14.7; metadata and wheel selection do not establish execution on Python 3.12. Distribution license texts were read from each wheel and retained in `NOTICE`. Exact artifact URLs and hashes appear in the schema manifest's `dependencyArtifacts`; each locally computed SHA-256 was also matched against the published PyPI version JSON metadata.

To reproduce the reviewed lock without silently upgrading its graph:

```sh
python3 -m venv .venv
.venv/bin/python -m pip download --only-binary=:all: --dest .verification/schema-wheels jsonschema==4.25.1 attrs==26.1.0 jsonschema-specifications==2025.9.1 referencing==0.37.0 rpds-py==2026.9.1
.venv/bin/python -m pip download --only-binary=:all: --python-version 3.12 --implementation cp --abi cp312 --platform macosx_11_0_arm64 --dest .verification/schema-wheels jsonschema==4.25.1 attrs==26.1.0 jsonschema-specifications==2025.9.1 referencing==0.37.0 rpds-py==2026.9.1 typing-extensions==4.15.0
.venv/bin/python -m pip hash .verification/schema-wheels/*.whl
```

On the current macOS arm64 CPython 3.14 host the first command selects the cp314 wheel; explicitly select the analogous 3.14/cp314 target if generating elsewhere. The baseline download explicitly includes typing-extensions because cross-target pip downloads can evaluate markers using the host interpreter; its lock line retains the `python_version < '3.13'` marker. Initial graph selection used `pip download --only-binary=:all: jsonschema==4.25.1`; updates must deliberately resolve both target interpreters again, inspect all `Requires-Dist` markers/versions and wheel licenses, hash the downloaded bytes, match the hashes to `https://pypi.org/pypi/NAME/VERSION/json`, and write one exact pinned line per resolved package with every accepted wheel hash. Then install with `--require-hashes` and run the offline checks on each available interpreter. Never invent hashes or promote untested baseline support.

## Durable independent golden provenance

Golden files are expected documents authored from literal scenario/model contracts, not captures of the product encoder. No tool here regenerates goldens during tests. Review mismatches against the specification and independent recipe before any intentional update. `Tests/Schemas/manifest.json` pins every golden/example's SHA-256. Existing seven goldens were unchanged in Task 22. The catalogue example is an exact copy of the Apple-profile catalogue golden; JSON/SARIF examples independently project the literal contracts onto the complete committed USDA fixture as recorded in Tests/Schemas/manifest.json; the budget example independently declares the six default values. Synthetic USDC locations illustrate a limitation report and are not a valid-scene oracle.

Task 16 originally authored complete/incomplete/operational JSON with Python's sorted compact serializer before implementing JSON output, preserving all 32 independently authored literal catalogue descriptors. The catalogue's checked-in literal document is its canonical source: retain all descriptor fields/order, `schemaVersion:1`, current tool `usdz-validator`/`0.2.0`, profile `apple-portable-v1`, serialize with the same canonical recipe below. The v0.2 literal selects 34 rules (32 general plus two Apple warnings); descriptor text is never copied from product output. The incomplete example's identity independently encodes big-endian UInt64 lengths, presence bytes, raw UTF-8 name and numeric offsets; the complete reproducible recipe below asserts its fixed SHA-256 vector.

Task 19's only reviewed JSON golden change was the additive `terminationReason:null` field in canonical key order, with all three prior documents otherwise identical. It requires no schema-major or identity change. SARIF omitted nil, so those goldens did not change. The literal recipe below includes this exact addition and adds representative external success/failure envelopes for Task 22. Their external failure identity is independently SHA-256 encoded; the earlier SARIF fixture deliberately retains its literal `external-occurrence` fixture ID. The recipes never import the product.

### Literal JSON authoring recipe

Copyright (c) 2026 USDZ Validation Kit contributors. MIT; see `LICENSE`.

Extract the following Python block verbatim to a temporary file and run it from an empty temporary staging directory. Compare its generated `Tests/Goldens/*.json` to the corresponding checked-in documents; do not overwrite checked-in expectations on mismatch. Catalogue descriptors remain the retained independent literal source described above. Recipe SHA-256: `22932be5987a425712610f24e31bb7acbf0c181d37639a6ac146bb86c7fd8f14` (UTF-8 bytes inside the fence, including the final LF).

<!-- uvk-json-recipe -->
```python
"""Independent literal v1 JSON expectations (USDZ Validation Kit contributors, MIT).
Run in an empty staging directory containing Tests/Goldens/rule-catalogue-v1.json.
No product invocation, import, report decoding, or captured product bytes.
"""
import copy
import hashlib
import json
import struct
from pathlib import Path

def field(value):
    value = value.encode('utf-8')
    return struct.pack('>Q', len(value)) + value

native_id = hashlib.sha256(field('uvk-occurrence-v1') + field('UVK-LIM-002')
    + b'\x01' + field('root.usdc') + b'\x01' + struct.pack('>Q', 0)
    + b'\x01' + struct.pack('>Q', 0) + field('binaryReferences')).hexdigest()
assert native_id == 'c9dce5d1e8d7ef85ae24d92062192f27535322e1aca4d933944d3115222579b4'
version = 'Apple USD Tools (0.25.11)'
external_id = hashlib.sha256(b''.join(field(v) for v in [
    'uvk-external-occurrence-v1', 'usdchecker', version, 'USDCK-001', 'failureReported'])).hexdigest()
counts = {'byCategory': {v: 0 for v in ['archiveSpecification', 'appleCompatibility', 'policy', 'validatorLimitation']},
          'bySeverity': {v: 0 for v in ['error', 'warning', 'note']}}
budgets = {'archiveBytes': 104857600, 'fileBytes': 26214400, 'fileCount': 1000,
           'textureBytes': 20971520, 'totalTextureBytes': 83886080, 'textureMaxDimension': 4096}
configuration = {'profile': 'general-v1', 'budgets': budgets, 'safetyEnvelopeVersion': 2,
    'gatePolicy': {'failOn': 'error', 'allowIncomplete': False},
    'includeSensitiveDetails': False, 'externalCheck': 'disabled'}
not_requested = {'requested': False, 'phase': None, 'availability': 'unknown', 'version': None,
    'policy': None, 'status': 'notRequested', 'outcome': None, 'exitCode': None, 'signal': None,
    'terminationReason': None, 'stdoutBytes': 0, 'stderrBytes': 0, 'hasStdout': False, 'hasStderr': False, 'findings': []}
location = {'entryName': 'root.usdc', 'archiveByteOffset': 64, 'layerByteOffset': 0, 'line': None, 'column': None}
native = {'ruleID': 'UVK-LIM-002', 'occurrenceID': native_id, 'category': 'validatorLimitation',
    'severity': 'warning', 'message': 'Native reference inspection is unavailable for binary USD.',
    'evidence': {'binary': True, 'bytes': 8, 'reason': 'binaryReferences', 'unknown': None},
    'location': location, 'provenance': {'kind': 'native', 'validatorVersion': '0.2.0'}}
external = {'ruleID': 'USDCK-001', 'occurrenceID': external_id, 'category': 'appleCompatibility',
    'severity': 'error', 'message': 'Checker reported failure.', 'evidence': {}, 'location': None,
    'provenance': {'kind': 'usdchecker', 'tool': 'usdchecker', 'version': version}}

def checker(failure=False, legacy=False):
    return {**copy.deepcopy(not_requested), 'requested': True, 'phase': 'validation',
        'availability': 'available', 'version': version, 'policy': 'strict-root-package-only-v1',
        'status': 'completed', 'outcome': 'failureReported' if failure else 'noFailureReported',
        'exitCode': 17 if failure else 0, 'terminationReason': None if legacy else 'exited',
        'stderrBytes': 12 if failure or legacy else 0, 'hasStderr': failure or legacy,
        'findings': [external] if failure else []}

out = Path('Tests/Goldens')
out.mkdir(parents=True, exist_ok=True)
for kind in ['complete', 'incomplete', 'operational', 'external-success', 'external-failure']:
    areas = {v: {'requested': v != 'appleAdvice',
                  'state': 'notRun' if v == 'appleAdvice' or kind == 'operational' else 'complete', 'reasons': []}
             for v in ['containerStructure', 'entrySafety', 'references', 'byteBudgets', 'textureDimensions', 'appleAdvice']}
    document = {'schemaVersion': 1, 'tool': {'name': 'usdz-validator', 'version': '0.2.0'},
        'input': {'displayName': 'input.usdz', 'byteSize': None if kind == 'operational' else 123},
        'configuration': copy.deepcopy(configuration), 'coverage': {'areas': areas, 'isComplete': kind not in ['incomplete', 'operational']},
        'nativeFindings': [], 'externalCheck': copy.deepcopy(not_requested),
        'operationalErrors': [{'category': 'operational', 'reason': 'inputUnavailable'}] if kind == 'operational' else [],
        'summary': {'native': copy.deepcopy(counts), 'external': copy.deepcopy(counts), 'externalOutcome': None},
        'validationStatus': {'incomplete': 'incomplete', 'operational': 'error', 'external-failure': 'failed'}.get(kind, 'passed'),
        'gateDecision': 'fail' if kind in ['incomplete', 'operational', 'external-failure'] else 'pass',
        'acceptedIncomplete': False, 'exitCode': {'incomplete': 2, 'operational': 3, 'external-failure': 1}.get(kind, 0)}
    if kind == 'incomplete':
        areas['references'].update(state='partial', reasons=[{'ruleID': 'UVK-LIM-002', 'reasonID': 'binaryReferences', 'location': location}])
        document['nativeFindings'] = [native]
        document['summary']['native']['bySeverity']['warning'] = 1
        document['summary']['native']['byCategory']['validatorLimitation'] = 1
    if kind in ['incomplete', 'external-success', 'external-failure']:
        document['configuration']['externalCheck'] = 'usdchecker'
        document['externalCheck'] = checker(failure=kind == 'external-failure', legacy=kind == 'incomplete')
        document['summary']['externalOutcome'] = document['externalCheck']['outcome']
    if kind == 'external-failure':
        document['summary']['external']['bySeverity']['error'] = 1
        document['summary']['external']['byCategory']['appleCompatibility'] = 1
    name = kind + '-v1.json' if kind.startswith('external-') else 'report-' + kind + '-v1.json'
    (out / name).write_bytes((json.dumps(document, ensure_ascii=False, sort_keys=True, separators=(',', ':')) + '\n').encode())
```

### Task 17 literal SARIF authoring recipe

Copyright (c) 2026 USDZ Validation Kit contributors. MIT; see `LICENSE`.

The independent Task 17 recipe follows with current v0.2 tool/provenance and envelope metadata, retaining its historical “scratch evidence only” docstring. This durable copy supersedes that storage comment: it must remain available after workflow scratch cleanup. Current recipe SHA-256: `5655995eeff54fdce9ebfe2fe5b416d00031cdb2d9302995dcdffc668ce3c333` (UTF-8 bytes inside the fence, including the final LF).

To reproduce, extract the block to a temporary `.py` file, create a fresh temporary staging directory containing `Tests/Goldens/rule-catalogue-v1.json` copied from the pinned independent literal catalogue, and run the script with that staging directory as cwd. It writes the three expected SARIF documents there. Compare all resulting bytes with the committed SARIF goldens. The script imports only the Python standard library and derives descriptors from the retained independent catalogue, not the product. Its literal null evidence must remain null; unavailable location fields are omitted.

<!-- uvk-sarif-recipe -->
```python
"""Author expected SARIF from literal expectations and Task 16's independent catalogue fixture.
Never invokes, imports, or captures the SARIF encoder; retained as scratch evidence only.
"""
import copy
import json
from pathlib import Path
root = Path.cwd()
fixtures = root / 'Tests/Goldens'
cat = json.loads((fixtures / 'rule-catalogue-v1.json').read_text())
rules = []
for rule in cat['rules']:
    if rule['category'] == 'appleCompatibility':
        continue
    props = {key: rule[key] for key in ['category', 'applicability', 'rationale']}
    if rule['family'] is not None:
        props['family'] = rule['family']
    rules.append({'id': rule['ruleID'], 'shortDescription': {'text': rule['title']},
                  'fullDescription': {'text': rule['description']},
                  'defaultConfiguration': {'level': rule['defaultSeverity']}, 'properties': props})
location = {'entryName': 'root.usdc', 'archiveByteOffset': 64, 'layerByteOffset': 0}
coverage = {'areas': {
    'appleAdvice': {'requested': False, 'state': 'notRun', 'reasons': []},
    'byteBudgets': {'requested': True, 'state': 'complete', 'reasons': []},
    'containerStructure': {'requested': True, 'state': 'complete', 'reasons': []},
    'entrySafety': {'requested': True, 'state': 'complete', 'reasons': []},
    'references': {'requested': True, 'state': 'partial', 'reasons': [
        {'ruleID': 'UVK-LIM-002', 'reasonID': 'binaryReferences', 'location': location}]},
    'textureDimensions': {'requested': True, 'state': 'complete', 'reasons': []},
}, 'isComplete': False}
configuration = {'profile': 'general-v1', 'budgets': {
    'archiveBytes': 104857600, 'fileBytes': 26214400, 'fileCount': 1000,
    'textureBytes': 20971520, 'totalTextureBytes': 83886080, 'textureMaxDimension': 4096},
    'safetyEnvelopeVersion': 2, 'gatePolicy': {'failOn': 'error', 'allowIncomplete': False},
    'includeSensitiveDetails': False, 'externalCheck': 'disabled'}
counts_native = {'bySeverity': {'error': 0, 'warning': 1, 'note': 0},
                 'byCategory': {'archiveSpecification': 0, 'appleCompatibility': 0, 'policy': 0, 'validatorLimitation': 1}}
counts_empty = {'bySeverity': {'error': 0, 'warning': 0, 'note': 0},
                'byCategory': {'archiveSpecification': 0, 'appleCompatibility': 0, 'policy': 0, 'validatorLimitation': 0}}
counts_failure = {'bySeverity': {'error': 1, 'warning': 0, 'note': 0},
                  'byCategory': {'archiveSpecification': 0, 'appleCompatibility': 1, 'policy': 0, 'validatorLimitation': 0}}
artifact = {'location': {'uri': 'input.usdz'}, 'length': 123}
native_result = {'ruleId': 'UVK-LIM-002', 'level': 'warning',
    'message': {'text': 'Native reference inspection is unavailable for binary USD.'},
    'partialFingerprints': {'uvkOccurrence/v1': 'c9dce5d1e8d7ef85ae24d92062192f27535322e1aca4d933944d3115222579b4'},
    'properties': {'category': 'validatorLimitation',
        'evidence': {'binary': True, 'bytes': 8, 'reason': 'binaryReferences', 'unknown': None},
        'provenance': {'kind': 'native', 'validatorVersion': '0.2.0'}},
    'locations': [{'physicalLocation': {'artifactLocation': {'uri': 'input.usdz'}, 'region': {'byteOffset': 64}},
        'logicalLocations': [{'fullyQualifiedName': 'root.usdc', 'properties': {'layerByteOffset': 0}}]}]}
external_rule = {'id': 'USDCK-001', 'shortDescription': {'text': 'External checker reported failure'},
    'fullDescription': {'text': 'Aggregate failure reported by the optional usdchecker.'},
    'defaultConfiguration': {'level': 'error'}, 'properties': {'category': 'appleCompatibility'}}
external_result = {'ruleId': 'USDCK-001', 'level': 'error', 'message': {'text': 'Checker reported failure.'},
    'partialFingerprints': {'uvkOccurrence/v1': 'external-occurrence'},
    'properties': {'category': 'appleCompatibility', 'evidence': {},
        'provenance': {'kind': 'usdchecker', 'tool': 'usdchecker', 'version': 'Apple USD Tools (0.25.11)'}}}
for kind in ['native', 'external-unavailable', 'external-failure']:
    config = copy.deepcopy(configuration)
    if kind != 'native':
        config['externalCheck'] = 'usdchecker'
    gate = {'validationStatus': 'failed' if kind == 'external-failure' else 'incomplete',
            'gateDecision': 'fail', 'acceptedIncomplete': False, 'exitCode': 1 if kind == 'external-failure' else 2}
    props = {'input': {'displayName': 'input.usdz', 'byteSize': 123}, 'configuration': config,
             'coverage': coverage, 'counts': counts_native, 'operationalErrors': [],
             'provenance': {'kind': 'native', 'validatorVersion': '0.2.0'}, **gate}
    runs = [{'tool': {'driver': {'name': 'usdz-validator', 'version': '0.2.0', 'rules': rules}},
             'artifacts': [artifact], 'invocations': [{'executionSuccessful': True}],
             'results': [native_result], 'properties': props}]
    if kind != 'native':
        failure = kind == 'external-failure'
        checker = {'requested': True, 'phase': 'validation' if failure else 'versionProbe',
            'availability': 'available' if failure else 'unavailable', 'policy': 'strict-root-package-only-v1',
            'status': 'completed' if failure else 'unavailable', 'stdoutBytes': 0, 'stderrBytes': 12 if failure else 0,
            'hasStdout': False, 'hasStderr': failure}
        driver = {'name': 'usdchecker', 'rules': [external_rule]}
        invocation = {'executionSuccessful': failure}
        if failure:
            checker.update(version='Apple USD Tools (0.25.11)', outcome='failureReported', exitCode=17)
            driver['version'] = 'Apple USD Tools (0.25.11)'
            invocation['exitCode'] = 17
        else:
            invocation['toolExecutionNotifications'] = [{'level': 'error', 'message': {'text': 'usdchecker invocation did not complete: unavailable.'}}]
        runs.append({'tool': {'driver': driver}, 'artifacts': [artifact], 'invocations': [invocation],
            'results': [external_result] if failure else [], 'properties': {'profile': 'general-v1',
                'counts': counts_failure if failure else counts_empty, 'externalCheck': checker,
                'provenance': {'kind': 'usdchecker', 'tool': 'usdchecker'}, **gate}})
    document = {'$schema': 'https://docs.oasis-open.org/sarif/sarif/v2.1.0/os/schemas/sarif-schema-2.1.0.json',
                'version': '2.1.0', 'runs': runs}
    (fixtures / (kind + '-v1.sarif')).write_bytes((json.dumps(document, ensure_ascii=False, sort_keys=True, separators=(',', ':')) + '\n').encode())
```

### Literal v0.2 binary JSON/SARIF authoring recipe

The four fixed models cover complete inventory, a live unsupported value plus the layer's partial-inventory reason, conclusive whole-layer malformed header plus unavailable inventory, and two numeric sites sharing one missing target. Duplicate visits to the first site collapse. Findings sort by policy before limitation, rule ID, and independently hashed occurrence ID; coverage reasons retain discovery order and merge identical member/reason records. The recipe's SHA-256 is `3a7be43b2b94e68826d7670117f6d5680d5dd0505223710b3424a23407b14af4`, bound below and in Tests/Schemas/manifest.json. It reads only the independently retained catalogue and writes exactly eight documents in an empty staging directory. Run it before comparing product encoders; it never captures encoder bytes. Historical USDA identity vectors and schema major 1 remain unchanged.

<!-- uvk-usdc-recipe -->
```python
"""Independent v0.2 binary report expectations; standard library only (MIT).
The fixed member has raw UTF-8 name root.usdc and local-header offset zero.
Structural paths use spec 7, field 3, with optional array indices 0 and 1.
No product invocation, import, encoder output, or scene/parser oracle is used.
"""
import copy
import hashlib
import json
import struct
from pathlib import Path

out = Path('Tests/Goldens')
cat = json.loads((out / 'rule-catalogue-v1.json').read_text())

def field(text):
    value = text.encode('utf-8')
    return struct.pack('>Q', len(value)) + value

def identity(rule, reason, coordinates=''):
    # The optional content offset is absent; local-header identity is not a displayed region.
    return hashlib.sha256(field('uvk-occurrence-v1') + field(rule)
        + b'\x01' + field('root.usdc') + b'\x01' + struct.pack('>Q', 0)
        + b'\x00' + field(reason + '|usdc-v1' + coordinates)).hexdigest()

location = {'entryName': 'root.usdc', 'archiveByteOffset': None,
            'layerByteOffset': None, 'line': None, 'column': None}
provenance = {'kind': 'native', 'validatorVersion': '0.2.0'}
configuration = {'profile': 'general-v1', 'budgets': {
    'archiveBytes': 104857600, 'fileBytes': 26214400, 'fileCount': 1000,
    'textureBytes': 20971520, 'totalTextureBytes': 83886080, 'textureMaxDimension': 4096},
    'safetyEnvelopeVersion': 2, 'gatePolicy': {'failOn': 'error', 'allowIncomplete': False},
    'includeSensitiveDetails': False, 'externalCheck': 'disabled'}
empty_counts = {'byCategory': dict.fromkeys(
    ['archiveSpecification', 'appleCompatibility', 'policy', 'validatorLimitation'], 0),
    'bySeverity': dict.fromkeys(['error', 'warning', 'note'], 0)}
external = {'requested': False, 'phase': None, 'availability': 'unknown', 'version': None,
    'policy': None, 'status': 'notRequested', 'outcome': None, 'exitCode': None, 'signal': None,
    'terminationReason': None, 'stdoutBytes': 0, 'stderrBytes': 0,
    'hasStdout': False, 'hasStderr': False, 'findings': []}

# These tuples are the independently selected scenario contract, in discovery order.
scenarios = {
    'complete': [],
    'partial': [
        ('UVK-LIM-007', 'unsupportedValue', '|s:7|f:3',
         'Binary USD reference inspection encountered an unsupported representation.'),
        ('UVK-LIM-007', 'partialBinaryReferences', '',
         'Native reference inspection is incomplete for this binary USD layer.')],
    'malformed': [
        ('UVK-USD-001', 'invalidHeader', '', 'The inspected binary USD structure is malformed.'),
        ('UVK-LIM-002', 'binaryReferences', '',
         'Native reference inspection is unavailable for this binary USD layer.')],
    'duplicates': [
        ('UVK-PATH-006', 'missingTarget', '|s:7|f:3|0:0',
         'The asset reference has no regular package target.'),
        ('UVK-PATH-006', 'missingTarget', '|s:7|f:3|0:1',
         'The asset reference has no regular package target.')],
}
assert identity('UVK-PATH-006', 'missingTarget', '|s:7|f:3|0:0') == '5398f4182331ac6b1a6c0989e4c2b1a890b101524c4fe3c24fd5720c4bb4a352'
assert identity('UVK-PATH-006', 'missingTarget', '|s:7|f:3|0:1') == 'b55784978fdd8273a72795e54dc6ff45f49fe6fb88ff49dbce096b08ffb14b44'

rules = []
for rule in cat['rules']:
    if rule['category'] == 'appleCompatibility':
        continue
    props = {key: rule[key] for key in ['category', 'applicability', 'rationale']}
    if rule['family'] is not None:
        props['family'] = rule['family']
    rules.append({'id': rule['ruleID'], 'shortDescription': {'text': rule['title']},
                  'fullDescription': {'text': rule['description']},
                  'defaultConfiguration': {'level': rule['defaultSeverity']}, 'properties': props})

def omit_nulls(value):
    if isinstance(value, dict):
        return {key: omit_nulls(item) for key, item in value.items() if item is not None}
    if isinstance(value, list):
        return [omit_nulls(item) for item in value]
    return value

def write(name, value):
    (out / name).write_bytes((json.dumps(value, ensure_ascii=False, sort_keys=True,
        separators=(',', ':')) + '\n').encode('utf-8'))

for kind, tuples in scenarios.items():
    areas = {area: {'requested': area != 'appleAdvice',
        'state': 'notRun' if area == 'appleAdvice' else 'complete', 'reasons': []}
        for area in ['containerStructure', 'entrySafety', 'references', 'byteBudgets',
                     'textureDimensions', 'appleAdvice']}
    findings, reasons = [], []
    counts = copy.deepcopy(empty_counts)
    for rule, reason, coordinates, message in tuples:
        limitation = rule.startswith('UVK-LIM-')
        category, severity = ('validatorLimitation', 'warning') if limitation else ('policy', 'error')
        findings.append({'ruleID': rule, 'occurrenceID': identity(rule, reason, coordinates),
            'category': category, 'severity': severity, 'message': message,
            'evidence': {'reason': reason}, 'location': location, 'provenance': provenance})
        counts['byCategory'][category] += 1
        counts['bySeverity'][severity] += 1
        coverage_reason = {'ruleID': rule, 'reasonID': reason, 'location': location}
        if coverage_reason not in reasons:
            reasons.append(coverage_reason)
    if tuples:
        areas['references'].update(state='partial', reasons=reasons)
    # Policy findings precede limitations, then fixed rule and occurrence identity byte order.
    findings.sort(key=lambda f: (f['category'] == 'validatorLimitation', f['ruleID'], f['occurrenceID']))
    gate = {'validationStatus': 'passed' if kind == 'complete' else 'incomplete' if kind == 'partial' else 'failed',
            'gateDecision': 'pass' if kind == 'complete' else 'fail',
            'acceptedIncomplete': False, 'exitCode': 0 if kind == 'complete' else 2 if kind == 'partial' else 1}
    coverage = {'areas': areas, 'isComplete': kind == 'complete'}
    doc = {'schemaVersion': 1, 'tool': {'name': 'usdz-validator', 'version': '0.2.0'},
        'input': {'displayName': 'input.usdz', 'byteSize': 123}, 'configuration': configuration,
        'coverage': coverage, 'nativeFindings': findings, 'externalCheck': external,
        'operationalErrors': [], 'summary': {'native': counts, 'external': empty_counts,
        'externalOutcome': None}, **gate}
    write('report-usdc-' + kind + '-v1.json', doc)
    results = [{'ruleId': f['ruleID'], 'level': f['severity'], 'message': {'text': f['message']},
        'partialFingerprints': {'uvkOccurrence/v1': f['occurrenceID']},
        'properties': {key: f[key] for key in ['category', 'evidence', 'provenance']},
        'locations': [{'physicalLocation': {'artifactLocation': {'uri': 'input.usdz'}},
                       'logicalLocations': [{'fullyQualifiedName': 'root.usdc'}]}]} for f in findings]
    write('report-usdc-' + kind + '-v1.sarif', {
        '$schema': 'https://docs.oasis-open.org/sarif/sarif/v2.1.0/os/schemas/sarif-schema-2.1.0.json',
        'version': '2.1.0', 'runs': [{'tool': {'driver': {'name': 'usdz-validator', 'version': '0.2.0', 'rules': rules}},
            'artifacts': [{'location': {'uri': 'input.usdz'}, 'length': 123}],
            'invocations': [{'executionSuccessful': True}], 'results': results,
            'properties': {'input': doc['input'], 'configuration': configuration,
                'coverage': omit_nulls(coverage), 'counts': counts, 'operationalErrors': [],
                'provenance': provenance, **gate}}]})
```

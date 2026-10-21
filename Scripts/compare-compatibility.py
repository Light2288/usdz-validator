#!/usr/bin/env python3
"""Compare immutable UVK cross-host exports and assess release evidence (MIT)."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

ENVIRONMENT_FIELDS = ('developerDir', 'swift', 'xcode', 'os', 'architecture',
                      'formatter', 'hardware', 'python', 'schemaPython', 'storage')
REQUIRED_STEPS = ('environment', 'format-check', 'resolve', 'resolved-lock', 'build',
                  'test', 'cli-test', 'release-build', 'release-test', 'address-sanitizer',
                  'schema-self-test', 'schema-tests', 'verification-tools', 'examples',
                  'golden-export', 'export-schemas', 'export-manifest', 'resource-tests',
                  'resource-measurements')


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def native_ids(document):
    if 'nativeFindings' in document:
        return [finding['occurrenceID'] for finding in document['nativeFindings']]
    if 'runs' in document:
        return [result['partialFingerprints']['uvkOccurrence/v1']
                for result in document['runs'][0]['results']]
    return []


def designated_role(environment):
    os_version = re.search(r'^ProductVersion:\s*(\S+)', environment.get('os', ''), re.M)
    xcode = re.search(r'^Xcode (\S+)', environment.get('xcode', ''), re.M)
    swift = re.search(r'Swift version (\S+)', environment.get('swift', ''))
    if not all((os_version, xcode, swift)):
        return 'unrecognized'
    observed = (os_version[1], xcode[1], swift[1])
    if observed == ('27.0.1', '27.1', '6.4'):
        return 'current'
    if (observed[0] == '15' or observed[0].startswith('15.')) and observed[1:] == ('16.0', '6.0'):
        return 'baseline'
    return 'unrecognized'


def evaluate_evidence(result, folder):
    """Missing/failed required evidence cannot be promoted by green matrix rows."""
    failures = []
    if result.get('error'):
        failures.append(result['error'])
    environment = result.get('environment', {})
    for key in ENVIRONMENT_FIELDS:
        if not environment.get(key):
            failures.append(f'missing environment: {key}')
    if environment.get('role') not in ('baseline', 'current') or environment.get('architecture') != 'arm64':
        failures.append('environment is not a designated arm64 combination')
    rows = result.get('steps', [])
    for name in REQUIRED_STEPS:
        matches = [row for row in rows if row.get('name') == name]
        if len(matches) != 1:
            failures.append(f'missing/duplicate required step: {name}')
            continue
        row = matches[0]
        baseline_formatter = name == 'format-check' and environment.get('role') == 'baseline'
        if baseline_formatter and row.get('status') == 'SKIPPED' and row.get('reason'):
            # The baseline records its formatter; current-host lint is a separate release gate.
            continue
        if row.get('status') != 'PASS' or row.get('exitCode') != 0 or not row.get('command'):
            failures.append(f'required step did not pass: {name}')
        for stream in ('stdout', 'stderr'):
            path = folder / row.get(stream, '__missing__')
            if not path.is_file():
                failures.append(f'missing {stream} evidence: {name}')
    smoke = result.get('installedCheckerSmoke', {})
    if smoke.get('status') not in ('PASS', 'SKIPPED') or (smoke.get('status') == 'SKIPPED' and not smoke.get('reason')):
        failures.append('installed checker smoke must be passed or explicitly skipped')
    current = 'FAIL' if failures else 'PASS'
    matrix = result.get('matrix', {})
    release = 'FAIL' if failures else ('PASS' if all(matrix.get(key) == 'PASS'
        for key in ('current', 'baseline', 'crossHost', 'python312')) else 'UNVERIFIED')
    return {'currentHostStatus': current, 'releaseStatus': release, 'failures': failures}


def write_manifest(root, directory):
    exports = sorted((directory / 'exports').glob('*'))
    if len(exports) != 73 or any(not path.is_file() for path in exports):
        raise ValueError(f'expected exactly 73 fixed golden exports, observed {len(exports)}')
    inventory = json.loads((root / 'Tests/Schemas/manifest.json').read_text())
    documents = [entry for entry in inventory['entries'] if 'format' in entry]
    if len(documents) != 13:
        raise ValueError('expected 13 reviewed checked-in schema documents')
    inputs = {}
    for manifest_path in ('Tests/Fixtures/manifest.json', 'Tests/Schemas/manifest.json'):
        manifest = json.loads((root / manifest_path).read_text())
        for entry in manifest['entries']:
            path = root / entry['path']
            digest = sha256(path)
            if digest != entry['sha256']:
                raise ValueError(f'{path}: reviewed input hash differs')
            inputs[entry['path']] = digest
    for name in ('.swift-format', 'Package.swift', 'Package.resolved', 'Tools/requirements-schema.lock',
                 'Tests/Fixtures/manifest.json', 'Tests/Schemas/manifest.json',
                 'Tests/USDZValidationTests/GoldenCompatibilityTests.swift'):
        inputs[name] = sha256(root / name)
    for path in sorted((root / 'Sources').rglob('*.swift')):
        inputs[path.relative_to(root).as_posix()] = sha256(path)
    for entry in documents:
        target = directory / 'checked-in' / entry['path']
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((root / entry['path']).read_bytes())
    paths = exports + sorted((directory / 'checked-in').rglob('*'))
    files, configurations, versions = {}, {}, set()
    for path in paths:
        if not path.is_file():
            continue
        document = json.loads(path.read_bytes())
        files[path.relative_to(directory).as_posix()] = {'sha256': sha256(path), 'nativeIDs': native_ids(document)}
        if 'configuration' in document:
            config = document['configuration']
            configurations[json.dumps(config, sort_keys=True)] = config
        for run in document.get('runs', []):
            if run['tool']['driver']['name'] == 'usdz-validator':
                versions.add(run['tool']['driver']['version'])
                config = run['properties']['configuration']
                configurations[json.dumps(config, sort_keys=True)] = config
        if 'validatorVersion' in document:
            versions.add(document['validatorVersion'])
    if len(files) != 86 or versions != {'0.1.0'} or not configurations:
        raise ValueError('missing corpus, configuration or v0.1 validator version evidence')
    manifest = {'schemaVersion': 1, 'inputs': inputs,
                'configurations': [configurations[key] for key in sorted(configurations)],
                'validatorVersions': sorted(versions), 'files': files}
    (directory / 'compatibility-manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
    return manifest


def checked_manifest(directory):
    manifest = json.loads((directory / 'compatibility-manifest.json').read_text())
    if manifest.get('schemaVersion') != 1 or not all(manifest.get(key) for key in
            ('inputs', 'configurations', 'validatorVersions', 'files')):
        raise ValueError(f'{directory}: incomplete compatibility manifest')
    expected = set(manifest['files'])
    actual = {path.relative_to(directory).as_posix() for sub in ('exports', 'checked-in')
              for path in (directory / sub).rglob('*') if path.is_file()}
    if expected != actual:
        raise ValueError(f'{directory}: missing or unmanifested exports')
    for name, entry in manifest['files'].items():
        relative = Path(name)
        if relative.is_absolute() or '..' in relative.parts or relative.parts[0] not in ('exports', 'checked-in'):
            raise ValueError(f'{directory}: unsafe export path')
        path = directory / relative
        if sha256(path) != entry['sha256'] or native_ids(json.loads(path.read_bytes())) != entry['nativeIDs']:
            raise ValueError(f'{path}: bytes or native occurrence IDs differ from manifest')
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('baseline', type=Path)
    parser.add_argument('current', type=Path)
    args = parser.parse_args()
    try:
        baseline, current = checked_manifest(args.baseline), checked_manifest(args.current)
        if baseline != current:
            raise ValueError('fixture/configuration/validator versions or exact export manifests differ')
        for name in baseline['files']:
            if (args.baseline / name).read_bytes() != (args.current / name).read_bytes():
                raise ValueError(f'{name}: exact canonical bytes differ')
        print(json.dumps({'compatibilityStatus': 'PASS', 'documents': len(baseline['files']),
                          'note': 'Byte compatibility only; inspect both host summaries and manual matrix before release.'}))
        return 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(json.dumps({'compatibilityStatus': 'FAIL', 'reason': str(error)}), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())

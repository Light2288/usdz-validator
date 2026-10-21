#!/usr/bin/env python3
"""Offline, development-only schema and compatibility corpus verification (MIT)."""
import argparse
from functools import lru_cache
import hashlib
import json
from pathlib import Path
import sys
import unittest

from jsonschema import Draft202012Validator, FormatChecker
from jsonschema.validators import validator_for
from referencing import Registry, Resource
from referencing.exceptions import NoSuchResource

ROOT = Path(__file__).resolve().parents[1]
SARIF_URL = 'https://docs.oasis-open.org/sarif/sarif/v2.1.0/os/schemas/sarif-schema-2.1.0.json'
SCHEMAS = {
    'report': 'Schemas/report-v1.schema.json',
    'catalogue': 'Schemas/catalogue-v1.schema.json',
    'budget-config': 'Schemas/budget-config-v1.schema.json',
    'sarif': 'Tests/Schemas/sarif-2.1.0.schema.json',
}
CATEGORIES = ['archiveSpecification', 'appleCompatibility', 'policy', 'validatorLimitation']
SEVERITIES = ['error', 'warning', 'note']


def read_json(path):
    # Reject duplicate keys and trailing data before schema validation loses lexical evidence.
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f'duplicate JSON key: {key}')
            result[key] = value
        return result
    def reject_constant(value):
        raise ValueError(f'non-JSON numeric constant: {value}')

    return json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=unique,
                      parse_constant=reject_constant)


def no_retrieval(uri):
    raise NoSuchResource(ref=uri)


@lru_cache(maxsize=1)
def local_registry():
    resources = []
    for path in SCHEMAS.values():
        schema = read_json(ROOT / path)
        resource = Resource.from_contents(schema)
        resources.append((schema['$id'], resource))
        if path == SCHEMAS['sarif']:
            resources.append((SARIF_URL, resource))
    # No network, filesystem fallback or implicit retriever is available.
    return Registry(retrieve=no_retrieval).with_resources(resources)


@lru_cache(maxsize=4)
def validator(kind):
    schema = read_json(ROOT / SCHEMAS[kind])
    cls = validator_for(schema)
    cls.check_schema(schema)
    return cls(schema, registry=local_registry(), format_checker=FormatChecker())


def subvalidator(name):
    return Draft202012Validator({'$ref': f'urn:usdz-validation-kit:report:1#/$defs/{name}'},
                                registry=local_registry())


def sarif_contract_errors(document):
    """UVK's provenance/run contract supplements the unmodified published SARIF schema.

    SARIF property bags intentionally allow arbitrary content. These checks protect
    UVK meaning without narrowing the upstream format or forbidding future rule IDs.
    """
    errors = []
    try:
        runs = document['runs']
        if len(runs) not in [1, 2]:
            return ['UVK requires one native run and an optional requested checker run']
        native = runs[0]
        props = native['properties']
        configuration = props['configuration']
        if not subvalidator('configuration').is_valid(configuration):
            errors.append('invalid effective configuration')
        requested = configuration['externalCheck'] == 'usdchecker'
        if len(runs) != (2 if requested else 1):
            errors.append('external request and run count differ')
        for index, run in enumerate(runs):
            expected = 'native' if index == 0 else 'usdchecker'
            properties = run['properties']
            driver = run['tool']['driver']
            if driver['name'] != ('usdz-validator' if index == 0 else 'usdchecker'):
                errors.append('run driver/order differs')
            if properties['provenance']['kind'] != expected:
                errors.append('run provenance differs')
            if not subvalidator('counts').is_valid(properties['counts']):
                errors.append('invalid separate counts')
            counts = {'bySeverity': dict.fromkeys(SEVERITIES, 0),
                      'byCategory': dict.fromkeys(CATEGORIES, 0)}
            for result in run['results']:
                result_props = result['properties']
                provenance = result_props['provenance']
                if provenance['kind'] != expected:
                    errors.append('result provenance merged into wrong run')
                if index == 0 and result['ruleId'] == 'USDCK-001':
                    errors.append('external result merged into native run')
                if not result['partialFingerprints']['uvkOccurrence/v1']:
                    errors.append('missing occurrence fingerprint')
                if expected == 'native' and not isinstance(provenance.get('validatorVersion'), str):
                    errors.append('missing native validator version')
                if expected == 'usdchecker' and provenance.get('tool') != 'usdchecker':
                    errors.append('missing checker provenance tool')
                if provenance.get('version', '') is None:
                    errors.append('unavailable SARIF provenance version must be omitted')
                counts['bySeverity'][result['level']] += 1
                counts['byCategory'][result_props['category']] += 1
                for location in result.get('locations', []):
                    physical = location.get('physicalLocation', {})
                    region = physical.get('region', {})
                    if 'byteOffset' in region and region['byteOffset'] < 0:
                        errors.append('UVK byte offsets must identify a real archive byte')
                    if any(key in region for key in ['startLine', 'startColumn', 'endLine', 'endColumn']):
                        errors.append('USDA coordinates cannot be physical ZIP lines')
            if counts != properties['counts']:
                errors.append('counts differ from their own run results')
            invocation = run['invocations'][0]
            if len(run['invocations']) != 1:
                errors.append('expected one invocation per run')
            if index == 0:
                if invocation['executionSuccessful'] != (properties['validationStatus'] != 'error'):
                    errors.append('native invocation differs from operational outcome')
                # Budget nulls and evidence nulls remain legal; only unavailable model fields omit.
                if props['input'].get('byteSize', 0) is None:
                    errors.append('unavailable SARIF input byte size must be omitted')
                if not isinstance(properties['coverage']['isComplete'], bool):
                    errors.append('missing native coverage')
                continue
            checker = properties['externalCheck']
            nullable = ['phase', 'version', 'policy', 'outcome', 'exitCode', 'signal', 'terminationReason']
            if any(key in checker and checker[key] is None for key in nullable + ['sensitiveDetails']):
                errors.append('unavailable SARIF checker fields must be omitted')
            projected = {key: checker.get(key) for key in nullable}
            projected.update({key: checker[key] for key in ['requested', 'availability', 'status',
                'stdoutBytes', 'stderrBytes', 'hasStdout', 'hasStderr']})
            projected['findings'] = []
            if 'sensitiveDetails' in checker:
                projected['sensitiveDetails'] = checker['sensitiveDetails']
            if not subvalidator('external').is_valid(projected):
                errors.append('invalid checker properties')
            if checker['requested'] is not True:
                errors.append('unrequested checker run')
            successful = checker['status'] == 'completed' and checker.get('outcome') in [
                'noFailureReported', 'failureReported']
            if invocation['executionSuccessful'] != successful:
                errors.append('checker completion differs from invocation')
            if not successful and not invocation.get('toolExecutionNotifications'):
                errors.append('unsuccessful checker lacks notification')
            for source, target in [('exitCode', 'exitCode'), ('signal', 'exitSignalNumber')]:
                if checker.get(source) != invocation.get(target):
                    errors.append('checker process metadata differs from invocation')
        return errors
    except (KeyError, TypeError, IndexError) as error:
        return errors + [f'missing or invalid UVK contract field: {error}']


def validate_document(path, kind):
    document = read_json(path)
    errors = sorted(validator(kind).iter_errors(document), key=lambda e: str(list(e.absolute_path)))
    messages = [f'{list(error.absolute_path)}: {error.message}' for error in errors]
    if kind == 'sarif' and not messages:
        messages.extend(sarif_contract_errors(document))
    if messages:
        raise ValueError(f'{path}: ' + '\n'.join(messages))


def verify_corpus():
    for kind in SCHEMAS:
        validator(kind)
    manifest = read_json(ROOT / 'Tests/Schemas/manifest.json')
    for entry in manifest['entries']:
        path = ROOT / entry['path']
        if hashlib.sha256(path.read_bytes()).hexdigest() != entry['sha256']:
            raise ValueError(f'{path}: SHA-256 differs from reviewed manifest')
        if 'format' in entry:
            validate_document(path, entry['format'])
    return sum('format' in entry for entry in manifest['entries'])


def exported_kind(path):
    if path.suffix == '.sarif':
        return 'sarif'
    if path.suffix == '.json':
        if path.name.startswith(('catalogue', 'rule-catalogue')):
            return 'catalogue'
        if path.name.startswith(('budget', 'config')):
            return 'budget-config'
        if path.name.startswith(('report', 'external', 'state')):
            return 'report'
    raise ValueError(f'{path}: unsupported exported filename (see Tools/README.md)')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path, help='also verify exports in this directory')
    parser.add_argument('--self-test', action='store_true', help='also run independent contract mutation tests')
    args = parser.parse_args()
    try:
        count = verify_corpus()
        if args.directory is not None:
            if not args.directory.is_dir():
                raise ValueError(f'{args.directory}: expected an export directory')
            paths = sorted(path for path in args.directory.iterdir() if path.is_file())
            if not paths:
                raise ValueError(f'{args.directory}: no exported documents')
            for path in paths:
                validate_document(path, exported_kind(path))
            count += len(paths)
        if args.self_test:
            suite = unittest.defaultTestLoader.discover(str(ROOT / 'Tests'), pattern='test_schema_contracts.py')
            if not unittest.TextTestRunner(verbosity=1).run(suite).wasSuccessful():
                return 1
        print(f'Validated {count} documents with local schemas; no remote resolution.')
        return 0
    except (OSError, ValueError) as error:
        print(str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())

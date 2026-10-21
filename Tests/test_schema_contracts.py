"""Independent contract mutations: schemas must reject drift, not just parse examples (MIT)."""
import copy
import importlib.util
import hashlib
import json
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import shutil
import unittest
from unittest.mock import patch

from jsonschema import Draft202012Validator
from referencing.exceptions import Unresolvable

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('verify_schemas', ROOT / 'Scripts/verify-schemas.py')
verify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verify)


def golden(name):
    return json.loads((ROOT / 'Tests/Goldens' / name).read_text())


class SchemaContractTests(unittest.TestCase):
    def testReportRequiredFieldsAndTypes(self):
        valid = golden('report-incomplete-v1.json')
        check = verify.validator('report')
        self.assertTrue(check.is_valid(valid))
        for key in valid:
            missing = copy.deepcopy(valid)
            del missing[key]
            with self.subTest(missing=key):
                self.assertFalse(check.is_valid(missing))
        for path, value in [
            (['schemaVersion'], 2), (['schemaVersion'], True), (['exitCode'], '0'),
            (['exitCode'], 4), (['acceptedIncomplete'], 1),
            (['validationStatus'], 'valid'), (['gateDecision'], 'accepted'),
            (['configuration', 'profile'], 'general-v2'),
            (['configuration', 'budgets', 'archiveBytes'], 0),
            (['externalCheck', 'terminationReason'], 'crashed'),
            (['externalCheck', 'phase'], 'inspection'),
            (['externalCheck', 'availability'], 'installed'),
            (['externalCheck', 'status'], 'failed'),
            (['externalCheck', 'outcome'], 'passed'),
            (['nativeFindings', 0, 'evidence', 'bytes'], 1.25),
            (['nativeFindings', 0, 'evidence', 'bytes'], 9223372036854775808),
            (['nativeFindings', 0, 'location', 'archiveByteOffset'], -1),
            (['nativeFindings', 0, 'provenance', 'kind'], 'usdchecker'),
        ]:
            document = copy.deepcopy(valid)
            node = document
            for key in path[:-1]:
                node = node[key]
            node[path[-1]] = value
            with self.subTest(path=path, value=value):
                self.assertFalse(check.is_valid(document))

    def testNullOmissionAndAdditiveV1Compatibility(self):
        check = verify.validator('report')
        valid = golden('report-incomplete-v1.json')
        self.assertIsNone(valid['externalCheck']['terminationReason'])
        for path in [('input', 'byteSize'), ('externalCheck', 'signal'),
                     ('externalCheck', 'terminationReason'), ('nativeFindings',)]:
            changed = copy.deepcopy(valid)
            if len(path) == 2:
                del changed[path[0]][path[1]]
            else:
                del changed[path[0]]
            with self.subTest(missing=path):
                self.assertFalse(check.is_valid(changed))
        valid['futureOptional'] = {'anything': [1, None]}
        valid['nativeFindings'][0]['ruleID'] = 'FUTURE-UNREGISTERED-007'
        valid['nativeFindings'][0]['futureOptional'] = True
        self.assertTrue(check.is_valid(valid))
        for reason in [None, 'exited', 'uncaughtSignal', 'terminated', 'killed',
                       'launchError', 'invalidRequest', 'captureError', 'reapError']:
            valid['externalCheck']['terminationReason'] = reason
            self.assertTrue(check.is_valid(valid), reason)
        merged = copy.deepcopy(valid)
        merged['nativeFindings'][0]['provenance'] = {
            'kind': 'usdchecker', 'tool': 'usdchecker', 'version': None}
        self.assertFalse(check.is_valid(merged))
        merged = copy.deepcopy(valid)
        merged['externalCheck']['findings'] = valid['nativeFindings']
        self.assertFalse(check.is_valid(merged))

    def testCatalogueContract(self):
        check = verify.validator('catalogue')
        valid = golden('rule-catalogue-v1.json')
        self.assertTrue(check.is_valid(valid))
        for path, value in [(['schemaVersion'], 2), (['profile'], 'other'),
                            (['rules', 0, 'defaultSeverity'], 'fatal'),
                            (['rules', 0, 'family'], 'other'),
                            (['rules', 0, 'category'], 'security')]:
            changed = copy.deepcopy(valid)
            node = changed
            for key in path[:-1]:
                node = node[key]
            node[path[-1]] = value
            self.assertFalse(check.is_valid(changed), path)
        for key in valid['rules'][0]:
            changed = copy.deepcopy(valid)
            del changed['rules'][0][key]
            self.assertFalse(check.is_valid(changed), key)
        valid['rules'][0]['ruleID'] = 'FUTURE-001'
        valid['rules'][0]['optionalAddition'] = 'allowed'
        valid['optionalAddition'] = True
        self.assertTrue(check.is_valid(valid))

    def testStrictConfigValues(self):
        check = verify.validator('budget-config')
        self.assertTrue(check.is_valid({'schemaVersion': 1, 'budgets': {}}))
        keys = ['archiveBytes', 'fileBytes', 'fileCount', 'textureBytes',
                'totalTextureBytes', 'textureMaxDimension']
        for key in keys:
            for value in [None, 1, 9223372036854775807]:
                self.assertTrue(check.is_valid({'schemaVersion': 1, 'budgets': {key: value}}))
            for value in [True, False, 0, -1, 1.5, '1', [], {}, 9223372036854775808]:
                with self.subTest(key=key, value=value):
                    self.assertFalse(check.is_valid({'schemaVersion': 1, 'budgets': {key: value}}))
        for document in [{}, {'schemaVersion': 1}, {'budgets': {}},
                         {'schemaVersion': 2, 'budgets': {}},
                         {'schemaVersion': True, 'budgets': {}},
                         {'schemaVersion': 1, 'budgets': {}, 'future': 1},
                         {'schemaVersion': 1, 'budgets': {'future': 1}}]:
            self.assertFalse(check.is_valid(document), document)

    def testPublishedSARIFLocations(self):
        check = verify.validator('sarif')
        valid = golden('native-v1.sarif')
        self.assertTrue(check.is_valid(valid))
        for region in [{'byteOffset': -2}, {'byteOffset': '64'}, {'byteLength': -1},
                       {'startLine': 0}, {'byteOffset': None}]:
            changed = copy.deepcopy(valid)
            changed['runs'][0]['results'][0]['locations'][0]['physicalLocation']['region'] = region
            self.assertFalse(check.is_valid(changed), region)
        changed = copy.deepcopy(valid)
        changed['version'] = '2.0.0'
        self.assertFalse(check.is_valid(changed))
        # Locations express archive byte regions; USDA coordinates are logical properties.
        physical = valid['runs'][0]['results'][0]['locations'][0]['physicalLocation']
        self.assertEqual(physical['region'], {'byteOffset': 64})

    def testSARIFSeparateRunsAndProvenance(self):
        valid = golden('external-failure-v1.sarif')
        self.assertEqual(verify.sarif_contract_errors(valid), [])
        self.assertEqual(verify.sarif_contract_errors(golden('external-unavailable-v1.sarif')), [])
        changes = []
        merged = copy.deepcopy(valid)
        merged['runs'][0]['results'] += merged['runs'][1]['results']
        merged['runs'].pop()
        changes.append(merged)
        wrong = copy.deepcopy(valid)
        wrong['runs'][1]['results'][0]['properties']['provenance']['kind'] = 'native'
        changes.append(wrong)
        wrong = copy.deepcopy(valid)
        wrong['runs'][0]['properties']['provenance']['kind'] = 'usdchecker'
        changes.append(wrong)
        wrong = copy.deepcopy(valid)
        wrong['runs'][1]['invocations'][0]['executionSuccessful'] = False
        changes.append(wrong)
        wrong = copy.deepcopy(valid)
        wrong['runs'][1]['properties']['externalCheck']['version'] = None
        changes.append(wrong)
        wrong = copy.deepcopy(valid)
        wrong['runs'].reverse()
        changes.append(wrong)
        wrong = copy.deepcopy(valid)
        wrong['runs'][0]['results'][0]['locations'][0]['physicalLocation']['region'] = {'byteOffset': -1}
        changes.append(wrong)
        wrong = copy.deepcopy(valid)
        wrong['runs'][1]['properties']['counts']['bySeverity']['error'] = 0
        changes.append(wrong)
        wrong = copy.deepcopy(valid)
        wrong['runs'][0]['results'][0]['locations'][0]['physicalLocation']['region'] = {'startLine': 1}
        changes.append(wrong)
        for changed in changes:
            self.assertTrue(verify.sarif_contract_errors(changed))

    def testNoRemoteResolution(self):
        # Registry's default retrieval is deliberately disabled; even reachable URIs fail.
        for reference in ['https://example.com/schema.json', 'file:///tmp/schema.json',
                          'urn:usdz-validation-kit:unknown:1']:
            check = Draft202012Validator({'$ref': reference}, registry=verify.local_registry())
            with patch.object(socket, 'create_connection', side_effect=AssertionError('network used')):
                with self.assertRaises(Exception) as caught:
                    check.validate({})
            self.assertIsInstance(caught.exception, Unresolvable)
        # Registered cross-schema reference exercises the real verifier registry.
        self.assertTrue(verify.validator('catalogue').is_valid(golden('rule-catalogue-v1.json')))

    def testCorpusAndManifestIntegrity(self):
        self.assertTrue((ROOT / 'Tests/Schemas/manifest.json').is_file())
        self.assertTrue((ROOT / 'Examples/budgets.json').is_file())
        self.assertTrue((ROOT / 'Tests/Goldens/external-success-v1.json').is_file())
        self.assertTrue((ROOT / 'Tests/Goldens/external-failure-v1.json').is_file())
        self.assertEqual(verify.verify_corpus(), 13)

    def testDurableIndependentRecipes(self):
        readme = (ROOT / 'Tools/README.md').read_text()
        expected = {
            'json': ('37b829f581c42cb42d3e9c08c5e6c2db3ae2d0278e7d130d5338af8a5939802b',
                     ['report-complete-v1.json', 'report-incomplete-v1.json', 'report-operational-v1.json',
                      'external-success-v1.json', 'external-failure-v1.json']),
            'sarif': ('67c7e3307e2b8ac83bdaa89e6d554051bae8d3bd251979d75c61e3952c3edc30',
                      ['native-v1.sarif', 'external-unavailable-v1.sarif', 'external-failure-v1.sarif']),
        }
        for name, (digest, filenames) in expected.items():
            source = readme.split(f'<!-- uvk-{name}-recipe -->\n```python\n', 1)[1].split('```', 1)[0]
            self.assertEqual(hashlib.sha256(source.encode()).hexdigest(), digest)
            with tempfile.TemporaryDirectory() as temporary:
                directory = Path(temporary)
                fixtures = directory / 'Tests/Goldens'
                fixtures.mkdir(parents=True)
                shutil.copyfile(ROOT / 'Tests/Goldens/rule-catalogue-v1.json', fixtures / 'rule-catalogue-v1.json')
                script = directory / 'literal-recipe.py'
                script.write_text(source)
                subprocess.run([sys.executable, str(script)], cwd=directory, check=True, capture_output=True)
                for filename in filenames:
                    self.assertEqual((fixtures / filename).read_bytes(),
                                     (ROOT / 'Tests/Goldens' / filename).read_bytes(), filename)


if __name__ == '__main__':
    unittest.main()

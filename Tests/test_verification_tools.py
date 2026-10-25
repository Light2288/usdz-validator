"""MIT release evidence and exact cross-host export regressions; no downloads."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'Scripts/compare-compatibility.py'


def tool():
    spec = importlib.util.spec_from_file_location('compatibility', SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def module_fixed_exports():
    names = {f'report-{kind}-v1.{suffix}' for kind in ('complete', 'incomplete', 'operational')
             for suffix in ('json', 'sarif')}
    names.update(f'{kind}-v1.sarif' for kind in ('native', 'external-unavailable', 'external-failure'))
    names.update(f'external-{kind}-v1.json' for kind in ('success', 'failure'))
    names.update(f'catalogue-{profile}-v1.json' for profile in ('apple', 'general'))
    names.update(f'report-usdc-{kind}-v1.{suffix}' for kind in ('complete', 'partial', 'malformed', 'duplicates')
                 for suffix in ('json', 'sarif'))
    for state in ('not-requested', 'unavailable', 'unsupported', 'unsafe', 'success', 'failure',
                  'missing-outcome', 'launch', 'invalid-request', 'capture', 'reap', 'signal',
                  'timeout', 'output-cap', 'failure-unknown-version'):
        names.update(f'state-{state}{sensitive}.{suffix}' for sensitive in ('', '-sensitive')
                     for suffix in ('json', 'sarif'))
    return sorted(names)


class VerificationToolTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)

    def evidence(self):
        module = tool()
        environment = {key: 'observed value' for key in module.ENVIRONMENT_FIELDS}
        environment['role'] = 'current'
        environment['architecture'] = 'arm64'
        result = {'environment': environment, 'steps': [], 'matrix': {
            'baseline': 'UNVERIFIED', 'current': 'PASS',
            'crossHost': 'UNVERIFIED', 'python312': 'UNVERIFIED'},
            'installedCheckerSmoke': {'status': 'SKIPPED', 'reason': 'not requested'}}
        for name in module.REQUIRED_STEPS:
            for stream in ('stdout', 'stderr'):
                (self.folder / f'{name}.{stream}').write_text('observed evidence\n')
            result['steps'].append({'name': name, 'status': 'PASS', 'exitCode': 0,
                'command': ['observed', name], 'stdout': f'{name}.stdout',
                'stderr': f'{name}.stderr'})
        return module, result

    def testObservedHostTabsAndBaselineAreRecognizedExactly(self):
        module = tool()
        current = {'os': 'ProductName:\t\tmacOS\nProductVersion:\t\t27.0.1\nBuildVersion:\t26A434',
                   'xcode': 'Xcode 27.1\nBuild version 27A9275',
                   'swift': 'Apple Swift version 6.4 (swiftlang-6.4.0.34.1)\nTarget: arm64-apple-macosx27.0.0'}
        self.assertEqual(module.designated_role(current), 'current')
        baseline = {'os': 'ProductVersion:\t15.0', 'xcode': 'Xcode 16.0\nBuild version example',
                    'swift': 'Apple Swift version 6.0 (swiftlang-example)'}
        self.assertEqual(module.designated_role(baseline), 'baseline')
        self.assertEqual(module.designated_role({**current, 'xcode': 'Xcode 28.0'}), 'unrecognized')

    def testMissingBaselineIsUnverifiedAndSmokeIsSkipped(self):
        module, result = self.evidence()
        status = module.evaluate_evidence(result, self.folder)
        self.assertEqual(status['currentHostStatus'], 'PASS')
        self.assertEqual(status['releaseStatus'], 'UNVERIFIED')
        self.assertEqual(result['installedCheckerSmoke']['status'], 'SKIPPED')
        del result['matrix']['baseline']
        self.assertEqual(module.evaluate_evidence(result, self.folder)['releaseStatus'], 'UNVERIFIED')

    def testPostGateFailureCannotPass(self):
        module, result = self.evidence()
        result['matrix'] = dict.fromkeys(('current', 'baseline', 'crossHost', 'python312'), 'PASS')
        result['error'] = 'resource evidence copy failed'
        self.assertEqual(module.evaluate_evidence(result, self.folder)['releaseStatus'], 'FAIL')

    def testMissingEnvironmentCannotPass(self):
        module, result = self.evidence()
        for key in module.ENVIRONMENT_FIELDS:
            candidate = copy.deepcopy(result)
            del candidate['environment'][key]
            self.assertNotEqual(module.evaluate_evidence(candidate, self.folder)['releaseStatus'], 'PASS', key)
            self.assertEqual(module.evaluate_evidence(candidate, self.folder)['currentHostStatus'], 'FAIL', key)

    def testEveryRequiredStepMustRunAndPreserveEvidence(self):
        module, result = self.evidence()
        for name in module.REQUIRED_STEPS:
            for change in ({'status': 'SKIPPED'}, {'exitCode': 17}, {'stdout': 'missing'}):
                candidate = copy.deepcopy(result)
                next(row for row in candidate['steps'] if row['name'] == name).update(change)
                self.assertEqual(module.evaluate_evidence(candidate, self.folder)['currentHostStatus'], 'FAIL', (name, change))
            candidate = copy.deepcopy(result)
            candidate['steps'] = [row for row in candidate['steps'] if row['name'] != name]
            self.assertEqual(module.evaluate_evidence(candidate, self.folder)['currentHostStatus'], 'FAIL', name)

    def exports(self, directory):
        directory.mkdir()
        (directory / 'exports').mkdir()
        (directory / 'exports/report.json').write_text('{"nativeFindings":[]}\n')
        manifest = {'schemaVersion': 1, 'inputs': {'fixture': 'sha256'},
                    'configurations': [{'profile': 'general-v1'}], 'validatorVersions': ['0.2.0'],
                    'files': {'exports/report.json': {'sha256': tool().sha256(directory / 'exports/report.json'),
                        'nativeIDs': []}}}
        (directory / 'compatibility-manifest.json').write_text(json.dumps(manifest))
        return manifest

    def compare(self, baseline, current):
        return subprocess.run(['python3', str(SCRIPT), str(baseline), str(current)], capture_output=True)

    def testExactComparisonRejectsManifestByteAndNativeIDChanges(self):
        baseline, current = self.folder / 'baseline', self.folder / 'current'
        manifest = self.exports(baseline)
        self.exports(current)
        self.assertEqual(self.compare(baseline, current).returncode, 0)
        for key, value in [('inputs', {'fixture': 'different'}),
                           ('configurations', [{'profile': 'apple-portable-v1'}]),
                           ('validatorVersions', ['9.9'])]:
            changed = {**manifest, key: value}
            (current / 'compatibility-manifest.json').write_text(json.dumps(changed))
            self.assertNotEqual(self.compare(baseline, current).returncode, 0, key)
        (current / 'compatibility-manifest.json').write_text(json.dumps(manifest))
        (current / 'exports/report.json').write_text('{"nativeFindings":[]} \n')
        self.assertNotEqual(self.compare(baseline, current).returncode, 0)
        (current / 'exports/report.json').write_text('{"nativeFindings":[]}\n')
        changed = copy.deepcopy(manifest)
        changed['files']['exports/report.json']['nativeIDs'] = ['forged']
        for directory in (baseline, current):
            (directory / 'compatibility-manifest.json').write_text(json.dumps(changed))
        self.assertNotEqual(self.compare(baseline, current).returncode, 0)

    def testMissingOrExtraExportCannotCompareEqual(self):
        baseline, current = self.folder / 'baseline', self.folder / 'current'
        self.exports(baseline)
        self.exports(current)
        (current / 'exports/extra.json').write_text('{}\n')
        self.assertNotEqual(self.compare(baseline, current).returncode, 0)
        (current / 'exports/extra.json').unlink()
        (current / 'exports/report.json').unlink()
        self.assertNotEqual(self.compare(baseline, current).returncode, 0)

    def reviewed_root(self):
        root = self.folder / 'root'
        root.mkdir()
        names = {'.swift-format', 'Package.swift', 'Package.resolved',
                 'Tools/requirements-schema.lock', 'Tests/Fixtures/manifest.json',
                 'Tests/Schemas/manifest.json',
                 'Tests/USDZValidationTests/GoldenCompatibilityTests.swift',
                 'Tests/USDZValidationTests/USDCReportTests.swift'}
        for manifest_path in ('Tests/Fixtures/manifest.json', 'Tests/Schemas/manifest.json'):
            names.update(row['path'] for row in json.loads((ROOT / manifest_path).read_text())['entries'])
        names.update(path.relative_to(ROOT).as_posix()
                     for path in (ROOT / 'Sources').rglob('*') if path.is_file())
        for name in names:
            destination = root / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes((ROOT / name).read_bytes())
        directory = self.folder / 'bound'
        (directory / 'exports').mkdir(parents=True)
        for name in module_fixed_exports():
            (directory / 'exports' / name).write_bytes(
                (ROOT / 'Tests/Goldens/report-complete-v1.json').read_bytes())
        return root, directory

    def testV02BindsEveryProductInputAndExactly102Documents(self):
        module = tool()
        root, directory = self.reviewed_root()
        manifest = module.write_manifest(root, directory)
        self.assertEqual(len(manifest['files']), 102)
        self.assertEqual(manifest['validatorVersions'], ['0.2.0'])
        for path in (root / 'Sources').rglob('*'):
            if path.is_file() and path.suffix in ('.swift', '.c', '.h'):
                self.assertEqual(manifest['inputs'][path.relative_to(root).as_posix()], module.sha256(path))
        for name in ('Sources/CUSDCCompression/LICENSE', 'Sources/CUSDCCompression/source-manifest.json', 'NOTICE'):
            self.assertEqual(manifest['inputs'][name], module.sha256(root / name))
        for name in ('Sources/CUSDCCompression/lz4.c', 'Sources/CUSDCCompression/include/lz4.h',
                     'Sources/CUSDCCompression/LICENSE', 'Sources/CUSDCCompression/source-manifest.json', 'NOTICE'):
            path = root / name
            original = path.read_bytes()
            path.write_bytes(original + b'\n')
            with self.subTest(changed=name), self.assertRaises(ValueError):
                module.write_manifest(root, directory)
            path.write_bytes(original)
            path.unlink()
            with self.subTest(missing=name), self.assertRaises((ValueError, OSError)):
                module.write_manifest(root, directory)
            path.write_bytes(original)
        extra = root / 'Sources/CUSDCCompression/unreviewed.c'
        extra.write_text('int unreviewed;\n')
        with self.assertRaises(ValueError):
            module.write_manifest(root, directory)

    def testFixedExportCountsRejectAddedRemovedAndHistoricalProduct(self):
        module = tool()
        root, directory = self.reviewed_root()
        module.write_manifest(root, directory)
        extra = directory / 'exports/report-extra.json'
        extra.write_text('{}\n')
        with self.assertRaises(ValueError):
            module.write_manifest(root, directory)
        extra.unlink()
        first = directory / 'exports/report-complete-v1.json'
        original = first.read_bytes()
        first.unlink()
        with self.assertRaises(ValueError):
            module.write_manifest(root, directory)
        historical = json.loads(original)
        historical['tool']['version'] = '0.1.0'
        first.write_text(json.dumps(historical))
        with self.assertRaises(ValueError):
            module.write_manifest(root, directory)
        first.write_bytes(original)
        first.rename(extra)
        with self.assertRaises(ValueError):
            module.write_manifest(root, directory)

    def testRunnerRecordsEarlyFailure(self):
        shim = self.folder / 'bin'
        shim.mkdir()
        swift = shim / 'swift'
        swift.write_text('#!/bin/sh\necho deliberate-tool-failure >&2\nexit 17\n')
        swift.chmod(0o755)
        destination = self.folder / 'evidence'
        environment = {**os.environ, 'PATH': str(shim) + os.pathsep + os.environ['PATH']}
        result = subprocess.run(['sh', str(ROOT / 'Scripts/verify-release.sh'),
                                 '--evidence-dir', str(destination)], env=environment,
                                capture_output=True, timeout=30)
        self.assertNotEqual(result.returncode, 0)
        summary = json.loads((destination / 'summary.json').read_text())
        self.assertEqual(summary['releaseStatus'], 'FAIL')
        self.assertEqual(summary['steps'][0]['status'], 'FAIL')
        self.assertIn('deliberate-tool-failure', (destination / summary['steps'][0]['stderr']).read_text())
        self.assertEqual(summary['installedCheckerSmoke']['status'], 'SKIPPED')

    def testReleaseHasNoHooks(self):
        executable = Path(os.environ.get('UVK_RELEASE_EXECUTABLE', ROOT / '.build/release/usdz-validator'))
        if not executable.is_file():
            self.skipTest('Release executable absent; release runner must build and rerun this test')
        command = [str(executable), 'validate', str(ROOT / 'Tests/Fixtures/valid-usda.usdz'), '--format', 'json']
        clean = dict(os.environ)
        for key in ('UVK_CLI_TEST_SCENARIO', 'UVK_CLI_TEST_EXECUTABLE', 'UVK_CLI_EXECUTABLE'):
            clean.pop(key, None)
        normal_release = subprocess.run(command, env=clean, capture_output=True, timeout=15)
        self.assertEqual(normal_release.returncode, 0)
        for scenario in ('internalFailure', 'checkerUnavailable', 'checkerSuccess', 'checkerFailure', 'encodingCap'):
            environment = {**clean, 'UVK_CLI_TEST_SCENARIO': scenario,
                           'UVK_CLI_TEST_EXECUTABLE': '/invalid', 'UVK_CLI_EXECUTABLE': '/invalid'}
            hooked = subprocess.run(command, env=environment, capture_output=True, timeout=15)
            self.assertEqual(hooked.returncode, normal_release.returncode, scenario)
            self.assertEqual(normal_release.stdout, hooked.stdout, scenario)
            self.assertEqual(normal_release.stderr, hooked.stderr, scenario)


class ResourceVerificationTests(unittest.TestCase):
    def resource_tool(self):
        spec = importlib.util.spec_from_file_location('resources', ROOT / 'Scripts/verify-resources.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    # Dropping a costly binary row must fail acceptance, even when the remaining rows pass.
    def testRequiredBinaryResourceRowsCannotDisappear(self):
        module = self.resource_tool()
        names = {case[0] for case in module.recipes()}
        required = {'usdc-metadata-16-mib', 'usdc-metadata-over-block',
                    'usdc-dense-250000', 'usdc-items-250001', 'usdc-utf8-4096',
                    'usdc-utf8-4097', 'usdc-shared-deep', 'usdc-depth-33',
                    'usdc-aggregate-near', 'usdc-aggregate-over', 'usdc-work-over',
                    'usdc-large-layer-small-metadata', 'usdc-mixed-occurrences',
                    'usdc-near-report-json', 'usdc-near-report-sarif',
                    'usdc-report-cap-json', 'usdc-report-cap-sarif',
                    'usdc-numeric-0', 'usdc-numeric-250000', 'usdc-numeric-250001',
                    'usdc-numeric-max', 'usdc-compressed-numeric-0',
                    'usdc-compressed-numeric-250000', 'usdc-compressed-numeric-250001',
                    'usdc-compressed-numeric-max', 'usdc-shared-numeric-near',
                    'usdc-numeric-aggregate', 'usdc-numeric-aggregate-over',
                    'usdc-truncated-numeric-header',
                    'usdc-unknown-numeric-flags', 'usdc-shared-asset-items-over'}
        self.assertTrue(required <= names, sorted(required - names))
        self.assertEqual(len(names), len(list(module.recipes())))

    def testMissingSkippedMisclassifiedOrOverBudgetRowsCannotPass(self):
        module = self.resource_tool()
        self.assertTrue(hasattr(module, 'validate_rows'), 'required-row acceptance validator missing')
        if not hasattr(module, 'validate_rows'):
            return
        rows = [dict(case=case[0], status='PASS', peak_rss_bytes=1, elapsed_seconds=1,
                     exit=case[3], expectation_checked=True,
                     expected_rule_reason=module.BINARY_EXPECTATIONS.get(case[0]),
                     typed_findings=([{'ruleID': module.BINARY_EXPECTATIONS[case[0]][0],
                         'evidence': {module.BINARY_EXPECTATIONS[case[0]][1]:
                                      module.BINARY_EXPECTATIONS[case[0]][2]}}]
                         if case[0] in module.BINARY_EXPECTATIONS else [])) for case in module.recipes()]
        self.assertEqual(module.validate_rows(rows), [])
        self.assertEqual(module.validate_rows(json.loads(json.dumps(rows))), [])
        for edit in ('missing', 'skipped', 'rss', 'elapsed', 'classification', 'exit', 'reason'):
            changed = copy.deepcopy(rows)
            if edit == 'missing':
                changed.pop()
            elif edit == 'skipped':
                changed[-1]['status'] = 'SKIPPED'
            elif edit == 'rss':
                changed[-1]['peak_rss_bytes'] = 268_435_457
            elif edit == 'elapsed':
                changed[-1]['elapsed_seconds'] = 60.001
            elif edit == 'classification':
                changed[-1]['expectation_checked'] = False
            elif edit == 'reason':
                next(row for row in changed if row['case'] == 'usdc-work-over')['typed_findings'] = [
                    {'ruleID': 'UVK-RES-001', 'evidence': {'resource': 'usdcItems'}}]
            else:
                changed[-1]['exit'] = 99
            with self.subTest(edit=edit):
                self.assertTrue(module.validate_rows(changed))

    # A syntactically valid report with the wrong resource reason cannot certify a quota row.
    def testResourceFindingAndReasonAreMandatory(self):
        module = self.resource_tool()
        self.assertTrue(hasattr(module, 'check_expected_findings'), 'typed resource proof missing')
        if not hasattr(module, 'check_expected_findings'):
            return
        findings = [{'ruleID': 'UVK-RES-001', 'evidence': {'resource': 'usdcDecodeBytes'}}]
        self.assertEqual(module.check_expected_findings('usdc-aggregate-over', findings), [])
        self.assertTrue(module.check_expected_findings('usdc-aggregate-over', []))
        findings[0]['evidence']['resource'] = 'tokenCount'
        self.assertTrue(module.check_expected_findings('usdc-aggregate-over', findings))

    def testActualWorkUsesSharedDictionaryTraversal(self):
        module = self.resource_tool()
        cases = {case[0]: case for case in module.binary_recipes()}
        entries = cases['usdc-work-over'][1]
        payload = b''.join(module.chunks(entries[0][1]))
        # Sixteen independently bounded map entries, each with string key 0, a
        # relative edge of 8, and a numeric leaf sharing the 416-byte count header.
        self.assertEqual(int.from_bytes(payload[88:96], 'little'), 16)
        for index in range(16):
            start = 96 + 20 * index
            self.assertEqual(payload[start:start+4], bytes(4))
            self.assertEqual(int.from_bytes(payload[start+4:start+12], 'little'), 8)
            self.assertEqual(int.from_bytes(payload[start+12:start+20], 'little'),
                             0x80030000000001a0)
        self.assertEqual(int.from_bytes(payload[416:424], 'little'), 2**64-1)

    def testArbitraryRecipeUnitsAreWrittenInAtMost64KiBChunks(self):
        module = self.resource_tool()
        parts = list(module.chunks([(b'x' * 70_000, 2)]))
        self.assertEqual(b''.join(parts), b'x' * 140_000)
        self.assertLessEqual(max(map(len, parts)), 65_536)


if __name__ == '__main__':
    unittest.main()

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
                    'configurations': [{'profile': 'general-v1'}], 'validatorVersions': ['0.1.0'],
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


if __name__ == '__main__':
    unittest.main()

#!/bin/sh
# Original MIT local release verification. No publication or hosted workflow.
set -eu
cd "$(dirname "$0")/.."
exec python3 - "$@" <<'PY'
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys

root = Path.cwd()
spec = importlib.util.spec_from_file_location('compatibility', root / 'Scripts/compare-compatibility.py')
compat = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compat)
parser = argparse.ArgumentParser(description='Run local gates, preserve evidence, and report unverified release environments.')
parser.add_argument('--evidence-dir', type=Path, required=True)
parser.add_argument('--installed-checker-smoke', action='store_true')
args = parser.parse_args()
folder = args.evidence_dir.resolve()
if folder.exists() and any(folder.iterdir()):
    parser.error('evidence directory must be empty; preserve previous evidence and select a new directory')
folder.mkdir(parents=True, exist_ok=True)
(folder / 'logs').mkdir()
environment = dict(os.environ)
# Every optional expensive/installed check is controlled by this runner, not inherited.
for key in ('UVK_RUN_RESOURCE_TESTS', 'UVK_RUN_INSTALLED_CHECKER', 'UVK_COMPAT_EXPORT_DIR',
            'UVK_CLI_EXECUTABLE', 'UVK_CLI_TEST_EXECUTABLE', 'UVK_CLI_TEST_SCENARIO'):
    environment.pop(key, None)
result = {'schemaVersion': 1, 'environment': {}, 'steps': [],
          'matrix': {'current': 'UNVERIFIED', 'baseline': 'UNVERIFIED',
                     'crossHost': 'UNVERIFIED', 'python312': 'UNVERIFIED'},
          'installedCheckerSmoke': {'status': 'SKIPPED', 'reason': 'not requested (opt-in only)'},
          'notes': ['Ordinary Swift runs explicitly skip real-size resources and installed checker smoke.',
                    'A local PASS cannot establish baseline, cross-host compatibility or Python 3.12 verification.']}


def finish():
    assessment = compat.evaluate_evidence(result, folder)
    result.update(assessment)
    role = result['environment'].get('role')
    if role in ('current', 'baseline'):
        result['matrix'][role] = assessment['currentHostStatus']
    (folder / 'summary.json').write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    print(json.dumps({key: result[key] for key in ('currentHostStatus', 'releaseStatus', 'matrix', 'installedCheckerSmoke')}), flush=True)
    return 0 if assessment['currentHostStatus'] == 'PASS' else 1


def run(name, command, extra=None, check=None):
    stdout, stderr = f'logs/{name}.stdout', f'logs/{name}.stderr'
    env = {**environment, **(extra or {})}
    row = {'name': name, 'command': command, 'environment': extra or {},
           'stdout': stdout, 'stderr': stderr, 'status': 'FAIL', 'exitCode': None}
    result['steps'].append(row)
    print(f'RUN {name}: {shlex.join(command)}', flush=True)
    with (folder / stdout).open('wb') as out, (folder / stderr).open('wb') as err:
        try:
            completed = subprocess.run(command, env=env, stdout=out, stderr=err)
            row['exitCode'] = completed.returncode
        except OSError as error:
            err.write((str(error) + '\n').encode())
    if row['exitCode'] == 0:
        try:
            if check:
                check((folder / stdout).read_text(errors='replace') + (folder / stderr).read_text(errors='replace'))
            row['status'] = 'PASS'
        except (ValueError, AssertionError, OSError, KeyError) as error:
            row['reason'] = str(error)
    print(f'{row["status"]} {name} (exit {row["exitCode"]})', flush=True)
    if row['status'] != 'PASS':
        raise RuntimeError(f'{name} failed; see {folder / stderr} and {folder / stdout}')


def observed_tests(text):
    if not re.search(r'Executed [1-9][0-9]* tests?', text) and not re.search(r'Ran [1-9][0-9]* tests?', text):
        raise ValueError('required test suite reported no executed tests')


def no_skipped_tests(text):
    observed_tests(text)
    if re.search(r'\bskipped\b', text, re.I):
        raise ValueError('required suite contains skipped tests')


try:
    commands = {
        'swift': ['swift', '--version'], 'xcode': ['xcodebuild', '-version'],
        'os': ['sw_vers'], 'architecture': ['uname', '-m'],
        'formatter': ['xcrun', 'swift-format', '--version'],
        'hardware': ['/usr/sbin/sysctl', 'hw.model', 'machdep.cpu.brand_string', 'hw.memsize'],
        'python': ['python3', '--version'], 'schemaPython': ['.venv/bin/python', '--version'],
        'storage': ['/bin/df', '-P', str(folder)],
        'developerDir': ['/usr/bin/xcode-select', '-p'],
    }
    row = {'name': 'environment', 'command': list(commands.values()), 'status': 'FAIL',
           'exitCode': None, 'stdout': 'logs/environment.stdout', 'stderr': 'logs/environment.stderr'}
    result['steps'].append(row)
    with (folder / row['stdout']).open('w') as out, (folder / row['stderr']).open('w') as err:
        for key, command in commands.items():
            out.write('$ ' + shlex.join(command) + '\n')
            completed = subprocess.run(command, env=environment, capture_output=True, text=True)
            out.write(completed.stdout)
            err.write(completed.stderr)
            row['exitCode'] = completed.returncode
            if completed.returncode != 0:
                raise RuntimeError(f'environment capture failed: {shlex.join(command)}')
            result['environment'][key] = completed.stdout.strip()
    selected = environment.get('DEVELOPER_DIR') or result['environment']['developerDir']
    environment['DEVELOPER_DIR'] = selected
    result['environment']['developerDir'] = selected
    result['environment']['inheritedDeveloperDir'] = os.environ.get('DEVELOPER_DIR')
    host = result['environment']
    host['role'] = compat.designated_role(host)
    if host['architecture'] != 'arm64' or host['role'] == 'unrecognized':
        raise RuntimeError('host is not either designated verification combination; see environment evidence')
    row['exitCode'], row['status'] = 0, 'PASS'
    print(f'PASS environment: {host["role"]}, DEVELOPER_DIR={selected}', flush=True)
    (folder / 'environment.json').write_text(json.dumps(host, indent=2) + '\n')
    if host['role'] == 'current':
        run('format-check', ['xcrun', 'swift-format', 'lint', '--strict', '--recursive',
            '--configuration', '.swift-format', 'Sources', 'Tests', 'Package.swift'])
    else:
        result['steps'].append({'name': 'format-check', 'status': 'SKIPPED',
            'reason': 'Baseline formatter recorded only; designated current host owns lint evidence.'})
    resolved = root / 'Package.resolved'
    before = resolved.read_bytes()
    (folder / 'Package.resolved.before').write_bytes(before)
    run('resolve', ['swift', 'package', 'resolve'])
    run('resolved-lock', ['python3', '-c',
        'from pathlib import Path; import sys; sys.exit(0 if Path("Package.resolved").read_bytes() == Path(sys.argv[1]).read_bytes() else "Package.resolved changed during resolve")',
        str(folder / 'Package.resolved.before')])
    result['packageResolvedSHA256'] = compat.sha256(resolved)
    run('build', ['swift', 'build', '--build-tests'])
    run('test', ['swift', 'test'], check=observed_tests)
    run('cli-test', ['sh', 'Scripts/test-cli.sh'], check=no_skipped_tests)
    run('release-build', ['swift', 'build', '-c', 'release'])
    release_bin = subprocess.run(['swift', 'build', '-c', 'release', '--show-bin-path'],
        env=environment, capture_output=True, text=True, check=True).stdout.strip()
    executable = str(Path(release_bin) / 'usdz-validator')
    result['releaseExecutable'] = {'path': executable, 'sha256': compat.sha256(Path(executable))}
    run('release-test', ['swift', 'test', '-c', 'release'], check=observed_tests)
    run('address-sanitizer', ['swift', 'test', '--sanitize=address'], check=observed_tests)
    run('schema-self-test', ['.venv/bin/python', 'Scripts/verify-schemas.py', '--self-test'], check=observed_tests)
    run('schema-tests', ['.venv/bin/python', '-m', 'unittest', 'discover', '-s', 'Tests', '-p', 'test_schema_contracts.py'], check=no_skipped_tests)
    run('verification-tools', ['python3', '-m', 'unittest', 'discover', '-s', 'Tests', '-p', 'test_verification_tools.py'],
        extra={'UVK_RELEASE_EXECUTABLE': executable}, check=no_skipped_tests)
    run('examples', ['python3', 'Scripts/verify-examples.py', '--executable', executable])
    exports = folder / 'exports'
    exports.mkdir()
    run('golden-export', ['swift', 'test', '--filter', 'GoldenCompatibilityTests'],
        extra={'UVK_COMPAT_EXPORT_DIR': str(exports)}, check=no_skipped_tests)
    run('export-schemas', ['.venv/bin/python', 'Scripts/verify-schemas.py', '--directory', str(exports), '--expected-export-count', '81'])
    run('export-manifest', ['python3', '-c',
        'import importlib.util; from pathlib import Path; import sys; s=importlib.util.spec_from_file_location("c", "Scripts/compare-compatibility.py"); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); manifest=m.write_manifest(Path.cwd(), Path(sys.argv[1])); print("Bound",len(manifest["files"]),"documents to reviewed fixture/configuration/validator inputs and native IDs")', str(folder)])
    run('resource-tests', ['swift', 'test', '-c', 'release', '--filter', 'ResourceBoundaryTests'],
        extra={'UVK_RUN_RESOURCE_TESTS': '1'}, check=no_skipped_tests)
    run('resource-measurements', ['python3', 'Scripts/verify-resources.py', '--executable',
        '.build/release/usdz-validator', '--output', 'docs/verification/resource-results.md'])
    shutil.copyfile(root / 'docs/verification/resource-results.md', folder / 'resource-results.md')
    if args.installed_checker_smoke:
        run('installed-checker-smoke', ['swift', 'test', '--filter', 'InstalledCheckerSmokeTests'],
            extra={'UVK_RUN_INSTALLED_CHECKER': '1'}, check=observed_tests)
        text = (folder / 'logs/installed-checker-smoke.stdout').read_text() + (folder / 'logs/installed-checker-smoke.stderr').read_text()
        skipped = bool(re.search(r'\bskipped\b', text, re.I))
        result['installedCheckerSmoke'] = {'status': 'SKIPPED' if skipped else 'PASS',
            'reason': 'requested but unavailable/unsupported; see exact installed version/status in logs' if skipped else 'requested installed tool completed; see logs'}
except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
    result['error'] = str(error)
    print(f'FAIL: {error}', file=sys.stderr, flush=True)
    if args.installed_checker_smoke and result['steps'][-1]['name'] == 'installed-checker-smoke':
        result['installedCheckerSmoke'] = {'status': 'FAIL', 'reason': str(error)}
sys.exit(finish())
PY

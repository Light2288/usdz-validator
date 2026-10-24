#!/usr/bin/env python3
"""Original MIT resource recipes and Darwin release CLI measurement; no downloads.

Fixture generation, hashing and report verification happen outside /usr/bin/time.
Only the validator child contributes Darwin maximum RSS (reported in bytes).
"""
import argparse
import hashlib
import json
import os
import pathlib
import platform
import re
import shlex
import signal
import struct
import subprocess
import tempfile
import time
import zlib

MIB = 1_048_576
CHUNK = 65_536
RSS_LIMIT = 268_435_456
SECONDS_LIMIT = 60
REPORT_LIMIT = 33_554_432


def command_output(arguments):
    result = subprocess.run(arguments, capture_output=True, text=True, timeout=15)
    return (result.stdout or result.stderr).strip()


def chunks(segments):
    for value, count in segments:
        if not value or count < 0:
            raise ValueError('recipe units must be nonempty with nonnegative counts')
        if len(value) > CHUNK:
            for _ in range(count):
                for offset in range(0, len(value), CHUNK):
                    yield value[offset:offset+CHUNK]
        else:
            block = value * (CHUNK // len(value))
            while count:
                units = min(count, len(block) // len(value))
                yield block[:units * len(value)]
                count -= units


def entry(name, segments):
    return (name.encode("ascii"), segments)


def write_archive(path, entries):
    """Classic stored ZIP, deterministic DOS epoch, 64-byte aligned payloads.

    At most 64 KiB payload chunks and O(entry count) bounded metadata are retained.
    Independent zlib CRC-32 never calls a product reader or extracts an asset.
    """
    records = []
    with path.open("wb") as target:
        for name, segments in entries:
            size = sum(len(value) * count for value, count in segments)
            crc = 0
            for block in chunks(segments):
                crc = zlib.crc32(block, crc)
            offset = target.tell()
            padding = (-(offset + 30 + len(name))) % 64
            if 0 < padding < 4:
                padding += 64
            extra = struct.pack("<HH", 0x1986, padding - 4) + bytes(padding - 4) if padding else b""
            target.write(struct.pack("<IHHHHHIIIHH", 0x04034B50, 20, 0, 0, 0, 0x21,
                                     crc, size, size, len(name), len(extra)))
            target.write(name)
            target.write(extra)
            for block in chunks(segments):
                target.write(block)
            records.append((name, crc, size, offset))
        directory = target.tell()
        for name, crc, size, offset in records:
            target.write(struct.pack("<IHHHHHHIIIHHHHHII", 0x02014B50, 0x0314, 20,
                                     0, 0, 0, 0x21, crc, size, size, len(name), 0, 0,
                                     0, 0, 0x81A40000, offset))
            target.write(name)
        directory_size = target.tell() - directory
        target.write(struct.pack("<IHHHHIIH", 0x06054B50, 0, 0, len(records), len(records),
                                 directory_size, directory, 0))


def jpeg_prefix():
    remaining = MIB - 21
    segments = [(b"\xff\xd8", 1)]
    while remaining:
        count = min(remaining, 65_537)
        if 0 < remaining - count < 4:
            count -= 4 - (remaining - count)
        segments.extend([(b"\xff\xe1" + struct.pack(">H", count - 2), 1), (b"B", count - 4)])
        remaining -= count
    segments.append((bytes.fromhex("ffc00011080008001003011100021100031100"), 1))
    return segments


def recipes():
    root = entry("root.usda", [(b"#usda 1.0\n", 1)])
    yield "near-512-mib", [root, entry("a.wav", [(b"B", 256 * MIB)]), entry("b.wav", [(b"B", 256 * MIB - 1024)])], "json", 0, None
    yield "10000-entries", [root] + [entry(f"f{i:05}.wav", []) for i in range(9999)], "json", 0, None
    text = [(b"#usda 1.0\n", 1), (b"@root.usda@ ", 100_000)]
    text.append((b" ", 16 * MIB - sum(len(value) * count for value, count in text)))
    yield "16-mib-100000-tokens", [entry("root.usda", text)], "json", 0, None
    yield "header-1-mib", [root, entry("image.jpg", jpeg_prefix())], "json", 0, None
    for format_name in ("json", "sarif"):
        # Long safe layer locations are retained in both findings and coverage reasons.
        # 9,990 actual missing references stay below token/finding/reason ceilings.
        name = "a" * 1095 + ".usda"
        yield f"near-report-{format_name}", [entry(name, [(b"#usda 1.0\n", 1), (b"@missing@ ", 9990)])], format_name, 1, 9990
    yield "findings-truncation", [entry("root.usda", [(b"#usda 1.0\n", 1), (b"@missing@ ", 10001)])], "json", 1, 10000
    for format_name in ("json", "sarif"):
        name = "a" * 4091 + ".usda"
        yield f"report-cap-{format_name}", [entry(name, [(b"#usda 1.0\n", 1), (b"@missing@ ", 9990)])], format_name, 3, None

    yield from binary_recipes()


def word(value, width=8):
    return value.to_bytes(width, 'little')


def literal_frame(data):
    block = bytes([min(len(data), 15) << 4])
    remaining = len(data) - 15
    if remaining >= 0:
        block += b'\xff' * (remaining // 255) + bytes([remaining % 255])
    return b'\0' + block + data


def repeated_token_frame(capacity):
    """Independent LZ4 distance-one run with six trailing literals, not a writer oracle."""
    prefix = b'/\0default\0root.usdc\0\0'
    count = capacity - len(prefix)
    literals = prefix + b'a'
    block = bytes([0xff])
    length = len(literals) - 15
    block += b'\xff' * (length // 255) + bytes([length % 255]) + literals
    block += b'\1\0'
    length = count - 7 - 19
    block += b'\xff' * (length // 255) + bytes([length % 255])
    return b'\0' + block + b'\x60aaaaa\0'


def crate_segments(reps=(), body=(), tokens=None, strings=(2, 3), token_capacity=None,
                   dense_strings=None, padding=0):
    """Original hostile structure recipe, independent of the shipping crate decoder.

    Only small metadata is constructed; opaque geometry/padding is a streamed fill.
    Exact original 0.9/0.10 conformance is covered by committed writer fixtures elsewhere.
    """
    tokens = tokens or [b'/', b'default', b'root.usdc', b'']
    raw = b''.join(token + b'\0' for token in tokens)
    def frame(data):
        encoded = literal_frame(data)
        return word(len(encoded)) + encoded
    def ints(values):
        if not values:
            return frame(b'')
        previous = 0
        raw = word(0, 4) + b'\xff' * ((len(values) + 3) // 4)
        for value in values:
            raw += word((value - previous) & 0xffffffff, 4)
            previous = value
        return frame(raw)
    if token_capacity is not None:
        encoded = repeated_token_frame(token_capacity)
        token_section = word(5) + word(token_capacity) + word(len(encoded)) + encoded
    else:
        token_section = word(len(tokens)) + word(len(raw)) + frame(raw)
    if dense_strings is not None:
        string_section = word(dense_strings) + word(0, 4) * dense_strings
    else:
        string_section = word(len(strings)) + b''.join(word(value, 4) for value in strings)
    sections = [
        ('TOKENS', token_section), ('STRINGS', string_section),
        ('FIELDS', word(len(reps)) + ints([1] * len(reps)) + frame(b''.join(word(rep) for rep in reps))),
        ('FIELDSETS', word(len(reps) + 1) + ints(list(range(len(reps))) + [0xffffffff])),
        ('PATHS', word(1) + word(1) + ints([0]) + ints([0]) + ints([0xfffffffe])),
        ('SPECS', word(1) + ints([0]) + ints([0]) + ints([7])),
    ]
    # body is a list of (bounded verbatim unit, repetition count), as for archive payloads.
    offset = 88 + sum(len(value) * count for value, count in body) + padding
    records = b''
    for name, data in sections:
        records += name.encode() + bytes(16 - len(name)) + word(offset) + word(len(data))
        offset += len(data)
    header = b'PXR-USDC' + bytes([0, 8, 0]) + bytes(5) + word(offset) + bytes(64)
    return [(header, 1)] + list(body) + [(b'B', padding)] + [(data, 1) for _, data in sections] + [(word(6) + records, 1)]


def deep_crate(depth=32, fields=2):
    body = b''
    for index in range(depth - 1):
        inner = 0x400c000000000002 if index == depth - 2 else 0x0034000000000000 | (88 + (index + 1) * 16)
        body += word(8) + word(inner)
    return crate_segments([0x0034000000000058] * fields, [(body, 1)])


def binary_recipes():
    yield 'usdc-metadata-16-mib', [entry('root.usdc', crate_segments(token_capacity=16*MIB))], 'json', 0, 0
    yield 'usdc-metadata-over-block', [entry('root.usdc', crate_segments(token_capacity=16*MIB+1))], 'json', 1, None
    yield 'usdc-dense-250000', [entry('root.usdc', crate_segments(dense_strings=250_000))], 'json', 0, 0
    yield 'usdc-items-250001', [entry('root.usdc', crate_segments(dense_strings=250_001))], 'json', 1, None
    for length in (4096, 4097):
        value = 'é'.encode() * (length // 2) + (b'a' if length % 2 else b'')
        # Empty authored asset paths are valid; a long literal intentionally has no target.
        segments = crate_segments([0x400c000000000002], tokens=[b'/', b'default', value, b''])
        yield f'usdc-utf8-{length}', [entry('root.usdc', segments)], 'json', 1, None
    yield 'usdc-shared-deep', [entry('root.usdc', deep_crate())], 'json', 0, 0
    yield 'usdc-depth-33', [entry('root.usdc', deep_crate(33))], 'json', 1, None
    # Two layers reserve 2*(16 MiB - 1024) plus their small table frames; the third exceeds 32 MiB.
    layers = [entry(f'l{i}.usdc', crate_segments(token_capacity=16*MIB-1024)) for i in range(3)]
    yield 'usdc-aggregate-near', layers[:2], 'json', 0, 0
    yield 'usdc-aggregate-over', layers, 'json', 1, None
    yield 'usdc-work-over', [entry('root.usdc', crate_segments([0x8003000000000058]*8, [(word(250_000), 1)]))], 'json', 1, None
    yield 'usdc-large-layer-small-metadata', [entry('root.usdc', crate_segments(padding=256*MIB-4096))], 'json', 0, None
    array = [(word(50_001), 1), (word(0, 4), 50_001)]
    yield 'usdc-mixed-occurrences', [entry('root.usda', [(b'#usda 1.0\n', 1), (b'@root.usda@ ', 50_000)]),
        entry('layer.usdc', crate_segments([0x800c000000000058], array, tokens=[b'/', b'default', b'root.usda', b'']))], 'json', 1, None
    for format_name in ('json', 'sarif'):
        body = [(word(9990), 1), (word(0, 4), 9990)]
        binary = crate_segments([0x800c000000000058], body, tokens=[b'/', b'default', b'missing', b''])
        yield f'usdc-near-report-{format_name}', [entry('a'*2195+'.usdc', binary)], format_name, 1, 9990
        yield f'usdc-report-cap-{format_name}', [entry('a'*4091+'.usdc', binary)], format_name, 3, None


BINARY_EXPECTATIONS = {
    'usdc-metadata-over-block': ('UVK-RES-001', 'resource', 'usdcMetadataBlockBytes'),
    'usdc-items-250001': ('UVK-RES-001', 'resource', 'usdcItems'),
    'usdc-utf8-4096': ('UVK-PATH-006', 'reason', 'missingTarget'),
    'usdc-utf8-4097': ('UVK-RES-001', 'resource', 'tokenBytes'),
    'usdc-depth-33': ('UVK-RES-001', 'resource', 'usdcDepth'),
    'usdc-aggregate-over': ('UVK-RES-001', 'resource', 'usdcDecodeBytes'),
    'usdc-work-over': ('UVK-RES-001', 'resource', 'usdcWork'),
    'usdc-mixed-occurrences': ('UVK-RES-001', 'resource', 'tokenCount'),
    'usdc-near-report-json': ('UVK-PATH-006', 'reason', 'missingTarget'),
    'usdc-near-report-sarif': ('UVK-PATH-006', 'reason', 'missingTarget'),
}


def check_expected_findings(name, findings):
    expected = BINARY_EXPECTATIONS.get(name)
    if expected is None:
        return []
    rule, key, value = expected
    if not any(finding.get('ruleID') == rule and finding.get('evidence', {}).get(key) == value
               for finding in findings):
        return [f'missing expected {rule} {key}={value}']
    return []


def validate_rows(rows):
    expected = {case[0]: case[3] for case in recipes()}
    failures = []
    if len(rows) != len(expected) or {row.get('case') for row in rows} != set(expected):
        failures.append('missing, duplicate or extra required resource row')
    for row in rows:
        name = row.get('case')
        if (row.get('status') != 'PASS' or row.get('peak_rss_bytes') is None
                or row.get('peak_rss_bytes', RSS_LIMIT+1) > RSS_LIMIT
                or row.get('elapsed_seconds', SECONDS_LIMIT+1) > SECONDS_LIMIT
                or row.get('exit') != expected.get(name) or row.get('expectation_checked') is not True):
            failures.append(f'{name}: incomplete, misclassified or over-budget row')
    return failures


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(CHUNK), b""):
            digest.update(block)
    return digest.hexdigest()


def measure(executable, folder, case):
    name, entries, format_name, expected_exit, expected_findings = case
    source = folder / "input.usdz"
    write_archive(source, entries)
    corpus_hash = sha256(source)
    output = folder / "report.out"
    output.write_bytes(b"KEEP\n")
    arguments = [str(executable), "validate", str(source), "--format", format_name, "--output", str(output)]
    measured_command = ["/usr/bin/time", "-l"] + arguments
    stdout = folder / "stdout"
    stderr = folder / "stderr"
    started = time.perf_counter()
    timed_out = False
    with stdout.open("wb") as out, stderr.open("wb") as err:
        process = subprocess.Popen(measured_command, stdout=out, stderr=err, start_new_session=True)
        try:
            process.wait(timeout=SECONDS_LIMIT)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
    elapsed = time.perf_counter() - started
    diagnostic = stderr.read_text(errors="replace")
    rss = re.search(r"(\d+)\s+maximum resident set size", diagnostic)
    native_elapsed = re.search(r"([\d.]+)\s+real\s+", diagnostic)
    rss_bytes = int(rss.group(1)) if rss else None
    elapsed = max(elapsed, float(native_elapsed.group(1))) if native_elapsed else elapsed
    failures = []
    if timed_out or elapsed > SECONDS_LIMIT:
        failures.append("elapsed/deadline")
    if rss_bytes is None or rss_bytes > RSS_LIMIT:
        failures.append("peak RSS")
    if process.returncode != expected_exit:
        failures.append(f"exit expected {expected_exit}")
    if stdout.stat().st_size != 0:
        failures.append("stdout must be empty with --output")
    report_bytes = output.stat().st_size
    finding_count = None
    if expected_exit == 3:
        if output.read_bytes() != b"KEEP\n" or "report output failed" not in diagnostic:
            failures.append("report-cap rejection must preserve destination and report its operational delivery failure")
    else:
        try:
            document = json.loads(output.read_bytes())
            if format_name == "json":
                findings = document["nativeFindings"]
                if document["externalCheck"]["status"] != "notRequested":
                    failures.append("external checker unexpectedly requested")
                rule_ids = [finding["ruleID"] for finding in findings]
                coverage = document['coverage']
            else:
                findings = document["runs"][0]["results"]
                if len(document["runs"]) != 1:
                    failures.append("external run unexpectedly present")
                rule_ids = [finding["ruleId"] for finding in findings]
                coverage = document['runs'][0]['properties']['coverage']
            finding_count = len(findings)
            normalized = findings if format_name == 'json' else [
                {'ruleID': f.get('ruleId'), 'evidence': f.get('properties', {}).get('evidence', {})}
                for f in findings]
            failures.extend(check_expected_findings(name, normalized))
            if name.startswith('usdc-'):
                expected_state = 'complete' if expected_exit == 0 else 'partial'
                if coverage['areas']['references']['state'] != expected_state:
                    failures.append(f'reference coverage expected {expected_state}')
            if expected_findings is not None and finding_count != expected_findings:
                failures.append(f"findings expected {expected_findings}")
            if (name.startswith("near-report") or name.startswith("usdc-near-report")) and not 24 * MIB <= report_bytes <= REPORT_LIMIT:
                failures.append("near-report size must exercise at least 24 MiB within the 32 MiB cap")
            if name == "findings-truncation" and rule_ids.count("UVK-RES-001") != 1:
                failures.append("missing single resource sentinel")
        except (ValueError, KeyError, TypeError) as error:
            failures.append(f"invalid report: {error}")
    row = dict(case=name, archive_bytes=source.stat().st_size, corpus_sha256=corpus_hash,
               elapsed_seconds=round(elapsed, 3), peak_rss_bytes=rss_bytes,
               exit=process.returncode, report_bytes=report_bytes,
               findings=finding_count, expected_exit=expected_exit, expected_findings=expected_findings,
               format=format_name, status="PASS" if not failures else "FAIL",
               failures=failures, expectation_checked=not failures,
               expected_rule_reason=BINARY_EXPECTATIONS.get(name), command=shlex.join(measured_command))
    print(json.dumps(row), flush=True)
    return row


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--executable", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    args = parser.parse_args()
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        parser.error("Darwin arm64 is required for native /usr/bin/time -l RSS acceptance")
    executable = args.executable.resolve(strict=True)
    host = {
        "machine": command_output(["/usr/sbin/sysctl", "-n", "hw.model"]),
        "cpu": command_output(["/usr/sbin/sysctl", "-n", "machdep.cpu.brand_string"]),
        "physical_memory_bytes": command_output(["/usr/sbin/sysctl", "-n", "hw.memsize"]),
        "os": command_output(["/usr/bin/sw_vers"]),
        "toolchain": command_output(["/usr/bin/xcrun", "swift", "--version"]),
        "xcode": command_output(["/usr/bin/xcodebuild", "-version"]),
        "executable_sha256": sha256(executable),
        "measurement_generator_sha256": sha256(pathlib.Path(__file__).resolve()),
    }
    rows = []
    with tempfile.TemporaryDirectory(prefix="uvk-resource-") as temporary:
        folder = pathlib.Path(temporary)
        mount_point = command_output(["/bin/df", "-P", str(folder)]).splitlines()[-1].split()[-1]
        disk_info = command_output(["/usr/sbin/diskutil", "info", "-plist", mount_point])
        import plistlib
        disk = plistlib.loads(disk_info.encode())
        host["storage"] = {key: disk.get(key) for key in ("BusProtocol", "SolidState", "Internal", "FilesystemName", "DeviceIdentifier", "MountPoint", "APFSPhysicalStores")}
        if disk.get("SolidState") is not True or disk.get("Internal") is not True:
            parser.error("The measured temporary corpus must be on a documented internal SSD")
        for case in recipes():
            rows.append(measure(executable, folder, case))
    matrix_failures = validate_rows(rows)
    passed = not matrix_failures
    lines = ["# Native resource acceptance", "", f"Result: {'PASS' if passed else 'FAIL'}; external checker disabled for every invocation.", "",
             "Target: peak RSS <=268,435,456 bytes and elapsed <=60 seconds per release native invocation.",
             "Darwin /usr/bin/time -l reports maximum resident set size in bytes. Elapsed is the greater of its real time and the parent wall measurement; a 60-second deadline kills and reaps the entire process group.", "",
             "Fixture generation, CRC construction, corpus hashing, and report parsing are outside the measured CLI process. Temporary regular files are streamed with at most 64 KiB chunks; no giant fixture is committed. Each file is <=256 MiB. Near-report cases retain 9,990 real reference findings plus coverage locations, with 1,100-byte USDA and 2,200-byte USDC safe layer names. Cap cases use 4,096-byte names, remain below upstream layer/token/count limits, and must return operational exit 3 without replacing an existing output destination or emitting partial stdout.", "",
             "Required rows (9 archive/USDA plus 17 USDC): " + str(len(rows)) + "; matrix failures: " + repr(matrix_failures), "",
             "## Observed host", "", "```json", json.dumps(host, indent=2), "```", "",
             "## Measured release invocations", "",
             "| Case | Archive bytes | Elapsed s | Peak RSS bytes | Exit | Findings | Output bytes | Result |",
             "| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |"]
    for row in rows:
        lines.append(f"| {row['case']} | {row['archive_bytes']} | {row['elapsed_seconds']} | {row['peak_rss_bytes']} | {row['exit']} | {row['findings']} | {row['report_bytes']} | {row['status']} |")
    lines.extend(["", "## Exact commands and corpus hashes", "", "Paths below identify deleted temporary measurement files; regenerate them with the command below. Timings/host data belong only in this verification document, never product reports.", "",
                  "Reproduce: `swift build -c release` then `python3 Scripts/verify-resources.py --executable .build/release/usdz-validator --output docs/verification/resource-results.md`.", "", "```json", json.dumps(rows, indent=2), "```", "",
                  "## Scope", "", "These observations establish only this release corpus on the recorded arm64 local-SSD host. They do not establish a universal/OS-enforced memory sandbox. macOS 15 / Xcode 16 / Swift 6.0 were not available for this run and remain unobserved; the recorded host/toolchain is the actual observed environment. Test-owned counter proofs separately cover logically exact aggregate declarations that cannot coexist with ZIP overhead at the archive byte ceiling.", ""])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())

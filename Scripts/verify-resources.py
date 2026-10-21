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
        # Recipes use single-byte fills or bounded verbatim units. Preserve unit boundaries.
        block = value * max(1, CHUNK // len(value))
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
            else:
                findings = document["runs"][0]["results"]
                if len(document["runs"]) != 1:
                    failures.append("external run unexpectedly present")
                rule_ids = [finding["ruleId"] for finding in findings]
            finding_count = len(findings)
            if expected_findings is not None and finding_count != expected_findings:
                failures.append(f"findings expected {expected_findings}")
            if name.startswith("near-report") and not 24 * MIB <= report_bytes <= REPORT_LIMIT:
                failures.append("near-report size must exercise at least 24 MiB within the 32 MiB cap")
            if name == "findings-truncation" and rule_ids.count("UVK-RES-001") != 1:
                failures.append("missing single resource sentinel")
        except (ValueError, KeyError, TypeError) as error:
            failures.append(f"invalid report: {error}")
    row = dict(case=name, archive_bytes=source.stat().st_size, corpus_sha256=corpus_hash,
               elapsed_seconds=round(elapsed, 3), peak_rss_bytes=rss_bytes,
               exit=process.returncode, report_bytes=report_bytes,
               findings=finding_count, status="PASS" if not failures else "FAIL",
               failures=failures, command=shlex.join(measured_command))
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
    passed = all(row["status"] == "PASS" for row in rows)
    lines = ["# Native resource acceptance", "", f"Result: {'PASS' if passed else 'FAIL'}; external checker disabled for every invocation.", "",
             "Target: peak RSS <=268,435,456 bytes and elapsed <=60 seconds per release native invocation.",
             "Darwin /usr/bin/time -l reports maximum resident set size in bytes. Elapsed is the greater of its real time and the parent wall measurement; a 60-second deadline kills and reaps the entire process group.", "",
             "Fixture generation, CRC construction, corpus hashing, and report parsing are outside the measured CLI process. Temporary regular files are streamed with at most 64 KiB chunks; no giant fixture is committed. Each file is <=256 MiB. Near-report cases retain 9,990 real reference findings plus coverage locations, with 1,100-byte safe layer names. Cap cases use 4,096-byte names, remain below upstream layer/token/count limits, and must return operational exit 3 without replacing an existing output destination or emitting partial stdout.", "",
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

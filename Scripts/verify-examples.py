#!/usr/bin/env python3
"""Verify documented native examples without rewriting any expected bytes.

Copyright (c) 2026 USDZ Validation Kit contributors. MIT; see LICENSE.
"""

import argparse
import json
from pathlib import Path
import re
import shlex
import subprocess
import sys
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parent.parent
DOCUMENTS = (
    "README.md", "SECURITY.md", "docs/cli.md", "docs/inspection-boundary.md",
    "docs/report-compatibility.md", "docs/fixtures.md", "CHANGELOG.md",
)
COMMANDS = {
    "report-json": "validate Tests/Fixtures/valid-usda.usdz --format json",
    "report-sarif": "validate Tests/Fixtures/valid-usda.usdz --format sarif",
    "catalogue": "rules --profile apple-portable-v1 --format json",
    "general-catalogue": "rules --profile general-v1 --format json",
    "budgets": "validate Tests/Fixtures/valid-usda.usdz --config Examples/budgets.json --format json",
}
EXPECTED = {
    "report-json": "Examples/report-v1.json",
    "report-sarif": "Examples/report.sarif",
    "catalogue": "Examples/catalogue-v1.json",
    "budgets": "Examples/report-v1.json",
}
DEFAULTS = {
    "archiveBytes": 104857600, "fileBytes": 26214400, "fileCount": 1000,
    "textureBytes": 20971520, "totalTextureBytes": 83886080,
    "textureMaxDimension": 4096,
}


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def document(data):
    text = data.decode("utf-8")
    value, end = json.JSONDecoder(object_pairs_hook=unique_object).raw_decode(text)
    assert text[end:] == "\n", "expected exactly one JSON document and final LF"
    return value


def verify_links(path):
    # Check local Markdown destinations, including heading fragments. External URLs
    # are references only: this verifier never retrieves network content.
    source = re.sub(r"```.*?```", "", path.read_text(), flags=re.S)
    for destination in re.findall(r"!?\[[^\]]*\]\(([^)]+)\)", source):
        destination = destination.strip().strip("<>")
        parts = urlsplit(destination)
        if parts.scheme or parts.netloc:
            continue
        target = path.parent / unquote(parts.path) if parts.path else path
        assert target.exists(), f"{path.relative_to(ROOT)}: missing link {destination}"
        if parts.fragment and target.suffix == ".md":
            headings = re.findall(r"^#+\s+(.+)$", target.read_text(), re.M)
            anchors = {re.sub(r"[^\w\- ]", "", h.lower()).replace(" ", "-") for h in headings}
            assert unquote(parts.fragment) in anchors, f"missing heading: {destination}"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--executable", type=Path, required=True)
    arguments = parser.parse_args()
    executable = arguments.executable.resolve()
    failures = []
    documents = {}
    for name in DOCUMENTS:
        path = ROOT / name
        if not path.is_file():
            failures.append(f"missing documentation: {name}")
            continue
        documents[name] = path.read_text()
        try:
            verify_links(path)
        except (AssertionError, ValueError) as error:
            failures.append(str(error))

    authored = "\n".join(documents.values())
    observed = {}
    for label, command in COMMANDS.items():
        expected_command = ".build/release/usdz-validator " + command
        marker = rf"<!-- verify-example:{label} -->\s*```sh\n(.*?)\n```"
        matches = re.findall(marker, authored, re.S)
        if matches != [expected_command]:
            failures.append(f"missing/stale documented command: {label}")
        try:
            result = subprocess.run(
                [str(executable), *shlex.split(command)], cwd=ROOT,
                capture_output=True, timeout=15, check=False,
            )
            assert result.returncode == 0, f"{label}: exit {result.returncode}"
            assert result.stderr == b"", f"{label}: unexpected stderr"
            if label in EXPECTED:
                assert result.stdout == (ROOT / EXPECTED[label]).read_bytes(), f"{label}: example byte mismatch"
            observed[label] = document(result.stdout)
        except (AssertionError, OSError, ValueError, subprocess.TimeoutExpired) as error:
            failures.append(str(error))

    try:
        complete = observed.get("report-json")
        if complete:
            assert complete["exitCode"] == 0 and complete["coverage"]["isComplete"]
            assert complete["externalCheck"]["status"] == "notRequested"
            assert complete["configuration"]["budgets"] == DEFAULTS
        budget = json.loads((ROOT / "Examples/budgets.json").read_text(), object_pairs_hook=unique_object)
        assert budget == {"schemaVersion": 1, "budgets": DEFAULTS}, "budget example differs from defaults"
        apple, general = observed.get("catalogue"), observed.get("general-catalogue")
        if apple and general:
            assert apple["profile"] == "apple-portable-v1" and general["profile"] == "general-v1"
            apple_ids = {rule["ruleID"] for rule in apple["rules"]}
            general_ids = {rule["ruleID"] for rule in general["rules"]}
            assert len(apple_ids) == 32 and len(general_ids) == 30
            assert apple_ids - general_ids == {"UVK-APL-001", "UVK-APL-002"}
            assert general_ids < apple_ids, "profile catalogue IDs differ"
    except (AssertionError, KeyError, ValueError) as error:
        failures.append(str(error))

    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        return 1
    print("PASS: 5 documented native commands; exact examples, defaults, profile IDs, and local links")
    return 0


if __name__ == "__main__":
    sys.exit(main())

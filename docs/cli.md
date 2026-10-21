# CLI reference

Run commands from the repository root after the [release build](../README.md#build-and-run).

```text
usdz-validator validate INPUT
  [--format text|json|sarif] [--output PATH]
  [--profile general-v1|apple-portable-v1] [--config PATH]
  [--fail-on error|warning] [--allow-incomplete] [--usdchecker]
  [--include-sensitive-details]
usdz-validator rules [--profile general-v1|apple-portable-v1] [--format text|json]
usdz-validator --help
usdz-validator --version
```

`validate` takes exactly one local file, with any filename suffix. URLs, stdin (`-`), directories, multiple inputs, recursive discovery, and batch mode are unsupported. Use `--` before an option-like input filename. Quote shell-sensitive paths as usual.

Defaults: text on stdout, `general-v1`, built-in budgets, `--fail-on error`, native gaps unaccepted, no checker probe/execution, and sensitive details excluded. `rules` reads no asset and probes no tool; it lists all selected descriptors in rule-ID order, including coverage/resource rules. Help/version write stdout and exit `0`; version identifies this validator.

## Complete native examples

The committed [valid USDA package](../Tests/Fixtures/valid-usda.usdz) is 469 bytes. These commands exit `0`, produce no stderr, request no tools, and print exactly one UTF-8 LF-terminated document. JSON and SARIF bytes match [report-v1.json](../Examples/report-v1.json) and [report.sarif](../Examples/report.sarif).

<!-- verify-example:report-json -->
```sh
.build/release/usdz-validator validate Tests/Fixtures/valid-usda.usdz --format json
```

<!-- verify-example:report-sarif -->
```sh
.build/release/usdz-validator validate Tests/Fixtures/valid-usda.usdz --format sarif
```

The [Apple catalogue example](../Examples/catalogue-v1.json) contains 32 native rules; the general profile contains 30. Selecting a profile never silently runs a checker.

<!-- verify-example:catalogue -->
```sh
.build/release/usdz-validator rules --profile apple-portable-v1 --format json
```

<!-- verify-example:general-catalogue -->
```sh
.build/release/usdz-validator rules --profile general-v1 --format json
```

An explicit [default budget file](../Examples/budgets.json) produces the same complete JSON bytes:

<!-- verify-example:budgets -->
```sh
.build/release/usdz-validator validate Tests/Fixtures/valid-usda.usdz --config Examples/budgets.json --format json
```

`python3 Scripts/verify-examples.py --executable .build/release/usdz-validator` executes these five commands, checks streams/exit codes, compares bytes, parses each machine report once, and verifies defaults, profile IDs and local documentation links. It never rewrites examples. Use [offline schema verification](../Tools/README.md#setup-and-verification) as well.

## Warning configuration

`--config PATH` loads only the named UTF-8 JSON file, at most 64 KiB. No current-directory, home-directory, or environment config discovery occurs. [Schema v1](../Schemas/budget-config-v1.schema.json) requires both `schemaVersion: 1` and `budgets`.

| Key | Default | Observed value |
| --- | ---: | --- |
| `archiveBytes` | 104857600 | Opened archive bytes |
| `fileBytes` | 26214400 | Each regular entry's encoded bytes |
| `fileCount` | 1000 | Regular entries |
| `textureBytes` | 20971520 | Each texture's encoded bytes |
| `totalTextureBytes` | 83886080 | All texture encoded bytes |
| `textureMaxDimension` | 4096 | Supported width or height |

Only `observed > threshold` warns; equality passes. Omitted budget keys use defaults; `null` disables only that warning check. Non-null values must be positive signed-64-bit integers. Booleans, floats (including `1.0`), zero, negatives, duplicate/unknown keys, unsupported versions and trailing non-whitespace data fail before inspecting input or executing tools. Config cannot set profiles, tools, search paths, or [hard safety ceilings](inspection-boundary.md#fixed-safety-envelope-v1). Effective budgets appear in reports.

## Streams and report destinations

Findings belong to the report, including text output. Stdout contains no progress, banners, logs, ANSI color, or separate tool diagnostics. Stderr carries concise invocation/configuration, operational, and output diagnostics. Invalid invocation/config produces no report. After valid configuration, input I/O failures produce an operational-error report when the destination is writable.

`--output PATH` leaves stdout empty and atomically replaces an ordinary report file from the same directory. Missing parent directories are not created. Symlinks, non-regular destinations, and input aliases (including hard links) are refused. Failed encoding/replacement preserves an existing destination. Reports are completely encoded and checked against 32 MiB before emission. A broken stdout pipe returns an operational failure; downstream write failure can prevent delivery of a complete document.

## Exit codes and gate policy

Evaluate this table from top to bottom; the first applicable condition wins.

| Exit | Condition |
| --- | --- |
| `64` | Invalid invocation/configuration |
| `70` | Unexpected internal failure |
| `3` | Input I/O/change, report encoding, or output failure |
| `1` | Native finding meets the threshold, hard safety error, or checker-reported failure |
| `2` | Unaccepted native gap or requested checker unavailable/unsupported/skipped/unable to complete |
| `0` | Configured gate accepts the result |

`--fail-on warning` blocks warnings and errors; notes never block by severity. Coverage gaps affect completeness independently. `--allow-incomplete` accepts native gaps only: it does not change coverage or suppress findings, override selected warnings/hard safety errors, or accept an unsuccessful requested checker. A USDC reference gap can therefore have `validationStatus: incomplete`, `gateDecision: pass`, and `acceptedIncomplete: true`. Higher-priority failures retain all known coverage gaps.

An otherwise correct binary-USDC package can return `2` under the default policy. In [five local Apple sample tests](verification/apple-assets.md), all originals had that native reference gap; the optional checker reported no failure on four and a material-subset failure on one. Explicitly accepting native incompleteness allowed the four to return `0`, while the external failure retained exit `1`.

## Optional installed checker

Use `--usdchecker` only for trusted input. The installed tool's parsers/resolvers can access filesystem/network resources beyond the native package boundary; there is no external filesystem/network/RSS sandbox. Only `/usr/bin/usdchecker`, reporting exactly `Apple USD Tools (0.25.11)`, is supported. No PATH discovery, downloads, shell, arbitrary executable/arguments, or `usdcat` conversion is available.

A version probe has a 5-second / 16 KiB cap. Validation uses `--strict --rootPackageOnly --out stderr`, plus `--arkit` for `apple-portable-v1`, then the absolute input as a separate argument. Its working directory is the input parent; its entire environment is `PATH=/usr/bin:/bin`, `LANG=C`, `LC_ALL=C`. Validation has a 60-second / combined 1 MiB capture cap. Timeout/overflow terminates, force-kills after at most one second if needed, reaps, and bounds pipe draining. Native unsafe/container/hard-limit failures skip execution.

The external record separates availability, version, phase (`versionProbe`/`validation`), status, exit/outcome and provenance. Status is `notRequested`, `unavailable`, `unsupportedVersion`, `skippedUnsafeInput`, `completed`, `launchFailed`, `timedOut`, or `outputLimitExceeded`. Completed zero exit means `noFailureReported`; nonzero means `failureReported` with aggregate error `USDCK-001`. This does not upgrade native USDC coverage. The tool's `--arkit` policy is its own version-specific policy (its observed help describes a 2023 target).

`--include-sensitive-details` exposes bounded absolute input/reference details and raw checker stdout/stderr. Default output contains only diagnostic presence/byte counts and aggregate outcomes. Opt-in retains escaping/resource caps and may reveal local paths; consider disclosure before sharing a report. See [SECURITY.md](../SECURITY.md).

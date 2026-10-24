# Native resource acceptance

Result: PASS; external checker disabled for every invocation.

Target: peak RSS <=268,435,456 bytes and elapsed <=60 seconds per release native invocation.
Darwin /usr/bin/time -l reports maximum resident set size in bytes. Elapsed is the greater of its real time and the parent wall measurement; a 60-second deadline kills and reaps the entire process group.

Fixture generation, CRC construction, corpus hashing, and report parsing are outside the measured CLI process. Temporary regular files are streamed with at most 64 KiB chunks; no giant fixture is committed. Each file is <=256 MiB. Near-report cases retain 9,990 real reference findings plus coverage locations, with 1,100-byte USDA and 2,200-byte USDC safe layer names. Cap cases use 4,096-byte names, remain below upstream layer/token/count limits, and must return operational exit 3 without replacing an existing output destination or emitting partial stdout.

Required rows (9 archive/USDA plus 17 USDC): 26; matrix failures: []

## Observed host

```json
{
  "machine": "Mac17,6",
  "cpu": "Apple M5 Max",
  "physical_memory_bytes": "38654705664",
  "os": "ProductName:\t\tmacOS\nProductVersion:\t\t27.0.1\nBuildVersion:\t\t26A434",
  "toolchain": "Apple Swift version 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1)\nTarget: arm64-apple-macosx27.0.0",
  "xcode": "Xcode 27.1\nBuild version 27A9275",
  "executable_sha256": "91e071cfd13a90e68bd972ce3d699adc4d0f6fd2f584a274388be5b04529394f",
  "measurement_generator_sha256": "9ed7f3b250092d43f1072b846ca724709d0866e14d0c5c600215b84449215ea8",
  "storage": {
    "BusProtocol": "Apple Fabric",
    "SolidState": true,
    "Internal": true,
    "FilesystemName": "APFS",
    "DeviceIdentifier": "disk3s5",
    "MountPoint": "/System/Volumes/Data",
    "APFSPhysicalStores": [
      {
        "APFSPhysicalStore": "disk0s2"
      }
    ]
  }
}
```

## Measured release invocations

| Case | Archive bytes | Elapsed s | Peak RSS bytes | Exit | Findings | Output bytes | Result |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| near-512-mib | 536870259 | 1.34 | 8552448 | 0 | 3 | 2992 | PASS |
| 10000-entries | 1200021 | 0.322 | 17596416 | 0 | 1 | 2034 | PASS |
| 16-mib-100000-tokens | 16777357 | 0.261 | 8454144 | 0 | 0 | 1666 | PASS |
| header-1-mib | 1048836 | 0.091 | 8273920 | 0 | 0 | 1665 | PASS |
| near-report-json | 102230 | 1.425 | 102367232 | 1 | 9990 | 27598046 | PASS |
| near-report-sarif | 102230 | 1.403 | 105725952 | 1 | 9990 | 29252677 | PASS |
| findings-truncation | 100161 | 0.452 | 37830656 | 1 | 10000 | 5804498 | PASS |
| report-cap-json | 108234 | 1.69 | 207093760 | 3 | None | 5 | PASS |
| report-cap-sarif | 108234 | 1.695 | 208683008 | 3 | None | 5 | PASS |
| usdc-metadata-16-mib | 66489 | 0.091 | 25280512 | 0 | 0 | 1663 | PASS |
| usdc-metadata-over-block | 66489 | 0.049 | 8568832 | 1 | 2 | 2893 | PASS |
| usdc-dense-250000 | 1000678 | 0.898 | 9453568 | 0 | 0 | 1665 | PASS |
| usdc-items-250001 | 1000682 | 0.091 | 8601600 | 1 | 2 | 2867 | PASS |
| usdc-utf8-4096 | 4810 | 0.049 | 8503296 | 1 | 1 | 2241 | PASS |
| usdc-utf8-4097 | 4811 | 0.048 | 8470528 | 1 | 2 | 2864 | PASS |
| usdc-shared-deep | 1221 | 0.05 | 8454144 | 0 | 0 | 1662 | PASS |
| usdc-depth-33 | 1237 | 0.049 | 8617984 | 1 | 2 | 2860 | PASS |
| usdc-aggregate-near | 132968 | 0.091 | 25264128 | 0 | 0 | 1664 | PASS |
| usdc-aggregate-over | 199453 | 0.088 | 25509888 | 1 | 2 | 2872 | PASS |
| usdc-work-over | 833 | 0.049 | 8470528 | 1 | 2 | 2862 | PASS |
| usdc-large-layer-small-metadata | 268432046 | 0.854 | 8601600 | 0 | 2 | 2521 | PASS |
| usdc-mixed-occurrences | 800839 | 0.375 | 8830976 | 1 | 2 | 2885 | PASS |
| usdc-near-report-json | 45040 | 1.569 | 84066304 | 1 | 9990 | 26057942 | PASS |
| usdc-report-cap-json | 48856 | 2.033 | 116768768 | 3 | None | 5 | PASS |
| usdc-near-report-sarif | 45040 | 1.568 | 85508096 | 1 | 9990 | 26783428 | PASS |
| usdc-report-cap-sarif | 48856 | 2.092 | 117620736 | 3 | None | 5 | PASS |

## Exact commands and corpus hashes

Paths below identify deleted temporary measurement files; regenerate them with the command below. Timings/host data belong only in this verification document, never product reports.

Reproduce: `swift build -c release` then `python3 Scripts/verify-resources.py --executable .build/release/usdz-validator --output docs/verification/resource-results.md`.

```json
[
  {
    "case": "near-512-mib",
    "archive_bytes": 536870259,
    "corpus_sha256": "5391ada98fd8ea1bb3c1e06572940d8739709a82b47c2fbef096df8e50202a90",
    "elapsed_seconds": 1.34,
    "peak_rss_bytes": 8552448,
    "exit": 0,
    "report_bytes": 2992,
    "findings": 3,
    "expected_exit": 0,
    "expected_findings": null,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": null,
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "10000-entries",
    "archive_bytes": 1200021,
    "corpus_sha256": "0da9b5eddeb0f1472a1d1a49e50940bb0996206e91908867a5dba417f23f15da",
    "elapsed_seconds": 0.322,
    "peak_rss_bytes": 17596416,
    "exit": 0,
    "report_bytes": 2034,
    "findings": 1,
    "expected_exit": 0,
    "expected_findings": null,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": null,
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "16-mib-100000-tokens",
    "archive_bytes": 16777357,
    "corpus_sha256": "e69ae8a6582687100ab7e7d05ac86b59070572ba508578763a5ac0e5b89fa45f",
    "elapsed_seconds": 0.261,
    "peak_rss_bytes": 8454144,
    "exit": 0,
    "report_bytes": 1666,
    "findings": 0,
    "expected_exit": 0,
    "expected_findings": null,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": null,
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "header-1-mib",
    "archive_bytes": 1048836,
    "corpus_sha256": "a5fc35449b2d7208e7d8008086ead89f49b5ad8054ba773014fd4eb36ab14e28",
    "elapsed_seconds": 0.091,
    "peak_rss_bytes": 8273920,
    "exit": 0,
    "report_bytes": 1665,
    "findings": 0,
    "expected_exit": 0,
    "expected_findings": null,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": null,
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "near-report-json",
    "archive_bytes": 102230,
    "corpus_sha256": "cde6d03bb40f300f7374fc8382be6574951ba2d5ae97af4350c57ba571fe5bc4",
    "elapsed_seconds": 1.425,
    "peak_rss_bytes": 102367232,
    "exit": 1,
    "report_bytes": 27598046,
    "findings": 9990,
    "expected_exit": 1,
    "expected_findings": 9990,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": null,
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "near-report-sarif",
    "archive_bytes": 102230,
    "corpus_sha256": "cde6d03bb40f300f7374fc8382be6574951ba2d5ae97af4350c57ba571fe5bc4",
    "elapsed_seconds": 1.403,
    "peak_rss_bytes": 105725952,
    "exit": 1,
    "report_bytes": 29252677,
    "findings": 9990,
    "expected_exit": 1,
    "expected_findings": 9990,
    "format": "sarif",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": null,
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format sarif --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "findings-truncation",
    "archive_bytes": 100161,
    "corpus_sha256": "c77c5366d856aaa83c595ac76aa4becca403aabbedee8f5be3ae4689e48affe7",
    "elapsed_seconds": 0.452,
    "peak_rss_bytes": 37830656,
    "exit": 1,
    "report_bytes": 5804498,
    "findings": 10000,
    "expected_exit": 1,
    "expected_findings": 10000,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": null,
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "report-cap-json",
    "archive_bytes": 108234,
    "corpus_sha256": "856c095bf0f2afcae13bde5d20173c5d7230759c691f244c36054699d78c2e94",
    "elapsed_seconds": 1.69,
    "peak_rss_bytes": 207093760,
    "exit": 3,
    "report_bytes": 5,
    "findings": null,
    "expected_exit": 3,
    "expected_findings": null,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": null,
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "report-cap-sarif",
    "archive_bytes": 108234,
    "corpus_sha256": "856c095bf0f2afcae13bde5d20173c5d7230759c691f244c36054699d78c2e94",
    "elapsed_seconds": 1.695,
    "peak_rss_bytes": 208683008,
    "exit": 3,
    "report_bytes": 5,
    "findings": null,
    "expected_exit": 3,
    "expected_findings": null,
    "format": "sarif",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": null,
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format sarif --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "usdc-metadata-16-mib",
    "archive_bytes": 66489,
    "corpus_sha256": "51f2ad4bb10a13b88f1c383867c791a2b18457f6e332769a4a2299fdc2dba30c",
    "elapsed_seconds": 0.091,
    "peak_rss_bytes": 25280512,
    "exit": 0,
    "report_bytes": 1663,
    "findings": 0,
    "expected_exit": 0,
    "expected_findings": 0,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": null,
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "usdc-metadata-over-block",
    "archive_bytes": 66489,
    "corpus_sha256": "31ec8f1d46f907f56bd81e222ed6cb69ff581240e996b52e60e8d8bc8bb98493",
    "elapsed_seconds": 0.049,
    "peak_rss_bytes": 8568832,
    "exit": 1,
    "report_bytes": 2893,
    "findings": 2,
    "expected_exit": 1,
    "expected_findings": null,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": [
      "UVK-RES-001",
      "resource",
      "usdcMetadataBlockBytes"
    ],
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "usdc-dense-250000",
    "archive_bytes": 1000678,
    "corpus_sha256": "aa1f001929c8450fcd44da72c63126b5b4b30ce7d85b1a74fc9017d1b7387996",
    "elapsed_seconds": 0.898,
    "peak_rss_bytes": 9453568,
    "exit": 0,
    "report_bytes": 1665,
    "findings": 0,
    "expected_exit": 0,
    "expected_findings": 0,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": null,
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "usdc-items-250001",
    "archive_bytes": 1000682,
    "corpus_sha256": "1adacc2cc2a12119b410b8f77ac2881b072936403333bb89216126ae7f23f157",
    "elapsed_seconds": 0.091,
    "peak_rss_bytes": 8601600,
    "exit": 1,
    "report_bytes": 2867,
    "findings": 2,
    "expected_exit": 1,
    "expected_findings": null,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": [
      "UVK-RES-001",
      "resource",
      "usdcItems"
    ],
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "usdc-utf8-4096",
    "archive_bytes": 4810,
    "corpus_sha256": "fc12fc9bc8c2adb65e29b6f6d25f294c0698670a0507a6909ecae53b5df0dc35",
    "elapsed_seconds": 0.049,
    "peak_rss_bytes": 8503296,
    "exit": 1,
    "report_bytes": 2241,
    "findings": 1,
    "expected_exit": 1,
    "expected_findings": null,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": [
      "UVK-PATH-006",
      "reason",
      "missingTarget"
    ],
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "usdc-utf8-4097",
    "archive_bytes": 4811,
    "corpus_sha256": "100facebb4b9bda233ec4d6fd7984c823b02c2bbec5615e19ddbe7b63f02e0a7",
    "elapsed_seconds": 0.048,
    "peak_rss_bytes": 8470528,
    "exit": 1,
    "report_bytes": 2864,
    "findings": 2,
    "expected_exit": 1,
    "expected_findings": null,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": [
      "UVK-RES-001",
      "resource",
      "tokenBytes"
    ],
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "usdc-shared-deep",
    "archive_bytes": 1221,
    "corpus_sha256": "3b0356f38f9b420cbfc7abf35b5582134f82af355c23c8e5b834dbd21a40b825",
    "elapsed_seconds": 0.05,
    "peak_rss_bytes": 8454144,
    "exit": 0,
    "report_bytes": 1662,
    "findings": 0,
    "expected_exit": 0,
    "expected_findings": 0,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": null,
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "usdc-depth-33",
    "archive_bytes": 1237,
    "corpus_sha256": "3ff4c9393c28579db87f8e7c6555b3cb7d98abe5a25919e9a758b0904066b10e",
    "elapsed_seconds": 0.049,
    "peak_rss_bytes": 8617984,
    "exit": 1,
    "report_bytes": 2860,
    "findings": 2,
    "expected_exit": 1,
    "expected_findings": null,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": [
      "UVK-RES-001",
      "resource",
      "usdcDepth"
    ],
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "usdc-aggregate-near",
    "archive_bytes": 132968,
    "corpus_sha256": "8a2fff4f8328c65f1cfe18caa3c391f1e97cf7663e1f810e4181b4d099fb8bef",
    "elapsed_seconds": 0.091,
    "peak_rss_bytes": 25264128,
    "exit": 0,
    "report_bytes": 1664,
    "findings": 0,
    "expected_exit": 0,
    "expected_findings": 0,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": null,
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "usdc-aggregate-over",
    "archive_bytes": 199453,
    "corpus_sha256": "7014fcbb5dc35fe6858ee2dcff413496886cbb7ee774400a0c94fb9812e1a4c6",
    "elapsed_seconds": 0.088,
    "peak_rss_bytes": 25509888,
    "exit": 1,
    "report_bytes": 2872,
    "findings": 2,
    "expected_exit": 1,
    "expected_findings": null,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": [
      "UVK-RES-001",
      "resource",
      "usdcDecodeBytes"
    ],
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "usdc-work-over",
    "archive_bytes": 833,
    "corpus_sha256": "c2d6729367e1dc8d733dd95665ec8493195f709018e0266b4dae58285a10b244",
    "elapsed_seconds": 0.049,
    "peak_rss_bytes": 8470528,
    "exit": 1,
    "report_bytes": 2862,
    "findings": 2,
    "expected_exit": 1,
    "expected_findings": null,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": [
      "UVK-RES-001",
      "resource",
      "usdcWork"
    ],
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "usdc-large-layer-small-metadata",
    "archive_bytes": 268432046,
    "corpus_sha256": "dd272bde32e6a0452dc01f43f10d1b689aeb3b16de16c5d5bb2764801962b9bb",
    "elapsed_seconds": 0.854,
    "peak_rss_bytes": 8601600,
    "exit": 0,
    "report_bytes": 2521,
    "findings": 2,
    "expected_exit": 0,
    "expected_findings": null,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": null,
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "usdc-mixed-occurrences",
    "archive_bytes": 800839,
    "corpus_sha256": "900d1befb81fadf04e9ea6a77203143c1332e6231569eda446f1f5763eadad61",
    "elapsed_seconds": 0.375,
    "peak_rss_bytes": 8830976,
    "exit": 1,
    "report_bytes": 2885,
    "findings": 2,
    "expected_exit": 1,
    "expected_findings": null,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": [
      "UVK-RES-001",
      "resource",
      "tokenCount"
    ],
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "usdc-near-report-json",
    "archive_bytes": 45040,
    "corpus_sha256": "0267f47185cc316cd0e481175c49dcc74ed92b0696092e70d0ee76904771b36c",
    "elapsed_seconds": 1.569,
    "peak_rss_bytes": 84066304,
    "exit": 1,
    "report_bytes": 26057942,
    "findings": 9990,
    "expected_exit": 1,
    "expected_findings": 9990,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": [
      "UVK-PATH-006",
      "reason",
      "missingTarget"
    ],
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "usdc-report-cap-json",
    "archive_bytes": 48856,
    "corpus_sha256": "8123a0e6ac8dc18533eb79b9f4defd9a98755e7bcb09f2262b76878f49ef0e85",
    "elapsed_seconds": 2.033,
    "peak_rss_bytes": 116768768,
    "exit": 3,
    "report_bytes": 5,
    "findings": null,
    "expected_exit": 3,
    "expected_findings": null,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": null,
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "usdc-near-report-sarif",
    "archive_bytes": 45040,
    "corpus_sha256": "0267f47185cc316cd0e481175c49dcc74ed92b0696092e70d0ee76904771b36c",
    "elapsed_seconds": 1.568,
    "peak_rss_bytes": 85508096,
    "exit": 1,
    "report_bytes": 26783428,
    "findings": 9990,
    "expected_exit": 1,
    "expected_findings": 9990,
    "format": "sarif",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": [
      "UVK-PATH-006",
      "reason",
      "missingTarget"
    ],
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format sarif --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  },
  {
    "case": "usdc-report-cap-sarif",
    "archive_bytes": 48856,
    "corpus_sha256": "8123a0e6ac8dc18533eb79b9f4defd9a98755e7bcb09f2262b76878f49ef0e85",
    "elapsed_seconds": 2.092,
    "peak_rss_bytes": 117620736,
    "exit": 3,
    "report_bytes": 5,
    "findings": null,
    "expected_exit": 3,
    "expected_findings": null,
    "format": "sarif",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": null,
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/input.usdz --format sarif --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-h6adyhbk/report.out"
  }
]
```

## Scope

These observations establish only this release corpus on the recorded arm64 local-SSD host. They do not establish a universal/OS-enforced memory sandbox. macOS 15 / Xcode 16 / Swift 6.0 were not available for this run and remain unobserved; the recorded host/toolchain is the actual observed environment. Test-owned counter proofs separately cover logically exact aggregate declarations that cannot coexist with ZIP overhead at the archive byte ceiling.

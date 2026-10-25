# Native resource acceptance

Product 0.2.0; safety-envelope version 3.

Result: PASS; external checker disabled for every invocation.

Target: peak RSS <=268,435,456 bytes and elapsed <=60 seconds per release native invocation.
Darwin /usr/bin/time -l reports maximum resident set size in bytes. Elapsed is the greater of its real time and the parent wall measurement; a 60-second deadline kills and reaps the entire process group.

Fixture generation, CRC construction, corpus hashing, and report parsing are outside the measured CLI process. Temporary regular files are streamed with at most 64 KiB chunks; no giant fixture is committed. Each file is <=256 MiB. Near-report cases retain 9,990 real reference findings plus coverage locations, with 1,100-byte USDA and 2,200-byte USDC safe layer names. Cap cases use 4,096-byte names, remain below upstream layer/token/count limits, and must return operational exit 3 without replacing an existing output destination or emitting partial stdout.

Actual-work recipe: 16-entry dictionaries share one UInt64.max numeric header. Each field costs 138 base operations plus 16*(item + two key lookups + relative edge + coordinate + ValueRep) = 234; fixed cost 109. 8,546 fields complete at 1,999,873; 8,547 require 2,000,107 and reject usdcWork at 1,999,912 before a 96-slot reservation. Two layers of 4,273 fields accumulate 1,999,982. Independent native tests assert exact counters and release; process measurements below cover complete CLI/report work.

Required rows (9 archive/USDA plus 31 USDC): 40; matrix failures: []

## Observed host

```json
{
  "machine": "Mac17,6",
  "cpu": "Apple M5 Max",
  "physical_memory_bytes": "38654705664",
  "os": "ProductName:\t\tmacOS\nProductVersion:\t\t27.0.1\nBuildVersion:\t\t26A434",
  "toolchain": "Apple Swift version 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1)\nTarget: arm64-apple-macosx27.0.0",
  "xcode": "Xcode 27.1\nBuild version 27A9275",
  "executable_sha256": "068c09e750dd1adf50dcd82f02f71352fa69e9c3dc8f85152c790bfca8429787",
  "measurement_generator_sha256": "f67edc2f10d3e72f000ca9469342082314d6334eb90eb589ec50c1adeabe38a4",
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
| near-512-mib | 536870259 | 1.366 | 8568832 | 0 | 3 | 2992 | PASS |
| 10000-entries | 1200021 | 0.322 | 17547264 | 0 | 1 | 2034 | PASS |
| 16-mib-100000-tokens | 16777357 | 0.27 | 8470528 | 0 | 0 | 1666 | PASS |
| header-1-mib | 1048836 | 0.091 | 8421376 | 0 | 0 | 1665 | PASS |
| near-report-json | 102230 | 1.377 | 102318080 | 1 | 9990 | 27598046 | PASS |
| near-report-sarif | 102230 | 1.418 | 105644032 | 1 | 9990 | 29252677 | PASS |
| findings-truncation | 100161 | 0.442 | 37765120 | 1 | 10000 | 5804498 | PASS |
| report-cap-json | 108234 | 1.728 | 207060992 | 3 | None | 5 | PASS |
| report-cap-sarif | 108234 | 1.73 | 208666624 | 3 | None | 5 | PASS |
| usdc-metadata-16-mib | 66489 | 0.091 | 25329664 | 0 | 0 | 1663 | PASS |
| usdc-metadata-over-block | 66489 | 0.091 | 8634368 | 1 | 2 | 2893 | PASS |
| usdc-dense-250000 | 1000678 | 0.834 | 9551872 | 0 | 0 | 1665 | PASS |
| usdc-items-250001 | 1000682 | 0.081 | 8683520 | 1 | 2 | 2867 | PASS |
| usdc-utf8-4096 | 4810 | 0.083 | 8552448 | 1 | 1 | 2241 | PASS |
| usdc-utf8-4097 | 4811 | 0.088 | 8552448 | 1 | 2 | 2864 | PASS |
| usdc-shared-deep | 1221 | 0.093 | 8470528 | 0 | 0 | 1662 | PASS |
| usdc-depth-33 | 1237 | 0.05 | 8716288 | 1 | 2 | 2860 | PASS |
| usdc-aggregate-near | 132968 | 0.146 | 25346048 | 0 | 0 | 1664 | PASS |
| usdc-aggregate-over | 199453 | 0.153 | 25608192 | 1 | 2 | 2872 | PASS |
| usdc-numeric-0 | 715 | 0.092 | 8306688 | 0 | 0 | 1661 | PASS |
| usdc-numeric-250000 | 715 | 0.089 | 8306688 | 0 | 0 | 1661 | PASS |
| usdc-numeric-250001 | 715 | 0.05 | 8339456 | 0 | 0 | 1661 | PASS |
| usdc-numeric-max | 715 | 0.05 | 8323072 | 0 | 0 | 1661 | PASS |
| usdc-compressed-numeric-0 | 715 | 0.05 | 8306688 | 0 | 0 | 1661 | PASS |
| usdc-compressed-numeric-250000 | 715 | 0.05 | 8306688 | 0 | 0 | 1661 | PASS |
| usdc-compressed-numeric-250001 | 715 | 0.049 | 8306688 | 0 | 0 | 1661 | PASS |
| usdc-compressed-numeric-max | 715 | 0.049 | 8290304 | 0 | 0 | 1661 | PASS |
| usdc-shared-numeric-near | 142590 | 1.764 | 8863744 | 0 | 0 | 1664 | PASS |
| usdc-work-over | 142606 | 1.773 | 9076736 | 1 | 2 | 2865 | PASS |
| usdc-numeric-aggregate | 143604 | 1.817 | 8732672 | 0 | 0 | 1664 | PASS |
| usdc-numeric-aggregate-over | 143621 | 1.791 | 8962048 | 1 | 2 | 2857 | PASS |
| usdc-truncated-numeric-header | 714 | 0.086 | 8519680 | 1 | 2 | 2866 | PASS |
| usdc-unknown-numeric-flags | 715 | 0.088 | 8536064 | 2 | 2 | 2919 | PASS |
| usdc-shared-asset-items-over | 733 | 0.091 | 8503296 | 1 | 2 | 2863 | PASS |
| usdc-large-layer-small-metadata | 268432046 | 0.737 | 8617984 | 0 | 2 | 2521 | PASS |
| usdc-mixed-occurrences | 800839 | 0.321 | 8847360 | 1 | 2 | 2885 | PASS |
| usdc-near-report-json | 45040 | 1.545 | 84000768 | 1 | 9990 | 26057942 | PASS |
| usdc-report-cap-json | 48856 | 2.044 | 116621312 | 3 | None | 5 | PASS |
| usdc-near-report-sarif | 45040 | 1.6 | 85573632 | 1 | 9990 | 26783428 | PASS |
| usdc-report-cap-sarif | 48856 | 2.095 | 117587968 | 3 | None | 5 | PASS |

## Exact commands and corpus hashes

Paths below identify deleted temporary measurement files; regenerate them with the command below. Timings/host data belong only in this verification document, never product reports.

Reproduce: `swift build -c release` then `python3 Scripts/verify-resources.py --executable .build/release/usdz-validator --output docs/verification/resource-results.md`.

```json
[
  {
    "case": "near-512-mib",
    "archive_bytes": 536870259,
    "corpus_sha256": "5391ada98fd8ea1bb3c1e06572940d8739709a82b47c2fbef096df8e50202a90",
    "elapsed_seconds": 1.366,
    "peak_rss_bytes": 8568832,
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
    "typed_findings": [
      {
        "ruleID": "UVK-BUD-001",
        "evidence": {}
      },
      {
        "ruleID": "UVK-BUD-002",
        "evidence": {}
      }
    ],
    "raw_time_stderr": "        1.33 real         1.25 user         0.05 sys\n             8568832  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 758  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                 122  involuntary context switches\n         39583292160  instructions retired\n          5739954684  cycles elapsed\n             2982416  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "10000-entries",
    "archive_bytes": 1200021,
    "corpus_sha256": "0da9b5eddeb0f1472a1d1a49e50940bb0996206e91908867a5dba417f23f15da",
    "elapsed_seconds": 0.322,
    "peak_rss_bytes": 17547264,
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
    "typed_findings": [
      {
        "ruleID": "UVK-BUD-003",
        "evidence": {}
      }
    ],
    "raw_time_stderr": "        0.27 real         0.11 user         0.13 sys\n            17547264  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                1307  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  39  involuntary context switches\n          5657531731  instructions retired\n          1106926001  cycles elapsed\n            11960848  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "16-mib-100000-tokens",
    "archive_bytes": 16777357,
    "corpus_sha256": "e69ae8a6582687100ab7e7d05ac86b59070572ba508578763a5ac0e5b89fa45f",
    "elapsed_seconds": 0.27,
    "peak_rss_bytes": 8470528,
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
    "typed_findings": [],
    "raw_time_stderr": "        0.22 real         0.19 user         0.00 sys\n             8470528  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 752  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  29  involuntary context switches\n          5721146864  instructions retired\n           877983166  cycles elapsed\n             2982392  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "header-1-mib",
    "archive_bytes": 1048836,
    "corpus_sha256": "a5fc35449b2d7208e7d8008086ead89f49b5ad8054ba773014fd4eb36ab14e28",
    "elapsed_seconds": 0.091,
    "peak_rss_bytes": 8421376,
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
    "typed_findings": [],
    "raw_time_stderr": "        0.03 real         0.00 user         0.00 sys\n             8421376  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 749  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  16  involuntary context switches\n           177136263  instructions retired\n            39292790  cycles elapsed\n             2916856  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "near-report-json",
    "archive_bytes": 102230,
    "corpus_sha256": "cde6d03bb40f300f7374fc8382be6574951ba2d5ae97af4350c57ba571fe5bc4",
    "elapsed_seconds": 1.377,
    "peak_rss_bytes": 102318080,
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
    "typed_findings": [
      {
        "ruleID": "UVK-PATH-006",
        "evidence": {
          "reason": "missingTarget"
        }
      }
    ],
    "raw_time_stderr": "        1.31 real         1.27 user         0.01 sys\n           102318080  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                6484  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                 158  involuntary context switches\n         35589100424  instructions retired\n          5617486540  cycles elapsed\n            96764480  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "near-report-sarif",
    "archive_bytes": 102230,
    "corpus_sha256": "cde6d03bb40f300f7374fc8382be6574951ba2d5ae97af4350c57ba571fe5bc4",
    "elapsed_seconds": 1.418,
    "peak_rss_bytes": 105644032,
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
    "typed_findings": [
      {
        "ruleID": "UVK-PATH-006",
        "evidence": {
          "reason": "missingTarget"
        }
      }
    ],
    "raw_time_stderr": "        1.36 real         1.32 user         0.01 sys\n           105644032  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                6690  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                 144  involuntary context switches\n         36984801132  instructions retired\n          5885348615  cycles elapsed\n           100090432  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format sarif --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "findings-truncation",
    "archive_bytes": 100161,
    "corpus_sha256": "c77c5366d856aaa83c595ac76aa4becca403aabbedee8f5be3ae4689e48affe7",
    "elapsed_seconds": 0.442,
    "peak_rss_bytes": 37765120,
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
    "typed_findings": [
      {
        "ruleID": "UVK-PATH-006",
        "evidence": {
          "reason": "missingTarget"
        }
      },
      {
        "ruleID": "UVK-RES-001",
        "evidence": {
          "resource": "findings"
        }
      }
    ],
    "raw_time_stderr": "        0.40 real         0.38 user         0.00 sys\n            37765120  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                2541  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  52  involuntary context switches\n          9197538740  instructions retired\n          1715816830  cycles elapsed\n            32195112  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "report-cap-json",
    "archive_bytes": 108234,
    "corpus_sha256": "856c095bf0f2afcae13bde5d20173c5d7230759c691f244c36054699d78c2e94",
    "elapsed_seconds": 1.728,
    "peak_rss_bytes": 207060992,
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
    "typed_findings": [],
    "raw_time_stderr": "error: report output failed.\n        1.65 real         1.60 user         0.02 sys\n           207060992  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n               13442  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                 163  involuntary context switches\n         46003597549  instructions retired\n          7216907188  cycles elapsed\n           179290784  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "report-cap-sarif",
    "archive_bytes": 108234,
    "corpus_sha256": "856c095bf0f2afcae13bde5d20173c5d7230759c691f244c36054699d78c2e94",
    "elapsed_seconds": 1.73,
    "peak_rss_bytes": 208666624,
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
    "typed_findings": [],
    "raw_time_stderr": "error: report output failed.\n        1.67 real         1.62 user         0.02 sys\n           208666624  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n               13531  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                 162  involuntary context switches\n         46126513934  instructions retired\n          7298917759  cycles elapsed\n           180896416  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format sarif --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-metadata-16-mib",
    "archive_bytes": 66489,
    "corpus_sha256": "51f2ad4bb10a13b88f1c383867c791a2b18457f6e332769a4a2299fdc2dba30c",
    "elapsed_seconds": 0.091,
    "peak_rss_bytes": 25329664,
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
    "typed_findings": [],
    "raw_time_stderr": "        0.04 real         0.02 user         0.00 sys\n            25329664  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                1781  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  17  involuntary context switches\n           304653821  instructions retired\n            88951110  cycles elapsed\n            19792376  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-metadata-over-block",
    "archive_bytes": 66489,
    "corpus_sha256": "31ec8f1d46f907f56bd81e222ed6cb69ff581240e996b52e60e8d8bc8bb98493",
    "elapsed_seconds": 0.091,
    "peak_rss_bytes": 8634368,
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
    "typed_findings": [
      {
        "ruleID": "UVK-LIM-002",
        "evidence": {
          "reason": "binaryReferences"
        }
      },
      {
        "ruleID": "UVK-RES-001",
        "evidence": {
          "resource": "usdcMetadataBlockBytes"
        }
      }
    ],
    "raw_time_stderr": "        0.02 real         0.00 user         0.00 sys\n             8634368  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 763  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  15  involuntary context switches\n            70402658  instructions retired\n            22324699  cycles elapsed\n             3015184  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-dense-250000",
    "archive_bytes": 1000678,
    "corpus_sha256": "aa1f001929c8450fcd44da72c63126b5b4b30ce7d85b1a74fc9017d1b7387996",
    "elapsed_seconds": 0.834,
    "peak_rss_bytes": 9551872,
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
    "typed_findings": [],
    "raw_time_stderr": "        0.80 real         0.22 user         0.55 sys\n             9551872  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 818  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  78  involuntary context switches\n         15611228563  instructions retired\n          3406511466  cycles elapsed\n             4014584  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-items-250001",
    "archive_bytes": 1000682,
    "corpus_sha256": "1adacc2cc2a12119b410b8f77ac2881b072936403333bb89216126ae7f23f157",
    "elapsed_seconds": 0.081,
    "peak_rss_bytes": 8683520,
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
    "typed_findings": [
      {
        "ruleID": "UVK-LIM-002",
        "evidence": {
          "reason": "binaryReferences"
        }
      },
      {
        "ruleID": "UVK-RES-001",
        "evidence": {
          "resource": "usdcItems"
        }
      }
    ],
    "raw_time_stderr": "        0.03 real         0.00 user         0.00 sys\n             8683520  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 765  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  16  involuntary context switches\n           171402287  instructions retired\n            40516271  cycles elapsed\n             3047952  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-utf8-4096",
    "archive_bytes": 4810,
    "corpus_sha256": "fc12fc9bc8c2adb65e29b6f6d25f294c0698670a0507a6909ecae53b5df0dc35",
    "elapsed_seconds": 0.083,
    "peak_rss_bytes": 8552448,
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
    "typed_findings": [
      {
        "ruleID": "UVK-PATH-006",
        "evidence": {
          "reason": "missingTarget"
        }
      }
    ],
    "raw_time_stderr": "        0.02 real         0.00 user         0.00 sys\n             8552448  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 758  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  16  involuntary context switches\n            60053380  instructions retired\n            20836552  cycles elapsed\n             2884088  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-utf8-4097",
    "archive_bytes": 4811,
    "corpus_sha256": "100facebb4b9bda233ec4d6fd7984c823b02c2bbec5615e19ddbe7b63f02e0a7",
    "elapsed_seconds": 0.088,
    "peak_rss_bytes": 8552448,
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
    "typed_findings": [
      {
        "ruleID": "UVK-LIM-002",
        "evidence": {
          "reason": "binaryReferences"
        }
      },
      {
        "ruleID": "UVK-RES-001",
        "evidence": {
          "resource": "tokenBytes"
        }
      }
    ],
    "raw_time_stderr": "        0.02 real         0.00 user         0.00 sys\n             8552448  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 758  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  16  involuntary context switches\n            58605360  instructions retired\n            22485516  cycles elapsed\n             2900472  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-shared-deep",
    "archive_bytes": 1221,
    "corpus_sha256": "3b0356f38f9b420cbfc7abf35b5582134f82af355c23c8e5b834dbd21a40b825",
    "elapsed_seconds": 0.093,
    "peak_rss_bytes": 8470528,
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
    "typed_findings": [],
    "raw_time_stderr": "        0.02 real         0.00 user         0.00 sys\n             8470528  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 752  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  19  involuntary context switches\n            63250659  instructions retired\n            24821089  cycles elapsed\n             2916832  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-depth-33",
    "archive_bytes": 1237,
    "corpus_sha256": "3ff4c9393c28579db87f8e7c6555b3cb7d98abe5a25919e9a758b0904066b10e",
    "elapsed_seconds": 0.05,
    "peak_rss_bytes": 8716288,
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
    "typed_findings": [
      {
        "ruleID": "UVK-LIM-002",
        "evidence": {
          "reason": "binaryReferences"
        }
      },
      {
        "ruleID": "UVK-RES-001",
        "evidence": {
          "resource": "usdcDepth"
        }
      }
    ],
    "raw_time_stderr": "        0.02 real         0.00 user         0.00 sys\n             8716288  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 768  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  15  involuntary context switches\n            61816909  instructions retired\n            20681164  cycles elapsed\n             3064312  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-aggregate-near",
    "archive_bytes": 132968,
    "corpus_sha256": "8a2fff4f8328c65f1cfe18caa3c391f1e97cf7663e1f810e4181b4d099fb8bef",
    "elapsed_seconds": 0.146,
    "peak_rss_bytes": 25346048,
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
    "typed_findings": [],
    "raw_time_stderr": "        0.06 real         0.04 user         0.00 sys\n            25346048  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                1781  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  14  involuntary context switches\n           541534154  instructions retired\n           148876605  cycles elapsed\n            19808760  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-aggregate-over",
    "archive_bytes": 199453,
    "corpus_sha256": "7014fcbb5dc35fe6858ee2dcff413496886cbb7ee774400a0c94fb9812e1a4c6",
    "elapsed_seconds": 0.153,
    "peak_rss_bytes": 25608192,
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
    "typed_findings": [
      {
        "ruleID": "UVK-LIM-002",
        "evidence": {
          "reason": "binaryReferences"
        }
      },
      {
        "ruleID": "UVK-RES-001",
        "evidence": {
          "resource": "usdcDecodeBytes"
        }
      }
    ],
    "raw_time_stderr": "        0.07 real         0.04 user         0.00 sys\n            25608192  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                1798  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  17  involuntary context switches\n           552591787  instructions retired\n           154297445  cycles elapsed\n            19972624  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-numeric-0",
    "archive_bytes": 715,
    "corpus_sha256": "080a6b15d2d742a0ff6e31dc83c265680f4c908a177fb1d0522aa45ccbf35f90",
    "elapsed_seconds": 0.092,
    "peak_rss_bytes": 8306688,
    "exit": 0,
    "report_bytes": 1661,
    "findings": 0,
    "expected_exit": 0,
    "expected_findings": 0,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": null,
    "typed_findings": [],
    "raw_time_stderr": "        0.02 real         0.00 user         0.00 sys\n             8306688  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 742  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  15  involuntary context switches\n            55159378  instructions retired\n            21847816  cycles elapsed\n             2752992  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-numeric-250000",
    "archive_bytes": 715,
    "corpus_sha256": "9f42e0b9947bccca9cc8288771c75af61e72d6e5caf938424dc618773d8c6689",
    "elapsed_seconds": 0.089,
    "peak_rss_bytes": 8306688,
    "exit": 0,
    "report_bytes": 1661,
    "findings": 0,
    "expected_exit": 0,
    "expected_findings": 0,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": null,
    "typed_findings": [],
    "raw_time_stderr": "        0.03 real         0.00 user         0.00 sys\n             8306688  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 741  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  13  involuntary context switches\n            55049196  instructions retired\n            22093268  cycles elapsed\n             2752992  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-numeric-250001",
    "archive_bytes": 715,
    "corpus_sha256": "4f1b8a9a4afc3af709b06c3cc9109327c2d958f92928580892a7fb99678fc06a",
    "elapsed_seconds": 0.05,
    "peak_rss_bytes": 8339456,
    "exit": 0,
    "report_bytes": 1661,
    "findings": 0,
    "expected_exit": 0,
    "expected_findings": 0,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": null,
    "typed_findings": [],
    "raw_time_stderr": "        0.02 real         0.00 user         0.00 sys\n             8339456  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 744  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  17  involuntary context switches\n            55143430  instructions retired\n            21688174  cycles elapsed\n             2785760  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-numeric-max",
    "archive_bytes": 715,
    "corpus_sha256": "180b3c6b65c6aa3b70825b80d9f98c6bd220a533835ecbf1a31e75f6a4edd12b",
    "elapsed_seconds": 0.05,
    "peak_rss_bytes": 8323072,
    "exit": 0,
    "report_bytes": 1661,
    "findings": 0,
    "expected_exit": 0,
    "expected_findings": 0,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": null,
    "typed_findings": [],
    "raw_time_stderr": "        0.02 real         0.00 user         0.00 sys\n             8323072  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 742  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  18  involuntary context switches\n            55112283  instructions retired\n            18673302  cycles elapsed\n             2769376  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-compressed-numeric-0",
    "archive_bytes": 715,
    "corpus_sha256": "a1fd3a595700b6e37b3539cdf034afc17317918bfd868873337722548ed28f0b",
    "elapsed_seconds": 0.05,
    "peak_rss_bytes": 8306688,
    "exit": 0,
    "report_bytes": 1661,
    "findings": 0,
    "expected_exit": 0,
    "expected_findings": 0,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": null,
    "typed_findings": [],
    "raw_time_stderr": "        0.02 real         0.00 user         0.00 sys\n             8306688  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 743  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   1  voluntary context switches\n                  20  involuntary context switches\n            55266106  instructions retired\n            19933269  cycles elapsed\n             2752992  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-compressed-numeric-250000",
    "archive_bytes": 715,
    "corpus_sha256": "f86e3d706673c852d3e7c6f4f9790ee86a26a9a0fa2d82973965a724b3617fed",
    "elapsed_seconds": 0.05,
    "peak_rss_bytes": 8306688,
    "exit": 0,
    "report_bytes": 1661,
    "findings": 0,
    "expected_exit": 0,
    "expected_findings": 0,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": null,
    "typed_findings": [],
    "raw_time_stderr": "        0.02 real         0.00 user         0.00 sys\n             8306688  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 742  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  17  involuntary context switches\n            55111680  instructions retired\n            18756603  cycles elapsed\n             2752992  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-compressed-numeric-250001",
    "archive_bytes": 715,
    "corpus_sha256": "7222f875fcac45b47eb004bae3ecdefe8c911fe2ad7cf44c34259f6585a4eb63",
    "elapsed_seconds": 0.049,
    "peak_rss_bytes": 8306688,
    "exit": 0,
    "report_bytes": 1661,
    "findings": 0,
    "expected_exit": 0,
    "expected_findings": 0,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": null,
    "typed_findings": [],
    "raw_time_stderr": "        0.02 real         0.00 user         0.00 sys\n             8306688  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 742  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  13  involuntary context switches\n            55030157  instructions retired\n            18522828  cycles elapsed\n             2752992  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-compressed-numeric-max",
    "archive_bytes": 715,
    "corpus_sha256": "ca92ee95a0738f52f06ecc9a264518afe18f96f10c7fb0749aabb98caba895d8",
    "elapsed_seconds": 0.049,
    "peak_rss_bytes": 8290304,
    "exit": 0,
    "report_bytes": 1661,
    "findings": 0,
    "expected_exit": 0,
    "expected_findings": 0,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": null,
    "typed_findings": [],
    "raw_time_stderr": "        0.01 real         0.00 user         0.00 sys\n             8290304  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 741  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  16  involuntary context switches\n            55095231  instructions retired\n            18657281  cycles elapsed\n             2736608  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-shared-numeric-near",
    "archive_bytes": 142590,
    "corpus_sha256": "e64aa3a920815ad69652e880113a302bb6a793fd8e223a14ca10d1ac04d16f64",
    "elapsed_seconds": 1.764,
    "peak_rss_bytes": 8863744,
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
    "typed_findings": [],
    "raw_time_stderr": "        1.74 real         0.51 user         1.21 sys\n             8863744  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 775  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                 193  involuntary context switches\n         34717097594  instructions retired\n          7676598567  cycles elapsed\n             3326456  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-work-over",
    "archive_bytes": 142606,
    "corpus_sha256": "ff647581be736d2b3a308ad35a86450ee5f3ac551479c056579d61d21b5aa3b7",
    "elapsed_seconds": 1.773,
    "peak_rss_bytes": 9076736,
    "exit": 1,
    "report_bytes": 2865,
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
    "typed_findings": [
      {
        "ruleID": "UVK-LIM-002",
        "evidence": {
          "reason": "binaryReferences"
        }
      },
      {
        "ruleID": "UVK-RES-001",
        "evidence": {
          "resource": "usdcWork"
        }
      }
    ],
    "raw_time_stderr": "        1.73 real         0.50 user         1.21 sys\n             9076736  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 790  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                 174  involuntary context switches\n         34731648821  instructions retired\n          7641545890  cycles elapsed\n             3441168  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-numeric-aggregate",
    "archive_bytes": 143604,
    "corpus_sha256": "de2c3ccecfb624d0d6b8283049e455473b3c314084f80487487b1cab8197ea2a",
    "elapsed_seconds": 1.817,
    "peak_rss_bytes": 8732672,
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
    "typed_findings": [],
    "raw_time_stderr": "        1.75 real         0.49 user         1.24 sys\n             8732672  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 768  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                 166  involuntary context switches\n         34731560780  instructions retired\n          7671317784  cycles elapsed\n             3195384  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-numeric-aggregate-over",
    "archive_bytes": 143621,
    "corpus_sha256": "cc824b64c3f8ebcf77bf26ed9aca3c671945522d1af82e645b42abd3733ba92a",
    "elapsed_seconds": 1.791,
    "peak_rss_bytes": 8962048,
    "exit": 1,
    "report_bytes": 2857,
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
    "typed_findings": [
      {
        "ruleID": "UVK-LIM-002",
        "evidence": {
          "reason": "binaryReferences"
        }
      },
      {
        "ruleID": "UVK-RES-001",
        "evidence": {
          "resource": "usdcWork"
        }
      }
    ],
    "raw_time_stderr": "        1.74 real         0.49 user         1.23 sys\n             8962048  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 782  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                 146  involuntary context switches\n         34719912159  instructions retired\n          7601514507  cycles elapsed\n             3326480  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-truncated-numeric-header",
    "archive_bytes": 714,
    "corpus_sha256": "e011ce6477db7c39941cdd6d147589bc9bcff95f5d160889170a7905b59aecca",
    "elapsed_seconds": 0.086,
    "peak_rss_bytes": 8519680,
    "exit": 1,
    "report_bytes": 2866,
    "findings": 2,
    "expected_exit": 1,
    "expected_findings": null,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": [
      "UVK-USD-001",
      "reason",
      "invalidRange"
    ],
    "typed_findings": [
      {
        "ruleID": "UVK-LIM-007",
        "evidence": {
          "reason": "partialBinaryReferences"
        }
      },
      {
        "ruleID": "UVK-USD-001",
        "evidence": {
          "reason": "invalidRange"
        }
      }
    ],
    "raw_time_stderr": "        0.02 real         0.00 user         0.00 sys\n             8519680  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 755  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  17  involuntary context switches\n            57616430  instructions retired\n            21318467  cycles elapsed\n             2867704  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-unknown-numeric-flags",
    "archive_bytes": 715,
    "corpus_sha256": "0f479c115a318ec08bcd36af642e5830b3f89cb614a106255c453c8c311230c8",
    "elapsed_seconds": 0.088,
    "peak_rss_bytes": 8536064,
    "exit": 2,
    "report_bytes": 2919,
    "findings": 2,
    "expected_exit": 2,
    "expected_findings": null,
    "format": "json",
    "status": "PASS",
    "failures": [],
    "expectation_checked": true,
    "expected_rule_reason": [
      "UVK-LIM-007",
      "reason",
      "unsupportedValue"
    ],
    "typed_findings": [
      {
        "ruleID": "UVK-LIM-007",
        "evidence": {
          "reason": "partialBinaryReferences"
        }
      },
      {
        "ruleID": "UVK-LIM-007",
        "evidence": {
          "reason": "unsupportedValue"
        }
      }
    ],
    "raw_time_stderr": "        0.02 real         0.00 user         0.00 sys\n             8536064  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 756  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  16  involuntary context switches\n            57872393  instructions retired\n            21026749  cycles elapsed\n             2884088  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-shared-asset-items-over",
    "archive_bytes": 733,
    "corpus_sha256": "6506aa346e5f203b313ce5584f9d27ecb1a09528940afc0dfae778269fa9b0c2",
    "elapsed_seconds": 0.091,
    "peak_rss_bytes": 8503296,
    "exit": 1,
    "report_bytes": 2863,
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
    "typed_findings": [
      {
        "ruleID": "UVK-LIM-002",
        "evidence": {
          "reason": "binaryReferences"
        }
      },
      {
        "ruleID": "UVK-RES-001",
        "evidence": {
          "resource": "usdcItems"
        }
      }
    ],
    "raw_time_stderr": "        0.03 real         0.00 user         0.00 sys\n             8503296  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 754  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  15  involuntary context switches\n            57746094  instructions retired\n            23584189  cycles elapsed\n             2851320  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-large-layer-small-metadata",
    "archive_bytes": 268432046,
    "corpus_sha256": "dd272bde32e6a0452dc01f43f10d1b689aeb3b16de16c5d5bb2764801962b9bb",
    "elapsed_seconds": 0.737,
    "peak_rss_bytes": 8617984,
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
    "typed_findings": [
      {
        "ruleID": "UVK-BUD-001",
        "evidence": {}
      },
      {
        "ruleID": "UVK-BUD-002",
        "evidence": {}
      }
    ],
    "raw_time_stderr": "        0.66 real         0.61 user         0.02 sys\n             8617984  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 761  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  76  involuntary context switches\n         19977139735  instructions retired\n          2829883181  cycles elapsed\n             2982416  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-mixed-occurrences",
    "archive_bytes": 800839,
    "corpus_sha256": "900d1befb81fadf04e9ea6a77203143c1332e6231569eda446f1f5763eadad61",
    "elapsed_seconds": 0.321,
    "peak_rss_bytes": 8847360,
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
    "typed_findings": [
      {
        "ruleID": "UVK-LIM-007",
        "evidence": {
          "reason": "partialBinaryReferences"
        }
      },
      {
        "ruleID": "UVK-RES-001",
        "evidence": {
          "resource": "tokenCount"
        }
      }
    ],
    "raw_time_stderr": "        0.29 real         0.15 user         0.11 sys\n             8847360  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                 775  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                  35  involuntary context switches\n          6130810545  instructions retired\n          1166714781  cycles elapsed\n             3195408  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-near-report-json",
    "archive_bytes": 45040,
    "corpus_sha256": "0267f47185cc316cd0e481175c49dcc74ed92b0696092e70d0ee76904771b36c",
    "elapsed_seconds": 1.545,
    "peak_rss_bytes": 84000768,
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
    "typed_findings": [
      {
        "ruleID": "UVK-PATH-006",
        "evidence": {
          "reason": "missingTarget"
        }
      }
    ],
    "raw_time_stderr": "        1.47 real         1.40 user         0.04 sys\n            84000768  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                5366  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                 155  involuntary context switches\n         40446134335  instructions retired\n          6416363736  cycles elapsed\n            78381632  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-report-cap-json",
    "archive_bytes": 48856,
    "corpus_sha256": "8123a0e6ac8dc18533eb79b9f4defd9a98755e7bcb09f2262b76878f49ef0e85",
    "elapsed_seconds": 2.044,
    "peak_rss_bytes": 116621312,
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
    "typed_findings": [],
    "raw_time_stderr": "error: report output failed.\n        1.97 real         1.90 user         0.04 sys\n           116621312  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                7353  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                 203  involuntary context switches\n         54603814486  instructions retired\n          8664335646  cycles elapsed\n           111018584  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-near-report-sarif",
    "archive_bytes": 45040,
    "corpus_sha256": "0267f47185cc316cd0e481175c49dcc74ed92b0696092e70d0ee76904771b36c",
    "elapsed_seconds": 1.6,
    "peak_rss_bytes": 85573632,
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
    "typed_findings": [
      {
        "ruleID": "UVK-PATH-006",
        "evidence": {
          "reason": "missingTarget"
        }
      }
    ],
    "raw_time_stderr": "        1.51 real         1.44 user         0.04 sys\n            85573632  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                5462  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                 141  involuntary context switches\n         41216676499  instructions retired\n          6555055220  cycles elapsed\n            79954496  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format sarif --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  },
  {
    "case": "usdc-report-cap-sarif",
    "archive_bytes": 48856,
    "corpus_sha256": "8123a0e6ac8dc18533eb79b9f4defd9a98755e7bcb09f2262b76878f49ef0e85",
    "elapsed_seconds": 2.095,
    "peak_rss_bytes": 117587968,
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
    "typed_findings": [],
    "raw_time_stderr": "error: report output failed.\n        2.00 real         1.93 user         0.04 sys\n           117587968  maximum resident set size\n                   0  average shared memory size\n                   0  average unshared data size\n                   0  average unshared stack size\n                7413  page reclaims\n                   4  page faults\n                   0  swaps\n                   0  block input operations\n                   0  block output operations\n                   0  messages sent\n                   0  messages received\n                   0  signals received\n                   0  voluntary context switches\n                 199  involuntary context switches\n         54622411813  instructions retired\n          8797821117  cycles elapsed\n           111985240  peak memory footprint\n",
    "raw_stdout": "",
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/input.usdz --format sarif --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-pyuc_dbe/report.out"
  }
]
```

## Scope

These observations establish only this release corpus on the recorded arm64 local-SSD host. They do not establish a universal/OS-enforced memory sandbox. macOS 15 / Xcode 16 / Swift 6.0 were not available for this run and remain unobserved; the recorded host/toolchain is the actual observed environment. Test-owned counter proofs separately cover logically exact aggregate declarations that cannot coexist with ZIP overhead at the archive byte ceiling.

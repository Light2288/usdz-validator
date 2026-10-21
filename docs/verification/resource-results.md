# Native resource acceptance

Result: PASS; external checker disabled for every invocation.

Target: peak RSS <=268,435,456 bytes and elapsed <=60 seconds per release native invocation.
Darwin /usr/bin/time -l reports maximum resident set size in bytes. Elapsed is the greater of its real time and the parent wall measurement; a 60-second deadline kills and reaps the entire process group.

Fixture generation, CRC construction, corpus hashing, and report parsing are outside the measured CLI process. Temporary regular files are streamed with at most 64 KiB chunks; no giant fixture is committed. Each file is <=256 MiB. Near-report cases retain 9,990 real reference findings plus coverage locations, with 1,100-byte safe layer names. Cap cases use 4,096-byte names, remain below upstream layer/token/count limits, and must return operational exit 3 without replacing an existing output destination or emitting partial stdout.

## Observed host

```json
{
  "machine": "Mac17,6",
  "cpu": "Apple M5 Max",
  "physical_memory_bytes": "38654705664",
  "os": "ProductName:\t\tmacOS\nProductVersion:\t\t27.0.1\nBuildVersion:\t\t26A434",
  "toolchain": "Apple Swift version 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1)\nTarget: arm64-apple-macosx27.0.0",
  "xcode": "Xcode 27.1\nBuild version 27A9275",
  "executable_sha256": "e05e5f86514aa97cfc7b897ea7adf5a3b85c5a2c73d6f094d4c527875b4a4b45",
  "measurement_generator_sha256": "12d1b457a7eff3a0fb356baecefd02a17a4e0cc71a237dcd5495f31a7e0cdcf0",
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
| near-512-mib | 536870259 | 1.447 | 8470528 | 0 | 3 | 2992 | PASS |
| 10000-entries | 1200021 | 0.292 | 17481728 | 0 | 1 | 2034 | PASS |
| 16-mib-100000-tokens | 16777357 | 0.289 | 8355840 | 0 | 0 | 1666 | PASS |
| header-1-mib | 1048836 | 0.077 | 8241152 | 0 | 0 | 1665 | PASS |
| near-report-json | 102230 | 1.375 | 102170624 | 1 | 9990 | 27598046 | PASS |
| near-report-sarif | 102230 | 1.434 | 105578496 | 1 | 9990 | 29251561 | PASS |
| findings-truncation | 100161 | 0.457 | 37683200 | 1 | 10000 | 5804498 | PASS |
| report-cap-json | 108234 | 1.815 | 207093760 | 3 | None | 5 | PASS |
| report-cap-sarif | 108234 | 1.712 | 208732160 | 3 | None | 5 | PASS |

## Exact commands and corpus hashes

Paths below identify deleted temporary measurement files; regenerate them with the command below. Timings/host data belong only in this verification document, never product reports.

Reproduce: `swift build -c release` then `python3 Scripts/verify-resources.py --executable .build/release/usdz-validator --output docs/verification/resource-results.md`.

```json
[
  {
    "case": "near-512-mib",
    "archive_bytes": 536870259,
    "corpus_sha256": "5391ada98fd8ea1bb3c1e06572940d8739709a82b47c2fbef096df8e50202a90",
    "elapsed_seconds": 1.447,
    "peak_rss_bytes": 8470528,
    "exit": 0,
    "report_bytes": 2992,
    "findings": 3,
    "status": "PASS",
    "failures": [],
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-xdvntox_/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-xdvntox_/report.out"
  },
  {
    "case": "10000-entries",
    "archive_bytes": 1200021,
    "corpus_sha256": "0da9b5eddeb0f1472a1d1a49e50940bb0996206e91908867a5dba417f23f15da",
    "elapsed_seconds": 0.292,
    "peak_rss_bytes": 17481728,
    "exit": 0,
    "report_bytes": 2034,
    "findings": 1,
    "status": "PASS",
    "failures": [],
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-xdvntox_/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-xdvntox_/report.out"
  },
  {
    "case": "16-mib-100000-tokens",
    "archive_bytes": 16777357,
    "corpus_sha256": "e69ae8a6582687100ab7e7d05ac86b59070572ba508578763a5ac0e5b89fa45f",
    "elapsed_seconds": 0.289,
    "peak_rss_bytes": 8355840,
    "exit": 0,
    "report_bytes": 1666,
    "findings": 0,
    "status": "PASS",
    "failures": [],
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-xdvntox_/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-xdvntox_/report.out"
  },
  {
    "case": "header-1-mib",
    "archive_bytes": 1048836,
    "corpus_sha256": "a5fc35449b2d7208e7d8008086ead89f49b5ad8054ba773014fd4eb36ab14e28",
    "elapsed_seconds": 0.077,
    "peak_rss_bytes": 8241152,
    "exit": 0,
    "report_bytes": 1665,
    "findings": 0,
    "status": "PASS",
    "failures": [],
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-xdvntox_/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-xdvntox_/report.out"
  },
  {
    "case": "near-report-json",
    "archive_bytes": 102230,
    "corpus_sha256": "cde6d03bb40f300f7374fc8382be6574951ba2d5ae97af4350c57ba571fe5bc4",
    "elapsed_seconds": 1.375,
    "peak_rss_bytes": 102170624,
    "exit": 1,
    "report_bytes": 27598046,
    "findings": 9990,
    "status": "PASS",
    "failures": [],
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-xdvntox_/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-xdvntox_/report.out"
  },
  {
    "case": "near-report-sarif",
    "archive_bytes": 102230,
    "corpus_sha256": "cde6d03bb40f300f7374fc8382be6574951ba2d5ae97af4350c57ba571fe5bc4",
    "elapsed_seconds": 1.434,
    "peak_rss_bytes": 105578496,
    "exit": 1,
    "report_bytes": 29251561,
    "findings": 9990,
    "status": "PASS",
    "failures": [],
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-xdvntox_/input.usdz --format sarif --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-xdvntox_/report.out"
  },
  {
    "case": "findings-truncation",
    "archive_bytes": 100161,
    "corpus_sha256": "c77c5366d856aaa83c595ac76aa4becca403aabbedee8f5be3ae4689e48affe7",
    "elapsed_seconds": 0.457,
    "peak_rss_bytes": 37683200,
    "exit": 1,
    "report_bytes": 5804498,
    "findings": 10000,
    "status": "PASS",
    "failures": [],
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-xdvntox_/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-xdvntox_/report.out"
  },
  {
    "case": "report-cap-json",
    "archive_bytes": 108234,
    "corpus_sha256": "856c095bf0f2afcae13bde5d20173c5d7230759c691f244c36054699d78c2e94",
    "elapsed_seconds": 1.815,
    "peak_rss_bytes": 207093760,
    "exit": 3,
    "report_bytes": 5,
    "findings": null,
    "status": "PASS",
    "failures": [],
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-xdvntox_/input.usdz --format json --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-xdvntox_/report.out"
  },
  {
    "case": "report-cap-sarif",
    "archive_bytes": 108234,
    "corpus_sha256": "856c095bf0f2afcae13bde5d20173c5d7230759c691f244c36054699d78c2e94",
    "elapsed_seconds": 1.712,
    "peak_rss_bytes": 208732160,
    "exit": 3,
    "report_bytes": 5,
    "findings": null,
    "status": "PASS",
    "failures": [],
    "command": "/usr/bin/time -l /Users/davide/Personal/Projects/usdz-validator/.build/out/Products/Release/usdz-validator validate /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-xdvntox_/input.usdz --format sarif --output /var/folders/8q/t_gg45z912xghvjmct5p7kkr0000gn/T/uvk-resource-xdvntox_/report.out"
  }
]
```

## Scope

These observations establish only this release corpus on the recorded arm64 local-SSD host. They do not establish a universal/OS-enforced memory sandbox. macOS 15 / Xcode 16 / Swift 6.0 were not available for this run and remain unobserved; the recorded host/toolchain is the actual observed environment. Test-owned counter proofs separately cover logically exact aggregate declarations that cannot coexist with ZIP overhead at the archive byte ceiling.

# Local Apple asset verification — 2026-10-21

Five user-provided files, described by the user as Apple gallery downloads, were tested on the verified current host with validator 0.1.0 and Apple USD Tools (0.25.11). All original SHA-256 values were unchanged after testing. No validator implementation change was needed.

These are opt-in manual observations. Exact download URLs and redistribution terms were not supplied or verified. Models, derived copies and raw diagnostic reports remain local in ignored verification output; they are not committed, downloaded by tests, or prerequisites for the normal unit suite. This document grants no rights to redistribute the assets.

## Original assets

Native inspection reported exactly one limitation per original: `UVK-LIM-002`, binary-USDC reference inspection unavailable. Container structure, entry safety, byte budgets and texture dimensions were complete, with no detected native errors or budget warnings. Every original's native default exit was `2`; native `--allow-incomplete` exit was `0`.

The optional installed checker was then requested through the CLI. It completed on every asset with policy `strict-root-package-only-v1` under `general-v1`:

| Original | Checker outcome | Checker exit | CLI `--usdchecker` exit | CLI `--usdchecker --allow-incomplete` exit |
| --- | --- | ---: | ---: | ---: |
| `seahorse_anim_mtl_variant.usdz` | No failure reported | 0 | 2 | 0 |
| `pancakes_photogrammetry.usdz` | No failure reported | 0 | 2 | 0 |
| `fender_stratocaster.usdz` | Failure reported | 1 | 1 | 1 |
| `slide.usdz` | No failure reported | 0 | 2 | 0 |
| `teapot.usdz` | No failure reported | 0 | 2 | 0 |

Exit `2` on an otherwise accepted binary asset is incomplete native coverage, not a claim that the model is broken. A checker success does not upgrade native reference coverage. `--allow-incomplete` accepts that native gap while retaining `validationStatus: incomplete`; it does not suppress native or checker errors. These observations do not cover the additional `apple-portable-v1`/`--arkit` checks, rendering, every variant/time sample, nested dependencies or exhaustive Apple compatibility.

Original fingerprints:

| File | SHA-256 |
| --- | --- |
| `seahorse_anim_mtl_variant.usdz` | `f079e84eba0a3a5e3133e3700ce2da17db6d2dcc061e23648cf20ac5471653cf` |
| `pancakes_photogrammetry.usdz` | `45f0d144138dcd3546b4d37132b91a7b00fb2bcf187f017342f4bc5a45f087b1` |
| `fender_stratocaster.usdz` | `3e0ee48cad8f03cb807cf4747be9c4a48023384a5450efbe269d8550bcf9f61e` |
| `slide.usdz` | `03c7d6786f73ce39b27e59091b370af8fa22c9affc5d8a09eb53ea996fe5eff2` |
| `teapot.usdz` | `44bb6d1dfe0e3e890f7b8f12a177b4ae9da385bc13fcec25819fc23eaebc055c` |

## Confirmed Fender finding

Apple's checker reported `usdGeomValidators:SubsetFamilies.InvalidSubsetFamily` at `/fender_stratocaster/StratocasterGuitar`:

> Imageable prim has invalid subset family 'materialBind': Number of unique indices at time DEFAULT does not match the element count 149979.

The failure reproduced by directly invoking `/usr/bin/usdchecker` with the adapter's exact arguments, and again without `--strict`. It is not merely a warning promoted by strict mode. The CLI correctly retained aggregate external error `USDCK-001`, its checker version and separate provenance.

A subsequent read-only diagnostic used the installed `/usr/bin/usdcat` to inspect the authored root layer in memory, then counted the guitar mesh's default `faceVertexCounts` and its direct face-based `materialBind` subset indices. No asset was rewritten, no converted asset was saved, and this diagnostic is not part of the validator:

| Observation | Value |
| --- | ---: |
| Mesh faces, all triangles | 149,979 |
| Material subsets | 18 |
| Total authored subset indices | 149,002 |
| Unique covered faces | 149,002 |
| Uncovered faces | 977 |
| Out-of-range indices | 0 |
| Duplicate/overlapping indices | 0 |

The authored `subsetFamily:materialBind:familyType` is `partition`, which requires complete, nonoverlapping face coverage. The 977 uncovered faces support the checker finding; the first uncovered face index is 106,975. This establishes an authored material-subset defect, not its visual impact or whether a particular renderer displays the asset acceptably. A gallery asset is not a conformance oracle for every later checker version.

## Damaged copies

Three separate copies of `slide.usdz` exercise specific errors. The originals were never modified or extracted.

| Local copy | Mutation | Blocking rule | Default exit | Exit with `--allow-incomplete` |
| --- | --- | --- | ---: | ---: |
| `slide-truncated.usdz` | Remove final 22-byte ZIP end record | `UVK-ARC-001` | 1 | 1 |
| `slide-corrupt-texture-crc.usdz` | Flip byte at offset 1,514,067 from 130 to 131 in `0/slide_stylized_bc.png`, leaving recorded CRC unchanged | `UVK-ARC-003` | 1 | 1 |
| `slide-unsafe-entry-path.usdz` | Rename that PNG to `../lide_stylized_bc.png` in both ZIP headers, retaining lengths, alignment and CRCs | `UVK-PATH-001` | 1 | 1 |

The path mutation changes name bytes at local offset 1,481,285 and central-directory offset 6,452,956. Python's independent `zipfile.testzip()` identified the intended PNG checksum failure in the CRC copy, and accepted every payload CRC in the unsafe-path copy. No extraction was performed. The installed checker was not invoked on these deliberately damaged or unsafe copies.

| Copy | SHA-256 |
| --- | --- |
| `slide-truncated.usdz` | `b80d1151d53e94a72f9153014fbf1344efe3ebf9338cf811ce7f52523ebfcc4c` |
| `slide-corrupt-texture-crc.usdz` | `07fb5316cfab7668b9243c862176fbdc2cc638528a8c3ee66839c78965064fd1` |
| `slide-unsafe-entry-path.usdz` | `72e19f5a410dd69197dcb1302482dc5e9451e00ccfe859b622fca44450e93205` |

Native checks used 44 invocations across originals, gate policies, damaged copies and report formats. Repeated native invocations had identical exit/stdout/stderr. Damaged-copy JSON, text and SARIF reports contained the expected findings; CLI stderr was empty. The checker tests used ten CLI invocations across the two gate policies, plus one diagnostic CLI invocation and two direct checker invocations to isolate Fender's failure. External-tool diagnostic bytes are not asserted deterministic across hosts or tool versions.

## Reproduction and evidence

With an original trusted asset already present locally, run from the repository root:

```sh
swift build -c release --product usdz-validator
.build/release/usdz-validator validate /path/to/slide.usdz --format json
.build/release/usdz-validator validate /path/to/slide.usdz --usdchecker --format json
.build/release/usdz-validator validate /path/to/slide.usdz --usdchecker --allow-incomplete --format json
```

The observed exits for that original are `2`, `2`, `0`, respectively. For the fingerprinted Fender original, the last two commands instead return `1`. The adapter's Fender failure can be reproduced directly:

```sh
/usr/bin/usdchecker --strict --rootPackageOnly --out stderr /path/to/fender_stratocaster.usdz
/usr/bin/usdchecker --rootPackageOnly --out stderr /path/to/fender_stratocaster.usdz
```

The original local records are retained under `verification-output/apple-assets-2026-10-21/`: `results.json` binds the native findings, mutation recipes and hashes; `usdchecker/results.json` records commands, tool version and outcomes. `usdchecker/fender-inspection.json` and its adjacent `inspect-fender.py` retain the follow-up count method, every uncovered face index, per-subset counts and the unchanged source hash. Their adjacent reproduction scripts and reports remain ignored. The opt-in diagnostic report includes local arguments/raw output; default reports omit those details. These private paths are evidence locations on the verification host, not files distributed with the repository.

The tested product state was commit `5729bad6b6832934751c179696248bea969c4ba9`; release executable SHA-256 was `f54fc70f44c3f9d5cfef7c3a8cddca34123e439c43799965ed82cae9698f7ffe`. Later rebuilds can relink that executable; the [release summary](release-summary.md) identifies the final verification state separately. The normal suite remains based on the original MIT fixture and deterministic fake checker states; see [fixture provenance](../fixtures.md).

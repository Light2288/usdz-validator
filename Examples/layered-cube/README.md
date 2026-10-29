# Logo-derived layered cube

The [project illustration](../../assets/branding/usdz-validator.png) became a real 3D example: a procedural reconstruction of its blue cube frame, pyramid, teal gridded platform, and pale-blue lower platform. The model has lightly translucent sides and consistent rear geometry. The illustration's magnifying glass and exterior glow are omitted.

## Files and provenance

- [model.usdz](model.usdz) is the self-contained, rotatable model. It contains one stored entry, `model.usdc`, with no textures or external dependencies.
- [source/model.usda](source/model.usda) is the editable, human-readable USD scene. Its units are meters, its up axis is Y, and its outer bounds span 20 cm.
- [validation.json](validation.json) is actual native CLI output for this package under the default policy.

The illustration was supplied as `Magnifying Glass Over Blue Layered Cube.png`. The model is the accepted candidate-003, authored on October 28, 2026 with a procedural Python generator. It interprets a single illustration rather than recovering exact hidden geometry, optics, or lighting. These files preserve the original image and accepted USDZ/USDA bytes without modification.

The retained creation record identifies Python 3.14.7 and Apple USD Tools 0.25.11. Packaging converted `model.usda` to binary `model.usdc` with `usdcat`, then packaged that scene with `usdzip`. Those are historical artwork-tool observations, not validator dependencies. The procedural generator and artwork inspection tools are outside this example; the editable USD source is included.

SHA-256 identities:

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| Project illustration | 1,345,721 | `74723d5ddd7017e0943882a3c9b35ef3aca4b137244007aaabbe4bc2804a256b` |
| `model.usdz` | 530,905 | `89ee36e574d27275387367e67199a24ab7b4d356325f2b5f1fdfa60f1f2297a3` |
| `source/model.usda` | 2,539,631 | `802c1a05ee68ecc5fc5c1b716a19a5dd1e2a69161bd512a10da981dd1e8ca1c3` |

## View and validate

On a Mac, select `model.usdz` in Finder and press Space to open Quick Look; drag to rotate. Appearance can vary between viewers. The repository supplies a downloadable asset rather than an embedded viewer.

From the repository root, [build the CLI](../../README.md#build-and-run), then reproduce the saved JSON on stdout:

```sh
.build/release/usdz-validator validate Examples/layered-cube/model.usdz --format json
```

The report was captured on October 29, 2026 with validator **0.2.0**, schema major **1**, safety envelope **3**, and the default **general-v1** profile. Built-in budgets apply; the failure threshold is `error`, incomplete coverage is not accepted, sensitive details are excluded, and the external checker is unrequested. The observed result is exit `0`, empty stderr, complete requested native coverage, no native findings, and no operational errors. The stdout document matches the saved report exactly.

## What the result establishes

Native acceptance covers the declared package, supported package-local references, and delivery-budget checks. This model has no textures or external dependencies, so it does not demonstrate missing-texture detection or texture-dimension handling on actual image data. Complete coverage does not establish complete USD conformance, geometry correctness, composed dependencies, asset security, or compatibility with every renderer.

Separate artwork checks performed on October 28, 2026 included imported-geometry inspection, USD load/package checks, rendered previews, and human-confirmed Quick Look rotation. These are historical observations of the same USDZ bytes, not checks performed by the validator or newly repeated visual/geometry acceptance. Exact illustration matching and identical rendering across viewers are not promised. See the [inspection boundary](../../docs/inspection-boundary.md) and [CLI policy](../../docs/cli.md#exit-codes-and-gate-policy).

## License

The project illustration, USDZ model, editable USDA source, report, and this documentation are distributed under the repository's [MIT license](../../LICENSE), copyright 2026 USDZ Validation Kit contributors. Preserve its copyright and permission notice when redistributing. The names of external creation tools describe provenance; their implementations are not included or relicensed here.

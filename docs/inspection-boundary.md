# Native inspection boundary

The engine reads one stable local regular file, read-only. It does not extract, decompress, decode pixels, load a USD stage, traverse composed dependencies, read authored references from the host filesystem, run native tools, or require a network connection. The [explicit installed checker](cli.md#optional-installed-checker) has a separate trusted-input boundary.

## Container and names

Native support covers classic single-disk ZIP with stored regular files and optional empty directories. It checks bounded EOCD/central/local metadata, consistent sizes/ownership/ranges, 64-byte payload alignment, CRC-32, encryption absence, and stored sizes at exactly 1:1 (including zero/zero). Compression, unequal sizes and nonempty/zero claims are rejected before payload interpretation. A CRC match does not validate an embedded format.

ZIP64, descriptors, split disks, unsupported required versions/flags/encodings, self-extracting prefixes, unsupported layouts and unknown type semantics cause explicit limitations; independently established malformed records remain errors. Nested `.usdz` content is recognized but uninspected. Unsafe indexing prerequisites stop dependent checks without speculative missing-reference findings.

The first regular entry in physical order must have recognized USD content under the standalone-asset policy; directories do not choose the default layer. This project policy applies when using the package as a stage and does not claim a universal unconditional USDZ default-layer rule. `#usda 1.0` and `PXR-USDC` identify bounded text/binary headers; they do not establish valid grammar, crate version, composition or scene content. Obvious `.usda`/`.usdc` signature mismatches are errors; `.usd` is classified by content.

The case-insensitive suffix catalogue is `.usd`, `.usda`, `.usdc`, `.usdz`, `.png`, `.jpg`, `.jpeg`, `.jpe`, `.jfif`, `.exr`, `.avif`, `.m4a`, `.mp3`, `.wav`. Other suffixes violate this version's file-type policy, not every future USDZ specification.

Names resolve in an in-memory, case-sensitive namespace using exact UTF-8 bytes. No Unicode normalization, case folding, percent decoding or search paths are used. ASCII or declared valid UTF-8 is supported; other encodings are limitations. Empty/control/NUL names, absolute/drive/UNC paths, backslashes, empty/`.`/`..` components, duplicates and file/directory conflicts are rejected. Only directories may have a trailing slash. Symlink/device/FIFO/socket and other non-regular member constructs are rejected.

## Lexical USDA references

Every recognized USDA layer is scanned, including unreferenced layers and inactive variants/metadata. Tokens found there can be lexical policy findings even when they are not active runtime dependencies. This is package-local lexical inspection, not a USD grammar or composition parser.

The lexer distinguishes comments, single/double/triple-quoted strings and asset delimiters `@...@`/`@@@...@@@`, with delimiter escapes and byte/line/column locations. Apparent tokens inside strings/comments are ignored; conclusively malformed supported literals are policy errors. Empty asset values are unauthored and require no target; prim paths outside delimiters are not file references.

For nonempty literal paths, absolute/scheme/drive/UNC, backslash/control and package-escape forms are checked before lookup. Anchored `./` or `../` resolves from the authoring layer directory; `..` may remain inside the package only. Unanchored paths try the authoring layer directory, then the default layer directory. An exact safe regular entry must exist: missing targets and directory targets are policy errors. No external resolver fallback, environment/tilde expansion, URI resolution or host-filesystem lookup occurs. Such paths may be legal in another USD resolver environment.

Expressions, variables, UDIM/templates, resolver identifiers and bracketed package/nested identifiers are not evaluated. They cause partial reference coverage after any demonstrably unsafe literal prefix is checked, without fabricated missing-target findings. Every binary USDC layer has incomplete native reference coverage, even after a successful checker run. [Incomplete acceptance](cli.md#exit-codes-and-gate-policy) changes the gate only.

## Textures and profiles

PNG/JPEG/EXR/AVIF regular entries count once toward encoded texture budgets even if unused. Directories do not count toward warning file counts or texture totals. These counts do not estimate decoded/GPU memory, material use, compression formats or mip levels. PNG signature/IHDR and supported JPEG frame markers provide positive dimensions within the scan cap; pixels and compressed image data are not decoded. Malformed supported headers are policy errors. Unsupported variants, cap exhaustion, EXR and AVIF leave requested dimension coverage partial. Disabling the dimension budget removes that requested check.

`general-v1` selects structure, safety, references and enabled budgets. `apple-portable-v1` adds warning-only advice to prefer binary layers and PNG/JPEG. It is a frozen project advisory subset: current Apple support can be broader, including USDA/EXR/AVIF. It imposes no universal single-layer requirement and certifies no renderer. See [Apple's evolving guidance](https://developer.apple.com/documentation/usd/creating-usd-files-for-apple-devices) and [the versioned catalogue](../Examples/catalogue-v1.json).

## Fixed safety envelope v1

These upper bounds cannot be changed through warning config. MiB = 1,048,576 bytes; KiB = 1,024 bytes.

| Resource | Ceiling |
| --- | --- |
| Input archive | 512 MiB |
| Entries, including directories | 10,000 |
| Central directory | 16 MiB |
| Declared regular-entry bytes | 256 MiB each |
| Aggregate declared uncompressed bytes | 512 MiB |
| USDA text | 16 MiB per layer |
| Entry name / asset token | 4 KiB each |
| Asset-token occurrences | 100,000 per invocation |
| Read chunk | 64 KiB |
| Texture header scan | 1 MiB per texture |
| Cumulative native reads | 1,152 MiB |
| Native findings | 10,000, with final resource sentinel on truncation |
| Rendered message | 1 KiB UTF-8 |
| Each variable evidence string | 4 KiB, with truncation markers |
| Config | 64 KiB |
| Encoded report | 32 MiB, including opted-in details |

A hard processing excess produces blocking `UVK-RES-001` and incomplete affected coverage. The specific texture scan-cap limitation is nonfatal; report-size overflow is operational exit `3`, with no partial document. Defaults and null behavior for all six separate warning budgets are in [CLI configuration](cli.md#warning-configuration).

Release acceptance targets are at most 256 MiB peak RSS and 60 seconds per maximum-envelope invocation on the recorded arm64 local-SSD host. [Measurements](verification/resource-results.md) apply to that host/corpus; RSS is not OS-enforced or universal. See [security assumptions](../SECURITY.md) and the [full v0.1 non-goals](../README.md#verification-and-support-scope).

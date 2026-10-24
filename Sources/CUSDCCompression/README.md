# Private crate compression target

This target compiles the untouched LZ4 1.10.0 `lib/lz4.c` and `lib/lz4.h` from
upstream tag `v1.10.0`, revision `ebb370ca83af193212df4dcbadcc5d87bc0de2f0`.
`source-manifest.json` records retrieval URLs, immutable revision URLs, byte counts
and SHA-256 hashes. `LICENSE` is the upstream BSD-2-Clause library license; the
original source/header notices are retained.

`USDZValidation` uses only `LZ4_decompress_safe`, with checked Int32 sizes, for
bounded internal crate metadata. There is no separate package product, system or
Homebrew library linkage, download at build/test time, or OpenUSD implementation
code in this target. The surrounding Swift decoder independently implements the
single pinned framing interpretation: one count byte (zero denotes a single
block), followed for nonzero counts by signed four-byte little-endian compressed
chunk lengths. Counts above 127 and LZ4 rejection remain unsupported; no alternate
framing retry occurs.

The compatibility evidence is OpenUSD commit
`96c1989167d2aaab5bd34627f32a321a6b79866b`,
`pxr/base/tf/fastCompression.cpp`, inspected as format evidence only. Published
framing discrepancies remain a support limitation. Each compressed frame and
reserved decoded block is limited to 16 MiB; cumulative decode, live storage and
structural work are independently charged by the Swift resource ledger.

To refresh this pin, deliberately select and review an upstream revision, retrieve
all three original files, verify version macros and hashes, update the manifest
and root `NOTICE`, and rerun compression tests including AddressSanitizer. Never
substitute a host library for these source inputs.

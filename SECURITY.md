# Security boundary and reporting

Native validation inspects one stable local regular file through a read-only descriptor. It rejects a symlink at the final input component and non-regular input before content reads, verifies opened metadata, and checks for detectable changes before returning. Parent-directory symlinks are not a blanket prohibition. This is not a snapshot guarantee against an adversarial writer that changes bytes and restores metadata; keep input stable during validation.

Native inspection never extracts/decompresses archive members, decodes image pixels, resolves authored references against the host filesystem, downloads resources or executes tools. Exact in-memory names, checked ranges and [fixed processing ceilings](docs/inspection-boundary.md#fixed-safety-envelope-v1) bound the inspected subset. Limits cannot be relaxed by budget config. Measured RSS/time targets apply to the [recorded corpus/host](docs/verification/resource-results.md), not a universal or OS-enforced memory sandbox.

Validation is not full asset-security certification. Uninspected USD grammar/composition, USDC dependencies, unsupported constructs, rendering behavior and downstream consumers remain outside the native guarantee. Read [inspection coverage](docs/inspection-boundary.md) and [v0.1 non-goals](README.md#verification-and-support-scope) alongside findings; accepting an incomplete gate does not fill coverage gaps.

## External trusted-input exception

`--usdchecker` explicitly authorizes `/usr/bin/usdchecker` for trusted input only. Its own parsers/resolvers can access filesystem and network resources outside the native package boundary. There is no promised external filesystem/network/RSS isolation. Fixed executable/version/arguments/environment, prerequisite checks, capture caps and timeouts improve repeatability and bounded process management; they do not transfer native hostile-input guarantees to the tool. [Exact invocation and limits](docs/cli.md#optional-installed-checker) are part of this contract.

Default reports redact absolute/external reference details, unsafe names, config/output paths and raw OS/tool text; control/terminal sequences are escaped. `--include-sensitive-details` explicitly reveals bounded absolute input/reference details and raw checker diagnostics, retaining escaping/caps. Such output can contain local paths or other sensitive tool text. Share it deliberately. Output-file replacement refuses symlinks, non-regular destinations and input aliases.

## Report a vulnerability privately

Contact the [repository owner](https://github.com/Light2288) privately using a contact method they publish. If the repository's [Security tab](https://github.com/Light2288/usdz-validator/security) offers private vulnerability reporting, use that channel. Availability of that feature and a dedicated private address have not been established; no response-time or maintained-release commitment is promised here. If no private route is published, request a private contact channel without posting the vulnerability details publicly.

Include the validator version, platform/toolchain, native versus checker mode, a minimal reproduction and expected/observed coverage or failure. Do not post exploit details, private assets or sensitive reports in a public issue while arranging private contact. The [MIT license](LICENSE) states the project's warranty terms.

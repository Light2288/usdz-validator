/// Permanent native descriptors. New meanings require new IDs; profiles only select descriptors.
public enum RuleCatalogue {
  public static func descriptors(profile: Profile) -> [RuleDescriptor] {
    descriptors.filter { profile == .applePortableV1 || $0.category != .appleCompatibility }
  }

  // Kept in rule-ID byte order for catalogue output, independently of finding category order.
  private static let descriptors: [RuleDescriptor] = [
    RuleDescriptor(
      ruleID: "UVK-APL-001", family: .container,
      category: .appleCompatibility, defaultSeverity: .warning,
      title: "Prefer binary USD delivery",
      description: "Text USD delivery advisory in Apple profile.",
      applicability:
        "Apple profile only; recognized USDA layers after safe container indexing. Skip when layer kind cannot be established.",
      rationale:
        "Binary USD is the frozen portability recommendation; current Apple systems may support USDA. This advice neither certifies a renderer nor requires a single layer."
    ),
    RuleDescriptor(
      ruleID: "UVK-APL-002", family: .budgets,
      category: .appleCompatibility, defaultSeverity: .warning,
      title: "Prefer PNG or JPEG textures",
      description: "EXR/AVIF outside the conservative PNG/JPEG Apple profile baseline.",
      applicability:
        "Apple profile only; recognized EXR or AVIF texture members after safe container indexing.",
      rationale:
        "PNG/JPEG is the frozen portability recommendation; current Apple systems may support EXR or AVIF. This advice does not certify renderer compatibility."
    ),
    RuleDescriptor(
      ruleID: "UVK-ARC-001", family: .container,
      category: .archiveSpecification, defaultSeverity: .error,
      title: "Malformed ZIP record",
      description: "Established malformed/truncated ZIP record or invalid field range.",
      applicability:
        "ZIP records whose required bytes or field ranges can be checked within the safety envelope. Unsupported features use a limitation when malformedness is not established.",
      rationale: "A container cannot be trusted when required records are malformed or truncated."),
    RuleDescriptor(
      ruleID: "UVK-ARC-002", family: .container,
      category: .archiveSpecification, defaultSeverity: .error,
      title: "Contradictory ZIP ownership",
      description:
        "Contradictory local/directory records, overlapping ownership, or unindexed members.",
      applicability:
        "Supported classic single-disk ZIP records after bounded metadata reads. Skip downstream checks whose ownership cannot be established.",
      rationale:
        "Directory and local records must describe consistent, nonoverlapping ownership of the package bytes."
    ),
    RuleDescriptor(
      ruleID: "UVK-ARC-003", family: .container,
      category: .archiveSpecification, defaultSeverity: .error,
      title: "Stored payload CRC mismatch",
      description: "Stored payload CRC mismatch.",
      applicability:
        "Safely indexed stored regular payloads that can be read completely within the safety envelope. Skip unsupported or unavailable payloads.",
      rationale: "The recorded CRC must match the encoded stored payload."),
    RuleDescriptor(
      ruleID: "UVK-ARC-004", family: .container,
      category: .archiveSpecification, defaultSeverity: .error,
      title: "Entry is not stored one-to-one",
      description: "Nonzero compression method or unequal stored/uncompressed sizes.",
      applicability:
        "Entries with established method and size fields, including zero/zero stored entries. Reject nonempty/zero claims before payload interpretation.",
      rationale:
        "The supported USDZ container uses stored payloads with equal encoded and uncompressed sizes."
    ),
    RuleDescriptor(
      ruleID: "UVK-ARC-005", family: .container,
      category: .archiveSpecification, defaultSeverity: .error,
      title: "Encrypted entry",
      description: "Encrypted entry.",
      applicability: "Entries whose ZIP encryption flags can be read conclusively.",
      rationale: "Encrypted entries are outside the permitted USDZ stored-container form."),
    RuleDescriptor(
      ruleID: "UVK-ARC-006", family: .container,
      category: .archiveSpecification, defaultSeverity: .error,
      title: "Unaligned regular payload",
      description: "Regular-file payload is not 64-byte aligned.",
      applicability:
        "Regular entries with safely established physical payload offsets; directory entries have no payload-alignment obligation.",
      rationale: "USDZ regular-file payloads require 64-byte alignment."),
    RuleDescriptor(
      ruleID: "UVK-ARC-007", family: .container,
      category: .archiveSpecification, defaultSeverity: .error,
      title: "USD suffix and signature disagree",
      description: "Obvious USD suffix/signature mismatch.",
      applicability:
        "USD members with enough safely readable signature bytes for a conclusive mismatch. Insufficient bytes do not establish a mismatch.",
      rationale: "A USD filename must not contradict its recognizable text or binary signature."),
    RuleDescriptor(
      ruleID: "UVK-BUD-001", family: .budgets,
      category: .policy, defaultSeverity: .warning,
      title: "Archive byte budget exceeded",
      description: "Archive byte budget exceeded.",
      applicability:
        "Known input byte size with archiveBytes enabled; warn only when observed bytes exceed the threshold.",
      rationale:
        "Encoded archive bytes are a configurable project delivery budget, separate from hard safety limits."
    ),
    RuleDescriptor(
      ruleID: "UVK-BUD-002", family: .budgets,
      category: .policy, defaultSeverity: .warning,
      title: "File byte budget exceeded",
      description: "Per-file encoded-byte budget exceeded.",
      applicability:
        "Safely indexed regular entries with fileBytes enabled; warn only when encoded bytes exceed the threshold.",
      rationale:
        "A per-file encoded-byte warning identifies large package members without decoding them."),
    RuleDescriptor(
      ruleID: "UVK-BUD-003", family: .budgets,
      category: .policy, defaultSeverity: .warning,
      title: "File count budget exceeded",
      description: "Regular-file-count budget exceeded.",
      applicability:
        "Established regular-entry count with fileCount enabled; warn only when the count exceeds the threshold.",
      rationale:
        "Regular-file count is a configurable delivery-complexity budget; directories do not count."
    ),
    RuleDescriptor(
      ruleID: "UVK-BUD-004", family: .budgets,
      category: .policy, defaultSeverity: .warning,
      title: "Texture byte budget exceeded",
      description: "Per-texture encoded-byte budget exceeded.",
      applicability:
        "Recognized texture members with textureBytes enabled and established stored sizes; warn only above the threshold.",
      rationale: "Encoded texture bytes measure delivery cost without decoding pixels."),
    RuleDescriptor(
      ruleID: "UVK-BUD-005", family: .budgets,
      category: .policy, defaultSeverity: .warning,
      title: "Total texture byte budget exceeded",
      description: "Total encoded texture-byte budget exceeded.",
      applicability:
        "Safely indexed recognized textures with totalTextureBytes enabled; warn only when their encoded-byte sum exceeds the threshold.",
      rationale:
        "Aggregate encoded texture bytes are a project budget independent of decoded memory cost."),
    RuleDescriptor(
      ruleID: "UVK-BUD-006", family: .budgets,
      category: .policy, defaultSeverity: .warning,
      title: "Texture dimension budget exceeded",
      description: "Supported texture width or height exceeds the dimension budget.",
      applicability:
        "textureMaxDimension enabled and conclusive dimensions from a supported PNG/JPEG header within the scan boundary; warn only above the threshold.",
      rationale:
        "Width or height is advisory delivery policy; no pixel decoding or decoded-memory estimate is performed."
    ),
    RuleDescriptor(
      ruleID: "UVK-BUD-007", family: .budgets,
      category: .policy, defaultSeverity: .error,
      title: "Malformed texture header",
      description: "Conclusively malformed supported texture header.",
      applicability:
        "Supported PNG/JPEG headers with enough readable bytes to establish malformedness during an enabled dimension check.",
      rationale:
        "Conclusive malformedness is a policy error; unavailable or unsupported dimensions instead produce an explicit limitation when requested."
    ),
    RuleDescriptor(
      ruleID: "UVK-LIM-001", family: .container,
      category: .validatorLimitation, defaultSeverity: .warning,
      title: "Unsupported ZIP semantics",
      description: "Unsupported ZIP feature, layout, encoding, or type semantics.",
      applicability:
        "ZIP64, data descriptors, unsupported layouts, encodings, or type semantics where supported inspection cannot continue conclusively.",
      rationale:
        "A processing boundary makes affected native coverage incomplete; it must not turn established malformed records into mere limitations."
    ),
    RuleDescriptor(
      ruleID: "UVK-LIM-002", family: .references,
      category: .validatorLimitation, defaultSeverity: .warning,
      title: "Binary references not inspected",
      description: "Binary USD reference inspection unavailable.",
      applicability:
        "Recognized binary USD layers; package-local reference inspection cannot parse USDC dependencies in v0.1.",
      rationale: "Recognizing a binary signature does not prove complete USD reference validation."),
    RuleDescriptor(
      ruleID: "UVK-LIM-003", family: .references,
      category: .validatorLimitation, defaultSeverity: .warning,
      title: "Unsupported asset identifier",
      description: "Expression/template/package identifier cannot be resolved natively.",
      applicability:
        "Recognized asset expressions, templates, or package identifiers outside the supported literal path subset.",
      rationale:
        "The validator does not evaluate expressions, composition, or nested package identifiers and cannot infer their targets."
    ),
    RuleDescriptor(
      ruleID: "UVK-LIM-004", family: .references,
      category: .validatorLimitation, defaultSeverity: .warning,
      title: "USD text encoding not scanned",
      description: "Recognized USD text cannot be scanned in its supported encoding.",
      applicability:
        "Recognized text USD whose encoding is outside the supported bounded USDA scanner.",
      rationale:
        "Unscannable recognized text leaves reference coverage incomplete without inventing missing-reference findings."
    ),
    RuleDescriptor(
      ruleID: "UVK-LIM-005", family: .budgets,
      category: .validatorLimitation, defaultSeverity: .warning,
      title: "Texture dimensions unavailable",
      description: "Requested texture dimensions unavailable within the supported boundary.",
      applicability:
        "textureMaxDimension enabled; unsupported formats, unsupported header variants, or no conclusive dimensions within the 1 MiB header scan boundary.",
      rationale:
        "Dimension coverage must be explicit when bounded PNG/JPEG inspection cannot provide a result; the scan boundary alone is not a hard safety error."
    ),
    RuleDescriptor(
      ruleID: "UVK-LIM-006", family: .container,
      category: .validatorLimitation, defaultSeverity: .warning,
      title: "Nested package not inspected",
      description: "Nested package content not inspected.",
      applicability:
        "Recognized nested .usdz members after safe container indexing; no recursive package inspection.",
      rationale:
        "The native engine does not extract or recursively inspect nested packages, so affected coverage remains incomplete."
    ),
    RuleDescriptor(
      ruleID: "UVK-PATH-001", family: .references,
      category: .policy, defaultSeverity: .error,
      title: "Unsafe archive member name",
      description: "Unsafe/invalid archive member name.",
      applicability:
        "Raw archive member names available from safely bounded metadata; retain exact bytes for identity even when display is redacted.",
      rationale:
        "Package names must remain safe package-relative identifiers without host-filesystem resolution."
    ),
    RuleDescriptor(
      ruleID: "UVK-PATH-002", family: .references,
      category: .policy, defaultSeverity: .error,
      title: "Conflicting package namespace",
      description: "Duplicate name or file/directory namespace conflict.",
      applicability:
        "Safely indexed member names compared by exact case-sensitive UTF-8 bytes without Unicode normalization.",
      rationale:
        "A package namespace must not ambiguously assign a name to multiple entries or incompatible file/directory ownership."
    ),
    RuleDescriptor(
      ruleID: "UVK-PATH-003", family: .references,
      category: .policy, defaultSeverity: .error,
      title: "Prohibited member type",
      description: "Symlink or prohibited non-regular member.",
      applicability:
        "Members whose supported ZIP attributes conclusively establish a prohibited type; unknown type semantics use a limitation.",
      rationale:
        "Package references must not depend on symlinks or prohibited special filesystem objects."),
    RuleDescriptor(
      ruleID: "UVK-PATH-004", family: .references,
      category: .policy, defaultSeverity: .error,
      title: "Unsafe literal asset path",
      description: "Absolute/external/unsafe literal asset path.",
      applicability:
        "Conclusive asset literals from supported USDA scanning; absolute and external values are redacted by default.",
      rationale:
        "Standalone package references must not access external resources or unsafe host paths."),
    RuleDescriptor(
      ruleID: "UVK-PATH-005", family: .references,
      category: .policy, defaultSeverity: .error,
      title: "Reference escapes package root",
      description: "Reference normalization escapes package root.",
      applicability:
        "Supported package-relative literal paths normalized against the containing layer; skip when safe layer identity is unavailable.",
      rationale: "Lexical reference resolution must remain within the package root."),
    RuleDescriptor(
      ruleID: "UVK-PATH-006", family: .references,
      category: .policy, defaultSeverity: .error,
      title: "Missing regular package target",
      description: "Supported literal path has no regular package target.",
      applicability:
        "Supported safely normalized literals and a trustworthy package index; skip when a container failure makes target existence unknowable.",
      rationale:
        "A supported package-local dependency must resolve to a regular package entry using exact UTF-8 identity."
    ),
    RuleDescriptor(
      ruleID: "UVK-PATH-007", family: .references,
      category: .policy, defaultSeverity: .error,
      title: "Malformed supported asset literal",
      description: "Conclusively malformed supported asset literal.",
      applicability:
        "The supported USDA asset-literal subset when scanning conclusively establishes malformedness; unsupported expressions use a limitation.",
      rationale:
        "Malformed supported syntax is an error without claiming complete USD grammar validation."),
    RuleDescriptor(
      ruleID: "UVK-POL-001", family: .container,
      category: .policy, defaultSeverity: .error,
      title: "Default layer policy failed",
      description: "First regular entry fails the standalone default-layer policy.",
      applicability:
        "A safely established first regular entry; skip when container ownership prevents determining entry order.",
      rationale:
        "This project requires the first regular entry to be a standalone USD default layer; it does not impose a universal single-layer requirement."
    ),
    RuleDescriptor(
      ruleID: "UVK-POL-002", family: .container,
      category: .policy, defaultSeverity: .error,
      title: "Member suffix outside policy",
      description: "Member outside the v0.1 suffix catalogue.",
      applicability:
        "Safely indexed members classified by the case-insensitive v0.1 suffix catalogue.",
      rationale:
        "The frozen member catalogue is project policy, not a universal claim about every future USDZ extension."
    ),
    RuleDescriptor(
      ruleID: "UVK-RES-001", family: nil,
      category: .policy, defaultSeverity: .error,
      title: "Hard processing ceiling exceeded",
      description: "Hard safety/processing ceiling exceeded, including findings truncation.",
      applicability:
        "Any fixed safety-envelope ceiling; reserve the final finding slot when discovery is truncated and stop affected work.",
      rationale:
        "Hard resource limits protect bounded native processing, mark affected coverage incomplete, and remain blocking even when incomplete coverage is accepted."
    ),
  ]
}

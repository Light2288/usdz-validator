import Foundation

public enum ReportFormat: String, CaseIterable, Sendable { case text, json, sarif }
public enum CatalogueFormat: String, CaseIterable, Sendable { case text, json }

public enum ReportEncoder {
  public static func encode(_ report: ValidationReport, format: ReportFormat) throws -> Data {
    switch format {
    case .text: return try TextReport.encode(report)
    case .json:
      var buffer = CappedBuffer()
      try CanonicalJSON.encode(JSONReport.value(report), into: &buffer)
      return buffer.finish()
    case .sarif: throw ValidationError.operational(.reportEncodingFailed)
    }
  }

  public static func encodeCatalogue(profile: Profile, format: CatalogueFormat) throws -> Data {
    let rules = RuleCatalogue.descriptors(profile: profile)
    var buffer = CappedBuffer()
    func text(_ value: String) -> String {
      Privacy.render(value, kind: .evidence, sensitive: false)
    }
    switch format {
    case .text:
      for rule in rules {
        for line in [
          "\(text(rule.ruleID)) \(rule.category.rawValue) \(rule.defaultSeverity.rawValue): \(text(rule.title))",
          "  family: \(rule.family?.rawValue ?? "none")",
          "  description: \(text(rule.description))",
          "  applicability: \(text(rule.applicability))",
          "  rationale: \(text(rule.rationale))",
        ] {
          try buffer.append(Data(line.utf8))
          try buffer.append(Data([0x0a]))
        }
      }
    case .json:
      let tool = ReportTool()
      let value = JSONValue.object([
        "schemaVersion": .integer(1),
        "tool": .object(["name": .string(text(tool.name)), "version": .string(text(tool.version))]),
        "profile": .string(profile.rawValue),
        "rules": .array(
          rules.map { rule in
            .object([
              "ruleID": .string(text(rule.ruleID)),
              "family": rule.family.map { .string($0.rawValue) } ?? .null,
              "category": .string(rule.category.rawValue),
              "defaultSeverity": .string(rule.defaultSeverity.rawValue),
              "title": .string(text(rule.title)), "description": .string(text(rule.description)),
              "applicability": .string(text(rule.applicability)),
              "rationale": .string(text(rule.rationale)),
            ])
          }),
      ])
      try CanonicalJSON.encode(value, into: &buffer)
    }
    return buffer.finish()
  }
}

import Foundation

public enum ReportFormat: String, CaseIterable, Sendable { case text, json, sarif }

public enum ReportEncoder {
  public static func encode(_ report: ValidationReport, format: ReportFormat) throws -> Data {
    switch format {
    case .text: return try TextReport.encode(report)
    case .json, .sarif: throw ValidationError.operational(.reportEncodingFailed)
    }
  }
}

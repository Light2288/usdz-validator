import Foundation

enum USDCScanState: Equatable {
  case complete, partial, uninspected
}

enum USDCReader {
  /// Callbacks are synchronous. All table/value storage is destroyed before returning or throwing.
  static func scan(
    entry: ZIPEntry, reader: BoundedReader, defaultEntry: ZIPEntry? = nil,
    onReference: (ReferenceOccurrence) -> Void, onIssue: (USDCIssue) -> Void
  ) throws -> USDCScanState {
    let input = USDCInput(entry: entry, reader: reader, defaultEntry: defaultEntry)
    let tables: USDCTables
    do {
      tables = try USDCTables.read(input: input)
    } catch let failure as USDCFailure {
      onIssue(USDCIssue(failure: failure, locator: nil))
      return .uninspected
    }
    var partial = false
    // No catch-all: snapshot and hard safety stops propagate unchanged.
    try tables.forEachLiveField { field in
      try USDCValues.walk(
        field: field, tables: tables, input: input, onReference: onReference,
        onIssue: { issue in
          partial = true
          onIssue(issue)
        })
    }
    return partial ? .partial : .complete
  }
}

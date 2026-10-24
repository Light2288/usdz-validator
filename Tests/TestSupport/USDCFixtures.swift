import Foundation

public struct USDCFixtureCase: Sendable {
  public let id: String
  public let crate: Data
  public let version: [UInt8]
  public let expectedValues: [Data]
  public let expectedInspectionComplete: Bool
  public let metadata: USDCFixtureRecord
}

/// Semantic coordinates are authored scene locations, not decoder offsets or output identities.
public struct USDCFixtureSite: Decodable, Sendable {
  public let value: String
  public let pathElements: [String]
  public let field: String
  public let container: [USDCFixtureCoordinate]
}

public enum USDCFixtureCoordinate: Decodable, Equatable, Sendable {
  case key(String)
  case index(Int)

  public init(from decoder: any Decoder) throws {
    let value = try decoder.singleValueContainer()
    if let index = try? value.decode(Int.self) { self = .index(index) }
    else { self = .key(try value.decode(String.self)) }
  }
}

public struct USDCFixtureRecord: Decodable, Sendable {
  public let id: String
  public let crate: String
  public let source: String
  public let version: [UInt8]
  public let expectedValues: [String]
  public let expectedSites: [USDCFixtureSite]
  public let expectedInspectionComplete: Bool
  public let rawUnregisteredValues: [String]
  public let writer: String
  public let writerVersion: String
  public let arguments: [String]
  public let crateSHA256: String
  public let sourceSHA256: String
  public let sourceLicense: String
  public let expectationOrigin: String
  public let provenanceRecords: [String]
  public let oracleOmissions: [String]
  public let liveTypeEvidence: [LiveTypeEvidence]

  public struct LiveTypeEvidence: Decodable, Sendable {
    public let tag: Int
    public let authoredDeclaration: String
    public let logicalSite: String
  }
}

public enum USDCFixtures {
  public static var root: URL { Fixtures.root.appendingPathComponent("USDC", isDirectory: true) }

  /// Load committed evidence only; no writer, oracle, product decoder or research checkout is used.
  public static func cases() throws -> [USDCFixtureCase] {
    struct Inventory: Decodable { let cases: [USDCFixtureRecord] }
    let inventory = try JSONDecoder().decode(Inventory.self,
      from: Data(contentsOf: root.appendingPathComponent("inventory.json")))
    return try inventory.cases.map { record in
      USDCFixtureCase(id: record.id,
        crate: try Data(contentsOf: root.appendingPathComponent(record.crate)),
        version: record.version, expectedValues: record.expectedValues.map { Data($0.utf8) },
        expectedInspectionComplete: record.expectedInspectionComplete, metadata: record)
    }
  }
}

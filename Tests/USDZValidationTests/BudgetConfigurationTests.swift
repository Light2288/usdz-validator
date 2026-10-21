import Foundation
import XCTest

@testable import USDZValidation

final class BudgetConfigurationTests: XCTestCase {
  // Accepting a generic JSON number or skipping native validation breaks these rejection rows.
  func testStrictShapeAndNumbers() throws {
    let defaults = try BudgetConfiguration.decode(Data(#"{"schemaVersion":1,"budgets":{}}"#.utf8))
    XCTAssertEqual(
      defaults,
      WarningBudgets(
        archiveBytes: 104_857_600, fileBytes: 26_214_400, fileCount: 1_000,
        textureBytes: 20_971_520, totalTextureBytes: 83_886_080, textureMaxDimension: 4_096
      ))
    let custom = try BudgetConfiguration.decode(
      Data(
        #"{"budgets":{"archiveBytes":1,"fileBytes":2,"fileCount":3,"textureBytes":4,"totalTextureBytes":5,"textureMaxDimension":9223372036854775807},"schemaVersion":1}"#
          .utf8))
    let expected = WarningBudgets(
      archiveBytes: 1, fileBytes: 2, fileCount: 3, textureBytes: 4,
      totalTextureBytes: 5, textureMaxDimension: Int64.max)
    XCTAssertEqual(custom, expected)
    XCTAssertEqual(try ValidationConfiguration(budgets: custom).budgets, expected)

    for value in [
      "true", "false", "1.0", "1e0", "1E+0", "1e-0", "01", "+1", "\"1\"",
      "[]", "{}", "9223372036854775808", "-9223372036854775809",
    ] {
      assertFailure(#"{"schemaVersion":1,"budgets":{"fileBytes":\#(value)}}"#, .invalidValue)
    }
    let keys = [
      "archiveBytes", "fileBytes", "fileCount", "textureBytes", "totalTextureBytes",
      "textureMaxDimension",
    ]
    for key in keys {
      for value in ["0", "-0", "-1", "-9223372036854775808"] {
        assertFailure(
          #"{"schemaVersion":1,"budgets":{"\#(key)":\#(value)}}"#, .invalidBudget)
      }
    }
    for value in ["0", "2", "-1", "9223372036854775807"] {
      assertFailure(#"{"schemaVersion":\#(value),"budgets":{}}"#, .invalidSchemaVersion)
    }
    for value in ["true", "null", "1.0", "1e0", "\"1\""] {
      assertFailure(#"{"schemaVersion":\#(value),"budgets":{}}"#, .invalidValue)
    }
  }

  func testNullDisablesOnlySelectedBudgetAndOmissionDefaults() throws {
    let selected = try BudgetConfiguration.decode(
      Data(#"{"schemaVersion":1,"budgets":{"textureMaxDimension":null}}"#.utf8))
    XCTAssertNil(selected.textureMaxDimension)
    XCTAssertEqual(selected.archiveBytes, 104_857_600)
    XCTAssertEqual(selected.fileBytes, 26_214_400)
    XCTAssertEqual(selected.fileCount, 1_000)
    XCTAssertEqual(selected.textureBytes, 20_971_520)
    XCTAssertEqual(selected.totalTextureBytes, 83_886_080)
    let disabled = try BudgetConfiguration.decode(
      Data(
        #"{"schemaVersion":1,"budgets":{"archiveBytes":null,"fileBytes":null,"fileCount":null,"textureBytes":null,"totalTextureBytes":null,"textureMaxDimension":null}}"#
          .utf8))
    XCTAssertEqual(
      disabled,
      WarningBudgets(
        archiveBytes: nil, fileBytes: nil, fileCount: nil, textureBytes: nil,
        totalTextureBytes: nil, textureMaxDimension: nil))
    XCTAssertEqual(try ValidationConfiguration(budgets: disabled).budgets, disabled)
  }

  func testRequiredShapeAndNoConfigurationOverrides() {
    for json in [
      "", "null", "true", "[]", "{}", #"{"schemaVersion":1}"#, #"{"budgets":{}}"#,
      #"{"schemaVersion":1,"budgets":null}"#, #"{"schemaVersion":1,"budgets":[]}"#,
    ] {
      assertFailure(json, .invalidValue)
    }
    for key in [
      "unknown", "profile", "tool", "externalCheck", "safetyEnvelopeVersion", "safetyLimits",
      "searchPath", "includeSensitiveDetails",
    ] {
      assertFailure(#"{"schemaVersion":1,"budgets":{},"\#(key)":1}"#, .unknownKey)
      assertFailure(#"{"schemaVersion":1,"budgets":{"\#(key)":1}}"#, .unknownKey)
    }
  }

  func testDecodedKeysRejectDuplicatesAndAcceptEscapedKnownKeys() throws {
    for json in [
      #"{"schemaVersion":1,"schemaVersion":1,"budgets":{}}"#,
      #"{"schemaVersion":1,"budgets":{},"budgets":{}}"#,
      #"{"schemaVersion":1,"schema\u0056ersion":1,"budgets":{}}"#,
      #"{"schemaVersion":1,"budgets":{},"\u0062udgets":{}}"#,
      #"{"schemaVersion":1,"budgets":{"fileBytes":1,"fileBytes":2}}"#,
      #"{"schemaVersion":1,"budgets":{"fileBytes":null,"file\u0042ytes":2}}"#,
      #"{"schemaVersion":1,"budgets":{"file\u0042ytes":1,"fileBytes":null}}"#,
    ] {
      assertFailure(json, .duplicateKey)
    }
    let escaped = try BudgetConfiguration.decode(
      Data(#"{"schema\u0056ersion":1,"\u0062udgets":{"file\u0042ytes":7}}"#.utf8))
    XCTAssertEqual(escaped.fileBytes, 7)
    for key in [
      #"a\"b"#, #"a\\b"#, #"a\/b"#, #"a\bb"#, #"a\fb"#, #"a\nb"#,
      #"a\rb"#, #"a\tb"#, #"\uD83D\uDE00"#, "è",
    ] {
      assertFailure(#"{"schemaVersion":1,"budgets":{"\#(key)":1}}"#, .unknownKey)
    }
  }

  func testMalformedSyntaxEncodingAndTrailingData() throws {
    for json in [
      #"{"schemaVersion":1,"budgets":{},}"#, #"{"schemaVersion":1,"budgets":{"fileBytes":1,}}"#,
      #"{"schemaVersion" 1,"budgets":{}}"#, #"{"schemaVersion":1 "budgets":{}}"#,
      #"{"schemaVersion":1,"budgets":{"fileBytes":nul}}"#,
      #"{"schemaVersion":1,"budgets":{"fileBytes":n ull}}"#,
      #"{"schemaVersion":1,"budgets":{"fileBytes":nu ll}}"#,
      #"{"schemaVersion":1,"budgets":{"fileBytes":nul l}}"#,
      #"{"schemaVersion":1,"budgets":{"fileBytes":null0}}"#,
      #"{"schemaVersion":1,"budgets":{"fileBytes":-}}"#,
      #"{"schemaVersion":1,"budgets":{"fileBytes":1x}}"#,
      #"{"schemaVersion":1,"budgets":{"fileBytes":1"#,
      #"{"schemaVersion":1,"budgets":{"\uD800":1}}"#,
      #"{"schemaVersion":1,"budgets":{"\uDC00":1}}"#,
      #"{"schemaVersion":1,"budgets":{"\uD800\u0041":1}}"#,
      #"{"schemaVersion":1,"budgets":{"\uZZZZ":1}}"#,
      #"{"schemaVersion":1,"budgets":{"\x41":1}}"#,
      "{\"schemaVersion\":1,\"budgets\":{\"file\nBytes\":1}}",
      "\u{FEFF}{\"schemaVersion\":1,\"budgets\":{}}",
      "\u{000B}{\"schemaVersion\":1,\"budgets\":{}}",
    ] {
      assertFailure(json, .invalidValue)
    }
    for suffix in ["{}", "null", "false", "1", "\u{0000}", "// comment"] {
      assertFailure(#"{"schemaVersion":1,"budgets":{}}"# + suffix, .trailingData)
    }
    for invalid in [
      Data([0xFF]), Data([0xC0, 0xAF]), Data([0xED, 0xA0, 0x80]),
      Data([0xF4, 0x90, 0x80, 0x80]),
    ] {
      assertFailure(invalid, .invalidEncoding)
    }
    var badKey = Data(#"{"schemaVersion":1,"budgets":{""#.utf8)
    badKey.append(0xFF)
    badKey.append(Data(#"":1}}"#.utf8))
    assertFailure(badKey, .invalidEncoding)
    let whitespace = try BudgetConfiguration.decode(
      Data(" \t\r\n{ \"budgets\" : { \"fileBytes\" : 9 }, \"schemaVersion\" : 1 }\n\t".utf8))
    XCTAssertEqual(whitespace.fileBytes, 9)
    var prefixed = Data([0, 0])
    prefixed.append(Data(#"{"schemaVersion":1,"budgets":{"fileBytes":9}}"#.utf8))
    XCTAssertEqual(try BudgetConfiguration.decode(prefixed.dropFirst(2)).fileBytes, 9)
  }

  func testEveryTruncatedPrefixIsControlled() throws {
    let complete = Data(
      #"{"schemaVersion":1,"budgets":{"file\u0042ytes":9223372036854775807,"textureMaxDimension":null}}"#
        .utf8)
    for length in 0..<complete.count {
      assertFailure(complete.prefix(length), .invalidValue)
    }
    XCTAssertEqual(try BudgetConfiguration.decode(complete).fileBytes, Int64.max)
  }

  func testBoundedBeforeAsset() throws {
    let valid = Data(#"{"schemaVersion":1,"budgets":{}}"#.utf8)
    var atLimit = valid
    atLimit.append(Data(repeating: 0x20, count: 65_536 - valid.count))
    XCTAssertEqual(try BudgetConfiguration.decode(atLimit).fileCount, 1_000)
    var overLimit = atLimit
    overLimit.append(0x20)
    assertFailure(overLimit, .sizeLimitExceeded)
    // Size wins even over malformed UTF-8 and syntax, before a parser buffer is made.
    assertFailure(Data(repeating: 0xFF, count: 65_537), .sizeLimitExceeded)
    let hugeNumber = Data(
      (#"{"schemaVersion":1,"budgets":{"fileBytes":"# + String(repeating: "9", count: 60_000)
        + "}}").utf8)
    assertFailure(hugeNumber, .invalidValue)

    var openedAssets = 0
    var ranTools = 0
    // This is the caller sequencing contract; actual CLI loading belongs to Task 20.
    func decodeThenInspect(_ bytes: Data) throws -> ValidationConfiguration {
      let budgets = try BudgetConfiguration.decode(bytes)
      let configuration = try ValidationConfiguration(budgets: budgets)
      openedAssets += 1
      ranTools += 1
      return configuration
    }
    for bytes in [
      overLimit, hugeNumber, Data(#"{"schemaVersion":1,"budgets":{"fileBytes":0}}"#.utf8),
    ] {
      XCTAssertThrowsError(try decodeThenInspect(bytes))
    }
    XCTAssertEqual(openedAssets, 0)
    XCTAssertEqual(ranTools, 0)
    XCTAssertEqual(try decodeThenInspect(valid).budgets.fileCount, 1_000)
    XCTAssertEqual(openedAssets, 1)
    XCTAssertEqual(ranTools, 1)
  }

  private func assertFailure(
    _ json: String, _ reason: ConfigurationFailureReason,
    file: StaticString = #filePath, line: UInt = #line
  ) {
    assertFailure(Data(json.utf8), reason, file: file, line: line)
  }

  private func assertFailure(
    _ bytes: Data, _ reason: ConfigurationFailureReason,
    file: StaticString = #filePath, line: UInt = #line
  ) {
    XCTAssertThrowsError(try BudgetConfiguration.decode(bytes), file: file, line: line) { error in
      XCTAssertEqual(error as? ValidationError, .configuration(reason), file: file, line: line)
    }
  }
}

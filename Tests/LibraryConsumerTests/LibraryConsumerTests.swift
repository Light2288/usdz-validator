import Foundation
import USDZValidation
import XCTest

final class LibraryConsumerTests: XCTestCase {
  func testLibraryAloneValidatesCompleteFixture() throws {
    let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent("Fixtures/valid-usda.usdz")
    let report = try Validator().validate(fileAt: fixture, configuration: ValidationConfiguration())
    XCTAssertEqual(report.exitCode, 0)
    XCTAssertTrue(report.coverage.isComplete)
    XCTAssertEqual(report.coverage.areas[.containerStructure]?.state, .complete)
    XCTAssertEqual(report.coverage.areas[.references]?.state, .complete)
    XCTAssertTrue(report.nativeFindings.isEmpty)
    XCTAssertEqual(report.externalCheck.status, .notRequested)
    XCTAssertEqual(report.input.displayName, "valid-usda.usdz")
  }
}

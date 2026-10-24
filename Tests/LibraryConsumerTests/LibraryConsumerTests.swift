import Foundation
import USDZValidation
import XCTest

final class LibraryConsumerTests: XCTestCase {
  // A library consumer must receive automatic binary inventory without internal imports or flags.
  func testLibraryAloneValidatesCompleteBinaryFixture() throws {
    let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent("Fixtures/valid-usdc.usdz")
    let report = try Validator().validate(fileAt: fixture, configuration: ValidationConfiguration())
    XCTAssertEqual(report.exitCode, 0)
    XCTAssertTrue(report.coverage.isComplete)
    XCTAssertEqual(report.coverage.areas[.references]?.state, .complete)
    XCTAssertTrue(report.nativeFindings.isEmpty)
    XCTAssertEqual(report.externalCheck.status, .notRequested)
  }

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

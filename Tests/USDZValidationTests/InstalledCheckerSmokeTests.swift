import Foundation
import TestSupport
import USDZValidation
import XCTest

final class InstalledCheckerSmokeTests: XCTestCase {
  func testExplicitInstalledCheckerSmoke() throws {
    guard ProcessInfo.processInfo.environment["UVK_RUN_INSTALLED_CHECKER"] == "1" else {
      throw XCTSkip("Installed checker smoke requires UVK_RUN_INSTALLED_CHECKER=1.")
    }
    let report = try Validator().validate(
      fileAt: Fixtures.root.appendingPathComponent("valid-usda.usdz"),
      configuration: ValidationConfiguration(externalCheck: .usdchecker))
    let check = report.externalCheck
    print(
      "Installed usdchecker: version=\(check.version ?? "unknown") status=\(check.status.rawValue) outcome=\(check.outcome?.rawValue ?? "none")"
    )
    if check.status == .unavailable || check.status == .unsupportedVersion {
      throw XCTSkip(
        "Installed checker unavailable or unsupported: \(check.status.rawValue), \(check.version ?? "unknown")."
      )
    }
    XCTAssertEqual(check.status, .completed)
    XCTAssertNotNil(check.outcome)
  }
}

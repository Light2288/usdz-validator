import XCTest

@testable import USDZValidation

final class ConfigurationTests: XCTestCase {
  func testDefaultsAndInvalidBudgets() throws {
    let configuration = try ValidationConfiguration()
    XCTAssertEqual(ValidatorVersion.current, "0.2.0")
    XCTAssertEqual(configuration.profile, .generalV1)
    XCTAssertEqual(Profile.generalV1.rawValue, "general-v1")
    XCTAssertEqual(Profile.applePortableV1.rawValue, "apple-portable-v1")
    XCTAssertEqual(configuration.budgets.archiveBytes, 104_857_600)
    XCTAssertEqual(configuration.budgets.fileBytes, 26_214_400)
    XCTAssertEqual(configuration.budgets.fileCount, 1_000)
    XCTAssertEqual(configuration.budgets.textureBytes, 20_971_520)
    XCTAssertEqual(configuration.budgets.totalTextureBytes, 83_886_080)
    XCTAssertEqual(WarningBudgets.defaults.textureMaxDimension, 4096)
    XCTAssertEqual(configuration.gatePolicy, GatePolicy(failOn: .error, allowIncomplete: false))
    XCTAssertEqual(configuration.safetyEnvelopeVersion, 3)
    XCTAssertFalse(configuration.includeSensitiveDetails)
    XCTAssertEqual(configuration.externalCheck, .disabled)

    // Removing validation for any one budget must make its zero/negative rows fail.
    for invalid: Int64 in [0, -1, Int64.min] {
      let budgets = [
        WarningBudgets(archiveBytes: invalid),
        WarningBudgets(fileBytes: invalid),
        WarningBudgets(fileCount: invalid),
        WarningBudgets(textureBytes: invalid),
        WarningBudgets(totalTextureBytes: invalid),
        WarningBudgets(textureMaxDimension: invalid),
      ]
      for budget in budgets {
        XCTAssertThrowsError(try ValidationConfiguration(budgets: budget)) { error in
          XCTAssertEqual(error as? ValidationError, .configuration(.invalidBudget))
        }
      }
    }

    let disabled = WarningBudgets(
      archiveBytes: nil, fileBytes: nil, fileCount: nil, textureBytes: nil,
      totalTextureBytes: nil, textureMaxDimension: nil
    )
    let selected = try ValidationConfiguration(
      profile: .applePortableV1, budgets: disabled,
      gatePolicy: GatePolicy(failOn: .warning, allowIncomplete: true),
      includeSensitiveDetails: true, externalCheck: .usdchecker
    )
    XCTAssertEqual(selected.budgets, disabled)
    XCTAssertEqual(selected.profile, .applePortableV1)
    XCTAssertEqual(selected.externalCheck, .usdchecker)
    XCTAssertTrue(selected.includeSensitiveDetails)
    XCTAssertEqual(selected.gatePolicy.failOn, .warning)
    XCTAssertTrue(selected.gatePolicy.allowIncomplete)

    let positive = WarningBudgets(
      archiveBytes: 1, fileBytes: 1, fileCount: 1, textureBytes: 1,
      totalTextureBytes: 1, textureMaxDimension: Int64.max
    )
    XCTAssertEqual(try ValidationConfiguration(budgets: positive).budgets, positive)
  }
}

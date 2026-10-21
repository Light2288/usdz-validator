#if UVK_PROCESS_TESTING
  import Foundation
  import USDZValidation

  enum ProcessTestHooks {
    static func report(fileAt url: URL, configuration: ValidationConfiguration) -> ValidationReport?
    {
      guard ProcessInfo.processInfo.environment["UVK_CLI_TEST_SCENARIO"] == "encodingCap" else {
        return nil
      }
      let finding = Finding(
        ruleID: "UVK-PATH-006", occurrenceID: "stable-id", category: .policy,
        severity: .error, message: "Missing reference.",
        evidence: ["detail": .string(String(repeating: "a", count: 4_096))], location: nil,
        provenance: .native(validatorVersion: ValidatorVersion.current))
      return ValidationReport(
        input: ReportInput(displayName: url.lastPathComponent, byteSize: 1),
        configuration: configuration, coverage: Coverage(areas: [:]),
        nativeFindings: Array(repeating: finding, count: 8_200))
    }

    static func validator() throws -> Validator? {
      guard let scenario = ProcessInfo.processInfo.environment["UVK_CLI_TEST_SCENARIO"] else {
        return nil
      }
      return try Validator.processTestScenario(scenario)
    }
  }
#endif

#if UVK_PROCESS_TESTING
  import Foundation
  import USDZValidation

  enum ProcessTestHooks {
    static func validator() throws -> Validator? {
      guard let scenario = ProcessInfo.processInfo.environment["UVK_CLI_TEST_SCENARIO"] else {
        return nil
      }
      return try Validator.processTestScenario(scenario)
    }
  }
#endif

import ArgumentParser
import USDZValidation

@main
struct USDZValidatorCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "usdz-validator",
    abstract: "Validate local USDZ assets.",
    version: ValidatorVersion.current
  )
}

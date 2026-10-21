import ArgumentParser
import Darwin
import Foundation
import USDZValidation

@main
struct USDZValidatorCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "usdz-validator",
    abstract: "Validate one local USDZ asset with bounded native inspection.",
    version: ValidatorVersion.current,
    subcommands: [ValidateCommand.self, RulesCommand.self]
  )

  static func main() {
    signal(SIGPIPE, SIG_IGN)
    let code = CommandDriver.run(
      arguments: Array(CommandLine.arguments.dropFirst()), streams: .standard
    ) { url, configuration in
      #if UVK_PROCESS_TESTING
        if let report = ProcessTestHooks.report(fileAt: url, configuration: configuration) {
          return report
        }
        if let validator = try ProcessTestHooks.validator() {
          return try validator.validate(fileAt: url, configuration: configuration)
        }
      #endif
      return try Validator().validate(fileAt: url, configuration: configuration)
    }
    Darwin.exit(code)
  }
}

struct ValidateCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "validate",
    abstract:
      "Validate exactly one local regular file; stdin, URLs, and batch input are unsupported.")
  @Argument(help: "Local input path (use -- before an option-like filename).") var input: String
  @Option(help: "Report format: text, json, or sarif.") var format = "text"
  @Option(help: "Write the complete report by atomic replacement at this local path.") var output:
    String?
  @Option(help: "Native profile: general-v1 or apple-portable-v1.") var profile = "general-v1"
  @Option(help: "Explicit UTF-8 JSON budget configuration (at most 64 KiB).") var config: String?
  @Option(name: .long, help: "Blocking severity: error or warning.") var failOn = "error"
  @Flag(name: .long, help: "Accept native coverage gaps without changing reported coverage.")
  var allowIncomplete = false
  @Flag(
    help:
      "Run /usr/bin/usdchecker for trusted input. Its parsers/resolvers can access resources beyond the native package-only boundary; execution is not sandboxed."
  ) var usdchecker = false
  @Flag(
    name: .long,
    help: "Include bounded absolute input/reference details and raw checker diagnostics.")
  var includeSensitiveDetails = false

  mutating func validate() throws {
    guard ReportFormat(rawValue: format) != nil, Profile(rawValue: profile) != nil,
      FailureThreshold(rawValue: failOn) != nil,
      !input.isEmpty, input != "-", !input.utf8.contains(0), !input.contains("://"),
      URL(string: input)?.scheme == nil,
      output.map({ !$0.isEmpty && !$0.utf8.contains(0) }) ?? true
    else { throw ArgumentParser.ValidationError("Invalid validation options or local path.") }
  }
}

struct RulesCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "rules",
    abstract: "List the selected native rule catalogue without opening assets or probing tools.")
  @Option(help: "Catalogue format: text or json.") var format = "text"
  @Option(help: "Native profile: general-v1 or apple-portable-v1.") var profile = "general-v1"
  mutating func validate() throws {
    guard CatalogueFormat(rawValue: format) != nil, Profile(rawValue: profile) != nil else {
      throw ArgumentParser.ValidationError("Invalid catalogue format or profile.")
    }
  }
}

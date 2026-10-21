import ArgumentParser
import Darwin
import Foundation
import USDZValidation

struct CLIStreams {
  let stdout: (Data) throws -> Void
  let stderr: (Data) throws -> Void

  static var standard: CLIStreams {
    CLIStreams(
      stdout: { try write($0, descriptor: STDOUT_FILENO) },
      stderr: { try write($0, descriptor: STDERR_FILENO) })
  }

  private static func write(_ data: Data, descriptor: Int32) throws {
    try data.withUnsafeBytes { bytes in
      var offset = 0
      while offset < bytes.count {
        let count = Darwin.write(
          descriptor, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
        if count < 0 && errno == EINTR { continue }
        guard count > 0 else {
          throw USDZValidation.ValidationError.operational(.outputWriteFailed)
        }
        offset += count
      }
    }
  }
}

enum CommandDriver {
  static func run(
    arguments: [String], streams: CLIStreams,
    validate: (URL, ValidationConfiguration) throws -> ValidationReport
  ) -> Int32 {
    run(
      arguments: arguments, streams: streams, loadConfiguration: readConfiguration,
      validate: validate)
  }

  static func run(
    arguments: [String], streams: CLIStreams, loadConfiguration: (URL) throws -> Data,
    validate: (URL, ValidationConfiguration) throws -> ValidationReport
  ) -> Int32 {
    let command: any ParsableCommand
    do {
      command = try USDZValidatorCommand.parseAsRoot(arguments)
    } catch {
      if USDZValidatorCommand.exitCode(for: error) == .success {
        do {
          try streams.stdout(Data(USDZValidatorCommand.fullMessage(for: error).utf8))
          return 0
        } catch { return diagnostic("outputWriteFailed", code: 3, streams: streams) }
      }
      return diagnostic("invalid invocation; use --help", code: 64, streams: streams)
    }
    if let rules = command as? RulesCommand {
      do {
        let data = try ReportEncoder.encodeCatalogue(
          profile: Profile(rawValue: rules.profile)!,
          format: CatalogueFormat(rawValue: rules.format)!)
        try streams.stdout(data)
        return 0
      } catch { return diagnostic("report output failed", code: 3, streams: streams) }
    }
    guard let options = command as? ValidateCommand else {
      if command is USDZValidatorCommand {
        return diagnostic("a command is required; use --help", code: 64, streams: streams)
      }
      // ArgumentParser represents help requests as a parsed help command.
      let target: any ParsableCommand.Type =
        arguments.contains("validate")
        ? ValidateCommand.self
        : arguments.contains("rules") ? RulesCommand.self : USDZValidatorCommand.self
      do {
        try streams.stdout(Data(USDZValidatorCommand.helpMessage(for: target).utf8))
        return 0
      } catch { return diagnostic("outputWriteFailed", code: 3, streams: streams) }
    }
    let configuration: ValidationConfiguration
    do {
      let budgets =
        try options.config.map {
          try BudgetConfiguration.decode(loadConfiguration(URL(fileURLWithPath: $0)))
        } ?? .defaults
      configuration = try ValidationConfiguration(
        profile: Profile(rawValue: options.profile)!, budgets: budgets,
        gatePolicy: GatePolicy(
          failOn: FailureThreshold(rawValue: options.failOn)!,
          allowIncomplete: options.allowIncomplete),
        includeSensitiveDetails: options.includeSensitiveDetails,
        externalCheck: options.usdchecker ? .usdchecker : .disabled)
    } catch let error as USDZValidation.ValidationError {
      if case .configuration(let reason) = error {
        return diagnostic("configuration: \(reason.rawValue)", code: 64, streams: streams)
      }
      return diagnostic("configuration: unreadableConfiguration", code: 64, streams: streams)
    } catch {
      return diagnostic("configuration: unreadableConfiguration", code: 64, streams: streams)
    }
    let url = URL(fileURLWithPath: options.input).standardizedFileURL
    var metadata = stat()
    if lstat(url.path, &metadata) == 0 && metadata.st_mode & S_IFMT == S_IFDIR {
      return diagnostic("input must be one local regular file", code: 64, streams: streams)
    }
    let report: ValidationReport
    var failure: USDZValidation.ValidationError?
    do { report = try validate(url, configuration) } catch let error
      as USDZValidation.ValidationError
    {
      if case .configuration(let reason) = error {
        return diagnostic("configuration: \(reason.rawValue)", code: 64, streams: streams)
      }
      failure = error
      report = ValidationReport(failure: error, fileAt: url, configuration: configuration)
    } catch {
      failure = .internalFailure(.unexpectedFailure)
      report = ValidationReport(
        failure: .internalFailure(.unexpectedFailure), fileAt: url, configuration: configuration)
    }
    do {
      let data = try ReportEncoder.encode(report, format: ReportFormat(rawValue: options.format)!)
      try streams.stdout(data)
    } catch {
      return diagnostic(
        "report output failed", code: deliveryFailureCode(preserving: report.exitCode),
        streams: streams)
    }
    if let failure {
      switch failure {
      case .operational(let reason):
        return diagnostic(
          "operational: \(reason.rawValue)", code: report.exitCode, streams: streams)
      case .internalFailure(let reason):
        return diagnostic("internal: \(reason.rawValue)", code: report.exitCode, streams: streams)
      case .configuration(let reason):
        return diagnostic("configuration: \(reason.rawValue)", code: 64, streams: streams)
      }
    }
    return report.exitCode
  }

  private static func diagnostic(_ message: String, code: Int32, streams: CLIStreams) -> Int32 {
    do {
      try streams.stderr(Data("error: \(message).\n".utf8))
      return code
    } catch { return deliveryFailureCode(preserving: code) }
  }

  private static func deliveryFailureCode(preserving code: Int32) -> Int32 {
    // Invocation/configuration and internal failures outrank secondary delivery failures.
    switch code {
    case 64, 70: return code
    default: return 3
    }
  }

  private static func readConfiguration(_ url: URL) throws -> Data {
    // Reject special paths before opening, then recheck the descriptor against races.
    guard !url.path.utf8.contains(0) else {
      throw USDZValidation.ValidationError.configuration(.unreadableConfiguration)
    }
    var named = stat()
    guard lstat(url.path, &named) == 0, named.st_mode & S_IFMT == S_IFREG else {
      throw USDZValidation.ValidationError.configuration(.unreadableConfiguration)
    }
    // Nonblocking + no-follow rejects replacement FIFOs and symlinks without waiting.
    let descriptor = Darwin.open(url.path, O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC)
    guard descriptor >= 0 else {
      throw USDZValidation.ValidationError.configuration(.unreadableConfiguration)
    }
    defer { _ = Darwin.close(descriptor) }
    var metadata = stat()
    guard fstat(descriptor, &metadata) == 0, metadata.st_mode & S_IFMT == S_IFREG else {
      throw USDZValidation.ValidationError.configuration(.unreadableConfiguration)
    }
    guard metadata.st_size >= 0, metadata.st_size <= 65_536 else {
      throw USDZValidation.ValidationError.configuration(.sizeLimitExceeded)
    }
    var result = Data()
    var buffer = [UInt8](repeating: 0, count: 8_192)
    while true {
      let count = Darwin.read(descriptor, &buffer, min(buffer.count, 65_537 - result.count))
      if count < 0 && errno == EINTR { continue }
      guard count >= 0 else {
        throw USDZValidation.ValidationError.configuration(.unreadableConfiguration)
      }
      if count == 0 { return result }
      result.append(contentsOf: buffer.prefix(count))
      guard result.count <= 65_536 else {
        throw USDZValidation.ValidationError.configuration(.sizeLimitExceeded)
      }
    }
  }
}

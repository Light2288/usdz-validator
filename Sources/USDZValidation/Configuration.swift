public enum Profile: String, CaseIterable, Equatable, Sendable {
  case generalV1 = "general-v1"
  case applePortableV1 = "apple-portable-v1"
}

public enum ExternalRequest: String, Equatable, Sendable {
  case disabled
  case usdchecker
}

/// Warning thresholds only. A nil threshold disables that advisory check.
/// Values are validated when made effective by ValidationConfiguration.
public struct WarningBudgets: Equatable, Sendable {
  public let archiveBytes: Int64?
  public let fileBytes: Int64?
  public let fileCount: Int64?
  public let textureBytes: Int64?
  public let totalTextureBytes: Int64?
  public let textureMaxDimension: Int64?

  public static let defaults = WarningBudgets()

  public init(
    archiveBytes: Int64? = 104_857_600,
    fileBytes: Int64? = 26_214_400,
    fileCount: Int64? = 1_000,
    textureBytes: Int64? = 20_971_520,
    totalTextureBytes: Int64? = 83_886_080,
    textureMaxDimension: Int64? = 4_096
  ) {
    self.archiveBytes = archiveBytes
    self.fileBytes = fileBytes
    self.fileCount = fileCount
    self.textureBytes = textureBytes
    self.totalTextureBytes = totalTextureBytes
    self.textureMaxDimension = textureMaxDimension
  }
}

public struct ValidationConfiguration: Equatable, Sendable {
  public let profile: Profile
  public let budgets: WarningBudgets
  public let safetyEnvelopeVersion: Int = 1
  public let gatePolicy: GatePolicy
  public let includeSensitiveDetails: Bool
  public let externalCheck: ExternalRequest

  public init(
    profile: Profile = .generalV1,
    budgets: WarningBudgets = .defaults,
    gatePolicy: GatePolicy = .default,
    includeSensitiveDetails: Bool = false,
    externalCheck: ExternalRequest = .disabled
  ) throws {
    let thresholds = [
      budgets.archiveBytes, budgets.fileBytes, budgets.fileCount, budgets.textureBytes,
      budgets.totalTextureBytes, budgets.textureMaxDimension,
    ]
    guard thresholds.compactMap({ $0 }).allSatisfy({ $0 > 0 }) else {
      throw ValidationError.configuration(.invalidBudget)
    }
    self.profile = profile
    self.budgets = budgets
    self.gatePolicy = gatePolicy
    self.includeSensitiveDetails = includeSensitiveDetails
    self.externalCheck = externalCheck
  }
}

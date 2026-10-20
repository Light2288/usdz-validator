/// Stable reason codes keep local paths and underlying system diagnostics out of reports.
public enum ValidationError: Error, Equatable, Sendable {
  case configuration(ConfigurationFailureReason)
  case operational(OperationalFailureReason)
  case internalFailure(InternalFailureReason)
}

public enum ConfigurationFailureReason: String, Equatable, Sendable {
  case invalidBudget
  case invalidSchemaVersion
  case unknownKey
  case duplicateKey
  case invalidValue
  case sizeLimitExceeded
  case trailingData
  case invalidEncoding
  case unreadableConfiguration
}

public enum OperationalFailureReason: String, Equatable, Sendable {
  case inputUnavailable
  case inputNotRegular
  case inputSymbolicLink
  case inputChanged
  case inputReadFailed
  case outputUnavailable
  case outputUnsafe
  case outputWriteFailed
  case reportEncodingFailed
  case reportLimitExceeded
}

public enum InternalFailureReason: String, Equatable, Sendable {
  case unexpectedFailure
  case invariantViolation
}

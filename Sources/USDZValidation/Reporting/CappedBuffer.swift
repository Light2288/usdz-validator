import Foundation

/// A complete encoded document is retained before any destination is written.
struct CappedBuffer {
  private let limit: Int
  private var data = Data()

  // The smaller injectable limit is internal and useful for boundary tests only.
  init(limit: Int = 33_554_432) {
    self.limit = min(max(0, limit), 33_554_432)
  }

  mutating func append(_ bytes: Data) throws {
    guard bytes.count <= limit - data.count else {
      throw ValidationError.operational(.reportLimitExceeded)
    }
    data.append(bytes)
  }

  func finish() -> Data { data }
}

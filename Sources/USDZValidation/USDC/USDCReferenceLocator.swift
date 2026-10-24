import Foundation

/// Structural occurrence coordinates never contain authored keys, scene paths or physical offsets.
struct USDCReferenceLocator: Equatable {
  enum Kind: UInt8 {
    case array = 0
    case dictionary = 1
    case listBucket = 2
    case listItem = 3
    case sample = 4
    case wrapper = 5
    case referenceCustomData = 6
  }

  struct Step: Equatable {
    let kind: Kind
    let index: UInt64
  }

  let specIndex: UInt64
  let fieldOrdinal: UInt64
  let steps: [Step]

  init(specIndex: UInt64, fieldOrdinal: UInt64, steps: [Step] = []) throws {
    // One value level may contribute bucket/item and customData coordinates. This is
    // an identity-storage bound; traversal must enforce the separate value depth ceiling.
    guard steps.count <= Int(SafetyResource.usdcDepth.limit) * 3 else {
      throw InspectionFailure.resourceLimit(.usdcDepth)
    }
    self.specIndex = specIndex
    self.fieldOrdinal = fieldOrdinal
    self.steps = steps
  }

  /// Callers provide fixed reason codes. Even 96 maximum-width numeric steps fit below 4 KiB.
  func discriminator(reason: String) -> String {
    var result = "\(reason)|usdc-v1|s:\(specIndex)|f:\(fieldOrdinal)"
    for step in steps { result += "|\(step.kind.rawValue):\(step.index)" }
    return result
  }
}

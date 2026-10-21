import Foundation
import XCTest

@testable import USDZValidation

final class CappedBufferTests: XCTestCase {
  func testExactLimits() throws {
    for (kind, limit): (DisclosureKind, Int) in [(.message, 1_024), (.evidence, 4_096)] {
      XCTAssertEqual(
        Privacy.render(String(repeating: "a", count: limit), kind: kind, sensitive: true).utf8
          .count, limit)
      let above = Privacy.render(
        String(repeating: "a", count: limit + 1), kind: kind, sensitive: true)
      XCTAssertEqual(above.utf8.count, limit)
      XCTAssertTrue(above.hasSuffix("[truncated]"))
      for scalar in ["😀", "é", "\u{001b}", "\u{202e}", "\\"] {
        let rendered = Privacy.render(
          String(repeating: scalar, count: limit), kind: kind, sensitive: true)
        XCTAssertLessThanOrEqual(rendered.utf8.count, limit)
        XCTAssertTrue(rendered.hasSuffix("[truncated]"))
        XCTAssertFalse(rendered.contains("�"))
        XCTAssertFalse(rendered.contains("\u{001b}"))
      }
    }
    var fullBuffer = CappedBuffer()
    try fullBuffer.append(Data(repeating: 0x61, count: 33_554_431))
    try fullBuffer.append(Data([0x0a]))
    XCTAssertEqual(fullBuffer.finish().count, 33_554_432)
    XCTAssertThrowsError(try fullBuffer.append(Data([0x0a]))) {
      XCTAssertEqual($0 as? ValidationError, .operational(.reportLimitExceeded))
    }
    XCTAssertEqual(fullBuffer.finish().count, 33_554_432)
    var small = CappedBuffer(limit: 3)
    try small.append(Data([1, 2]))
    XCTAssertThrowsError(try small.append(Data([3, 4])))
    XCTAssertEqual(small.finish(), Data([1, 2]))
    try small.append(Data([3]))
    XCTAssertEqual(small.finish(), Data([1, 2, 3]))
  }

  func testNativeRetentionAndPresentationDoNotChangeIdentity() {
    let key = FindingKey(
      ruleID: "UVK-PATH-006", entryNameBytes: Data("a.usda".utf8), entryOffset: 1, contentOffset: 2,
      discriminator: "missingTarget")
    let diagnostics = NativeDiagnostics()
    diagnostics.emit(
      ruleID: "UVK-PATH-006", message: String(repeating: "😀", count: 300),
      evidence: ["detail": .string(String(repeating: "😀", count: 1_100))],
      location: FindingLocation(entryName: "a.usda"), key: key)
    let finding = diagnostics.finish().0[0]
    XCTAssertEqual(finding.occurrenceID, FindingIdentity.native(key))
    XCTAssertLessThanOrEqual(finding.message.utf8.count, 1_024)
    XCTAssertTrue(finding.message.hasSuffix("[truncated]"))
    guard case .string(let evidence) = finding.evidence["detail"] else {
      return XCTFail("missing evidence")
    }
    XCTAssertLessThanOrEqual(evidence.utf8.count, 4_096)
    XCTAssertTrue(evidence.hasSuffix("[truncated]"))
    XCTAssertFalse(evidence.contains("�"))
  }
}

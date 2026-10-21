import Foundation
import XCTest

@testable import USDZValidation

final class PrivacyTests: XCTestCase {
  func testMaliciousNamesAndDisclosure() throws {
    let owner = "/Users/fixture-owner/"
    XCTAssertEqual(
      Privacy.render(owner + "a\u{001b}\n\u{202e}\u{0000}.usdz", kind: .basename, sensitive: false),
      "a\\u{001B}\\n\\u{202E}\\u{0000}.usdz")
    for value in [
      owner + "secret.usda", "C:\\private\\secret.usda", "../secret.usda", "https://host/a",
      "//host/a",
    ] {
      for kind: DisclosureKind in [.member, .reference, .path, .evidence, .message] {
        XCTAssertFalse(Privacy.render(value, kind: kind, sensitive: false).contains(value))
      }
    }
    for wrapped in [
      "failed at `/Users/fixture-owner/input`", "failed: \u{001b}/Users/fixture-owner/input",
      "failed at “/Users/fixture-owner/input”",
    ] {
      for kind: DisclosureKind in [.message, .evidence] {
        XCTAssertFalse(
          Privacy.render(wrapped, kind: kind, sensitive: false).contains("/Users/fixture-owner/"))
      }
    }
    XCTAssertEqual(
      Privacy.render("Sources/a.usda", kind: .member, sensitive: false), "Sources/a.usda")
    XCTAssertEqual(
      Privacy.render("read failed at " + owner + "input", kind: .error, sensitive: false),
      "[redacted error]")
    XCTAssertEqual(
      Privacy.render("diagnostic " + owner, kind: .toolDetail, sensitive: false),
      "[redacted tool detail]")
    let detail = Privacy.render(
      owner + "\u{001b}\n" + String(repeating: "😀", count: 2_000), kind: .toolDetail,
      sensitive: true)
    XCTAssertTrue(detail.hasPrefix(owner + "\\u{001B}\\n"))
    XCTAssertFalse(detail.contains("\u{001b}"))
    XCTAssertLessThanOrEqual(detail.utf8.count, 4_096)
    XCTAssertTrue(detail.hasSuffix("[truncated]"))
    let basename = Privacy.render(
      owner + String(repeating: "x", count: 5_000), kind: .basename, sensitive: false)
    XCTAssertFalse(basename.contains(owner))
    XCTAssertEqual(basename.utf8.count, 4_096)
    XCTAssertTrue(basename.hasSuffix("[truncated]"))
  }
}

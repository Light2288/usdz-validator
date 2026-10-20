import Darwin
import Foundation
import XCTest

@testable import USDZValidation

final class FileSnapshotTests: XCTestCase {
  func testRejectsSymlinkFIFOAndDirectoryWithoutBlocking() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("input.usdz")
    try Data([0, 1, 2]).write(to: file)
    let link = directory.appendingPathComponent("link.usdz")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
    XCTAssertThrowsError(try FileSnapshot.open(link)) { error in
      XCTAssertEqual(error as? ValidationError, .operational(.inputSymbolicLink))
    }
    XCTAssertThrowsError(try FileSnapshot.open(directory)) { error in
      XCTAssertEqual(error as? ValidationError, .operational(.inputNotRegular))
    }
    let fifo = directory.appendingPathComponent("pipe")
    XCTAssertEqual(mkfifo(fifo.path, 0o600), 0)
    let started = ContinuousClock.now
    XCTAssertThrowsError(try FileSnapshot.open(fifo)) { error in
      XCTAssertEqual(error as? ValidationError, .operational(.inputNotRegular))
    }
    XCTAssertLessThan(started.duration(to: .now), .seconds(2))
    XCTAssertThrowsError(try FileSnapshot.open(directory.appendingPathComponent("absent"))) {
      error in
      XCTAssertEqual(error as? ValidationError, .operational(.inputUnavailable))
    }
  }

  func testDescriptorReadRangesAndDeterministicClose() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("input.usdz")
    try Data([0, 1, 2, 3]).write(to: file)
    let snapshot = try FileSnapshot.open(file)
    XCTAssertEqual(snapshot.size, 4)
    XCTAssertEqual(try snapshot.read(offset: 1, count: 2), Data([1, 2]))
    XCTAssertEqual(try snapshot.read(offset: 4, count: 0), Data())
    for (offset, count) in [(UInt64.max, 1), (0, -1), (4, 1)] {
      XCTAssertThrowsError(try snapshot.read(offset: offset, count: count)) { error in
        XCTAssertEqual(error as? InspectionFailure, .malformedRange)
      }
    }
    try snapshot.verifyUnchanged()
    try snapshot.close()
    XCTAssertNoThrow(try snapshot.close())
    XCTAssertThrowsError(try snapshot.read(offset: 0, count: 1)) { error in
      XCTAssertEqual(error as? ValidationError, .operational(.inputReadFailed))
    }
    XCTAssertThrowsError(try snapshot.verifyUnchanged()) { error in
      XCTAssertEqual(error as? ValidationError, .operational(.inputReadFailed))
    }
  }

  func testDetectsTruncationReplacementAndSameSizeChange() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    for mutation in ["truncate", "replace", "sameSize", "unlink", "symlink"] {
      let file = directory.appendingPathComponent(mutation)
      try Data([0, 1, 2, 3]).write(to: file)
      let snapshot = try FileSnapshot.open(file)
      defer { try? snapshot.close() }
      switch mutation {
      case "truncate":
        let handle = try FileHandle(forWritingTo: file)
        try handle.truncate(atOffset: 1)
        try handle.close()
      case "replace":
        try Data([0, 1, 2, 3]).write(to: file, options: .atomic)
      case "sameSize":
        let handle = try FileHandle(forWritingTo: file)
        try handle.write(contentsOf: Data([4, 5, 6, 7]))
        try handle.close()
      case "symlink":
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createSymbolicLink(at: file, withDestinationURL: directory)
      default: try FileManager.default.removeItem(at: file)
      }
      XCTAssertThrowsError(try snapshot.verifyUnchanged(), mutation) { error in
        XCTAssertEqual(error as? ValidationError, .operational(.inputChanged))
      }
      XCTAssertThrowsError(try snapshot.read(offset: 0, count: 1), mutation) { error in
        XCTAssertEqual(error as? ValidationError, .operational(.inputChanged))
      }
    }
  }

  func testDescriptorChunkLimitAndSparseOversizedInput() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("input.usdz")
    try Data(repeating: 0x41, count: 65_537).write(to: file)
    let snapshot = try FileSnapshot.open(file)
    defer { try? snapshot.close() }
    XCTAssertEqual(try snapshot.read(offset: 0, count: 65_536).count, 65_536)
    XCTAssertThrowsError(try snapshot.read(offset: 0, count: 65_537)) { error in
      XCTAssertEqual(error as? InspectionFailure, .resourceLimit(.readChunkBytes))
    }
    let sparse = directory.appendingPathComponent("large.usdz")
    XCTAssertTrue(FileManager.default.createFile(atPath: sparse.path, contents: nil))
    let handle = try FileHandle(forWritingTo: sparse)
    try handle.truncate(atOffset: 536_870_913)
    try handle.close()
    let large = try FileSnapshot.open(sparse)
    defer { try? large.close() }
    XCTAssertEqual(large.size, 536_870_913)
    XCTAssertThrowsError(try large.read(offset: 0, count: 1)) { error in
      XCTAssertEqual(error as? InspectionFailure, .resourceLimit(.archiveBytes))
    }
  }

  private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    return url
  }
}

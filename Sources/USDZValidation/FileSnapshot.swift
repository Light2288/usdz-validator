import Darwin
import Foundation

/// Owns one read-only descriptor. Metadata detects ordinary concurrent changes, not writers
/// capable of restoring metadata. Call close() for deterministic release; deinit is a fallback.
final class FileSnapshot {
  let size: UInt64
  private let url: URL
  private let identity: Identity
  private var descriptor: Int32?

  private struct Identity: Equatable {
    let device: dev_t
    let inode: ino_t
    let mode: mode_t
    let bytes: off_t
    let modifiedSeconds: Int
    let modifiedNanoseconds: Int
    let changedSeconds: Int
    let changedNanoseconds: Int

    init(_ metadata: stat) {
      device = metadata.st_dev
      inode = metadata.st_ino
      mode = metadata.st_mode
      bytes = metadata.st_size
      modifiedSeconds = metadata.st_mtimespec.tv_sec
      modifiedNanoseconds = metadata.st_mtimespec.tv_nsec
      changedSeconds = metadata.st_ctimespec.tv_sec
      changedNanoseconds = metadata.st_ctimespec.tv_nsec
    }
  }

  private init(url: URL, descriptor: Int32, metadata: stat, size: UInt64) {
    self.url = url
    self.descriptor = descriptor
    self.identity = Identity(metadata)
    self.size = size
  }

  static func open(_ url: URL) throws -> FileSnapshot {
    guard url.isFileURL else { throw ValidationError.operational(.inputUnavailable) }
    var named = stat()
    let namedResult = url.withUnsafeFileSystemRepresentation { path in
      guard let path else { return Int32(-1) }
      return lstat(path, &named)
    }
    guard namedResult == 0 else { throw ValidationError.operational(.inputUnavailable) }
    guard named.st_mode & S_IFMT != S_IFLNK else {
      throw ValidationError.operational(.inputSymbolicLink)
    }
    guard named.st_mode & S_IFMT == S_IFREG else {
      throw ValidationError.operational(.inputNotRegular)
    }
    let descriptor = url.withUnsafeFileSystemRepresentation { path in
      guard let path else { return Int32(-1) }
      return Darwin.open(path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
    }
    guard descriptor >= 0 else {
      if errno == ELOOP { throw ValidationError.operational(.inputSymbolicLink) }
      throw ValidationError.operational(.inputUnavailable)
    }
    var metadata = stat()
    let result = fstat(descriptor, &metadata)
    guard result == 0 else {
      // Preserve the primary stat failure; this descriptor has not escaped its owner.
      _ = Darwin.close(descriptor)
      throw ValidationError.operational(.inputReadFailed)
    }
    guard metadata.st_mode & S_IFMT == S_IFREG else {
      _ = Darwin.close(descriptor)
      throw ValidationError.operational(.inputNotRegular)
    }
    guard Identity(named) == Identity(metadata) else {
      _ = Darwin.close(descriptor)
      throw ValidationError.operational(.inputChanged)
    }
    guard let size = UInt64(exactly: metadata.st_size) else {
      _ = Darwin.close(descriptor)
      throw ValidationError.operational(.inputReadFailed)
    }
    return FileSnapshot(url: url, descriptor: descriptor, metadata: metadata, size: size)
  }

  func read(offset: UInt64, count: Int) throws -> Data {
    guard let bytes = UInt64(exactly: count), let fileOffset = off_t(exactly: offset) else {
      throw InspectionFailure.malformedRange
    }
    let (end, overflow) = offset.addingReportingOverflow(bytes)
    guard !overflow, end <= size else { throw InspectionFailure.malformedRange }
    guard size <= SafetyResource.archiveBytes.limit else {
      throw InspectionFailure.resourceLimit(.archiveBytes)
    }
    guard bytes <= SafetyResource.readChunkBytes.limit else {
      throw InspectionFailure.resourceLimit(.readChunkBytes)
    }
    try verifyUnchanged()
    guard let descriptor else { throw ValidationError.operational(.inputReadFailed) }
    guard count > 0 else { return Data() }
    var data = Data(count: count)
    let received = data.withUnsafeMutableBytes { buffer in
      var result: Int
      repeat {
        result = pread(descriptor, buffer.baseAddress, count, fileOffset)
      } while result < 0 && errno == EINTR
      return result
    }
    try verifyUnchanged()
    guard received == count else { throw ValidationError.operational(.inputReadFailed) }
    return data
  }

  func verifyUnchanged() throws {
    guard let descriptor else { throw ValidationError.operational(.inputReadFailed) }
    var metadata = stat()
    guard fstat(descriptor, &metadata) == 0 else {
      throw ValidationError.operational(.inputReadFailed)
    }
    guard identity == Identity(metadata) else {
      throw ValidationError.operational(.inputChanged)
    }
    // fstat alone cannot detect an atomic pathname replacement: the old inode stays open.
    var named = stat()
    let result = url.withUnsafeFileSystemRepresentation { path in
      guard let path else { return Int32(-1) }
      return lstat(path, &named)
    }
    guard result == 0, identity == Identity(named) else {
      throw ValidationError.operational(.inputChanged)
    }
  }

  func close() throws {
    guard let descriptor else { return }
    self.descriptor = nil
    // Do not retry close on EINTR: a reused descriptor must never be closed accidentally.
    guard Darwin.close(descriptor) == 0 else {
      throw ValidationError.operational(.inputReadFailed)
    }
  }

  deinit {
    if let descriptor { _ = Darwin.close(descriptor) }
  }
}

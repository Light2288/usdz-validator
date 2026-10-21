import Darwin
import Foundation
import USDZValidation

/// Replaces only after a complete report is closed and detectable identity changes are ruled out.
/// Metadata checks do not sandbox an unrestricted concurrent filesystem writer.
enum ReportDestination {
  struct Operations {
    var write: (Int32, UnsafeRawPointer, Int) -> Int = { Darwin.write($0, $1, $2) }
    var close: (Int32) -> Int32 = { Darwin.close($0) }
    var rename: (Int32, String, Int32, String) -> Int32 = { renameat($0, $1, $2, $3) }
  }

  private struct Identity: Equatable {
    let device: dev_t
    let inode: ino_t
    init(_ value: stat) {
      device = value.st_dev
      inode = value.st_ino
    }
  }

  private struct Metadata: Equatable {
    let identity: Identity
    let mode: mode_t
    let size: off_t
    let links: nlink_t
    let owner: uid_t
    let group: gid_t
    let flags: UInt32
    let modifiedSeconds: Int
    let modifiedNanoseconds: Int
    let changedSeconds: Int
    let changedNanoseconds: Int
    init(_ value: stat) {
      identity = Identity(value)
      mode = value.st_mode
      size = value.st_size
      links = value.st_nlink
      owner = value.st_uid
      group = value.st_gid
      flags = value.st_flags
      modifiedSeconds = value.st_mtimespec.tv_sec
      modifiedNanoseconds = value.st_mtimespec.tv_nsec
      changedSeconds = value.st_ctimespec.tv_sec
      changedNanoseconds = value.st_ctimespec.tv_nsec
    }
  }

  static func write(_ completeReport: Data, to destination: URL, input: URL) throws {
    try write(completeReport, to: destination, input: input, operations: Operations())
  }

  static func write(
    _ completeReport: Data, to destination: URL, input: URL, operations: Operations
  ) throws {
    guard destination.isFileURL, input.isFileURL,
      !destination.path.utf8.contains(0), !input.path.utf8.contains(0)
    else { throw ValidationError.operational(.outputUnsafe) }
    let destination = destination.standardizedFileURL
    let input = input.standardizedFileURL
    guard destination.path != input.path else { throw ValidationError.operational(.outputUnsafe) }
    let parent = destination.deletingLastPathComponent()
    let name = destination.lastPathComponent
    guard !name.isEmpty, name != ".", name != ".." else {
      throw ValidationError.operational(.outputUnsafe)
    }
    var parentNamed = stat()
    guard lstat(parent.path, &parentNamed) == 0, parentNamed.st_mode & S_IFMT == S_IFDIR else {
      throw ValidationError.operational(.outputUnavailable)
    }
    let directory = Darwin.open(parent.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard directory >= 0 else { throw ValidationError.operational(.outputUnavailable) }
    defer { _ = Darwin.close(directory) }
    var parentOpened = stat()
    guard fstat(directory, &parentOpened) == 0,
      Identity(parentNamed) == Identity(parentOpened), parentOpened.st_mode & S_IFMT == S_IFDIR
    else { throw ValidationError.operational(.outputUnsafe) }

    let inputNamed = try inputMetadata(input)
    var inputDescriptor: Int32?
    defer { if let inputDescriptor { _ = Darwin.close(inputDescriptor) } }
    if let inputNamed, inputNamed.mode & S_IFMT == S_IFREG {
      let descriptor = Darwin.open(input.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
      if descriptor >= 0 {
        inputDescriptor = descriptor
        guard try metadata(descriptor) == inputNamed else {
          throw ValidationError.operational(.outputUnsafe)
        }
      } else if errno != EACCES && errno != EPERM {
        throw ValidationError.operational(.outputUnsafe)
      }
      // An unreadable input still deserves its operational report. Its named identity remains protected.
    }
    let previous = try namedMetadata(directory, name)
    var previousDescriptor: Int32?
    defer { if let previousDescriptor { _ = Darwin.close(previousDescriptor) } }
    if let previous {
      guard previous.mode & S_IFMT == S_IFREG, previous.identity != inputNamed?.identity else {
        throw ValidationError.operational(.outputUnsafe)
      }
      let descriptor = openat(directory, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
      guard descriptor >= 0 else { throw ValidationError.operational(.outputUnavailable) }
      previousDescriptor = descriptor
      guard try metadata(descriptor) == previous else {
        throw ValidationError.operational(.outputUnsafe)
      }
    }

    let temporaryName = ".usdz-validator-report-\(UUID().uuidString).tmp"
    let temporary = openat(
      directory, temporaryName, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
    guard temporary >= 0 else { throw ValidationError.operational(.outputUnavailable) }
    var temporaryDescriptor: Int32? = temporary
    var temporaryIdentity: Identity?
    do {
      let opened = try metadata(temporary)
      temporaryIdentity = opened.identity
      guard opened.mode & S_IFMT == S_IFREG, opened.links == 1,
        opened.mode & 0o777 == 0o600,
        try namedMetadata(directory, temporaryName) == opened
      else { throw ValidationError.operational(.outputUnsafe) }
      try completeReport.withUnsafeBytes { bytes in
        var offset = 0
        while offset < bytes.count {
          let count = operations.write(
            temporary, bytes.baseAddress!.advanced(by: offset), min(bytes.count - offset, 65_536))
          if count < 0 && errno == EINTR { continue }
          guard count > 0, count <= bytes.count - offset else {
            throw ValidationError.operational(.outputWriteFailed)
          }
          offset += count
        }
      }
      let completed = try metadata(temporary)
      guard completed.identity == opened.identity, completed.mode == opened.mode,
        completed.links == 1, completed.size == completeReport.count,
        try namedMetadata(directory, temporaryName) == completed
      else { throw ValidationError.operational(.outputUnsafe) }
      // As with POSIX close, do not retry a failed close and risk closing a reused descriptor.
      temporaryDescriptor = nil
      guard operations.close(temporary) == 0 else {
        throw ValidationError.operational(.outputWriteFailed)
      }
      var currentParent = stat()
      guard lstat(parent.path, &currentParent) == 0,
        Identity(currentParent) == Identity(parentOpened),
        currentParent.st_mode & S_IFMT == S_IFDIR,
        try inputMetadata(input) == inputNamed,
        try namedMetadata(directory, name) == previous,
        try namedMetadata(directory, temporaryName) == completed
      else { throw ValidationError.operational(.outputUnsafe) }
      if let inputDescriptor, try metadata(inputDescriptor) != inputNamed {
        throw ValidationError.operational(.outputUnsafe)
      }
      if let previousDescriptor, try metadata(previousDescriptor) != previous {
        throw ValidationError.operational(.outputUnsafe)
      }
      guard operations.rename(directory, temporaryName, directory, name) == 0 else {
        throw ValidationError.operational(.outputWriteFailed)
      }
    } catch {
      if let temporaryDescriptor { _ = Darwin.close(temporaryDescriptor) }
      // Do not unlink a different file substituted at the temporary pathname.
      if let temporaryIdentity,
        let current = try namedMetadata(directory, temporaryName),
        current.identity == temporaryIdentity
      {
        guard unlinkat(directory, temporaryName, 0) == 0 else {
          throw ValidationError.operational(.outputWriteFailed)
        }
      }
      throw error
    }
  }

  private static func metadata(_ descriptor: Int32) throws -> Metadata {
    var value = stat()
    guard fstat(descriptor, &value) == 0 else {
      throw ValidationError.operational(.outputWriteFailed)
    }
    return Metadata(value)
  }

  private static func namedMetadata(_ directory: Int32, _ name: String) throws -> Metadata? {
    var value = stat()
    if fstatat(directory, name, &value, AT_SYMLINK_NOFOLLOW) == 0 { return Metadata(value) }
    guard errno == ENOENT else { throw ValidationError.operational(.outputUnavailable) }
    return nil
  }

  private static func inputMetadata(_ input: URL) throws -> Metadata? {
    var value = stat()
    if lstat(input.path, &value) == 0 { return Metadata(value) }
    // Missing or inaccessible input can be the very reason this report is being delivered.
    guard errno == ENOENT || errno == ENOTDIR || errno == EACCES || errno == EPERM else {
      throw ValidationError.operational(.outputUnsafe)
    }
    return nil
  }
}

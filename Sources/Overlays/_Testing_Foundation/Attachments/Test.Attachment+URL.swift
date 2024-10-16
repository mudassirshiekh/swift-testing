//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if canImport(Foundation)
@_spi(Experimental) public import Testing
public import Foundation

#if SWT_TARGET_OS_APPLE && canImport(UniformTypeIdentifiers)
private import UniformTypeIdentifiers
@_spi(Experimental) private import _Testing_UniformTypeIdentifiers
#endif

#if !SWT_NO_FILE_IO
extension URL {
  /// The file system path of the URL, equivalent to `path`.
  var fileSystemPath: String {
#if os(Windows)
    // BUG: `path` includes a leading slash which makes it invalid on Windows.
    // SEE: https://github.com/swiftlang/swift-foundation/pull/964
    let utf8 = path.utf8
    let array = Array(utf8)
    if array.count > 4, array[0] == UInt8(ascii: "/"), Character(UnicodeScalar(array[1])).isLetter, array[2] == UInt8(ascii: ":"), array[3] == UInt8(ascii: "/") {
      return String(Substring(utf8.dropFirst()))
    }
#endif
    return path
  }
}

// MARK: - Attaching files

@_spi(Experimental)
extension Test.Attachment {
  /// Initialize an instance of this type with the contents of the given URL.
  ///
  /// - Parameters:
  ///   - url: The URL containing the attachment's data.
  ///   - preferredName: The preferred name of the attachment when writing it
  ///     to a test report or to disk. If `nil`, the name of the attachment is
  ///     derived from the last path component of `url`.
  ///   - sourceLocation: The source location of the attachment.
  ///
  /// - Throws: Any error that occurs attempting to read from `url`.
  public init(
    contentsOf url: URL,
    named preferredName: String? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) async throws {
    guard url.isFileURL else {
      // TODO: network URLs?
      throw CocoaError(.featureUnsupported, userInfo: [NSLocalizedDescriptionKey: "Attaching downloaded files is not supported"])
    }

    // FIXME: use NSFileCoordinator on Darwin?

    let url = url.resolvingSymlinksInPath()
    let isDirectory = try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory!

    let attachableValue: any Test.Attachable & Sendable
    if isDirectory {
      attachableValue = await _DirectoryContentAttachableProxy(contentsOfDirectoryAt: url)
    } else {
      // Load the file.
      attachableValue = try Data(contentsOf: url, options: [.mappedIfSafe])
    }

    // Determine the preferred name of the attachment if one was not provided.
    var preferredName = preferredName
    if preferredName == nil, case let lastPathComponent = url.lastPathComponent, !lastPathComponent.isEmpty {
    if isDirectory {
      preferredName = (lastPathComponent as NSString).appendingPathExtension("tar.gz")
    } else {
      preferredName = lastPathComponent
    }

#if SWT_TARGET_OS_APPLE && canImport(UniformTypeIdentifiers)
      // Determine the content type of the attachment. We don't do this for
      // directories because we already know the type, but also because we want
      // to append .tar.gz as an extension and that isn't a valid path extension
      // according to UniformTypeIdentifiers.
      if !isDirectory, #available(_uttypesAPI, *), let contentType = try url.resourceValues(forKeys: [.contentTypeKey]).contentType {
        self.init(attachableValue, named: preferredName, as: contentType, sourceLocation: sourceLocation)
        return
      }
#endif
    }

    self.init(attachableValue, named: preferredName, sourceLocation: sourceLocation)
  }
}

// MARK: - Attaching directories

/// A type representing the content of a directory as an attachable value.
private struct _DirectoryContentAttachableProxy: Test.Attachable {
  /// The URL of the directory.
  ///
  /// The contents of this directory may change after this instance is
  /// initialized. Such changes are not tracked.
  var url: URL

  /// The archived contents of the directory, or any error that occurred
  /// attempting to archive them.
  private let _directoryContent: Result<Data, any Error>

  /// Initialize an instance of this type.
  ///
  /// - Parameters:
  ///   - directoryURL: A URL referring to the directory to attach.
  ///
  /// This initializer asynchronously compresses the contents of `directoryURL`
  /// into an archive (currently of `.tar.gz` format, although this is subject
  /// to change) and stores a mapped copy of that archive.
  init(contentsOfDirectoryAt directoryURL: URL) async {
    url = directoryURL

    do {
      let temporaryName = "\(UUID().uuidString).tar.gz"
      let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(temporaryName)
      try await compressFileSystemObject(atPath: url.fileSystemPath, toPath: temporaryURL.fileSystemPath)
      _directoryContent = try .success(Data(contentsOf: temporaryURL, options: [.mappedIfSafe]))
    } catch {
      _directoryContent = .failure(error)
    }
  }

  func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try _directoryContent.get().withUnsafeBytes(body)
  }
}
#endif
#endif

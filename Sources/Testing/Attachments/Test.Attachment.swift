//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

private import _TestingInternals

@_spi(Experimental)
extension Test {
  /// A type describing values that can be attached to the output of a test run
  /// and inspected later by the user.
  ///
  /// Attachments are included in test reports in Xcode or written to disk when
  /// tests are run at the command line. To create an attachment, you need a
  /// value of some type that conforms to ``Test/Attachable``. Initialize an
  /// instance of ``Test/Attachment`` with that value and, optionally, a
  /// preferred filename to use when writing to disk.
  ///
  /// On Apple platforms, additional functionality is available if you import
  /// the [UniformTypeIdentifiers](https://developer.apple.com/documentation/uniformtypeidentifiers) module.
  public struct Attachment: Sendable {
    /// The value of this attachment.
    ///
    /// The type of this property's value may not match the type of the value
    /// originally used to create this attachment.
    public var attachableValue: any Attachable & Sendable /* & Copyable rdar://137614425 */

    /// The source location of the attachment.
    public var sourceLocation: SourceLocation

    /// Initialize an instance of this type that encloses the given attachable
    /// value.
    ///
    /// - Parameters:
    ///   - attachableValue: The value that will be attached to the output of
    ///     the test run.
    ///   - preferredName: The preferred name of the attachment when writing it
    ///     to a test report or to disk. If `nil`, the testing library attempts
    ///     to derive a reasonable filename for the attached value.
    ///   - contentType: The content type of the attached value, if applicable
    ///     and known to the caller.
    ///   - sourceLocation: The source location of the attachment.
    ///
    /// This is the designated initializer for this type.
    package init(
      _ attachableValue: some Attachable & Sendable & Copyable,
      named preferredName: String?,
      as contentType: (any Sendable)?,
      sourceLocation: SourceLocation
    ) {
      self.attachableValue = attachableValue
      self.preferredName = preferredName ?? attachableValue._attachmentPreferredName ?? "untitled"
      self._contentType = contentType
      self.sourceLocation = sourceLocation

      self.update()
    }

    /// Initialize an instance of this type that encloses the given attachable
    /// value.
    ///
    /// - Parameters:
    ///   - attachableValue: The value that will be attached to the output of
    ///     the test run.
    ///   - preferredName: The preferred name of the attachment when writing it
    ///     to a test report or to disk. If `nil`, the testing library attempts
    ///     to derive a reasonable filename for the attached value.
    ///   - sourceLocation: The source location of the attachment.
    public init(
      _ attachableValue: some Attachable & Sendable & Copyable,
      named preferredName: String? = nil,
      sourceLocation: SourceLocation = #_sourceLocation
    ) {
      self.init(attachableValue, named: preferredName, as: nil, sourceLocation: sourceLocation)
    }

    /// A filename to use when writing this attachment to a test report or to a
    /// file on disk.
    ///
    /// The value of this property is used as a hint to the testing library. The
    /// testing library may substitute a different filename as needed. If the
    /// value of this property has not been explicitly set, the testing library
    /// will attempt to generate its own value.
    public var preferredName: String

    /// Storage for the `contentType` property defined in the
    /// UniformTypeIdentifiers cross-module overlay and for the `mediaType`
    /// property defined locally.
    ///
    /// Where possible, use the `contentType` or `mediaType` property instead of
    /// this one. Use this property directly only if implementing one of those
    /// properties or if you need to know if the stored value of this property
    /// is `nil`.
    ///
    /// Do not set this property directly (unless implementing one of the above
    /// properties.)
    package var _contentType: (any Sendable)?
  }
}

// MARK: -

extension Test.Attachment {
  /// Attach this instance to the current test.
  ///
  /// An attachment can only be attached once.
  public consuming func attach() {
    Event.post(.valueAttached(self))
  }
}

// MARK: - Non-sendable and move-only attachments

/// A type that stands in for an attachable type that is not also sendable.
private struct _AttachableProxy: Test.Attachable, Sendable {
  /// The result of `withUnsafeBufferPointer(for:_:)` from the original
  /// attachable value.
  var encodedValue = [UInt8]()

  var _attachmentPreferredName: String?
  package var _attachmentContentType: (any Sendable)?

  func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try encodedValue.withUnsafeBufferPointer(for: attachment, body)
  }
}

extension Test.Attachment {
  /// Initialize an instance of this type that encloses the given attachable
  /// value.
  ///
  /// - Parameters:
  ///   - attachableValue: The value that will be attached to the output of
  ///     the test run.
  ///   - preferredName: The preferred name of the attachment when writing it
  ///     to a test report or to disk. If `nil`, the testing library attempts
  ///     to derive a reasonable filename for the attached value.
  ///   - contentType: The content type of the attached value, if applicable and
  ///     known to the caller.
  ///   - sourceLocation: The source location of the attachment.
  ///
  /// When attaching a value of a type that does not conform to `Sendable`, the
  /// testing library encodes it as data immediately. If the value cannot be
  /// encoded and an error is thrown, that error is recorded as an issue in the
  /// current test and the resulting instance of ``Test/Attachment`` is empty.
  package init(
    _ attachableValue: borrowing some Test.Attachable & ~Copyable,
    named preferredName: String?,
    as contentType: (any Sendable)?,
    sourceLocation: SourceLocation
  ) {
    var proxyAttachable = _AttachableProxy()
    proxyAttachable._attachmentPreferredName = attachableValue._attachmentPreferredName
    proxyAttachable._attachmentContentType = attachableValue._attachmentContentType

    // BUG: the borrow checker thinks that withErrorRecording() is consuming
    // attachableValue, so get around it with an additional do/catch clause.
    do {
      let proxyAttachment = Self(proxyAttachable, named: preferredName, as: contentType, sourceLocation: sourceLocation)
      proxyAttachable.encodedValue = try attachableValue.withUnsafeBufferPointer(for: proxyAttachment) { buffer in
        [UInt8](buffer)
      }
    } catch {
      Issue.withErrorRecording(at: sourceLocation) {
        throw error
      }
    }

    self.init(proxyAttachable, named: preferredName, as: contentType, sourceLocation: sourceLocation)
  }

  /// Initialize an instance of this type that encloses the given attachable
  /// value.
  ///
  /// - Parameters:
  ///   - attachableValue: The value that will be attached to the output of
  ///     the test run.
  ///   - preferredName: The preferred name of the attachment when writing it
  ///     to a test report or to disk. If `nil`, the testing library attempts
  ///     to derive a reasonable filename for the attached value.
  ///   - sourceLocation: The source location of the attachment.
  ///
  /// When attaching a value of a type that does not conform to both `Sendable`
  /// and `Copyable`, the testing library encodes it as data immediately. If the
  /// value cannot be encoded and an error is thrown, that error is recorded as
  /// an issue in the current test and the resulting instance of
  /// ``Test/Attachment`` is empty.
  @_disfavoredOverload
  public init(
    _ attachableValue: borrowing some Test.Attachable & ~Copyable,
    named preferredName: String? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    self.init(attachableValue, named: preferredName, as: nil, sourceLocation: sourceLocation)
  }
}

#if !SWT_NO_FILE_IO
// MARK: - Writing

extension Test.Attachment {
  /// Write the attachment's contents to a file in the specified directory.
  ///
  /// - Parameters:
  ///   - directoryPath: The directory that should contain the attachment when
  ///     written.
  ///
  /// - Throws: Any error preventing writing the attachment.
  ///
  /// The attachment is written to a file _within_ `directoryPath`, whose name
  /// is derived from the value of the ``Test/Attachment/preferredName``
  /// property.
  func write(toFileInDirectoryAtPath directoryPath: String) throws {
    let preferredName = preferredName
    var preferredPath = appendPathComponent(preferredName, to: directoryPath)

    // Very naïve algorithm to find a filename that doesn't exist. This could be
    // subject to race conditions, but the odds of two threads independently
    // producing the same 64-bit random number are low enough that we can ignore
    // them for now. (TODO: better file-naming algorithm.)
    while fileExists(atPath: preferredPath) {
      preferredPath = appendPathComponent("\(UInt64.random(in: 0 ..< .max))-\(preferredName)", to: directoryPath)
    }

    try attachableValue.withUnsafeBufferPointer(for: self) { buffer in
      let file = try FileHandle(forWritingAtPath: preferredPath)
      try file.write(buffer)
    }
  }
}
#endif

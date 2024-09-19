//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if SWT_TARGET_OS_APPLE && canImport(UniformTypeIdentifiers)
@_spi(Experimental) public import Testing
public import UniformTypeIdentifiers

@_spi(Experimental)
@available(_uttypesAPI, *)
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
  public init(
    _ attachableValue: some Test.Attachable & Sendable & Copyable,
    named preferredName: String? = nil,
    as contentType: UTType,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    self.init(attachableValue, named: preferredName, as: contentType as any Sendable, sourceLocation: sourceLocation)
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
  ///   - contentType: The content type of the attached value, if applicable and
  ///     known to the caller.
  ///   - sourceLocation: The source location of the attachment.
  ///
  /// When attaching a value of a type that does not conform to `Sendable`, the
  /// testing library encodes it as data immediately. If the value cannot be
  /// encoded and an error is thrown, that error is recorded as an issue in the
  /// current test and the resulting instance of ``Testing/Test/Attachment`` is
  /// empty.
  @_disfavoredOverload
  public init(
    _ attachableValue: borrowing some Test.Attachable & ~Copyable,
    named preferredName: String? = nil,
    as contentType: UTType,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    self.init(attachableValue, named: preferredName, as: contentType as any Sendable, sourceLocation: sourceLocation)
  }
}

@_spi(Experimental)
@available(_uttypesAPI, *)
extension Test.Attachment {
  /// The content type of the attachment, if known.
  ///
  /// If the value of this property was not provided during initialization and
  /// was not subsequently set, the testing library makes a best effort to
  /// determine the type of the data represented by this value. If no better
  /// type is available for this attachment, the value of this property will be
  /// [`UTType.data`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/data).
  ///
  /// If you set the value of this property to a new type, the value of this
  /// instance's ``preferredName`` property may be updated to include a path
  /// extension that matches the new type.
  public var contentType: UTType {
    get {
      if let mediaType = _contentType as? String, let contentType = UTType(mimeType: mediaType) {
        return contentType
      }
      return _contentType as? UTType ?? .data
    }
    set {
      let oldValue = _contentType as? UTType
      _contentType = newValue
      if oldValue != newValue {
        self.update()
      }
    }
  }
}
#endif

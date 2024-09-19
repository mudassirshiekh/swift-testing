//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(Experimental)
extension Test {
  /// A protocol describing a type that can be attached to a test report or
  /// written to disk when a test is run.
  ///
  /// TODO: write more about this protocol, how it works, and list the types
  /// that conform to it (including discussion of the Foundation cross-module
  /// overlay.)
  ///
  /// To attach an attachable value to a test report or test run output, use it
  /// to initialize a new instance of ``Test/Attachment``, then call
  /// ``Test/Attachment/attach()``. An attachment can only be attached once.
  ///
  /// Generally speaking, you should not need to make new types conform to this
  /// protocol.
  public protocol Attachable: ~Copyable {
    /// A filename to use when writing this attachment to a test report or to a
    /// file on disk.
    ///
    /// The value of this property is used as a hint to the testing library. The
    /// default implementation returns `nil`.
    ///
    /// Do not get the value of this property directly. Use
    /// ``Test/Attachment/preferredName`` instead.
    var _attachmentPreferredName: String? { get }

    /// An instance of `UTType` representing the content type of this attachable
    /// value or an instance of `String` representing its media type.
    ///
    /// The value of this property is used as a hint to the testing library. The
    /// default implementation returns `nil`.
    ///
    /// Do not get the value of this property directly. On Apple platforms,
    /// import the [UniformTypeIdentifiers](https://developer.apple.com/documentation/uniformtypeidentifiers)
    /// module and use ``Test/Attachment/contentType`` instead. On other
    /// platforms, use the ``Test/Attachment/mediaType`` property instead.
    var _attachmentContentType: (any Sendable)? { get }

    /// Call a function and pass a buffer representing this instance to it.
    ///
    /// - Parameters:
    ///   - attachment: The attachment that is requesting a buffer (that is, the
    ///     attachment containing this instance.)
    ///   - body: A function to call. A temporary buffer containing a data
    ///     representation of this instance is passed to it.
    ///
    /// - Returns: Whatever is returned by `body`.
    ///
    /// - Throws: Whatever is thrown by `body`, or any error that prevented the
    ///   creation of the buffer.
    ///
    /// The testing library uses this function when writing an attachment to a
    /// test report or to a file on disk. The format of the buffer is
    /// implementation-defined, but should be "idiomatic" for this type: for
    /// example, if this type represents an image, it would be appropriate for
    /// the buffer to contain an image in PNG format, JPEG format, etc., but it
    /// would not be idiomatic for the buffer to contain a textual description
    /// of the image.
    borrowing func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R
  }
}

// MARK: - Default implementations

extension Test.Attachable where Self: ~Copyable {
  public var _attachmentPreferredName: String? {
    nil
  }

  public var _attachmentContentType: (any Sendable)? {
    nil
  }
}

// Implement the protocol requirements for byte arrays and buffers so that
// developers can attach raw data when needed.
@_spi(Experimental)
extension [UInt8]: Test.Attachable {
  public func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try withUnsafeBytes(body)
  }
}

@_spi(Experimental)
extension UnsafeBufferPointer<UInt8>: Test.Attachable {
  public func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try body(.init(self))
  }
}

@_spi(Experimental)
extension UnsafeRawBufferPointer: Test.Attachable {
  public func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try body(self)
  }
}

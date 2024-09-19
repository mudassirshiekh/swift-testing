//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if SWT_TARGET_OS_APPLE && canImport(CoreGraphics)
@_spi(Experimental) public import Testing
import CoreGraphics

public import UniformTypeIdentifiers
@_spi(Experimental) private import _Testing_UniformTypeIdentifiers

@_spi(Experimental)
@available(_uttypesAPI, *)
extension Test.Attachment {
  /// Initialize an instance of this type that encloses the given image.
  ///
  /// - Parameters:
  ///   - attachableValue: The value that will be attached to the output of
  ///     the test run.
  ///   - preferredName: The preferred name of the attachment when writing it
  ///     to a test report or to disk. If `nil`, the testing library attempts
  ///     to derive a reasonable filename for the attached value.
  ///   - contentType: The image format with which to encode `attachableValue`.
  ///     If this type does not conform to [`UTType.image`](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/image),
  ///     the result is undefined. Pass `nil` to let the testing library decide
  ///     which image format to use.
  ///   - encodingQuality: The encoding quality to use when encoding the image.
  ///     If the image format used for encoding (specified by the `contentType`
  ///     argument) does not support variable-quality encoding, the value of
  ///     this argument is ignored.
  ///   - sourceLocation: The source location of the attachment.
  public init(
    _ attachableValue: some Test.AttachableImage,
    named preferredName: String? = nil,
    as contentType: UTType?,
    encodingQuality: Float = 1.0,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    let contentType = contentType ?? attachableValue.preferredContentType(forEncodingQuality: encodingQuality)
    self.init(
      AttachableImage(image: attachableValue, encodingQuality: encodingQuality),
      named: preferredName,
      as: contentType,
      sourceLocation: sourceLocation
    )
  }

  /// Initialize an instance of this type that encloses the given image.
  ///
  /// - Parameters:
  ///   - attachableValue: The value that will be attached to the output of
  ///     the test run.
  ///   - preferredName: The preferred name of the attachment when writing it
  ///     to a test report or to disk. If `nil`, the testing library attempts
  ///     to derive a reasonable filename for the attached value.
  ///   - encodingQuality: The encoding quality to use when encoding the image.
  ///     If the image format used for encoding (specified by the `contentType`
  ///     argument) does not support variable-quality encoding, the value of
  ///     this argument is ignored.
  ///   - sourceLocation: The source location of the attachment.
  public init(
    _ attachableValue: some Test.AttachableImage,
    named preferredName: String? = nil,
    encodingQuality: Float = 1.0,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    self.init(
      attachableValue,
      named: preferredName,
      as: nil,
      encodingQuality: encodingQuality,
      sourceLocation: sourceLocation
    )
  }
}
#endif

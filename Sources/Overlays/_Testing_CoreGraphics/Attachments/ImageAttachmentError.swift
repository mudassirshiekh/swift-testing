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
import UniformTypeIdentifiers

/// A type representing errors that can occur when attaching an image.
@available(_uttypesAPI, *)
enum ImageAttachmentError: Error, CustomStringConvertible {
  /// The specified content type did not conform to `.image`.
  ///
  /// - Parameters:
  ///   - contentType: The content type to convert the image to.
  case contentTypeDoesNotConformToImage(_ contentType: UTType)

  /// The image could not be converted to an instance of `CGImage`.
  case couldNotCreateCGImage

  /// The image destination could not be created.
  ///
  /// - Parameters:
  ///   - contentType: The content type to convert the image to.
  case couldNotCreateImageDestination(_ contentType: UTType)

  /// The image could not be converted.
  ///
  /// - Parameters:
  ///   - contentType: The content type to convert the image to.
  case couldNotConvertImage(_ contentType: UTType)

  var description: String {
    switch self {
    case let .contentTypeDoesNotConformToImage(contentType):
      "The type '\(contentType.localizedDescription ?? contentType.identifier)' does not represent an image type."
    case .couldNotCreateCGImage:
      "Could not create the corresponding Core Graphics image."
    case let .couldNotCreateImageDestination(contentType):
      "Could not create the Core Graphics image destination to encode this image as '\(contentType.localizedDescription ?? contentType.identifier)'."
    case let .couldNotConvertImage(contentType):
      "Could not convert the image to '\(contentType.localizedDescription ?? contentType.identifier)'."
    }
  }
}
#endif

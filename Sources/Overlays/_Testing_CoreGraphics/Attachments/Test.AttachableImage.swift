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
public import CoreGraphics

private import ImageIO
import UniformTypeIdentifiers
@_spi(Experimental) private import _Testing_UniformTypeIdentifiers

@_spi(Experimental)
@available(_uttypesAPI, *)
extension Test {
  /// A protocol describing images that can be converted to instances of
  /// ``Testing/Test/Attachment``.
  ///
  /// The following system-provided image types conform to this protocol and can
  /// be attached to a test:
  ///
  /// - [`CGImage`](https://developer.apple.com/documentation/coregraphics/cgimage)
  /// - [`CIImage`](https://developer.apple.com/documentation/coreimage/ciimage)
  /// - [`NSImage`](https://developer.apple.com/documentation/appkit/nsimage)
  ///   (macOS)
  /// - [`UIImage`](https://developer.apple.com/documentation/uikit/uiimage)
  ///   (iOS, watchOS, tvOS, visionOS, and Mac Catalyst)
  /// - [`XCUIScreenshot`](https://developer.apple.com/documentation/xctest/xcuiscreenshot)
  ///
  /// You do not need to add your own conformances to this protocol. If you have
  /// an image in another format that needs to be attached to a test, first
  /// convert it to an instance of one of the types above.
  public protocol AttachableImage: Test.Attachable {
    /// An instance of `CGImage` representing this image, or `nil` if one could
    /// not be created.
    ///
    /// This property is not part of the public interface of the testing
    /// library.
    var _attachableCGImage: CGImage? { get }

    /// The orientation of the image.
    ///
    /// The value of this property is the raw value of an instance of
    /// `CGImagePropertyOrientation`. The default value of this property is
    /// `.up`.
    ///
    /// This property is not part of the public interface of the testing
    /// library.
    var _attachmentOrientation: UInt32 { get }
  }
}

@_spi(Experimental)
@available(_uttypesAPI, *)
extension Test.AttachableImage {
  public var _attachmentOrientation: UInt32 {
    CGImagePropertyOrientation.up.rawValue
  }

  /// Determine the preferred content type to encode this image as for a given
  /// encoding quality.
  ///
  /// - Parameters:
  ///   - encodingQuality: The encoding quality to use when encoding the image.
  ///
  /// - Returns: The type to encode this image as.
  func preferredContentType(forEncodingQuality encodingQuality: Float) -> UTType {
    // If the caller wants lossy encoding, use JPEG.
    if encodingQuality < 1.0 {
      return .jpeg
    }

    // Lossless encoding implies PNG.
    return .png
  }

  /// Determine the content type to encode this image as.
  ///
  /// - Parameters:
  ///   - attachment: The attachment that is encoding the image.
  ///   - encodingQuality: The encoding quality to use when encoding the image.
  ///
  /// - Returns: The type to encode this image as.
  private func _contentType(for attachment: borrowing Test.Attachment, withEncodingQuality encodingQuality: Float) throws -> UTType {
    // If the caller specified an image type, use that type. If it's .data (no
    // path extension present), we'll fall back to either JPEG or PNG below.
    let contentType = attachment.contentType
    if contentType != .data {
      guard contentType.conforms(to: .image) else {
        throw ImageAttachmentError.contentTypeDoesNotConformToImage(contentType)
      }
      return contentType
    }

    return preferredContentType(forEncodingQuality: encodingQuality)
  }

  public func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    let data = NSMutableData()

    // Get the encoding quality to use.
    var encodingQuality = Float(1.0)
    if let imageWrapper = attachment.attachableValue as? AttachableImage<Self> {
      encodingQuality = imageWrapper.encodingQuality
    }

    // Get the type to encode as.
    let contentType = try _contentType(for: attachment, withEncodingQuality: encodingQuality)

    // Convert the image to a CGImage.
    guard let _attachableCGImage else {
      throw ImageAttachmentError.couldNotCreateCGImage
    }

    // Create the image destination.
    let typeIdentifier = contentType.identifier
    guard let dest = CGImageDestinationCreateWithData(data as CFMutableData, typeIdentifier as CFString, 1, nil) else {
      throw ImageAttachmentError.couldNotCreateImageDestination(contentType)
    }

    // Perform the image conversion.
    let properties: [String: Any] = [
      kCGImageDestinationLossyCompressionQuality as String: CGFloat(encodingQuality),
      kCGImagePropertyOrientation as String: UInt32(_attachmentOrientation),
    ]
    CGImageDestinationAddImage(dest, _attachableCGImage, properties as CFDictionary)
    guard CGImageDestinationFinalize(dest) else {
      throw ImageAttachmentError.couldNotConvertImage(contentType)
    }

    // Pass the bits of the image out to the body. Note that we have an
    // NSMutableData here so we have to use slightly different API than we would
    // with an instance of Data.
    return try withExtendedLifetime(data) {
      try body(UnsafeRawBufferPointer(start: data.bytes, count: data.length))
    }
  }
}
#endif

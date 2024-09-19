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
@_spi(Experimental) import Testing
import CoreGraphics

/// A wrapper type for image types such as `CGImage` and `NSImage` that can be
/// attached indirectly.
@available(_uttypesAPI, *)
struct AttachableImage<T>: Test.Attachable, Sendable where T: Test.AttachableImage {
  /// The underlying image.
  nonisolated(unsafe) var image: T

  /// The encoding quality to use when encoding `image`.
  var encodingQuality: Float

  init(image: T, encodingQuality: Float) {
    /// `CGImage` and `UIImage` are sendable, but `NSImage` is not. `NSImage`
    /// instances can be created from closures that are run at rendering time.
    /// Strictly speaking, we should render `NSImage` instances up front, but in
    /// the majority of cases it won't be an issue. So we'll defensively copy
    /// `NSImage` here which will also help us avoid any concurrent mutation.
    if let image = image as? NSObject,
       image.responds(to: Selector("copyWithZone:" as String)),
       let imageCopy = image.copy() as? T {
      self.image = imageCopy
    } else {
      self.image = image
    }
    self.encodingQuality = encodingQuality
  }

  func withUnsafeBufferPointer<R>(for attachment: borrowing Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    try image.withUnsafeBufferPointer(for: attachment, body)
  }
}
#endif

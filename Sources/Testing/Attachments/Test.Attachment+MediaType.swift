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

extension Test.Attachment {
  // MARK: - Upcalls to the UniformTypeIdentifiers overlay

#if SWT_TARGET_OS_APPLE && canImport(UniformTypeIdentifiers)
  /// A function defined in the UniformTypeIdentifiers cross-module overlay
  /// that gets the preferred media type from an attachment's content type.
  private static let _copyMediaType = symbol(named: "swt_uttype_copyMediaType").map {
    unsafeBitCast($0, to: (@Sendable @convention(c) (_ attachmentAddress: UnsafeRawPointer) -> UnsafeMutablePointer<CChar>?).self)
  }

  /// A function defined in the UniformTypeIdentifiers cross-module overlay that
  /// updates an instance of ``Test/Attachment``.
  private static let _updateAttachment = symbol(named: "swt_uttype_updateAttachment").map {
    unsafeBitCast($0, to: (@Sendable @convention(c) (UnsafeMutableRawPointer) -> Void).self)
  }
#endif

  // MARK: -

  /// The media type (MIME type) of the attachment, if known.
  ///
  /// The testing library makes a best effort to determine the type of the
  /// data represented by an instance of ``Attachable``. If no better type is
  /// available for this attachment, the value of this property will be
  /// `"application/octet-stream"`.
  ///
  /// If you set the value of this property to a new type, the value of this
  /// instance's ``preferredName`` property may be updated to include a path
  /// extension that matches the new type.
  ///
  /// On Apple platforms, when you import the [UniformTypeIdentifiers](https://developer.apple.com/documentation/uniformtypeidentifiers)
  /// module, you can also use the ``contentType`` property to represent the
  /// type of an attachment.
  public var mediaType: String {
    get {
      if let mediaType = _contentType as? String {
        return mediaType
      }
#if SWT_TARGET_OS_APPLE && canImport(UniformTypeIdentifiers)
      if let copyMediaType = Self._copyMediaType {
        let mediaType = withUnsafePointer(to: self) { `self` in
          let mediaType = copyMediaType(self)
          defer {
            free(mediaType)
          }
          return mediaType.flatMap { String(validatingCString: $0) }
        }
        if let mediaType {
          return mediaType
        }
      }
#endif
      return "application/octet-stream"
    }
    set {
      _contentType = newValue
      self.update()
    }
  }

  /// Update the properties of this instance, for instance by changing its
  /// ``preferredName`` property to match its ``contentType`` property.
  mutating func update() {
#if SWT_TARGET_OS_APPLE && canImport(UniformTypeIdentifiers)
    if let updateAttachment = Self._updateAttachment {
      // Ask the cross-import overlay to provide additional/better metadata.
      return withUnsafeMutablePointer(to: &self) { `self` in
        updateAttachment(self)
      }
    }
#endif

    // If we reach this point, UniformTypeIdentifiers isn't linked in (or just
    // isn't available on this platform!)
    // TODO: use platform-specific API if available to reconcile preferredName and mediaType
  }
}


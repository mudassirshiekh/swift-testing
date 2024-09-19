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
@_spi(Experimental) import Testing
import UniformTypeIdentifiers

extension Test.Attachment {
  /// Update the properties of this instance by attempting to resolve its
  /// content type and an appropriate preferred name.
  ///
  /// When linked into the current process, the `update()` function in the
  /// testing library calls this one.
  @available(_uttypesAPI, *)
  mutating func update() {
    // First, check if the attachment has a media type set. If so, try to turn
    // it into a declared UTType.
    if let mediaType = _contentType as? String, let contentType = UTType(mimeType: mediaType), contentType.isDeclared {
      _contentType = contentType
    }

    // Next check for a path extension on the attachment's preferred name.
    if _contentType == nil {
      let pathExtension = (preferredName as NSString).pathExtension
      if !pathExtension.isEmpty, let contentType = UTType(filenameExtension: pathExtension), contentType.isDeclared {
        _contentType = contentType
      }
    }

    // Finally, check if the attachable value's type has a preferred content
    // type and use that. We save this for last so it doesn't override explicit
    // values set by the developer.
    if _contentType == nil, let attachableContentType = attachableValue._attachmentContentType {
      _contentType = attachableContentType
    }

    // Regardless of whether we had to derive a new content type above or if we
    // already had one, if we have one *now*, make sure the filename has an
    // appropriate path extension.
    if let contentType = _contentType as? UTType, contentType != .data {
      preferredName = (preferredName as NSString).appendingPathExtension(for: contentType)
    }
  }
}

// MARK: - Exported C symbols

/// A C entry point corresponding to ``Testing/Test/Attachment/update()``.
///
/// - Parameters:
///   - attachmentAddress: The address of an instance of
///     ``Testing/Test/Attachment`` to update. It is modified in place.
///
/// - Warning: This function is used to implement ``Testing/Test/Attachment``.
///   Do not call it directly.
@available(_uttypesAPI, *)
@_cdecl("swt_uttype_updateAttachment")
@usableFromInline func updateAttachment(_ attachmentAddress: UnsafeMutableRawPointer) {
  let attachmentAddress = attachmentAddress.assumingMemoryBound(to: Test.Attachment.self)
  attachmentAddress.pointee.update()
}

/// A C entry point to get the media type of an attachment based on its content
/// type.
///
/// - Parameters:
///   - attachmentAddress: The address of an instance of
///     ``Testing/Test/Attachment`` to read from.
///
/// - Returns: The best available media type for the content type of the
///   attachment, or `nil` if one was not available. The caller is responsible
///   for freeing this C string.
///
/// - Warning: This function is used to implement ``Testing/Test/Attachment``.
///   Do not call it directly.
@available(_uttypesAPI, *)
@_cdecl("swt_uttype_copyMediaType")
@usableFromInline func getMediaType(for attachmentAddress: UnsafeRawPointer) -> UnsafeMutablePointer<CChar>? {
  let attachmentAddress = attachmentAddress.assumingMemoryBound(to: Test.Attachment.self)
  if let contentType = attachmentAddress.pointee._contentType as? UTType, let mediaType = contentType.preferredMIMEType {
    return strdup(mediaType)
  }
  return nil
}
#endif

//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if SWT_TARGET_OS_APPLE && canImport(CoreImage)
public import CoreImage
@_exported @_spi(Experimental) public import _Testing_CoreGraphics

@_spi(Experimental)
@available(_uttypesAPI, *)
extension CIImage: Test.AttachableImage {
  public var _attachableCGImage: CGImage? {
    CIContext().createCGImage(self, from: extent)
  }
}
#endif

//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

#if SWT_TARGET_OS_APPLE && canImport(UIKit)
public import UIKit
@_exported @_spi(Experimental) public import _Testing_CoreGraphics
private import ImageIO
private import CoreImage

@_spi(Experimental)
@available(_uttypesAPI, *)
extension UIImage: Test.AttachableImage {
  public var _attachableCGImage: CGImage? {
    if let cgImage {
      return cgImage
    } else if let ciImage {
      return CIContext().createCGImage(ciImage, from: ciImage.extent)
    }
    return nil
  }

  public var _attachmentOrientation: UInt32 {
    let result: CGImagePropertyOrientation = switch imageOrientation {
    case .up: .up
    case .down: .down
    case .left: .left
    case .right: .right
    case .upMirrored: .upMirrored
    case .downMirrored: .downMirrored
    case .leftMirrored: .leftMirrored
    case .rightMirrored: .rightMirrored
    }
    return result.rawValue
  }
}
#endif

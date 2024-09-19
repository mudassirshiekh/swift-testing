//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing
#if canImport(Foundation)
import Foundation
@_spi(Experimental) import _Testing_Foundation
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
@_spi(Experimental) import _Testing_UniformTypeIdentifiers
#endif
#if canImport(AppKit)
import AppKit
@_spi(Experimental) import _Testing_AppKit
#endif
#if canImport(UIKit)
import UIKit
@_spi(Experimental) import _Testing_UIKit
#endif
#if canImport(CoreImage)
import CoreImage
@_spi(Experimental) import _Testing_CoreImage
#endif
#if SWT_TARGET_OS_APPLE && canImport(XCTest)
import XCTest
@_spi(Experimental) import _Testing_XCUIAutomation
#endif

@Suite("Attachment Tests")
struct AttachmentTests {
  @Test func saveValue() {
    let attachableValue = MyAttachable(string: "<!doctype html>")
    Test.Attachment(attachableValue, named: "loremipsum").attach()
  }

  @Test func attachValue() async {
    await confirmation("Attachment detected") { valueAttached in
      await Test {
        let attachableValue = MyAttachable(string: "<!doctype html>")
        Test.Attachment(attachableValue, named: "loremipsum").attach()
      }.run { event, _ in
        guard case let .valueAttached(attachment) = event.kind else {
          return
        }

        #expect(attachment.preferredName == "loremipsum")
        valueAttached()
      }
    }
  }

  @Test func attachSendableValue() async {
    await confirmation("Attachment detected") { valueAttached in
      await Test {
        let attachableValue = MySendableAttachable(string: "<!doctype html>")
        Test.Attachment(attachableValue, named: "loremipsum").attach()
      }.run { event, _ in
        guard case let .valueAttached(attachment) = event.kind else {
          return
        }

        #expect(attachment.preferredName == "loremipsum")
        valueAttached()
      }
    }
  }

#if canImport(UniformTypeIdentifiers)
  @Test func getAndSetContentType() async {
    let attachableValue = MySendableAttachable(string: "")
    var attachment = Test.Attachment(attachableValue, named: "loremipsum")

    // Get the default (should just be raw bytes at this point.)
    #expect(attachment.contentType == .data)

    // Switch to a UTType and confirm it stuck.
    attachment.contentType = .pdf
    #expect(attachment.contentType == .pdf)
    #expect(attachment.preferredName == "loremipsum.pdf")

    // Convert it to a different UTType.
    attachment.contentType = .jpeg
    #expect(attachment.contentType == .jpeg)
    #expect(attachment.preferredName == "loremipsum.pdf.jpeg")
  }
#endif

#if canImport(Foundation)
  @Test func attachData() async throws {
    let data = try #require("<!doctype html>".data(using: .utf8))
    await confirmation("Attachment detected") { valueAttached in
      await Test {
        Test.Attachment(data, named: "loremipsum").attach()
      }.run { event, _ in
        guard case let .valueAttached(attachment) = event.kind else {
          return
        }

        #expect(attachment.preferredName == "loremipsum")
        valueAttached()
      }
    }
  }

  @Test func attachContentsOfFileURL() async throws {
    let data = try #require("<!doctype html>".data(using: .utf8))
    let temporaryFileName = "\(UUID().uuidString).html"
    let temporaryPath = try appendPathComponent(temporaryFileName, to: temporaryDirectory())
    let temporaryURL = URL(fileURLWithPath: temporaryPath, isDirectory: false)
    try data.write(to: temporaryURL)

    await confirmation("Attachment detected") { valueAttached in
      await Test {
        let attachment = try await Test.Attachment(contentsOf: temporaryURL)
        attachment.attach()
      }.run { event, _ in
        guard case let .valueAttached(attachment) = event.kind else {
          return
        }

        #expect(attachment.preferredName == temporaryFileName)
        #expect(throws: Never.self) {
          try attachment.attachableValue.withUnsafeBufferPointer(for: attachment) { buffer in
            #expect(buffer.count == data.count)
          }
        }
        valueAttached()
      }
    }
  }

  @Test func attachContentsOfDirectoryURL() async throws {
    let temporaryFileName = UUID().uuidString
    let temporaryPath = try appendPathComponent(temporaryFileName, to: temporaryDirectory())
    let temporaryURL = URL(fileURLWithPath: temporaryPath, isDirectory: false)
    try FileManager.default.createDirectory(at: temporaryURL, withIntermediateDirectories: true)

    await confirmation("Attachment detected") { valueAttached in
      await Test {
        let attachment = try await Test.Attachment(contentsOf: temporaryURL)
        attachment.attach()
      }.run { event, _ in
        guard case let .valueAttached(attachment) = event.kind else {
          return
        }

        #expect(attachment.preferredName == "\(temporaryFileName).tar.gz")
        valueAttached()
      }
    }
  }

  @Test func attachUnsupportedContentsOfURL() async throws {
    let url = try #require(URL(string: "https://www.example.com"))
    await #expect(throws: CocoaError.self) {
      _ = try await Test.Attachment(contentsOf: url)
    }
  }

  @available(_uttypesAPI, *)
  struct CodableAttachmentArguments: Sendable, CustomTestArgumentEncodable, CustomTestStringConvertible {
    var forSecureCoding: Bool
    var contentType: (any Sendable)?
    var pathExtension: String?
    var firstCharacter: Character
    var decode: @Sendable (Data) throws -> String

    @Sendable static func decodeWithJSONDecoder(_ data: Data) throws -> String {
      try JSONDecoder().decode(MyCodableAttachable.self, from: data).string
    }

    @Sendable static func decodeWithPropertyListDecoder(_ data: Data) throws -> String {
      try PropertyListDecoder().decode(MyCodableAttachable.self, from: data).string
    }

    @Sendable static func decodeWithNSKeyedUnarchiver(_ data: Data) throws -> String {
      let result = try NSKeyedUnarchiver.unarchivedObject(ofClass: MySecureCodingAttachable.self, from: data)
      return try #require(result).string
    }

    static func all() -> [Self] {
      var result = [Self]()

      for forSecureCoding in [false, true] {
        let decode = forSecureCoding ? decodeWithNSKeyedUnarchiver : decodeWithPropertyListDecoder
        result += [
          Self(
            forSecureCoding: forSecureCoding,
            firstCharacter: forSecureCoding ? "b" : "{",
            decode: forSecureCoding ? decodeWithNSKeyedUnarchiver : decodeWithJSONDecoder
          )
        ]

        result += [
          Self(forSecureCoding: forSecureCoding, pathExtension: "xml", firstCharacter: "<", decode: decode),
          Self(forSecureCoding: forSecureCoding, pathExtension: "plist", firstCharacter: "b", decode: decode),
        ]

        if !forSecureCoding {
          result += [
            Self(forSecureCoding: forSecureCoding, pathExtension: "json", firstCharacter: "{", decode: decodeWithJSONDecoder),
          ]
        }
      }

      return result
    }

    func encodeTestArgument(to encoder: some Encoder) throws {
      var container = encoder.unkeyedContainer()
      try container.encode(pathExtension)
      try container.encode(forSecureCoding)
      try container.encode(firstCharacter.asciiValue!)
    }

    var testDescription: String {
      "(forSecureCoding: \(forSecureCoding), contentType: \(String(describingForTest: contentType)))"
    }
  }

  @available(_uttypesAPI, *)
  @Test("Attach Codable- and NSSecureCoding-conformant values", .serialized, arguments: CodableAttachmentArguments.all())
  func attachCodable(args: CodableAttachmentArguments) async throws {
    var name = "loremipsum"
    if let ext = args.pathExtension {
      name = "\(name).\(ext)"
    }

    var attachment: Test.Attachment
    if args.forSecureCoding {
      let attachableValue = MySecureCodingAttachable(string: "stringly speaking")
      attachment = Test.Attachment(attachableValue, named: name)
    } else {
      let attachableValue = MyCodableAttachable(string: "stringly speaking")
      attachment = Test.Attachment(attachableValue, named: name)
    }

    try attachment.attachableValue.withUnsafeBufferPointer(for: attachment) { bytes in
      #expect(bytes.first == args.firstCharacter.asciiValue)
      let decodedStringValue = try args.decode(Data(bytes))
      #expect(decodedStringValue == "stringly speaking")
    }
  }

  @available(_uttypesAPI, *)
  @Test("Attach NSSecureCoding-conformant value but with a JSON type")
  func attachNSSecureCodingAsJSON() async throws {
    let attachableValue = MySecureCodingAttachable(string: "stringly speaking")
    let attachment = Test.Attachment(attachableValue, named: "loremipsum.json")
    #expect(throws: CocoaError.self) {
      try attachment.attachableValue.withUnsafeBufferPointer(for: attachment) { _ in }
    }
  }

  @available(_uttypesAPI, *)
  @Test("Attach NSSecureCoding-conformant value but with a nonsensical type")
  func attachNSSecureCodingAsNonsensical() async throws {
    let attachableValue = MySecureCodingAttachable(string: "stringly speaking")
    let attachment = Test.Attachment(attachableValue, named: "loremipsum.gif")
    #expect(throws: CocoaError.self) {
      try attachment.attachableValue.withUnsafeBufferPointer(for: attachment) { _ in }
    }
  }
#endif

#if canImport(UniformTypeIdentifiers)
  @available(_uttypesAPI, *)
  @Test func attachValueWithUTType() async {
    await confirmation("Attachment detected") { valueAttached in
      await Test {
        let attachableValue = MyAttachable(string: "<!doctype html>")
        Test.Attachment(attachableValue, named: "loremipsum", as: .plainText).attach()
      }.run { event, _ in
        guard case let .valueAttached(attachment) = event.kind else {
          return
        }

        #expect(attachment.preferredName == "loremipsum.txt")
        valueAttached()
      }
    }
  }

  @available(_uttypesAPI, *)
  @Test func attachSendableValueWithUTType() async {
    await confirmation("Attachment detected") { valueAttached in
      await Test {
        let attachableValue = MySendableAttachable(string: "<!doctype html>")
        Test.Attachment(attachableValue, named: "loremipsum", as: .plainText).attach()
      }.run { event, _ in
        guard case let .valueAttached(attachment) = event.kind else {
          return
        }

        #expect(attachment.preferredName == "loremipsum.txt")
        valueAttached()
      }
    }
  }

  @available(_uttypesAPI, *)
  @Test func changingContentType() {
    // Explicitly passing a type modifies the preferred name. Note it's expected
    // that we preserve the original extension as this is the behavior of the
    // underlying UTType API (tries to be non-destructive to user input.)
    do {
      let attachableValue = MySendableAttachable(string: "<!doctype html>")
      let attachment = Test.Attachment(attachableValue, named: "loremipsum.txt", as: .html)
      #expect(attachment.preferredName == "loremipsum.txt.html")
    }
  }
#endif

#if canImport(AppKit) || canImport(UIKit)
#if canImport(AppKit)
  static var platformImage: NSImage {
    get throws {
      try #require(NSImage(systemSymbolName: "checkmark.diamond.fill", accessibilityDescription: nil))
    }
  }
#elseif canImport(UIKit)
  static var platformImage: UIImage {
    get throws {
      try #require(UIImage(systemName: "checkmark.diamond.fill"))
    }
  }
#endif

  static var cgImage: CGImage {
    get throws {
      let platformImage = try platformImage
      return try #require(platformImage._attachableCGImage)
    }
  }

  @available(_uttypesAPI, *)
  @Test func attachCGImage() throws {
    let attachment = Test.Attachment(try Self.cgImage, named: "diamond.jpg")
    try attachment.attachableValue.withUnsafeBufferPointer(for: attachment) { buffer in
      #expect(buffer.count > 32)
    }
  }

  @available(_uttypesAPI, *)
  @Test(arguments: [Float(0.0).nextUp, 0.25, 0.5, 0.75, 1.0], [.png as UTType?, .jpeg, .gif, .image, .data, nil])
  func attachCGImage(quality: Float, type: UTType?) throws {
    let attachment = Test.Attachment(try Self.cgImage, named: "diamond", as: type, encodingQuality: quality)
    try attachment.attachableValue.withUnsafeBufferPointer(for: attachment) { buffer in
      #expect(buffer.count > 32)
    }
  }

#if canImport(CoreImage)
  @available(_uttypesAPI, *)
  @Test(arguments: [Float(0.0).nextUp, 0.25, 0.5, 0.75, 1.0], [.png as UTType?, .jpeg, .gif, .image, .data, nil])
  func attachCIImage(quality: Float, type: UTType?) throws {
    let image = CIImage(cgImage: try Self.cgImage)
    let attachment = Test.Attachment(image, named: "diamond", as: type, encodingQuality: quality)
    try attachment.attachableValue.withUnsafeBufferPointer(for: attachment) { buffer in
      #expect(buffer.count > 32)
    }
  }
#endif

#if SWT_TARGET_OS_APPLE && canImport(XCTest)
  @MainActor func emptyScreenshot() -> XCUIScreenshot {
    XCUIScreenshot.perform(Selector("emptyScreenshot" as String)).takeUnretainedValue() as! XCUIScreenshot
  }

  @available(_uttypesAPI, *)
  @Test(arguments: [Float(0.0).nextUp, 0.25, 0.5, 0.75, 1.0], [.png as UTType?, .jpeg, .gif, .image, .data, nil])
  func attachXCUIScreenshot(quality: Float, type: UTType?) async throws {
    let screenshot = await emptyScreenshot()
    let attachment = Test.Attachment(screenshot, named: "diamond", as: type, encodingQuality: quality)
    try attachment.attachableValue.withUnsafeBufferPointer(for: attachment) { buffer in
      #expect(buffer.count > 32)
    }
  }
#endif

  @available(_uttypesAPI, *)
  @Test func cannotAttachImageWithNonImageType() async {
    #expect(throws: (any Error).self) {
      let attachment = Test.Attachment(try Self.cgImage, named: "diamond", as: .mp3)
      try attachment.attachableValue.withUnsafeBufferPointer(for: attachment) { _ in }
    }
  }
#endif
}

// MARK: - Fixtures

struct MyAttachable: Test.Attachable, ~Copyable {
  var string: String

  func withUnsafeBufferPointer<R>(for attachment: borrowing Testing.Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    var string = string
    return try string.withUTF8 { buffer in
      try body(.init(buffer))
    }
  }
}

@available(*, unavailable)
extension MyAttachable: Sendable {}

struct MySendableAttachable: Test.Attachable, Sendable {
  var string: String

  func withUnsafeBufferPointer<R>(for attachment: borrowing Testing.Test.Attachment, _ body: (UnsafeRawBufferPointer) throws -> R) throws -> R {
    var string = string
    return try string.withUTF8 { buffer in
      try body(.init(buffer))
    }
  }
}

#if canImport(Foundation)
struct MyCodableAttachable: Codable, Test.Attachable, Sendable {
  var string: String
}

final class MySecureCodingAttachable: NSObject, NSSecureCoding, Test.Attachable, Sendable {
  let string: String

  init(string: String) {
    self.string = string
  }

  static var supportsSecureCoding: Bool {
    true
  }

  func encode(with coder: NSCoder) {
    coder.encode(string, forKey: "string")
  }

  required init?(coder: NSCoder) {
    string = (coder.decodeObject(of: NSString.self, forKey: "string") as? String) ?? ""
  }
}
#endif

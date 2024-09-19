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

  @Test func getAndSetMediaType() async {
    let attachableValue = MySendableAttachable(string: "")
    var attachment = Test.Attachment(attachableValue)

    // Get the default (should just be raw bytes at this point.)
    #expect(attachment.mediaType == "application/octet-stream")
#if canImport(UniformTypeIdentifiers)
    #expect(attachment.contentType == .data)
#endif

#if canImport(UniformTypeIdentifiers)
    // Switch to a UTType and confirm it stuck.
    attachment.contentType = .pdf
    #expect(attachment.mediaType == "application/pdf")
    #expect(attachment.contentType == .pdf)
#endif

    // Convert it back to a media type and confirm it stuck.
    attachment.mediaType = "image/jpeg"
    #expect(attachment.mediaType == "image/jpeg")
#if canImport(UniformTypeIdentifiers)
    #expect(attachment.contentType == .jpeg)
#endif
  }

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
#if canImport(UniformTypeIdentifiers)
        #expect(attachment.contentType == .html)
        #expect(attachment.mediaType == "text/html")
#endif
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
#if canImport(UniformTypeIdentifiers)
        #expect(attachment.contentType.conforms(to: .gzip))
#endif
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
        result += [
          Self(
            forSecureCoding: forSecureCoding,
            firstCharacter: forSecureCoding ? "b" : "{",
            decode: forSecureCoding ? decodeWithNSKeyedUnarchiver : decodeWithJSONDecoder
          )
        ]

        let decode = forSecureCoding ? decodeWithNSKeyedUnarchiver : decodeWithPropertyListDecoder
#if canImport(UniformTypeIdentifiers)
        result += [
          Self(forSecureCoding: forSecureCoding, contentType: UTType.xml, firstCharacter: "<", decode: decode),
          Self(forSecureCoding: forSecureCoding, contentType: UTType.xmlPropertyList, firstCharacter: "<", decode: decode),
          Self(forSecureCoding: forSecureCoding, contentType: UTType.propertyList, firstCharacter: "b", decode: decode),
          Self(forSecureCoding: forSecureCoding, contentType: UTType.binaryPropertyList, firstCharacter: "b", decode: decode),
        ]

        if forSecureCoding {
          result += [
            Self(forSecureCoding: forSecureCoding, contentType: UTType.data, firstCharacter: "b", decode: decode),
          ]
        } else {
          result += [
            Self(forSecureCoding: forSecureCoding, contentType: UTType.data, firstCharacter: "{", decode: decodeWithJSONDecoder),
            Self(forSecureCoding: forSecureCoding, contentType: UTType.json, firstCharacter: "{", decode: decodeWithJSONDecoder),
          ]
        }
#endif

        result += [
          Self(forSecureCoding: forSecureCoding, contentType: "application/xml", firstCharacter: "<", decode: decode),
          Self(forSecureCoding: forSecureCoding, contentType: "text/xml", firstCharacter: "<", decode: decode),
        ]

        if forSecureCoding {
          result += [
            Self(forSecureCoding: forSecureCoding, contentType: "application/octet-stream", firstCharacter: "b", decode: decode),
          ]
        } else {
          result += [
            Self(forSecureCoding: forSecureCoding, contentType: "application/octet-stream", firstCharacter: "{", decode: decodeWithJSONDecoder),
            Self(forSecureCoding: forSecureCoding, contentType: "application/json", firstCharacter: "{", decode: decodeWithJSONDecoder),
          ]
        }

        result += [
          Self(forSecureCoding: forSecureCoding, pathExtension: "xml", firstCharacter: "<", decode: decode),
          Self(forSecureCoding: forSecureCoding, pathExtension: "plist", firstCharacter: "b", decode: decode),
        ]

        if forSecureCoding {
          result += [
            Self(forSecureCoding: forSecureCoding, pathExtension: "", firstCharacter: "b", decode: decode),
          ]
        } else {
          result += [
            Self(forSecureCoding: forSecureCoding, pathExtension: "", firstCharacter: "{", decode: decodeWithJSONDecoder),
            Self(forSecureCoding: forSecureCoding, pathExtension: "json", firstCharacter: "{", decode: decodeWithJSONDecoder),
          ]
        }
      }

      return result
    }

    func encodeTestArgument(to encoder: some Encoder) throws {
      var container = encoder.unkeyedContainer()
#if canImport(UniformTypeIdentifiers)
      if let contentType = contentType as? UTType {
        try container.encode(contentType)
      }
#endif
      if let mediaType = contentType as? String {
        try container.encode(mediaType)
      }
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
    if let ext = args.pathExtension, !ext.isEmpty {
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

#if canImport(UniformTypeIdentifiers)
    if let contentType = args.contentType as? UTType {
      attachment._contentType = contentType
    }
#endif
    if let mediaType = args.contentType as? String {
      attachment.mediaType = mediaType
    }
    if args.contentType == nil {
      attachment._contentType = nil
    }

    try attachment.attachableValue.withUnsafeBufferPointer(for: attachment) { bytes in
      #expect(bytes.first == args.firstCharacter.asciiValue)
      let decodedStringValue = try args.decode(Data(bytes))
      #expect(decodedStringValue == "stringly speaking")
    }
  }

#if canImport(UniformTypeIdentifiers)
  @available(_uttypesAPI, *)
  @Test("Attach NSSecureCoding-conformant value but with OpenStep plist format")
  func attachNSSecureCodingAsOpenStep() async throws {
    let attachableValue = MySecureCodingAttachable(string: "stringly speaking")
    var attachment = Test.Attachment(attachableValue, named: "loremipsum")
    attachment.contentType = try #require(UTType("com.apple.ascii-property-list"))

    #expect(throws: (any Error).self) {
      try attachment.attachableValue.withUnsafeBufferPointer(for: attachment) { _ in }
    }
  }
#endif

  @available(_uttypesAPI, *)
  @Test("Attach NSSecureCoding-conformant value but with a JSON type")
  func attachNSSecureCodingAsJSON() async throws {
    let attachableValue = MySecureCodingAttachable(string: "stringly speaking")
    var attachment = Test.Attachment(attachableValue, named: "loremipsum")
#if canImport(UniformTypeIdentifiers)
    attachment.contentType = .json
#else
    attachment.mediaType = "application/json"
#endif

    #expect(throws: CocoaError.self) {
      try attachment.attachableValue.withUnsafeBufferPointer(for: attachment) { _ in }
    }
  }

  @available(_uttypesAPI, *)
  @Test("Attach NSSecureCoding-conformant value but with a nonsensical type")
  func attachNSSecureCodingAsNonsensical() async throws {
    let attachableValue = MySecureCodingAttachable(string: "stringly speaking")
    var attachment = Test.Attachment(attachableValue, named: "loremipsum")
#if canImport(UniformTypeIdentifiers)
    attachment.contentType = .gif
#else
    attachment.mediaType = "image/gif"
#endif

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
        #expect(attachment.contentType == .plainText)
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
        #expect(attachment.contentType == .plainText)
        valueAttached()
      }
    }
  }

  @available(_uttypesAPI, *)
  @Test func defaultContentType() {
    let attachableValue = MySendableAttachable(string: "")
    let attachment = Test.Attachment(attachableValue)
    #expect(attachment._contentType == nil)
    #expect(attachment.contentType == .data)
  }

  @available(_uttypesAPI, *)
  @Test func changingContentType() {
    let attachableValue = MySendableAttachable(string: "<!doctype html>")
    var attachment = Test.Attachment(attachableValue, named: "loremipsum", as: .plainText)
    #expect(attachment.preferredName == "loremipsum.txt")
    #expect(attachment.contentType == .plainText)

    // Setting to a different type updates the preferred name. Note it's
    // expected that we preserve the original extension as this is the behavior
    // of the underlying UTType API (tries to be non-destructive to user input.)
    attachment.contentType = .html
    #expect(attachment.preferredName == "loremipsum.txt.html")
    #expect(attachment.contentType == .html)

    // Clearing doesn't affect anything.
    attachment._contentType = nil
    #expect(attachment.preferredName == "loremipsum.txt.html")
    #expect(attachment.contentType == .data)
  }

  @available(_uttypesAPI, *)
  @Test func extensionDecidesContentTypeWhenPresent() {
    let attachableValue = MySendableAttachable(string: "<!doctype html>")
    var attachment = Test.Attachment(attachableValue, named: "loremipsum.jpg")
    #expect(attachment.preferredName == "loremipsum.jpg")
    #expect(attachment.contentType == .jpeg)

    // Clearing doesn't affect anything and setting back to the previous type
    // also doesn't affect the preferred name.
    attachment._contentType = nil
    attachment.contentType = .jpeg
    #expect(attachment.preferredName == "loremipsum.jpg")
    #expect(attachment.contentType == .jpeg)
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

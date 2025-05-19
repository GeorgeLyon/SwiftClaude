import Foundation
import Testing

@testable import JSONSupport

@Suite
private struct JSONSupportTests {

  @Test
  func basicTests() async throws {
    var byteBuffer = JSON.ByteBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// Complete string
    byteBuffer.append(
      """
      Hello, World!"
      """
    )
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "Hello, World!")
    byteBuffer.reset()
    stringBuffer.reset()

    /// Partial string
    byteBuffer.append("Hello")
    byteBuffer.append(", ")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    /// Trailing space is omitted because the last character can be modified by subsequent characters.
    #expect(stringBuffer.stringValue == "Hello,")
    byteBuffer.append("World!")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    /// Exclamation mark is omitted because the last character can be modified by subsequent characters, but the space after the comma is returned now.
    #expect(stringBuffer.stringValue == "Hello, World")
    byteBuffer.append("\"")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "Hello, World!")
  }

  @Test
  func emptyStringTest() async throws {
    var byteBuffer = JSON.ByteBuffer()
    var stringBuffer = JSON.StringBuffer()

    byteBuffer.append("\"")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "")
  }

  @Test
  func internationalCharactersTest() async throws {
    var byteBuffer = JSON.ByteBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// Non-ASCII UTF-8 characters
    byteBuffer.append("こんにちは世界\"")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "こんにちは世界")

    byteBuffer.reset()
    stringBuffer.reset()

    /// Incremental non-ASCII parsing
    byteBuffer.append("こんに")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "こん")
    byteBuffer.append("ちは世界\"")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "こんにちは世界")
  }

  @Test
  func basicEscapeSequencesTest() async throws {
    var byteBuffer = JSON.ByteBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// Double quote escape
    byteBuffer.append("\\\"\"")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "\"")

    byteBuffer.reset()
    stringBuffer.reset()

    /// Backslash escape
    byteBuffer.append("\\\\\"")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "\\")

    byteBuffer.reset()
    stringBuffer.reset()

    /// Forward slash escape
    byteBuffer.append("\\/\"")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "/")
  }

  @Test
  func controlCharactersTest() async throws {
    var byteBuffer = JSON.ByteBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// Newline
    byteBuffer.append("\\n\"")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "\n")

    byteBuffer.reset()
    stringBuffer.reset()

    /// Tab
    byteBuffer.append("\\t\"")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "\t")

    byteBuffer.reset()
    stringBuffer.reset()

    /// Mixed control characters
    byteBuffer.append("Line 1\\nLine 2\\tTabbed\"")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "Line 1\nLine 2\tTabbed")
  }

  @Test
  func unsupportedEscapeCharactersTest() async throws {
    var byteBuffer = JSON.ByteBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// Unsupported \b
    byteBuffer.append("\\b\"")
    #expect(throws: Error.self) {
      try byteBuffer.readStringFragment(into: &stringBuffer)
    }
    byteBuffer.reset()
    stringBuffer.reset()

    /// Unsupported \r
    byteBuffer.append("\\r\"")
    #expect(throws: Error.self) {
      try byteBuffer.readStringFragment(into: &stringBuffer)
    }
    byteBuffer.reset()
    stringBuffer.reset()

    /// Unsupported \f
    byteBuffer.append("\\f\"")
    #expect(throws: Error.self) {
      try byteBuffer.readStringFragment(into: &stringBuffer)
    }
    byteBuffer.reset()
    stringBuffer.reset()
  }

  @Test
  func invalidEscapeSequencesTest() async throws {
    var byteBuffer = JSON.ByteBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// Invalid escape \z
    byteBuffer.append("\\z\"")
    #expect(throws: Error.self) {
      try byteBuffer.readStringFragment(into: &stringBuffer)
    }
    byteBuffer.reset()
    stringBuffer.reset()
  }

  @Test
  func unicodeEscapeSequencesTest() async throws {
    var byteBuffer = JSON.ByteBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// Basic unicode escape
    byteBuffer.append("\\u0041\"")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "A")

    byteBuffer.reset()
    stringBuffer.reset()

    /// Non-ASCII unicode escape
    byteBuffer.append("\\u00A9\"")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "©")

    byteBuffer.reset()
    stringBuffer.reset()

    /// Mixed regular and unicode-escaped characters
    byteBuffer.append("Copyright \\u00A9 2025\"")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "Copyright © 2025")
  }

  @Test
  func invalidUnicodeEscapeSequencesTest() async throws {
    var byteBuffer = JSON.ByteBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// Non-hex characters
    byteBuffer.append("\\u0XYZ\"")
    #expect(throws: Error.self) {
      try byteBuffer.readStringFragment(into: &stringBuffer)
    }
    byteBuffer.reset()
    stringBuffer.reset()
  }

  @Test
  func surrogatePairsTest() async throws {
    var byteBuffer = JSON.ByteBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// Valid surrogate pair for 😀 (U+1F600)
    byteBuffer.append("\\uD83D\\uDE00\"")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "😀")

    byteBuffer.reset()
    stringBuffer.reset()

    /// Incremental surrogate pair parsing
    byteBuffer.append("\\uD83D")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "")  // Nothing to return yet
    byteBuffer.append("\\uDE00\"")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "😀")
  }

  @Test
  func invalidSurrogatePairsTest() async throws {
    var byteBuffer = JSON.ByteBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// High surrogate without low surrogate
    byteBuffer.append("\\uD83D\"")
    #expect(throws: Error.self) {
      try byteBuffer.readStringFragment(into: &stringBuffer)
    }
    byteBuffer.reset()
    stringBuffer.reset()

    byteBuffer.reset()
    stringBuffer.reset()

    /// Low surrogate without high surrogate
    byteBuffer.append("\\uDE00\"")
    #expect(throws: Error.self) {
      try byteBuffer.readStringFragment(into: &stringBuffer)
    }
    byteBuffer.reset()
    stringBuffer.reset()

    /// Malformed surrogate pair
    byteBuffer.append("\\uD83DX\"")
    #expect(throws: Error.self) {
      try byteBuffer.readStringFragment(into: &stringBuffer)
    }
    byteBuffer.reset()
    stringBuffer.reset()
  }

  @Test
  func edgeCasesTest() async throws {
    var byteBuffer = JSON.ByteBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// Null character
    byteBuffer.append("\\u0000\"")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "\0")
    byteBuffer.reset()
    stringBuffer.reset()

    /// String with mixed escapes and regular characters
    byteBuffer.append("Hello\\tWorld\\nNew\\\"Line\\\\Path\"")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "Hello\tWorld\nNew\"Line\\Path")
  }

  @Test
  func incrementalParsingTest() async throws {
    var byteBuffer = JSON.ByteBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// String with escape sequence split
    byteBuffer.append("Test\\")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "Tes")  // 't' gets dropped as it could be modified
    byteBuffer.append("n more text\"")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "Test\n more tex")

    byteBuffer.reset()
    stringBuffer.reset()

    /// Unicode escape split across buffers
    byteBuffer.append("\\u00")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "")  // Nothing complete yet
    byteBuffer.append("A9 copyright\"")
    try byteBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "© copyrigh")
  }
}

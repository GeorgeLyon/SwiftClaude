import Foundation
import Testing

@testable import JSONSupport

@Suite
private struct StringTests {

  @Test
  func basicTests() async throws {
    var scalarBuffer = JSON.UnicodeScalarBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// Complete string
    scalarBuffer.push(
      """
      Hello, World!"
      """
    )
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "Hello, World!")
    scalarBuffer.reset()
    stringBuffer.reset()

    /// Partial string
    scalarBuffer.push("Hello")
    scalarBuffer.push(", ")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    /// Trailing space is omitted because the last character can be modified by subsequent characters.
    #expect(stringBuffer.stringValue == "Hello,")
    scalarBuffer.push("World!")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    /// Exclamation mark is omitted because the last character can be modified by subsequent characters, but the space after the comma is returned now.
    #expect(stringBuffer.stringValue == "Hello, World")
    scalarBuffer.push("\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "Hello, World!")
  }

  @Test
  func emptyStringTest() async throws {
    var scalarBuffer = JSON.UnicodeScalarBuffer()
    var stringBuffer = JSON.StringBuffer()

    scalarBuffer.push("\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "")
  }

  @Test
  func internationalCharactersTest() async throws {
    var scalarBuffer = JSON.UnicodeScalarBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// Non-ASCII UTF-8 characters
    scalarBuffer.push("こんにちは世界\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "こんにちは世界")

    scalarBuffer.reset()
    stringBuffer.reset()

    /// Incremental non-ASCII parsing
    scalarBuffer.push("こんに")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "こん")
    scalarBuffer.push("ちは世界\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "こんにちは世界")
  }

  @Test
  func basicEscapeSequencesTest() async throws {
    var scalarBuffer = JSON.UnicodeScalarBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// Double quote escape
    scalarBuffer.push("\\\"\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "\"")

    scalarBuffer.reset()
    stringBuffer.reset()

    /// Backslash escape
    scalarBuffer.push("\\\\\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "\\")

    scalarBuffer.reset()
    stringBuffer.reset()

    /// Forward slash escape
    scalarBuffer.push("\\/\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "/")
  }

  @Test
  func controlCharactersTest() async throws {
    var scalarBuffer = JSON.UnicodeScalarBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// Newline
    scalarBuffer.push("\\n\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "\n")
    scalarBuffer.reset()
    stringBuffer.reset()

    /// Tab
    scalarBuffer.push("\\t\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "\t")
    scalarBuffer.reset()
    stringBuffer.reset()

    /// Carriage return
    scalarBuffer.push("\\r\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "\r")
    scalarBuffer.reset()
    stringBuffer.reset()

    /// Mixed control characters
    scalarBuffer.push("Line 1\\nLine 2\\tTabbed\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "Line 1\nLine 2\tTabbed")
  }

  @Test
  func unsupportedEscapeCharactersTest() async throws {
    var scalarBuffer = JSON.UnicodeScalarBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// Unsupported \b
    scalarBuffer.push("\\b\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "�")
    scalarBuffer.reset()
    stringBuffer.reset()

    /// Unsupported \f
    scalarBuffer.push("\\f\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "�")
    scalarBuffer.reset()
    stringBuffer.reset()
  }

  @Test
  func invalidEscapeSequencesTest() async throws {
    var scalarBuffer = JSON.UnicodeScalarBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// Invalid escape \z
    scalarBuffer.push("\\z\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "�")
    scalarBuffer.reset()
    stringBuffer.reset()
  }

  @Test
  func unicodeEscapeSequencesTest() async throws {
    var scalarBuffer = JSON.UnicodeScalarBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// Basic unicode escape
    scalarBuffer.push("\\u0041\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "A")
    scalarBuffer.reset()
    stringBuffer.reset()

    /// Non-ASCII unicode escape
    scalarBuffer.push("\\u00A9\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "©")
    scalarBuffer.reset()
    stringBuffer.reset()

    /// Non-ASCII unicode escape (lowercase letters)
    scalarBuffer.push("\\u00a9\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "©")
    scalarBuffer.reset()
    stringBuffer.reset()

    /// Mixed regular and unicode-escaped characters
    scalarBuffer.push("Copyright \\u00A9 2025\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "Copyright © 2025")
  }

  @Test
  func invalidUnicodeEscapeSequencesTest() async throws {
    var scalarBuffer = JSON.UnicodeScalarBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// Non-hex characters
    scalarBuffer.push("\\u0XYZ\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "�XYZ")
    scalarBuffer.reset()
    stringBuffer.reset()
  }

  @Test
  func surrogatePairsTest() async throws {
    var scalarBuffer = JSON.UnicodeScalarBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// Valid surrogate pair for 😀 (U+1F600)
    scalarBuffer.push("\\uD83D\\uDE00\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "😀")
    scalarBuffer.reset()
    stringBuffer.reset()

    /// Incremental surrogate pair parsing
    scalarBuffer.push("\\uD83D")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "")  // Nothing to return yet
    scalarBuffer.push("\\uDE00\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "😀")
  }

  @Test
  func invalidSurrogatePairsTest() async throws {
    var scalarBuffer = JSON.UnicodeScalarBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// High surrogate without low surrogate, but incomplete
    scalarBuffer.push("\\uD83D")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "")  // Waiting on the low surrogate
    scalarBuffer.reset()
    stringBuffer.reset()

    scalarBuffer.reset()
    stringBuffer.reset()

    /// Low surrogate without high surrogate
    scalarBuffer.push("\\uDE00\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "�")
    scalarBuffer.reset()
    stringBuffer.reset()

    /// High surrogate without low surrogate
    scalarBuffer.push("\\uD83D🥸")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "��")
    scalarBuffer.reset()
    stringBuffer.reset()
  }

  @Test
  func edgeCasesTest() async throws {
    var scalarBuffer = JSON.UnicodeScalarBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// Null character
    scalarBuffer.push("\\u0000\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "\0")
    scalarBuffer.reset()
    stringBuffer.reset()

    /// String with mixed escapes and regular characters
    scalarBuffer.push("Hello\\tWorld\\nNew\\\"Line\\\\Path\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "Hello\tWorld\nNew\"Line\\Path")
  }

  @Test
  func incrementalParsingTest() async throws {
    var scalarBuffer = JSON.UnicodeScalarBuffer()
    var stringBuffer = JSON.StringBuffer()

    /// String with escape sequence split
    scalarBuffer.push("Test\\")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "Tes")  // 't' gets dropped as it could be modified
    scalarBuffer.push("n more text\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "Test\n more text")
    scalarBuffer.reset()
    stringBuffer.reset()

    /// Unicode escape split across buffers
    scalarBuffer.push("\\u00")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "")  // Nothing complete yet
    scalarBuffer.push("A9 copyright\"")
    try scalarBuffer.readStringFragment(into: &stringBuffer)
    #expect(stringBuffer.stringValue == "© copyright")
  }
}

import Foundation
import Testing

@testable import JSONSupport

@Suite
private struct StringTests {

  @Test
  func simpleTest() async throws {
    var stream = JSON.DecodingStream()
    var stringBuffer = JSON.StringBuffer()
    var context = JSON.DecodingContext()

    /// Complete string
    stream.push(
      """
      Hello, World!"
      """
    )
    stream.finish()
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "Hello, World!")
    stream.reset()
    stringBuffer.reset()

    /// Partial string
    stream.push("Hello")
    stream.push(", ")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    /// Trailing space is omitted because the last character can be modified by subsequent characters.
    #expect(stringBuffer.validSubstring == "Hello,")
    stream.push("World!")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    /// Exclamation mark is omitted because the last character can be modified by subsequent characters, but the space after the comma is returned now.
    #expect(stringBuffer.validSubstring == "Hello, World")
    stream.push("\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "Hello, World!")
    /// `"` should be buffered because it may be modified
    #expect(!stringBuffer.isComplete)
    stream.finish()
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.isComplete)
  }

  @Test
  func emptyStringTest() async throws {
    var stream = JSON.DecodingStream()
    var stringBuffer = JSON.StringBuffer()
    var context = JSON.DecodingContext()

    stream.push("\"")
    stream.finish()
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "")
    #expect(stringBuffer.isComplete)
  }

  @Test
  func internationalCharactersTest() async throws {
    var stream = JSON.DecodingStream()
    var stringBuffer = JSON.StringBuffer()
    var context = JSON.DecodingContext()

    /// Non-ASCII UTF-8 characters
    stream.push("こんにちは世界\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "こんにちは世界")

    stream.reset()
    stringBuffer.reset()

    /// Incremental non-ASCII parsing
    stream.push("こんに")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "こん")
    stream.push("ちは世界\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "こんにちは世界")
  }

  @Test
  func basicEscapeSequencesTest() async throws {
    var stream = JSON.DecodingStream()
    var stringBuffer = JSON.StringBuffer()
    var context = JSON.DecodingContext()

    /// Double quote escape
    stream.push("\\\"\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "\"")

    stream.reset()
    stringBuffer.reset()

    /// Backslash escape
    stream.push("\\\\\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "\\")

    stream.reset()
    stringBuffer.reset()

    /// Forward slash escape
    stream.push("\\/\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "/")
  }

  @Test
  func controlCharactersTest() async throws {
    var stream = JSON.DecodingStream()
    var stringBuffer = JSON.StringBuffer()
    var context = JSON.DecodingContext()

    /// Newline
    stream.push("\\n\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "\n")
    stream.reset()
    stringBuffer.reset()

    /// Tab
    stream.push("\\t\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "\t")
    stream.reset()
    stringBuffer.reset()

    /// Carriage return
    stream.push("\\r\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "\r")
    stream.reset()
    stringBuffer.reset()

    /// Mixed control characters
    stream.push("Line 1\\nLine 2\\tTabbed\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "Line 1\nLine 2\tTabbed")
  }

  @Test
  func unsupportedEscapeCharactersTest() async throws {
    var stream = JSON.DecodingStream()
    var stringBuffer = JSON.StringBuffer()
    var context = JSON.DecodingContext()

    /// Unsupported \b
    stream.push("\\b\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "�")
    stream.reset()
    stringBuffer.reset()

    /// Unsupported \f
    stream.push("\\f\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "�")
    stream.reset()
    stringBuffer.reset()
  }

  @Test
  func invalidEscapeSequencesTest() async throws {
    var stream = JSON.DecodingStream()
    var stringBuffer = JSON.StringBuffer()
    var context = JSON.DecodingContext()

    /// Invalid escape character
    stream.push("\\z\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "�")
    stream.reset()
    stringBuffer.reset()

    /// Modified escape character
    stream.push("\\n\u{0301}\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "�")
    stream.reset()
    stringBuffer.reset()
  }

  @Test
  func unicodeEscapeSequencesTest() async throws {
    var stream = JSON.DecodingStream()
    var stringBuffer = JSON.StringBuffer()
    var context = JSON.DecodingContext()

    /// Basic unicode escape
    stream.push("\\u0041\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "A")
    stream.reset()
    stringBuffer.reset()

    /// Non-ASCII unicode escape
    stream.push("\\u00A9\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "©")
    stream.reset()
    stringBuffer.reset()

    /// Non-ASCII unicode escape (lowercase letters)
    stream.push("\\u00a9\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "©")
    stream.reset()
    stringBuffer.reset()

    /// Mixed regular and unicode-escaped characters
    stream.push("Copyright \\u00A9 2025\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "Copyright © 2025")
  }

  @Test
  func invalidUnicodeEscapeSequencesTest() async throws {
    var stream = JSON.DecodingStream()
    var stringBuffer = JSON.StringBuffer()
    var context = JSON.DecodingContext()

    /// Non-hex characters
    stream.push("\\u0XYZ\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "�XYZ")
    stream.reset()
    stringBuffer.reset()
  }

  @Test
  func surrogatePairsTest() async throws {
    var stream = JSON.DecodingStream()
    var stringBuffer = JSON.StringBuffer()
    var context = JSON.DecodingContext()

    /// Valid surrogate pair for 😀 (U+1F600)
    stream.push("\\uD83D\\uDE00\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "😀")
    stream.reset()
    stringBuffer.reset()

    /// Incremental surrogate pair parsing
    stream.push("\\uD83D")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "")  // Nothing to return yet
    stream.push("\\u")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "")  // Nothing to return yet
    stream.push("DE00\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "😀")
  }

  @Test
  func invalidSurrogatePairsTest() async throws {
    var stream = JSON.DecodingStream()
    var stringBuffer = JSON.StringBuffer()
    var context = JSON.DecodingContext()

    /// High surrogate followed by a scalar
    stream.push("\\uD83D\\u00A9\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "�©")  // Waiting on the low surrogate
    stream.reset()
    stringBuffer.reset()

    /// High surrogate followed by a high surrogate
    stream.push("\\uD83D\\uD83D\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "��")
    stream.reset()
    stringBuffer.reset()

    /// High surrogate without low surrogate
    stream.push("\\uD83D🥸\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "�🥸")
    stream.reset()
    stringBuffer.reset()
  }

  @Test
  func edgeCasesTest() async throws {
    var stream = JSON.DecodingStream()
    var stringBuffer = JSON.StringBuffer()
    var context = JSON.DecodingContext()

    /// Null character
    stream.push("\\u0000\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "\0")
    stream.reset()
    stringBuffer.reset()

    /// String with mixed escapes and regular characters
    stream.push("Hello\\tWorld\\nNew\\\"Line\\\\Path\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "Hello\tWorld\nNew\"Line\\Path")
  }

  @Test
  func incrementalParsingTest() async throws {
    var stream = JSON.DecodingStream()
    var stringBuffer = JSON.StringBuffer()
    var context = JSON.DecodingContext()

    /// String with escape sequence split
    stream.push("fac\\")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "fa")  // 'c' gets dropped as it could be modified
    stream.push("u0327ade\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "façade")
    stream.reset()
    stringBuffer.reset()

    /// Unicode escape split across buffers
    stream.push("\\u00")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "")  // Nothing complete yet
    stream.push("A9 copyright\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "© copyright")
  }

  @Test
  func completelyPathalogicalTest() async throws {
    var stream = JSON.DecodingStream()
    var stringBuffer = JSON.StringBuffer()
    var context = JSON.DecodingContext()

    /// String with escape sequence split
    stream.push("\"")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "")
    stream.push("\u{0327}")
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "")
    stream.finish()
    try stream.readStringFragment(into: &stringBuffer, in: &context)
    #expect(stringBuffer.validSubstring == "\"" + "\u{0327}")
    stream.reset()
    stringBuffer.reset()
  }
}

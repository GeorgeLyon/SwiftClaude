import Foundation
import Testing

@testable import JSONSupport

@Suite("String Tests")
private struct StringTests {

  @Test
  func basicTest() async throws {

    /// Complete string
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"Hello, World!\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["Hello, World!"])
      }

      #expect(state.isComplete)
    }

  }

  @Test
  func incrementalParsingTest() async throws {
    /// Partial read
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"Hello, ")

      var state = try stream.decodeStringStart().getValue()

      /// Trailing space is omitted because the last character can be modified by subsequent characters.
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["Hello,"])
      }

      stream.push("World!")
      /// Exclamation mark is omitted because the last character can be modified by subsequent characters, but the space after the comma is returned now.
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == [" World"])
      }

      stream.push("\"")
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["!"])
      }
      #expect(!state.isComplete)

      stream.finish()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == [])
      }
      #expect(state.isComplete)
    }
  }

  @Test
  func emptyStringTest() async throws {
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\"")

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == [])
      }
      #expect(!state.isComplete)

      stream.finish()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == [])
      }
      #expect(state.isComplete)
    }
  }

  @Test
  func internationalCharactersTest() async throws {
    /// Non-ASCII UTF-8 characters
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"こんにちは世界\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["こんにちは世界"])
      }
      #expect(state.isComplete)
    }

    /// Incremental non-ASCII parsing
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"こんに")

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["こん"])
      }

      stream.push("ちは世界\"")
      stream.finish()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["にちは世界"])
      }
      #expect(state.isComplete)
    }
  }

  @Test
  func basicEscapeSequencesTest() async throws {
    /// Double quote escape
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\\"\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["\""])
      }
      #expect(state.isComplete)
    }

    /// Backslash escape
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\\\\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["\\"])
      }
      #expect(state.isComplete)
    }

    /// Forward slash escape
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\/\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["/"])
      }
      #expect(state.isComplete)
    }

    /// Split Escape
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\")

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == [])
      }

      stream.push("\"\"")
      stream.finish()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["\""])
      }
      #expect(state.isComplete)
    }
  }

  @Test
  func controlCharactersTest() async throws {
    /// Newline
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\n\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["\n"])
      }
      #expect(state.isComplete)
    }

    /// Tab
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\t\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["\t"])
      }
      #expect(state.isComplete)
    }

    /// Carriage return
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\r\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["\r"])
      }
      #expect(state.isComplete)
    }

    /// Mixed control characters
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"Line 1\\nLine 2\\tTabbed\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["Line 1", "\n", "Line 2", "\t", "Tabbed"])
      }
      #expect(state.isComplete)
    }
  }

  @Test
  func unsupportedEscapeCharactersTest() async throws {
    /// Unsupported \b
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\b\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�"])
      }
      #expect(state.isComplete)
    }

    /// Unsupported \f
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\f\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�"])
      }
      #expect(state.isComplete)
    }
  }

  @Test
  func invalidEscapeSequencesTest() async throws {
    /// Invalid escape character
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\z\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�"])
      }
      #expect(state.isComplete)
    }

    /// Modified escape character
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\n\u{0301}\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�"])
      }
      #expect(state.isComplete)
    }
  }

  @Test
  func unicodeEscapeSequencesTest() async throws {
    /// Basic unicode escape
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\u0041\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["A"])
      }
      #expect(state.isComplete)
    }

    /// Non-ASCII unicode escape
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\u00A9\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["©"])
      }
      #expect(state.isComplete)
    }

    /// Non-ASCII unicode escape (lowercase letters)
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\u00a9\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["©"])
      }
      #expect(state.isComplete)
    }

    /// Mixed regular and unicode-escaped characters
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"Copyright \\u00A9 2025\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["Copyright ", "©", " 2025"])
      }
      #expect(state.isComplete)
    }
  }

  @Test
  func invalidUnicodeEscapeSequencesTest() async throws {
    /// Non-hex characters
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\u0XYZ\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�", "0XYZ"])
      }
      #expect(state.isComplete)
    }
  }

  @Test
  func surrogatePairsTest() async throws {
    /// Valid surrogate pair for 😀 (U+1F600)
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\uD83D\\uDE00\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["😀"])
      }
      #expect(state.isComplete)
    }

    /// Incremental surrogate pair parsing
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\uD83D")

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == [])
      }

      stream.push("\\u")
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == [])
      }

      stream.push("DE00\"")
      stream.finish()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["😀"])
      }
      #expect(state.isComplete)
    }
  }

  @Test
  func invalidSurrogatePairsTest() async throws {
    /// High surrogate followed by a scalar
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\uD83D\\u00A9\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�", "©"])  // Waiting on the low surrogate
      }
      #expect(state.isComplete)
    }

    /// High surrogate followed by a high surrogate
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\uD83D\\uD83D\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["��"])
      }
      #expect(state.isComplete)
    }

    /// High surrogate without low surrogate
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\uD83D🥸\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�", "🥸"])
      }
      #expect(state.isComplete)
    }

    /// High surrogate followed by a different escape sequence
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\uD83D\\n\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�", "\n"])
      }
      #expect(state.isComplete)
    }
  }

  @Test
  func edgeCasesTest() async throws {
    /// Null character
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\u0000\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["\0"])
      }
      #expect(state.isComplete)
    }

    /// String with mixed escapes and regular characters
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"Hello\\tWorld\\nNew\\\"Line\\\\Path\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["Hello", "\t", "World", "\n", "New", "\"", "Line", "\\", "Path"])
      }
      #expect(state.isComplete)
    }
  }

  @Test
  func incrementalParsingTest2() async throws {
    /// String with escape sequence split
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"fac\\")

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        /// 'c' gets dropped as it could be modified
        #expect($0 == ["fa"])
      }

      stream.push("u0327ade\"")
      stream.finish()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["c", "\u{0327}", "ade"])
        #expect($0.joined() == "çade")
      }
      #expect(state.isComplete)
    }

    /// Unicode escape split across buffers
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\u00")

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == [])
      }

      stream.push("A9 copyright\"")
      stream.finish()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["©", " copyright"])
      }
      #expect(state.isComplete)
    }
  }

  @Test
  func completelyPathalogicalTest() async throws {
    /// String with escape sequence split
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\"")

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == [])
      }

      stream.push("\u{0327}\"")
      stream.finish()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["\"" + "\u{0327}"])
      }

      #expect(state.isComplete)
    }
  }

  @Test
  func whitespaceBeforeOpeningQuoteTest() async throws {
    /// Single space before opening quote
    do {
      var stream = JSON.DecodingStream()
      stream.push(" \"Hello\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["Hello"])
      }
      #expect(state.isComplete)
    }

    /// Multiple spaces before opening quote
    do {
      var stream = JSON.DecodingStream()
      stream.push("   \"World\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["World"])
      }
      #expect(state.isComplete)
    }

    /// Tab before opening quote
    do {
      var stream = JSON.DecodingStream()
      stream.push("\t\"Tab\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["Tab"])
      }
      #expect(state.isComplete)
    }

    /// Newline before opening quote
    do {
      var stream = JSON.DecodingStream()
      stream.push("\n\"Newline\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["Newline"])
      }
      #expect(state.isComplete)
    }

    /// Mixed whitespace before opening quote
    do {
      var stream = JSON.DecodingStream()
      stream.push(" \t\n\"Mixed\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["Mixed"])
      }
      #expect(state.isComplete)
    }

    /// Incremental whitespace parsing
    do {
      var stream = JSON.DecodingStream()
      stream.push("  ")

      // Can't decode string start until we have the opening quote
      #expect(throws: Error.self) {
        _ = try stream.decodeStringStart().getValue()
      }

      stream.push("\"Incremental\"")
      stream.finish()

      var state = try stream.decodeStringStart().getValue()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["Incremental"])
      }
      #expect(state.isComplete)
    }
  }

}

// MARK: - Support

extension JSON.DecodingStream {

  /// Takes a closure since Swift Testing doesn't currently support non-copyable type in `#expect` expressions.
  mutating func withDecodedStringFragments(
    state: inout JSON.StringDecodingState,
    _ body: ([String]) -> Void
  ) throws {
    var fragments: [String] = []
    _ = try decodeStringFragments(state: &state) { decoded in
      fragments.append(String(decoded))
    }
    body(fragments)
  }

}

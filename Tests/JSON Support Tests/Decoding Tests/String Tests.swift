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

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["Hello, World!"])
      }

      #expect(result.isComplete)
    }

  }

  @Test
  func incrementalParsingTest() async throws {
    /// Partial read
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"Hello, ")

      var state = JSON.StringDecodingState()

      /// Trailing space is omitted because the last character can be modified by subsequent characters.
      var result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["Hello,"])
      }

      stream.push("World!")
      /// Exclamation mark is omitted because the last character can be modified by subsequent characters, but the space after the comma is returned now.
      result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == [" World"])
      }

      stream.push("\"")
      result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["!"])
      }
      #expect(!result.isComplete)

      stream.finish()
      result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == [])
      }
      #expect(result.isComplete)
    }
  }

  @Test
  func emptyStringTest() async throws {
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\"")

      var state = JSON.StringDecodingState()
      var result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == [])
      }
      #expect(!result.isComplete)

      stream.finish()
      result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == [])
      }
      #expect(result.isComplete)
    }
  }

  @Test
  func internationalCharactersTest() async throws {
    /// Non-ASCII UTF-8 characters
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"こんにちは世界\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["こんにちは世界"])
      }
      #expect(result.isComplete)
    }

    /// Incremental non-ASCII parsing
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"こんに")

      var state = JSON.StringDecodingState()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["こん"])
      }

      stream.push("ちは世界\"")
      stream.finish()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["にちは世界"])
      }
      #expect(result.isComplete)
    }
  }

  @Test
  func basicEscapeSequencesTest() async throws {
    /// Double quote escape
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\\"\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["\""])
      }
      #expect(result.isComplete)
    }

    /// Backslash escape
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\\\\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["\\"])
      }
      #expect(result.isComplete)
    }

    /// Forward slash escape
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\/\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["/"])
      }
      #expect(result.isComplete)
    }

    /// Split Escape
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\")

      var state = JSON.StringDecodingState()
      var result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == [])
      }

      stream.push("\"\"")
      stream.finish()
      result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["\""])
      }
      #expect(result.isComplete)
    }
  }

  @Test
  func controlCharactersTest() async throws {
    /// Newline
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\n\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["\n"])
      }
      #expect(result.isComplete)
    }

    /// Tab
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\t\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["\t"])
      }
      #expect(result.isComplete)
    }

    /// Carriage return
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\r\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["\r"])
      }
      #expect(result.isComplete)
    }

    /// Mixed control characters
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"Line 1\\nLine 2\\tTabbed\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["Line 1", "\n", "Line 2", "\t", "Tabbed"])
      }
      #expect(result.isComplete)
    }
  }

  @Test
  func unsupportedEscapeCharactersTest() async throws {
    /// Unsupported \b
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\b\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�"])
      }
      #expect(result.isComplete)
    }

    /// Unsupported \f
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\f\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�"])
      }
      #expect(result.isComplete)
    }
  }

  @Test
  func invalidEscapeSequencesTest() async throws {
    /// Invalid escape character
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\z\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�"])
      }
      #expect(result.isComplete)
    }

    /// Modified escape character
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\n\u{0301}\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�"])
      }
      #expect(result.isComplete)
    }
  }

  @Test
  func unicodeEscapeSequencesTest() async throws {
    /// Basic unicode escape
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\u0041\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["A"])
      }
      #expect(result.isComplete)
    }

    /// Non-ASCII unicode escape
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\u00A9\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["©"])
      }
      #expect(result.isComplete)
    }

    /// Non-ASCII unicode escape (lowercase letters)
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\u00a9\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["©"])
      }
      #expect(result.isComplete)
    }

    /// Mixed regular and unicode-escaped characters
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"Copyright \\u00A9 2025\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["Copyright ", "©", " 2025"])
      }
      #expect(result.isComplete)
    }
  }

  @Test
  func invalidUnicodeEscapeSequencesTest() async throws {
    /// Non-hex characters
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\u0XYZ\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�", "0XYZ"])
      }
      #expect(result.isComplete)
    }
  }

  @Test
  func surrogatePairsTest() async throws {
    /// Valid surrogate pair for 😀 (U+1F600)
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\uD83D\\uDE00\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["😀"])
      }
      #expect(result.isComplete)
    }

    /// Incremental surrogate pair parsing
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\uD83D")

      var state = JSON.StringDecodingState()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == [])
      }

      stream.push("\\u")
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == [])
      }

      stream.push("DE00\"")
      stream.finish()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["😀"])
      }
      #expect(result.isComplete)
    }
  }

  @Test
  func invalidSurrogatePairsTest() async throws {
    /// High surrogate followed by a scalar
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\uD83D\\u00A9\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�", "©"])  // Waiting on the low surrogate
      }
      #expect(result.isComplete)
    }

    /// High surrogate followed by a high surrogate
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\uD83D\\uD83D\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�", "�"])
      }
      #expect(result.isComplete)
    }

    /// High surrogate without low surrogate
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\uD83D🥸\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�", "🥸"])
      }
      #expect(result.isComplete)
    }

    /// High surrogate followed by a different escape sequence
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\uD83D\\n\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�", "\n"])
      }
      #expect(result.isComplete)
    }

    /// HIgh surrogate followed by a valid surrogate pair
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\uD83D\\uD83D\\uDE00\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�", "😀"])
      }
      #expect(result.isComplete)
    }
  }

  @Test
  func edgeCasesTest() async throws {
    /// Null character
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\u0000\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["\0"])
      }
      #expect(result.isComplete)
    }

    /// String with mixed escapes and regular characters
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"Hello\\tWorld\\nNew\\\"Line\\\\Path\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["Hello", "\t", "World", "\n", "New", "\"", "Line", "\\", "Path"])
      }
      #expect(result.isComplete)
    }
  }

  @Test
  func incrementalParsingTest2() async throws {
    /// String with escape sequence split
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"fac\\")

      var state = JSON.StringDecodingState()
      try stream.withDecodedStringFragments(state: &state) {
        /// 'c' gets dropped as it could be modified
        #expect($0 == ["fa"])
      }

      stream.push("u0327ade\"")
      stream.finish()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["c", "\u{0327}", "ade"])
        #expect($0.joined() == "çade")
      }
      #expect(result.isComplete)
    }

    /// Unicode escape split across buffers
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\u00")

      var state = JSON.StringDecodingState()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == [])
      }

      stream.push("A9 copyright\"")
      stream.finish()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["©", " copyright"])
      }
      #expect(result.isComplete)
    }
  }

  @Test
  func endQuoteWithCombiningDiacritic() async throws {
    /// End quote with combining diacritic
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\"")

      var state = JSON.StringDecodingState()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == [])
      }

      stream.push("\u{0327}\"")
      stream.finish()

      #expect(throws: Error.self) {
        try stream.withDecodedStringFragments(state: &state) {
          #expect($0 == ["\"" + "\u{0327}"])
        }
      }
    }
  }

  @Test
  func additionalSurrogatePairEdgeCasesTest() async throws {
    /// Low surrogate without high surrogate
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\uDE00\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�"])
      }
      #expect(result.isComplete)
    }

    /// Low surrogate at start of string
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\uDE00Hello\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�", "Hello"])
      }
      #expect(result.isComplete)
    }

    /// Multiple invalid surrogates
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\uDE00\\uDE01\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�", "�"])
      }
      #expect(result.isComplete)
    }

    /// High surrogate at end of string (no low surrogate)
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"Hello\\uD83D\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["Hello", "�"])
      }
      #expect(result.isComplete)
    }
  }

  @Test
  func incompleteUnicodeEscapeSequencesTest() async throws {
    /// Unicode escape with only 1 hex digit
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\u0\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�", "0"])
      }
      #expect(result.isComplete)
    }

    /// Unicode escape with only 2 hex digits
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\u00\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�", "00"])
      }
      #expect(result.isComplete)
    }

    /// Unicode escape with only 3 hex digits
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\u004\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�", "004"])
      }
      #expect(result.isComplete)
    }

    /// Unicode escape cut off at \\u
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\u\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["�"])
      }
      #expect(result.isComplete)
    }
  }

  @Test
  func escapeSequenceEdgeCasesTest() async throws {
    /// Incomplete escape at end of string
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"test\\")

      var state = JSON.StringDecodingState()
      try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["tes"])  // 't' is dropped because it could be part of escape
      }

      stream.push("n\"")
      stream.finish()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["t", "\n"])
      }
      #expect(result.isComplete)
    }

    /// Multiple consecutive escapes
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\\\\\\\\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["\\", "\\"])
      }
      #expect(result.isComplete)
    }

    /// Escape followed by unicode escape
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\n\\u0041\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["\n", "A"])
      }
      #expect(result.isComplete)
    }

    /// Unicode escape followed by regular escape
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\u0041\\n\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["A", "\n"])
      }
      #expect(result.isComplete)
    }
  }

  @Test
  func whitespaceBeforeOpeningQuoteTest() async throws {
    /// Single space before opening quote
    do {
      var stream = JSON.DecodingStream()
      stream.push(" \"Hello\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["Hello"])
      }
      #expect(result.isComplete)
    }

    /// Multiple spaces before opening quote
    do {
      var stream = JSON.DecodingStream()
      stream.push("   \"World\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["World"])
      }
      #expect(result.isComplete)
    }

    /// Tab before opening quote
    do {
      var stream = JSON.DecodingStream()
      stream.push("\t\"Tab\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["Tab"])
      }
      #expect(result.isComplete)
    }

    /// Newline before opening quote
    do {
      var stream = JSON.DecodingStream()
      stream.push("\n\"Newline\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["Newline"])
      }
      #expect(result.isComplete)
    }

    /// Mixed whitespace before opening quote
    do {
      var stream = JSON.DecodingStream()
      stream.push(" \t\n\"Mixed\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["Mixed"])
      }
      #expect(result.isComplete)
    }

    /// Incremental whitespace parsing
    do {
      var stream = JSON.DecodingStream()
      stream.push("  ")
      stream.push("\"Incremental\"")
      stream.finish()

      var state = JSON.StringDecodingState()
      let result = try stream.withDecodedStringFragments(state: &state) {
        #expect($0 == ["Incremental"])
      }
      #expect(result.isComplete)
    }
  }

}

// MARK: - Support

extension JSON.DecodingStream {

  /// Takes a closure since Swift Testing doesn't currently support non-copyable type in `#expect` expressions.
  @discardableResult
  mutating func withDecodedStringFragments(
    state: inout JSON.StringDecodingState,
    _ body: ([String]) -> Void
  ) throws -> JSON.DecodingResult<JSON.StringComponent> {
    var fragments: [String] = []
    let result = try decodeStringFragments(state: &state) { decoded in
      fragments.append(String(decoded))
    }
    body(fragments)
    return result
  }

}

extension JSON.DecodingResult where Value == JSON.StringComponent {

  var isComplete: Bool {
    if case .decoded(.end) = self {
      return true
    } else {
      return false
    }
  }

}

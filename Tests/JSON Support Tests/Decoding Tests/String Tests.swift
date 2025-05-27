import Foundation
import Testing

@testable import JSONSupport

@Suite("String Tests")
private struct StringTests {

  @Test
  func basicTest() async throws {

    /// Complete string
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"Hello, World!\"")
      decoder.stream.finish()

      try decoder.withDecodedFragments {
        #expect($0 == ["Hello, World!"])
      }

      #expect(try decoder.isComplete)
    }

    /// Partial read
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"Hello, ")

      /// Trailing space is omitted because the last character can be modified by subsequent characters.
      try decoder.withDecodedFragments {
        #expect($0 == ["Hello,"])
      }

      decoder.stream.push("World!")
      /// Exclamation mark is omitted because the last character can be modified by subsequent characters, but the space after the comma is returned now.
      try decoder.withDecodedFragments {
        #expect($0 == [" World"])
      }

      decoder.stream.push("\"")
      try decoder.withDecodedFragments {
        #expect($0 == ["!"])
      }
      #expect(try !decoder.isComplete)

      decoder.stream.finish()
      try decoder.withDecodedFragments {
        #expect($0 == [])
      }
      #expect(try decoder.isComplete)
    }
  }

  @Test
  func emptyStringTest() async throws {
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\"")

      try decoder.withDecodedFragments {
        #expect($0 == [])
      }
      #expect(try !decoder.isComplete)
    }
  }

  @Test
  func testFinish() async throws {
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\"")
      decoder.stream.finish()
      let result = decoder.finish()
      switch result {
      case .decodingComplete(var remainder):
        switch remainder.readCharacter() {
        case .needsMoreData:
          #expect(Bool(false), "Should not need more data when stream is finished")
        case .matched:
          #expect(Bool(false), "Should not have any remaining characters")
        case .notMatched:
          // This is expected - no remaining characters in the stream
          #expect(Bool(true))
        }
      case .needsMoreData:
        #expect(Bool(false), "Should not need more data when stream is finished")
      case .decodingFailed(let error, _):
        #expect(Bool(false), "Should not fail: \(error)")
      }
    }
  }

  @Test
  func internationalCharactersTest() async throws {
    /// Non-ASCII UTF-8 characters
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"こんにちは世界\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["こんにちは世界"])
      }
      #expect(try !decoder.isComplete)
    }

    /// Incremental non-ASCII parsing
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"こんに")

      try decoder.withDecodedFragments {
        #expect($0 == ["こん"])
      }

      decoder.stream.push("ちは世界\"")
      try decoder.withDecodedFragments {
        #expect($0 == ["にちは世界"])
      }
      #expect(try !decoder.isComplete)
    }
  }

  @Test
  func basicEscapeSequencesTest() async throws {
    /// Double quote escape
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\\\"\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["\""])
      }
      #expect(try !decoder.isComplete)
    }

    /// Backslash escape
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\\\\\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["\\"])
      }
      #expect(try !decoder.isComplete)
    }

    /// Forward slash escape
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\\/\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["/"])
      }
      #expect(try !decoder.isComplete)
    }

    /// Split Escape
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\\")

      try decoder.withDecodedFragments {
        #expect($0 == [])
      }

      decoder.stream.push("\"\"")
      decoder.stream.finish()
      try decoder.withDecodedFragments {
        #expect($0 == ["\""])
      }
      let isComplete = try decoder.isComplete
      #expect(isComplete)
    }
  }

  @Test
  func controlCharactersTest() async throws {
    /// Newline
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\\n\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["\n"])
      }
      #expect(try !decoder.isComplete)
    }

    /// Tab
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\\t\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["\t"])
      }
      #expect(try !decoder.isComplete)
    }

    /// Carriage return
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\\r\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["\r"])
      }
      #expect(try !decoder.isComplete)
    }

    /// Mixed control characters
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"Line 1\\nLine 2\\tTabbed\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["Line 1", "\n", "Line 2", "\t", "Tabbed"])
      }
      #expect(try !decoder.isComplete)
    }
  }

  @Test
  func unsupportedEscapeCharactersTest() async throws {
    /// Unsupported \b
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\\b\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["�"])
      }
      #expect(try !decoder.isComplete)
    }

    /// Unsupported \f
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\\f\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["�"])
      }
      #expect(try !decoder.isComplete)
    }
  }

  @Test
  func invalidEscapeSequencesTest() async throws {
    /// Invalid escape character
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\\z\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["�"])
      }
      #expect(try !decoder.isComplete)
    }

    /// Modified escape character
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\\n\u{0301}\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["�"])
      }
      #expect(try !decoder.isComplete)
    }
  }

  @Test
  func unicodeEscapeSequencesTest() async throws {
    /// Basic unicode escape
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\\u0041\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["A"])
      }
      #expect(try !decoder.isComplete)
    }

    /// Non-ASCII unicode escape
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\\u00A9\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["©"])
      }
      #expect(try !decoder.isComplete)
    }

    /// Non-ASCII unicode escape (lowercase letters)
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\\u00a9\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["©"])
      }
      #expect(try !decoder.isComplete)
    }

    /// Mixed regular and unicode-escaped characters
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"Copyright \\u00A9 2025\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["Copyright ", "©", " 2025"])
      }
      #expect(try !decoder.isComplete)
    }
  }

  @Test
  func invalidUnicodeEscapeSequencesTest() async throws {
    /// Non-hex characters
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\\u0XYZ\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["�", "0XYZ"])
      }
      #expect(try !decoder.isComplete)
    }
  }

  @Test
  func surrogatePairsTest() async throws {
    /// Valid surrogate pair for 😀 (U+1F600)
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\\uD83D\\uDE00\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["😀"])
      }
      #expect(try !decoder.isComplete)
    }

    /// Incremental surrogate pair parsing
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\\uD83D")

      try decoder.withDecodedFragments {
        #expect($0 == [])
      }

      decoder.stream.push("\\u")
      try decoder.withDecodedFragments {
        #expect($0 == [])
      }

      decoder.stream.push("DE00\"")
      try decoder.withDecodedFragments {
        #expect($0 == ["😀"])
      }
      #expect(try !decoder.isComplete)
    }
  }

  @Test
  func invalidSurrogatePairsTest() async throws {
    /// High surrogate followed by a scalar
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\\uD83D\\u00A9\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["�", "©"])  // Waiting on the low surrogate
      }
      #expect(try !decoder.isComplete)
    }

    /// High surrogate followed by a high surrogate
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\\uD83D\\uD83D\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["��"])
      }
      #expect(try !decoder.isComplete)
    }

    /// High surrogate without low surrogate
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\\uD83D🥸\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["�", "🥸"])
      }
      #expect(try !decoder.isComplete)
    }

    /// High surrogate followed by a different escape sequence
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\\uD83D\\n\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["�", "\n"])
      }
      #expect(try !decoder.isComplete)
    }
  }

  @Test
  func edgeCasesTest() async throws {
    /// Null character
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\\u0000\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["\0"])
      }
      #expect(try !decoder.isComplete)
    }

    /// String with mixed escapes and regular characters
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"Hello\\tWorld\\nNew\\\"Line\\\\Path\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["Hello", "\t", "World", "\n", "New", "\"", "Line", "\\", "Path"])
      }
      #expect(try !decoder.isComplete)
    }
  }

  @Test
  func incrementalParsingTest() async throws {
    /// String with escape sequence split
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"fac\\")

      try decoder.withDecodedFragments {
        /// 'c' gets dropped as it could be modified
        #expect($0 == ["fa"])
      }

      decoder.stream.push("u0327ade\"")
      try decoder.withDecodedFragments {
        #expect($0 == ["c", "\u{0327}", "ade"])
        #expect($0.joined() == "çade")
      }
      #expect(try !decoder.isComplete)
    }

    /// Unicode escape split across buffers
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\\u00")

      try decoder.withDecodedFragments {
        #expect($0 == [])
      }

      decoder.stream.push("A9 copyright\"")
      try decoder.withDecodedFragments {
        #expect($0 == ["©", " copyright"])
      }
      #expect(try !decoder.isComplete)
    }
  }

  @Test
  func completelyPathalogicalTest() async throws {
    /// String with escape sequence split
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\"\"")

      try decoder.withDecodedFragments {
        #expect($0 == [])
      }

      decoder.stream.push("\u{0327}\"")
      decoder.stream.finish()
      try decoder.withDecodedFragments {
        #expect($0 == ["\"" + "\u{0327}"])
      }

      #expect(try decoder.isComplete)
    }
  }

  @Test
  func whitespaceBeforeOpeningQuoteTest() async throws {
    /// Single space before opening quote
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push(" \"Hello\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["Hello"])
      }
      #expect(try !decoder.isComplete)
    }

    /// Multiple spaces before opening quote
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("   \"World\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["World"])
      }
      #expect(try !decoder.isComplete)
    }

    /// Tab before opening quote
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\t\"Tab\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["Tab"])
      }
      #expect(try !decoder.isComplete)
    }

    /// Newline before opening quote
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("\n\"Newline\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["Newline"])
      }
      #expect(try !decoder.isComplete)
    }

    /// Mixed whitespace before opening quote
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push(" \t\n\"Mixed\"")

      try decoder.withDecodedFragments {
        #expect($0 == ["Mixed"])
      }
      #expect(try !decoder.isComplete)
    }

    /// Incremental whitespace parsing
    do {
      var decoder = JSON.StringDecoder()
      decoder.stream.push("  ")

      try decoder.withDecodedFragments {
        #expect($0 == [])
      }

      decoder.stream.push("\"Incremental\"")
      try decoder.withDecodedFragments {
        #expect($0 == ["Incremental"])
      }
      #expect(try !decoder.isComplete)
    }
  }

}
// MARK: - Support

extension JSON.StringDecoder {

  /// Takes a closure since Swift Testing doesn't currently support non-copyable type in `#expect` expressions.
  mutating func withDecodedFragments(
    _ body: ([String]) -> Void
  ) throws {
    var fragments: [String] = []
    _ = try decodeFragments { decoded in
      fragments.append(String(decoded))
    }
    body(fragments)
  }

}

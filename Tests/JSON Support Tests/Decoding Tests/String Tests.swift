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

  }

}

/*
    /// Partial read
    do {
      var value = JSON.Value()
      value.stream.push("\"Hello, ")

      var decoder = value.decodeAsString()
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
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }
  }

  @Test
  func emptyStringTest() async throws {
    do {
      var value = JSON.Value()
      value.stream.push("\"\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == [""])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }
  }

  @Test
  func testFinish() async throws {
    do {
      var value = JSON.Value()
      value.stream.push("\"\"")
      value.stream.finish()
      let decoder = value.decodeAsString()
      var remainingStream = try decoder.finish()
      #expect(remainingStream.readCharacter() == nil)
    }
  }

  @Test
  func internationalCharactersTest() async throws {
    /// Non-ASCII UTF-8 characters
    do {
      var value = JSON.Value()
      value.stream.push("\"こんにちは世界\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["こんにちは世界"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Incremental non-ASCII parsing
    do {
      var value = JSON.Value()
      value.stream.push("\"こんに")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["こん"])
      }

      decoder.stream.push("ちは世界\"")
      try decoder.withDecodedFragments {
        #expect($0 == ["にちは世界"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }
  }

  @Test
  func basicEscapeSequencesTest() async throws {
    /// Double quote escape
    do {
      var value = JSON.Value()
      value.stream.push("\"\\\"\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["\""])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Backslash escape
    do {
      var value = JSON.Value()
      value.stream.push("\"\\\\\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["\\"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Forward slash escape
    do {
      var value = JSON.Value()
      value.stream.push("\"\\/\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["/"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Split Escape
    do {
      var value = JSON.Value()
      value.stream.push("\"\\")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == [""])
      }

      decoder.stream.push("\"\"")
      decoder.stream.finish()
      try decoder.withDecodedFragments {
        #expect($0 == ["\""])
      }
      let isComplete = decoder.isComplete
      #expect(isComplete)
    }
  }

  @Test
  func controlCharactersTest() async throws {
    /// Newline
    do {
      var value = JSON.Value()
      value.stream.push("\"\\n\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["\n"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Tab
    do {
      var value = JSON.Value()
      value.stream.push("\"\\t\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["\t"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Carriage return
    do {
      var value = JSON.Value()
      value.stream.push("\"\\r\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["\r"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Mixed control characters
    do {
      var value = JSON.Value()
      value.stream.push("\"Line 1\\nLine 2\\tTabbed\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["Line 1\nLine 2\tTabbed"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }
  }

  @Test
  func unsupportedEscapeCharactersTest() async throws {
    /// Unsupported \b
    do {
      var value = JSON.Value()
      value.stream.push("\"\\b\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["�"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Unsupported \f
    do {
      var value = JSON.Value()
      value.stream.push("\"\\f\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["�"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }
  }

  @Test
  func invalidEscapeSequencesTest() async throws {
    /// Invalid escape character
    do {
      var value = JSON.Value()
      value.stream.push("\"\\z\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["�"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Modified escape character
    do {
      var value = JSON.Value()
      value.stream.push("\"\\n\u{0301}\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["�"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }
  }

  @Test
  func unicodeEscapeSequencesTest() async throws {
    /// Basic unicode escape
    do {
      var value = JSON.Value()
      value.stream.push("\"\\u0041\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["A"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Non-ASCII unicode escape
    do {
      var value = JSON.Value()
      value.stream.push("\"\\u00A9\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["©"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Non-ASCII unicode escape (lowercase letters)
    do {
      var value = JSON.Value()
      value.stream.push("\"\\u00a9\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["©"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Mixed regular and unicode-escaped characters
    do {
      var value = JSON.Value()
      value.stream.push("\"Copyright \\u00A9 2025\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["Copyright © 2025"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }
  }

  @Test
  func invalidUnicodeEscapeSequencesTest() async throws {
    /// Non-hex characters
    do {
      var value = JSON.Value()
      value.stream.push("\"\\u0XYZ\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["�0XYZ"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }
  }

  @Test
  func surrogatePairsTest() async throws {
    /// Valid surrogate pair for 😀 (U+1F600)
    do {
      var value = JSON.Value()
      value.stream.push("\"\\uD83D\\uDE00\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["😀"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Incremental surrogate pair parsing
    do {
      var value = JSON.Value()
      value.stream.push("\"\\uD83D")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == [""])  // Empty string is returned instead of empty array
      }

      decoder.stream.push("\\u")
      try decoder.withDecodedFragments {
        #expect($0 == [""])  // Empty string is returned instead of empty array
      }

      decoder.stream.push("DE00\"")
      try decoder.withDecodedFragments {
        #expect($0 == ["😀"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }
  }

  @Test
  func invalidSurrogatePairsTest() async throws {
    /// High surrogate followed by a scalar
    do {
      var value = JSON.Value()
      value.stream.push("\"\\uD83D\\u00A9\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["�©"])  // Waiting on the low surrogate
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// High surrogate followed by a high surrogate
    do {
      var value = JSON.Value()
      value.stream.push("\"\\uD83D\\uD83D\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["��"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// High surrogate without low surrogate
    do {
      var value = JSON.Value()
      value.stream.push("\"\\uD83D🥸\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["�🥸"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// High surrogate followed by a different escape sequence
    do {
      var value = JSON.Value()
      value.stream.push("\"\\uD83D\\n\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["�\n"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }
  }

  @Test
  func edgeCasesTest() async throws {
    /// Null character
    do {
      var value = JSON.Value()
      value.stream.push("\"\\u0000\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["\0"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// String with mixed escapes and regular characters
    do {
      var value = JSON.Value()
      value.stream.push("\"Hello\\tWorld\\nNew\\\"Line\\\\Path\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["Hello\tWorld\nNew\"Line\\Path"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }
  }

  @Test
  func incrementalParsingTest() async throws {
    /// String with escape sequence split
    do {
      var value = JSON.Value()
      value.stream.push("\"fac\\")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["fa"])  // 'c' gets dropped as it could be modified
      }

      decoder.stream.push("u0327ade\"")
      try decoder.withDecodedFragments {
        #expect($0 == ["çade"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Unicode escape split across buffers
    do {
      var value = JSON.Value()
      value.stream.push("\"\\u00")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == [""])  // Empty string is returned instead of empty array
      }

      decoder.stream.push("A9 copyright\"")
      try decoder.withDecodedFragments {
        #expect($0 == ["© copyright"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }
  }

  @Test
  func completelyPathalogicalTest() async throws {
    /// String with escape sequence split
    do {
      var value = JSON.Value()
      value.stream.push("\"\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == [""])
      }

      decoder.stream.push("\u{0327}")
      decoder.stream.finish()
      try decoder.withDecodedFragments {
        #expect($0 == ["\"" + "\u{0327}"])
      }

      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }
  }

  @Test
  func whitespaceBeforeOpeningQuoteTest() async throws {
    /// Single space before opening quote
    do {
      var value = JSON.Value()
      value.stream.push(" \"Hello\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["Hello"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Multiple spaces before opening quote
    do {
      var value = JSON.Value()
      value.stream.push("   \"World\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["World"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Tab before opening quote
    do {
      var value = JSON.Value()
      value.stream.push("\t\"Tab\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["Tab"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Newline before opening quote
    do {
      var value = JSON.Value()
      value.stream.push("\n\"Newline\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["Newline"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Mixed whitespace before opening quote
    do {
      var value = JSON.Value()
      value.stream.push(" \t\n\"Mixed\"")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == ["Mixed"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Incremental whitespace parsing
    do {
      var value = JSON.Value()
      value.stream.push("  ")

      var decoder = value.decodeAsString()
      try decoder.withDecodedFragments {
        #expect($0 == [""])
      }

      decoder.stream.push("\"Incremental\"")
      try decoder.withDecodedFragments {
        #expect($0 == ["Incremental"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }
  }
}

 */
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

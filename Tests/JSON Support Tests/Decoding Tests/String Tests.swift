import Foundation
import Testing

@testable import JSONSupport

@Suite("String Tests")
private struct StringTests {

  @Test
  func simpleTest() async throws {
    /// Complete string
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"Hello, World!\"")

      var decoder = stream.decodeString()
      try decoder.withDecodedFragments {
        #expect($0 == ["Hello, World!"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Partial read
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"Hello, ")

      var decoder = stream.decodeString()
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
      var stream = JSON.DecodingStream()
      stream.push("\"\"")

      var decoder = stream.decodeString()
      try decoder.withDecodedFragments {
        #expect($0 == [""])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }
  }

  @Test
  func internationalCharactersTest() async throws {
    /// Non-ASCII UTF-8 characters
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"こんにちは世界\"")

      var decoder = stream.decodeString()
      try decoder.withDecodedFragments {
        #expect($0 == ["こんにちは世界"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Incremental non-ASCII parsing
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"こんに")

      var decoder = stream.decodeString()
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
      var stream = JSON.DecodingStream()
      stream.push("\"\\\"\"")

      var decoder = stream.decodeString()
      try decoder.withDecodedFragments {
        #expect($0 == ["\""])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Backslash escape
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\\\\"")

      var decoder = stream.decodeString()
      try decoder.withDecodedFragments {
        #expect($0 == ["\\"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Forward slash escape
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\/\"")

      var decoder = stream.decodeString()
      try decoder.withDecodedFragments {
        #expect($0 == ["/"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }
  }

  @Test
  func controlCharactersTest() async throws {
    /// Newline
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\n\"")

      var decoder = stream.decodeString()
      try decoder.withDecodedFragments {
        #expect($0 == ["\n"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Tab
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\t\"")

      var decoder = stream.decodeString()
      try decoder.withDecodedFragments {
        #expect($0 == ["\t"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Carriage return
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\r\"")

      var decoder = stream.decodeString()
      try decoder.withDecodedFragments {
        #expect($0 == ["\r"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Mixed control characters
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"Line 1\\nLine 2\\tTabbed\"")

      var decoder = stream.decodeString()
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
      var stream = JSON.DecodingStream()
      stream.push("\"\\b\"")

      var decoder = stream.decodeString()
      try decoder.withDecodedFragments {
        #expect($0 == ["�"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Unsupported \f
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\f\"")

      var decoder = stream.decodeString()
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
      var stream = JSON.DecodingStream()
      stream.push("\"\\z\"")

      var decoder = stream.decodeString()
      try decoder.withDecodedFragments {
        #expect($0 == ["�"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Modified escape character
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\n\u{0301}\"")

      var decoder = stream.decodeString()
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
      var stream = JSON.DecodingStream()
      stream.push("\"\\u0041\"")

      var decoder = stream.decodeString()
      try decoder.withDecodedFragments {
        #expect($0 == ["A"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Non-ASCII unicode escape
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\u00A9\"")

      var decoder = stream.decodeString()
      try decoder.withDecodedFragments {
        #expect($0 == ["©"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Non-ASCII unicode escape (lowercase letters)
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\u00a9\"")

      var decoder = stream.decodeString()
      try decoder.withDecodedFragments {
        #expect($0 == ["©"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Mixed regular and unicode-escaped characters
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"Copyright \\u00A9 2025\"")

      var decoder = stream.decodeString()
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
      var stream = JSON.DecodingStream()
      stream.push("\"\\u0XYZ\"")

      var decoder = stream.decodeString()
      try decoder.withDecodedFragments {
        #expect($0 == ["�XYZ"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }
  }

  @Test
  func surrogatePairsTest() async throws {
    /// Valid surrogate pair for 😀 (U+1F600)
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\uD83D\\uDE00\"")

      var decoder = stream.decodeString()
      try decoder.withDecodedFragments {
        #expect($0 == ["😀"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// Incremental surrogate pair parsing
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\uD83D")

      var decoder = stream.decodeString()
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
      var stream = JSON.DecodingStream()
      stream.push("\"\\uD83D\\u00A9\"")

      var decoder = stream.decodeString()
      try decoder.withDecodedFragments {
        #expect($0 == ["�©"])  // Waiting on the low surrogate
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// High surrogate followed by a high surrogate
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\uD83D\\uD83D\"")

      var decoder = stream.decodeString()
      try decoder.withDecodedFragments {
        #expect($0 == ["��"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// High surrogate without low surrogate
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\uD83D🥸\"")

      var decoder = stream.decodeString()
      try decoder.withDecodedFragments {
        #expect($0 == ["�🥸"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }
  }

  @Test
  func edgeCasesTest() async throws {
    /// Null character
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\u0000\"")

      var decoder = stream.decodeString()
      try decoder.withDecodedFragments {
        #expect($0 == ["\0"])
      }
      let isComplete = decoder.isComplete
      #expect(!isComplete)
    }

    /// String with mixed escapes and regular characters
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"Hello\\tWorld\\nNew\\\"Line\\\\Path\"")

      var decoder = stream.decodeString()
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
      var stream = JSON.DecodingStream()
      stream.push("\"fac\\")

      var decoder = stream.decodeString()
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
      var stream = JSON.DecodingStream()
      stream.push("\"\\u00")

      var decoder = stream.decodeString()
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
      var stream = JSON.DecodingStream()
      stream.push("\"\"")

      var decoder = stream.decodeString()
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
}

// MARK: - Support

extension JSON.StringDecoder {

  mutating func withDecodedFragments(
    _ body: ([String]) throws -> Void
  ) throws {
    var fragments: [String] = []
    try decodeFragments { fragment in
      fragments.append(String(fragment))
    }
    try body(fragments)
  }

}

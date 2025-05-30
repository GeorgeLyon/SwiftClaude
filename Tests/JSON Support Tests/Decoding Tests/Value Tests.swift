import Foundation
import Testing

@testable import JSONSupport

@Suite("Value Tests")
private struct ValueTests {

  @Test
  func numberValuesTest() async throws {
    /// Integer
    do {
      var stream = JSON.DecodingStream()
      stream.push("42")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "42")
      }
    }

    /// Zero
    do {
      var stream = JSON.DecodingStream()
      stream.push("0")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "0")
      }
    }

    /// Negative integer
    do {
      var stream = JSON.DecodingStream()
      stream.push("-123")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "-123")
      }
    }

    /// Decimal
    do {
      var stream = JSON.DecodingStream()
      stream.push("3.14159")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "3.14159")
      }
    }

    /// Negative decimal
    do {
      var stream = JSON.DecodingStream()
      stream.push("-0.5")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "-0.5")
      }
    }

    /// Number with exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("1.23e4")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "1.23e4")
      }
    }

    /// Number with negative exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("1.23e-4")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "1.23e-4")
      }
    }

    /// Number with capital E exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("1.23E+4")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "1.23E+4")
      }
    }

    /// Large integer
    do {
      var stream = JSON.DecodingStream()
      stream.push("9223372036854775807")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "9223372036854775807")
      }
    }
  }

  @Test
  func stringValuesTest() async throws {
    /// Simple string
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"hello world\"")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "\"hello world\"")
      }
    }

    /// Empty string
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\"")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "\"\"")
      }
    }

    /// String with escapes
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"hello\\nworld\\t!\"")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "\"hello\\nworld\\t!\"")
      }
    }

    /// String with quotes
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"She said \\\"Hello\\\"\"")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "\"She said \\\"Hello\\\"\"")
      }
    }

    /// String with unicode escape
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\u0048\\u0065\\u006C\\u006C\\u006F\"")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "\"\\u0048\\u0065\\u006C\\u006C\\u006F\"")
      }
    }

    /// String with backslash
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"path\\\\to\\\\file\"")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "\"path\\\\to\\\\file\"")
      }
    }

    /// String with various escapes
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"\\b\\f\\r\\/\"")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "\"\\b\\f\\r\\/\"")
      }
    }

    /// Long string
    do {
      let longString = String(repeating: "a", count: 1000)
      var stream = JSON.DecodingStream()
      stream.push("\"\(longString)\"")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "\"\(longString)\"")
      }
    }
  }

  @Test
  func booleanValuesTest() async throws {
    /// True
    do {
      var stream = JSON.DecodingStream()
      stream.push("true")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "true")
      }
    }

    /// False
    do {
      var stream = JSON.DecodingStream()
      stream.push("false")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "false")
      }
    }

    /// True with whitespace
    do {
      var stream = JSON.DecodingStream()
      stream.push("  true  ")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "  true")
      }
    }
  }

  @Test
  func nullValueTest() async throws {
    /// Null
    do {
      var stream = JSON.DecodingStream()
      stream.push("null")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "null")
      }
    }

    /// Null with whitespace
    do {
      var stream = JSON.DecodingStream()
      stream.push("   null   ")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "   null")
      }
    }
  }

  @Test
  func incrementalValueParsingTest() async throws {
    /// Number needs more data
    do {
      var stream = JSON.DecodingStream()
      stream.push("12")

      var state = JSON.ValueDecodingState()
      try stream.withDecodeValueResult(state: &state) { result, decodedSubstring in
        #expect(result.needsMoreData)
        #expect(decodedSubstring == "")
      }

      stream.push("3")
      stream.finish()

      try stream.withDecodeValueResult(state: &state) { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "123")
      }
    }

    /// String needs more data
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"hel")

      var state = JSON.ValueDecodingState()
      try stream.withDecodeValueResult(state: &state) { result, decodedSubstring in
        #expect(result.needsMoreData)
        #expect(decodedSubstring == "\"he")
      }

      stream.push("lo\"")
      stream.finish()

      try stream.withDecodeValueResult(state: &state) { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "llo\"")
      }
    }

    /// Array needs more data
    do {
      var stream = JSON.DecodingStream()
      stream.push("[1, 2")

      var state = JSON.ValueDecodingState()
      try stream.withDecodeValueResult(state: &state) { result, decodedSubstring in
        #expect(result.needsMoreData)
        #expect(decodedSubstring == "[1, ")
      }

      stream.push(", 3]")
      stream.finish()

      try stream.withDecodeValueResult(state: &state) { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "2, 3]")
      }
    }
  }

  @Test
  func arrayValuesTest() async throws {
    /// Empty array
    do {
      var stream = JSON.DecodingStream()
      stream.push("[]")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "[]")
      }
    }

    /// Array with numbers
    do {
      var stream = JSON.DecodingStream()
      stream.push("[1, 2, 3]")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "[1, 2, 3]")
      }
    }

    /// Array with strings
    do {
      var stream = JSON.DecodingStream()
      stream.push("[\"hello\", \"world\"]")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "[\"hello\", \"world\"]")
      }
    }

    /// Mixed array
    do {
      var stream = JSON.DecodingStream()
      stream.push("[42, \"hello\", true, null]")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "[42, \"hello\", true, null]")
      }
    }

    /// Nested arrays
    do {
      var stream = JSON.DecodingStream()
      stream.push("[[1, 2], [3, 4], [5]]")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "[[1, 2], [3, 4], [5]]")
      }
    }

    /// Array with whitespace
    do {
      var stream = JSON.DecodingStream()
      stream.push("[ 1 , 2 , 3 ]")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "[ 1 , 2 , 3 ]")
      }
    }

    /// Array with newlines
    do {
      var stream = JSON.DecodingStream()
      stream.push("[\n  1,\n  2,\n  3\n]")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "[\n  1,\n  2,\n  3\n]")
      }
    }
  }

}

// MARK: - Support

extension JSON.DecodingStream {

  fileprivate mutating func withDecodeValueResult(
    _ checkpoint: JSON.DecodingStream.Checkpoint? = nil,
    _ body: (JSON.DecodingResult<Void>, Substring) -> Void
  ) throws {
    var state = JSON.ValueDecodingState()
    try withDecodeValueResult(checkpoint, state: &state, body)
  }

  fileprivate mutating func withDecodeValueResult(
    _ checkpoint: JSON.DecodingStream.Checkpoint? = nil,
    state: inout JSON.ValueDecodingState,
    _ body: (JSON.DecodingResult<Void>, Substring) -> Void
  ) throws {
    let checkpoint = checkpoint ?? createCheckpoint()
    let result = try decodeValue(&state)
    body(result, substringDecoded(since: checkpoint))
  }

}

extension JSON.DecodingResult {
  var needsMoreData: Bool {
    switch self {
    case .needsMoreData:
      return true
    case .decoded:
      return false
    }
  }
  var isDecoded: Bool {
    switch self {
    case .needsMoreData:
      return false
    case .decoded:
      return true
    }
  }
}

import Foundation
import Testing

@testable import JSONSupport

@Suite("Reencodable Value Tests")
private struct ReencodableValueTests {

  @Test
  func basicReencodableValuesTest() async throws {
    /// Number
    do {
      var stream = JSON.DecodingStream()
      stream.push("42")
      stream.finish()

      var state = JSON.ReencodableValueDecodingState()
      let result = try stream.decodeReencodableValue(state: &state).getValue()

      // Test re-encoding
      var encodingStream = JSON.EncodingStream()
      encodingStream.encode(result)
      #expect(encodingStream.string == "42")
    }

    /// String
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"hello world\"")
      stream.finish()

      var state = JSON.ReencodableValueDecodingState()
      let result = try stream.decodeReencodableValue(state: &state).getValue()

      var encodingStream = JSON.EncodingStream()
      encodingStream.encode(result)
      #expect(encodingStream.string == "\"hello world\"")
    }

    /// Boolean
    do {
      var stream = JSON.DecodingStream()
      stream.push("true")
      stream.finish()

      var state = JSON.ReencodableValueDecodingState()
      let result = try stream.decodeReencodableValue(state: &state).getValue()

      var encodingStream = JSON.EncodingStream()
      encodingStream.encode(result)
      #expect(encodingStream.string == "true")
    }

    /// Null
    do {
      var stream = JSON.DecodingStream()
      stream.push("null")
      stream.finish()

      var state = JSON.ReencodableValueDecodingState()
      let result = try stream.decodeReencodableValue(state: &state).getValue()

      var encodingStream = JSON.EncodingStream()
      encodingStream.encode(result)
      #expect(encodingStream.string == "null")
    }
  }

  @Test
  func complexReencodableValuesTest() async throws {
    /// Object
    do {
      var stream = JSON.DecodingStream()
      stream.push("{\"name\": \"John\", \"age\": 30}")
      stream.finish()

      var state = JSON.ReencodableValueDecodingState()
      let result = try stream.decodeReencodableValue(state: &state).getValue()

      var encodingStream = JSON.EncodingStream()
      encodingStream.encode(result)
      #expect(encodingStream.string == "{\"name\": \"John\", \"age\": 30}")
    }

    /// Array
    do {
      var stream = JSON.DecodingStream()
      stream.push("[1, 2, 3, \"hello\", true, null]")
      stream.finish()

      var state = JSON.ReencodableValueDecodingState()
      let result = try stream.decodeReencodableValue(state: &state).getValue()

      var encodingStream = JSON.EncodingStream()
      encodingStream.encode(result)
      #expect(encodingStream.string == "[1, 2, 3, \"hello\", true, null]")
    }

    /// Nested structure
    do {
      var stream = JSON.DecodingStream()
      let json = "{\"users\": [{\"id\": 1, \"name\": \"Alice\"}, {\"id\": 2, \"name\": \"Bob\"}]}"
      stream.push(json)
      stream.finish()

      var state = JSON.ReencodableValueDecodingState()
      let result = try stream.decodeReencodableValue(state: &state).getValue()

      var encodingStream = JSON.EncodingStream()
      encodingStream.encode(result)
      #expect(encodingStream.string == json)
    }
  }

  @Test
  func whitespacePreservationTest() async throws {
    /// Leading whitespace
    do {
      var stream = JSON.DecodingStream()
      stream.push("   42")
      stream.finish()

      var state = JSON.ReencodableValueDecodingState()
      let result = try stream.decodeReencodableValue(state: &state).getValue()

      var encodingStream = JSON.EncodingStream()
      encodingStream.encode(result)
      #expect(encodingStream.string == "42")  // Leading whitespace is trimmed
    }

    /// Whitespace in object
    do {
      var stream = JSON.DecodingStream()
      let json = "{ \"name\" : \"John\" , \"age\" : 30 }"
      stream.push(json)
      stream.finish()

      var state = JSON.ReencodableValueDecodingState()
      let result = try stream.decodeReencodableValue(state: &state).getValue()

      var encodingStream = JSON.EncodingStream()
      encodingStream.encode(result)
      #expect(encodingStream.string == json)
    }

    /// Newlines and tabs
    do {
      var stream = JSON.DecodingStream()
      let json = "{\n\t\"name\": \"John\",\n\t\"age\": 30\n}"
      stream.push(json)
      stream.finish()

      var state = JSON.ReencodableValueDecodingState()
      let result = try stream.decodeReencodableValue(state: &state).getValue()

      var encodingStream = JSON.EncodingStream()
      encodingStream.encode(result)
      #expect(encodingStream.string == json)
    }
  }

  @Test
  func incrementalReencodableDecodingTest() async throws {
    /// Number incremental
    do {
      var stream = JSON.DecodingStream()
      stream.push("12")

      var state = JSON.ReencodableValueDecodingState()
      let result = try stream.decodeReencodableValue(state: &state)
      #expect(result.needsMoreData)

      stream.push("3.45")
      stream.finish()

      let value = try stream.decodeReencodableValue(state: &state).getValue()

      var encodingStream = JSON.EncodingStream()
      encodingStream.encode(value)
      #expect(encodingStream.string == "123.45")
    }

    /// String incremental
    do {
      var stream = JSON.DecodingStream()
      stream.push("\"hel")

      var state = JSON.ReencodableValueDecodingState()
      var result = try stream.decodeReencodableValue(state: &state)
      #expect(result.needsMoreData)

      stream.push("lo wor")
      result = try stream.decodeReencodableValue(state: &state)
      #expect(result.needsMoreData)

      stream.push("ld\"")
      stream.finish()

      let value = try stream.decodeReencodableValue(state: &state).getValue()

      var encodingStream = JSON.EncodingStream()
      encodingStream.encode(value)
      #expect(encodingStream.string == "\"hello world\"")
    }

    /// Object incremental
    do {
      var stream = JSON.DecodingStream()
      stream.push("{\"na")

      var state = JSON.ReencodableValueDecodingState()
      var result = try stream.decodeReencodableValue(state: &state)
      #expect(result.needsMoreData)

      stream.push("me\": \"Jo")
      result = try stream.decodeReencodableValue(state: &state)
      #expect(result.needsMoreData)

      stream.push("hn\"}")
      stream.finish()

      let value = try stream.decodeReencodableValue(state: &state).getValue()

      var encodingStream = JSON.EncodingStream()
      encodingStream.encode(value)
      #expect(encodingStream.string == "{\"name\": \"John\"}")
    }

    /// Array incremental
    do {
      var stream = JSON.DecodingStream()
      stream.push("[1, ")

      var state = JSON.ReencodableValueDecodingState()
      var result = try stream.decodeReencodableValue(state: &state)
      #expect(result.needsMoreData)

      stream.push("2, 3")
      result = try stream.decodeReencodableValue(state: &state)
      #expect(result.needsMoreData)

      stream.push("]")
      stream.finish()

      let value = try stream.decodeReencodableValue(state: &state).getValue()

      var encodingStream = JSON.EncodingStream()
      encodingStream.encode(value)
      #expect(encodingStream.string == "[1, 2, 3]")
    }
  }

  @Test
  func escapeSequencePreservationTest() async throws {
    /// Escaped quotes
    do {
      var stream = JSON.DecodingStream()
      let json = "\"She said \\\"Hello\\\"\""
      stream.push(json)
      stream.finish()

      var state = JSON.ReencodableValueDecodingState()
      let result = try stream.decodeReencodableValue(state: &state).getValue()

      var encodingStream = JSON.EncodingStream()
      encodingStream.encode(result)
      #expect(encodingStream.string == json)
    }

    /// Unicode escapes
    do {
      var stream = JSON.DecodingStream()
      let json = "\"\\u0048\\u0065\\u006C\\u006C\\u006F\""
      stream.push(json)
      stream.finish()

      var state = JSON.ReencodableValueDecodingState()
      let result = try stream.decodeReencodableValue(state: &state).getValue()

      var encodingStream = JSON.EncodingStream()
      encodingStream.encode(result)
      #expect(encodingStream.string == json)
    }

    /// Various escape sequences
    do {
      var stream = JSON.DecodingStream()
      let json = "\"\\n\\r\\t\\b\\f\\\\\\/\""
      stream.push(json)
      stream.finish()

      var state = JSON.ReencodableValueDecodingState()
      let result = try stream.decodeReencodableValue(state: &state).getValue()

      var encodingStream = JSON.EncodingStream()
      encodingStream.encode(result)
      #expect(encodingStream.string == json)
    }
  }

  @Test
  func multipleReencodableValuesTest() async throws {
    /// Multiple values in sequence
    do {
      var stream = JSON.DecodingStream()

      // First value
      stream.push("42 ")
      stream.finish()

      var state1 = JSON.ReencodableValueDecodingState()
      let value1 = try stream.decodeReencodableValue(state: &state1).getValue()

      // Reset and decode second value
      stream.reset()
      stream.push("\"hello\" ")
      stream.finish()

      var state2 = JSON.ReencodableValueDecodingState()
      let value2 = try stream.decodeReencodableValue(state: &state2).getValue()

      // Re-encode both values
      var encodingStream = JSON.EncodingStream()
      encodingStream.encode(value1)
      encodingStream.write(" ")
      encodingStream.encode(value2)
      #expect(encodingStream.string == "42 \"hello\"")
    }
  }

  @Test
  func edgeCasesTest() async throws {
    /// Empty object
    do {
      var stream = JSON.DecodingStream()
      stream.push("{}")
      stream.finish()

      var state = JSON.ReencodableValueDecodingState()
      let result = try stream.decodeReencodableValue(state: &state).getValue()

      var encodingStream = JSON.EncodingStream()
      encodingStream.encode(result)
      #expect(encodingStream.string == "{}")
    }

    /// Empty array
    do {
      var stream = JSON.DecodingStream()
      stream.push("[]")
      stream.finish()

      var state = JSON.ReencodableValueDecodingState()
      let result = try stream.decodeReencodableValue(state: &state).getValue()

      var encodingStream = JSON.EncodingStream()
      encodingStream.encode(result)
      #expect(encodingStream.string == "[]")
    }

    /// Very long number
    do {
      var stream = JSON.DecodingStream()
      let longNumber = "9223372036854775807"
      stream.push(longNumber)
      stream.finish()

      var state = JSON.ReencodableValueDecodingState()
      let result = try stream.decodeReencodableValue(state: &state).getValue()

      var encodingStream = JSON.EncodingStream()
      encodingStream.encode(result)
      #expect(encodingStream.string == longNumber)
    }

    /// Scientific notation
    do {
      var stream = JSON.DecodingStream()
      let scientific = "1.23e-45"
      stream.push(scientific)
      stream.finish()

      var state = JSON.ReencodableValueDecodingState()
      let result = try stream.decodeReencodableValue(state: &state).getValue()

      var encodingStream = JSON.EncodingStream()
      encodingStream.encode(result)
      #expect(encodingStream.string == scientific)
    }
  }
}

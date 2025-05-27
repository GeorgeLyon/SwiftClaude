import Testing

@testable import JSONSupport

@Suite("Value Tests")
private struct ValueTests {

  @Test func stringTest() async throws {
    var decoder = JSON.ValueDecoder()
    decoder.stream.push("\"Hello, World!\"")
    try decoder.stringDecoder.withDecodedFragments {
      #expect($0 == ["Hello, World!"])
    }
  }

  @Test func numberDecoderTest() async throws {
    /// Integer
    do {
      var decoder = JSON.ValueDecoder()
      decoder.stream.push("42")
      decoder.stream.finish()

      let result = try decoder.numberDecoder.decodeNumber()
      let number = try result.getValue()
      #expect(number.stringValue == "42")
      #expect(number.integerPart == "42")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)
    }

    /// Decimal
    do {
      var decoder = JSON.ValueDecoder()
      decoder.stream.push("3.14159")
      decoder.stream.finish()

      let result = try decoder.numberDecoder.decodeNumber()
      let number = try result.getValue()
      #expect(number.stringValue == "3.14159")
      #expect(number.integerPart == "3")
      #expect(number.fractionalPart == "14159")
      #expect(number.exponent == nil)
    }

    /// Scientific notation
    do {
      var decoder = JSON.ValueDecoder()
      decoder.stream.push("1.23e-4")
      decoder.stream.finish()

      let result = try decoder.numberDecoder.decodeNumber()
      let number = try result.getValue()
      #expect(number.stringValue == "1.23e-4")
      #expect(number.integerPart == "1")
      #expect(number.fractionalPart == "23")
      #expect(number.exponent == "-4")
    }
  }

  @Test func nullDecoderTest() async throws {
    var decoder = JSON.ValueDecoder()
    decoder.stream.push("null")
    decoder.stream.finish()

    let result = try decoder.nullDecoder.decodeNull()
    #expect(try result.getValue() == ())
    #expect(try decoder.nullDecoder.isComplete)
  }

  @Test func booleanDecoderTest() async throws {
    /// True value
    do {
      var decoder = JSON.ValueDecoder()
      decoder.stream.push("true")
      decoder.stream.finish()

      let result = try decoder.booleanDecoder.decodeBoolean()
      #expect(try result.getValue() == true)
      #expect(try decoder.booleanDecoder.isComplete)
    }

    /// False value
    do {
      var decoder = JSON.ValueDecoder()
      decoder.stream.push("false")
      decoder.stream.finish()

      let result = try decoder.booleanDecoder.decodeBoolean()
      #expect(try result.getValue() == false)
      #expect(try decoder.booleanDecoder.isComplete)
    }
  }

  @Test func typeMismatchTest() async throws {
    /// Try to decode a string as a number
    do {
      var decoder = JSON.ValueDecoder()
      decoder.stream.push("\"hello\"")
      decoder.stream.finish()

      // First decode as string to consume the value
      _ = try decoder.stringDecoder.decodeFragments { _ in }

      // Now try to get it as a number - should have error state
      #expect(throws: (any Error).self) {
        _ = try decoder.numberDecoder.decodeNumber()
      }
    }

    /// Try to decode a number as null
    do {
      var decoder = JSON.ValueDecoder()
      decoder.stream.push("123")
      decoder.stream.finish()

      // First decode as number to consume the value
      _ = try decoder.numberDecoder.decodeNumber()

      // Now try to get it as null - should have error state
      #expect(throws: (any Error).self) {
        _ = try decoder.nullDecoder.decodeNull()
      }
    }

    /// Try to decode a boolean as a string
    do {
      var decoder = JSON.ValueDecoder()
      decoder.stream.push("true")
      decoder.stream.finish()

      // First decode as boolean to consume the value
      _ = try decoder.booleanDecoder.decodeBoolean()

      // Now try to get it as string - should have error state
      #expect(throws: (any Error).self) {
        _ = try decoder.stringDecoder.decodeFragments { _ in }
      }
    }
  }

  @Test func incrementalDecodingTest() async throws {
    /// Number with incremental parsing
    do {
      var decoder = JSON.ValueDecoder()
      decoder.stream.push("12")
      #expect(try decoder.numberDecoder.decodeNumber().needsMoreData)

      decoder.stream.push("3.45")
      #expect(try decoder.numberDecoder.decodeNumber().needsMoreData)

      decoder.stream.finish()
      let result = try decoder.numberDecoder.decodeNumber()
      let number = try result.getValue()
      #expect(number.stringValue == "123.45")
    }

    /// Boolean with incremental parsing
    do {
      var decoder = JSON.ValueDecoder()
      decoder.stream.push("fal")
      #expect(try decoder.booleanDecoder.decodeBoolean().needsMoreData)

      decoder.stream.push("se")
      #expect(try decoder.booleanDecoder.decodeBoolean().needsMoreData)

      decoder.stream.finish()
      let result = try decoder.booleanDecoder.decodeBoolean()
      #expect(try result.getValue() == false)
    }

    /// Null with incremental parsing
    do {
      var decoder = JSON.ValueDecoder()
      decoder.stream.push("nu")
      #expect(try decoder.nullDecoder.decodeNull().needsMoreData)

      decoder.stream.push("ll")
      #expect(try decoder.nullDecoder.decodeNull().needsMoreData)

      decoder.stream.finish()
      let result = try decoder.nullDecoder.decodeNull()
      #expect(try result.getValue() == ())
    }
  }

  @Test func whitespaceHandlingTest() async throws {
    /// Number with leading whitespace
    do {
      var decoder = JSON.ValueDecoder()
      decoder.stream.push("  \n\t42")
      decoder.stream.finish()

      let result = try decoder.numberDecoder.decodeNumber()
      let number = try result.getValue()
      #expect(number.stringValue == "42")
    }

    /// Boolean with leading whitespace
    do {
      var decoder = JSON.ValueDecoder()
      decoder.stream.push("\t\n true")
      decoder.stream.finish()

      let result = try decoder.booleanDecoder.decodeBoolean()
      #expect(try result.getValue() == true)
    }

    /// Null with leading whitespace
    do {
      var decoder = JSON.ValueDecoder()
      decoder.stream.push("   null")
      decoder.stream.finish()

      let result = try decoder.nullDecoder.decodeNull()
      #expect(try result.getValue() == ())
    }
  }

}

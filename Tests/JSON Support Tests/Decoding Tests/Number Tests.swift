import Foundation
import Testing

@testable import JSONSupport

@Suite("Number Tests")
private struct NumberTests {

  @Test
  func basicIntegerTest() async throws {

    /// Complete integer
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push("42")
      decoder.stream.finish()

      let number = try decoder.decodeNumber().getValue()
      #expect(number.stringValue == "42")
      #expect(number.integerPart == "42")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)

      #expect(try decoder.isComplete)
    }

    /// Partial read
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push("12")
      #expect(try decoder.decodeNumber().needsMoreData)
      decoder.stream.push("34")
      #expect(try decoder.decodeNumber().needsMoreData)
      decoder.stream.finish()

      let number = try decoder.decodeNumber().getValue()
      #expect(number.stringValue == "1234")
      #expect(number.integerPart == "1234")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)
      #expect(try decoder.isComplete)
    }
  }
  
  @Test
  func negativeNumberTest() async throws {
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push("-42")
      decoder.stream.finish()

      let number = try decoder.decodeNumber().getValue()
      #expect(number.stringValue == "-42")
      #expect(number.integerPart == "-42")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)

      #expect(try decoder.isComplete)
    }
  }
  
  @Test
  func zeroTest() async throws {
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push("0")
      decoder.stream.finish()

      let number = try decoder.decodeNumber().getValue()
      #expect(number.stringValue == "0")
      #expect(number.integerPart == "0")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)

      #expect(try decoder.isComplete)
    }
  }
  
  @Test
  func decimalTest() async throws {
    /// Basic decimal
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push("123.456")
      decoder.stream.finish()

      let number = try decoder.decodeNumber().getValue()
      #expect(number.stringValue == "123.456")
      #expect(number.significand == "123.456")
      #expect(number.integerPart == "123")
      #expect(number.fractionalPart == "456")
      #expect(number.exponent == nil)

      #expect(try decoder.isComplete)
    }

    /// Partial decimal read
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push("3.1")
      #expect(try decoder.decodeNumber().needsMoreData)
      
      decoder.stream.push("415")
      #expect(try decoder.decodeNumber().needsMoreData)
      
      decoder.stream.finish()
      let number = try decoder.decodeNumber().getValue()
      #expect(number.stringValue == "3.1415")
      #expect(number.significand == "3.1415")
      #expect(number.integerPart == "3")
      #expect(number.fractionalPart == "1415")
      #expect(number.exponent == nil)

      #expect(try decoder.isComplete)
    }
  }
  
  @Test
  func negativeDecimalTest() async throws {
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push("-99.99")
      decoder.stream.finish()

      let number = try decoder.decodeNumber().getValue()
      #expect(number.stringValue == "-99.99")
      #expect(number.significand == "-99.99")
      #expect(number.integerPart == "-99")
      #expect(number.fractionalPart == "99")
      #expect(number.exponent == nil)

      #expect(try decoder.isComplete)
    }
  }
  
  @Test
  func scientificNotationTest() async throws {
    /// Positive exponent
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push("1.23e10")
      decoder.stream.finish()

      let number = try decoder.decodeNumber().getValue()
      #expect(number.stringValue == "1.23e10")
      #expect(number.significand == "1.23")
      #expect(number.integerPart == "1")
      #expect(number.fractionalPart == "23")
      #expect(number.exponent == "10")

      #expect(try decoder.isComplete)
    }

    /// Negative exponent
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push("1.23e-10")
      decoder.stream.finish()

      let number = try decoder.decodeNumber().getValue()
      #expect(number.stringValue == "1.23e-10")
      #expect(number.significand == "1.23")
      #expect(number.integerPart == "1")
      #expect(number.fractionalPart == "23")
      #expect(number.exponent == "-10")

      #expect(try decoder.isComplete)
    }

    /// Explicit positive exponent
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push("2.5E+3")
      decoder.stream.finish()

      let number = try decoder.decodeNumber().getValue()
      #expect(number.stringValue == "2.5E+3")
      #expect(number.significand == "2.5")
      #expect(number.integerPart == "2")
      #expect(number.fractionalPart == "5")
      #expect(number.exponent == "+3")

      #expect(try decoder.isComplete)
    }

    /// Integer with exponent
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push("42e2")
      decoder.stream.finish()

      let number = try decoder.decodeNumber().getValue()
      #expect(number.stringValue == "42e2")
      #expect(number.significand == "42")
      #expect(number.integerPart == "42")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == "2")

      #expect(try decoder.isComplete)
    }
  }
  
  @Test
  func testFinish() async throws {
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push("123")
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
  func whitespaceBeforeNumberTest() async throws {
    /// Single space before number
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push(" 123")
      decoder.stream.finish()

      let number = try decoder.decodeNumber().getValue()
      #expect(number.stringValue == "123")
      #expect(number.integerPart == "123")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)

      #expect(try decoder.isComplete)
    }

    /// Multiple spaces before number
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push("   456")
      decoder.stream.finish()

      let number = try decoder.decodeNumber().getValue()
      #expect(number.stringValue == "456")
      #expect(number.integerPart == "456")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)

      #expect(try decoder.isComplete)
    }

    /// Tab before number
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push("\t789")
      decoder.stream.finish()

      let number = try decoder.decodeNumber().getValue()
      #expect(number.stringValue == "789")
      #expect(number.integerPart == "789")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)

      #expect(try decoder.isComplete)
    }

    /// Newline before number
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push("\n123")
      decoder.stream.finish()

      let number = try decoder.decodeNumber().getValue()
      #expect(number.stringValue == "123")
      #expect(number.integerPart == "123")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)

      #expect(try decoder.isComplete)
    }

    /// Mixed whitespace before number
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push(" \t\n456")
      decoder.stream.finish()

      let number = try decoder.decodeNumber().getValue()
      #expect(number.stringValue == "456")
      #expect(number.integerPart == "456")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)

      #expect(try decoder.isComplete)
    }

    /// Incremental whitespace parsing
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push("  ")
      #expect(try decoder.decodeNumber().needsMoreData)
      
      decoder.stream.push("789")
      #expect(try decoder.decodeNumber().needsMoreData)
      
      decoder.stream.finish()
      let number = try decoder.decodeNumber().getValue()
      #expect(number.stringValue == "789")
      #expect(number.integerPart == "789")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)

      #expect(try decoder.isComplete)
    }
  }
  
  @Test
  func incrementalParsingTest() async throws {
    /// Decimal point split across buffers
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push("123.")
      #expect(try decoder.decodeNumber().needsMoreData)
      
      decoder.stream.push("456")
      #expect(try decoder.decodeNumber().needsMoreData)
      
      decoder.stream.finish()
      let number = try decoder.decodeNumber().getValue()
      #expect(number.stringValue == "123.456")
      #expect(number.significand == "123.456")
      #expect(number.integerPart == "123")
      #expect(number.fractionalPart == "456")
      #expect(number.exponent == nil)

      #expect(try decoder.isComplete)
    }

    /// Scientific notation split across buffers
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push("1.5e1")
      #expect(try decoder.decodeNumber().needsMoreData)
      
      decoder.stream.push("0")
      #expect(try decoder.decodeNumber().needsMoreData)
      
      decoder.stream.finish()
      let number = try decoder.decodeNumber().getValue()
      #expect(number.stringValue == "1.5e10")
      #expect(number.significand == "1.5")
      #expect(number.integerPart == "1")
      #expect(number.fractionalPart == "5")
      #expect(number.exponent == "10")

      #expect(try decoder.isComplete)
    }

    /// Exponent sign split across buffers
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push("2.0E-")
      #expect(try decoder.decodeNumber().needsMoreData)
      
      decoder.stream.push("5")
      #expect(try decoder.decodeNumber().needsMoreData)
      
      decoder.stream.finish()
      let number = try decoder.decodeNumber().getValue()
      #expect(number.stringValue == "2.0E-5")
      #expect(number.significand == "2.0")
      #expect(number.integerPart == "2")
      #expect(number.fractionalPart == "0")
      #expect(number.exponent == "-5")

      #expect(try decoder.isComplete)
    }
  }
  
  @Test
  func edgeCasesTest() async throws {
    /// Negative zero
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push("-0")
      decoder.stream.finish()

      let number = try decoder.decodeNumber().getValue()
      #expect(number.stringValue == "-0")
      #expect(number.integerPart == "-0")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)

      #expect(try decoder.isComplete)
    }

    /// Zero with decimal part
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push("0.0")
      decoder.stream.finish()

      let number = try decoder.decodeNumber().getValue()
      #expect(number.stringValue == "0.0")
      #expect(number.significand == "0.0")
      #expect(number.integerPart == "0")
      #expect(number.fractionalPart == "0")
      #expect(number.exponent == nil)

      #expect(try decoder.isComplete)
    }

    /// Zero with exponent
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push("0e0")
      decoder.stream.finish()

      let number = try decoder.decodeNumber().getValue()
      #expect(number.stringValue == "0e0")
      #expect(number.significand == "0")
      #expect(number.integerPart == "0")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == "0")

      #expect(try decoder.isComplete)
    }

    /// Very large number
    do {
      var decoder = JSON.NumberDecoder()
      decoder.stream.push("123456789012345678901234567890")
      decoder.stream.finish()

      let number = try decoder.decodeNumber().getValue()
      #expect(number.stringValue == "123456789012345678901234567890")
      #expect(number.integerPart == "123456789012345678901234567890")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)

      #expect(try decoder.isComplete)
    }
  }
}

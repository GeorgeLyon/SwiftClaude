import Foundation
import Testing

@testable import JSONSupport

@Suite("Number Tests")
private struct NumberTests {

  // MARK: - Integer Tests

  @Test
  func integerTest() async throws {
    /// Simple positive integer
    do {
      var stream = JSON.DecodingStream()
      stream.push("42")
      stream.finish()

      let result = try stream.decodeNumber { number in
        #expect(number.stringValue == "42")
        #expect(number.significand == "42")
        #expect(number.integerPart == "42")
        #expect(number.fractionalPart == nil)
        #expect(number.exponent == nil)
        return Int(number.significand)!
      }
      #expect(result == 42)
    }

    /// Negative integer
    do {
      var stream = JSON.DecodingStream()
      stream.push("-123")
      stream.finish()

      let result = try stream.decodeNumber { number in
        #expect(number.stringValue == "-123")
        #expect(number.significand == "-123")
        #expect(number.integerPart == "-123")
        #expect(number.fractionalPart == nil)
        #expect(number.exponent == nil)
        return Int(number.significand)!
      }
      #expect(result == -123)
    }

    /// Zero
    do {
      var stream = JSON.DecodingStream()
      stream.push("0")
      stream.finish()

      let result = try stream.decodeNumber { number in
        #expect(number.stringValue == "0")
        #expect(number.significand == "0")
        #expect(number.integerPart == "0")
        #expect(number.fractionalPart == nil)
        #expect(number.exponent == nil)
        return Int(number.significand)!
      }
      #expect(result == 0)
    }

    /// Negative zero
    do {
      var stream = JSON.DecodingStream()
      stream.push("-0")
      stream.finish()

      let result = try stream.decodeNumber { number in
        #expect(number.stringValue == "-0")
        #expect(number.significand == "-0")
        #expect(number.integerPart == "-0")
        #expect(number.fractionalPart == nil)
        #expect(number.exponent == nil)
        return Int(number.significand)!
      }
      #expect(result == 0)
    }
  }

  @Test
  func decimalTest() async throws {
    /// Simple decimal
    do {
      var stream = JSON.DecodingStream()
      stream.push("42.5")
      stream.finish()

      let result = try stream.decodeNumber { number in
        #expect(number.stringValue == "42.5")
        #expect(number.significand == "42.5")
        #expect(number.integerPart == "42")
        #expect(number.fractionalPart == "5")
        #expect(number.exponent == nil)
        return Double(number.significand)!
      }
      #expect(result == 42.5)
    }

    /// Negative decimal
    do {
      var stream = JSON.DecodingStream()
      stream.push("-123.456")
      stream.finish()

      let result = try stream.decodeNumber { number in
        #expect(number.stringValue == "-123.456")
        #expect(number.significand == "-123.456")
        #expect(number.integerPart == "-123")
        #expect(number.fractionalPart == "456")
        #expect(number.exponent == nil)
        return Double(number.significand)!
      }
      #expect(result == -123.456)
    }

    /// Zero with decimal
    do {
      var stream = JSON.DecodingStream()
      stream.push("0.0")
      stream.finish()

      let result = try stream.decodeNumber { number in
        #expect(number.stringValue == "0.0")
        #expect(number.significand == "0.0")
        #expect(number.integerPart == "0")
        #expect(number.fractionalPart == "0")
        #expect(number.exponent == nil)
        return Double(number.significand)!
      }
      #expect(result == 0.0)
    }

    /// Decimal with multiple fractional digits
    do {
      var stream = JSON.DecodingStream()
      stream.push("3.14159")
      stream.finish()

      let result = try stream.decodeNumber { number in
        #expect(number.stringValue == "3.14159")
        #expect(number.significand == "3.14159")
        #expect(number.integerPart == "3")
        #expect(number.fractionalPart == "14159")
        #expect(number.exponent == nil)
        return Double(number.significand)!
      }
      #expect(result == 3.14159)
    }
  }

  @Test
  func scientificNotationTest() async throws {
    /// Positive exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("1.23e4")
      stream.finish()

      let result = try stream.decodeNumber { number in
        #expect(number.stringValue == "1.23e4")
        #expect(number.significand == "1.23")
        #expect(number.integerPart == "1")
        #expect(number.fractionalPart == "23")
        #expect(number.exponent == "4")
        return Double(number.stringValue)!
      }
      #expect(result == 12300.0)
    }

    /// Negative exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("1.23e-4")
      stream.finish()

      let result = try stream.decodeNumber { number in
        #expect(number.stringValue == "1.23e-4")
        #expect(number.significand == "1.23")
        #expect(number.integerPart == "1")
        #expect(number.fractionalPart == "23")
        #expect(number.exponent == "-4")
        return Double(number.stringValue)!
      }
      #expect(result == 0.000123)
    }

    /// Uppercase E
    do {
      var stream = JSON.DecodingStream()
      stream.push("5E2")
      stream.finish()

      let result = try stream.decodeNumber { number in
        #expect(number.stringValue == "5E2")
        #expect(number.significand == "5")
        #expect(number.integerPart == "5")
        #expect(number.fractionalPart == nil)
        #expect(number.exponent == "2")
        return Double(number.stringValue)!
      }
      #expect(result == 500.0)
    }

    /// Positive exponent with plus sign
    do {
      var stream = JSON.DecodingStream()
      stream.push("2.5e+3")
      stream.finish()

      let result = try stream.decodeNumber { number in
        #expect(number.stringValue == "2.5e+3")
        #expect(number.significand == "2.5")
        #expect(number.integerPart == "2")
        #expect(number.fractionalPart == "5")
        #expect(number.exponent == "+3")
        return Double(number.stringValue)!
      }
      #expect(result == 2500.0)
    }

    /// Zero exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("7.5e0")
      stream.finish()

      let result = try stream.decodeNumber { number in
        #expect(number.stringValue == "7.5e0")
        #expect(number.significand == "7.5")
        #expect(number.integerPart == "7")
        #expect(number.fractionalPart == "5")
        #expect(number.exponent == "0")
        return Double(number.stringValue)!
      }
      #expect(result == 7.5)
    }

    /// Integer with exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("42e2")
      stream.finish()

      let result = try stream.decodeNumber { number in
        #expect(number.stringValue == "42e2")
        #expect(number.significand == "42")
        #expect(number.integerPart == "42")
        #expect(number.fractionalPart == nil)
        #expect(number.exponent == "2")
        return Double(number.stringValue)!
      }
      #expect(result == 4200.0)
    }
  }

  @Test
  func whitespaceHandlingTest() async throws {
    /// Leading whitespace
    do {
      var stream = JSON.DecodingStream()
      stream.push("  42")
      stream.finish()

      let result = try stream.decodeNumber { number in
        #expect(number.stringValue == "42")
        return Int(number.significand)!
      }
      #expect(result == 42)
    }

    /// Multiple types of leading whitespace
    do {
      var stream = JSON.DecodingStream()
      stream.push(" \t\n\r123.45")
      stream.finish()

      let result = try stream.decodeNumber { number in
        #expect(number.stringValue == "123.45")
        return Double(number.significand)!
      }
      #expect(result == 123.45)
    }
  }

  @Test
  func invalidNumbersTest() async throws {
    /// Leading zeros
    do {
      var stream = JSON.DecodingStream()
      stream.push("007")
      stream.finish()

      #expect(throws: JSON.Number.Error.leadingZeroes) {
        try stream.decodeNumber { _ in return 0 }
      }
    }

    /// Multiple leading zeros
    do {
      var stream = JSON.DecodingStream()
      stream.push("0000")
      stream.finish()

      #expect(throws: JSON.Number.Error.leadingZeroes) {
        try stream.decodeNumber { _ in return 0 }
      }
    }

    /// Leading zero with decimal
    do {
      var stream = JSON.DecodingStream()
      stream.push("007.5")
      stream.finish()

      #expect(throws: JSON.Number.Error.leadingZeroes) {
        try stream.decodeNumber { _ in return 0 }
      }
    }

    /// Non-numeric input
    do {
      var stream = JSON.DecodingStream()
      stream.push("abc")
      stream.finish()

      let result = try stream.decodeNumber { _ in return 42 }
      #expect(result == nil)
    }

    /// Empty input
    do {
      var stream = JSON.DecodingStream()
      stream.push("")
      stream.finish()

      let result = try stream.decodeNumber { _ in return 42 }
      #expect(result == nil)
    }
  }

  @Test
  func partialNumberTest() async throws {
    /// Partial integer
    do {
      var stream = JSON.DecodingStream()
      stream.push("12")

      let result = try stream.decodeNumber { _ in return 42 }
      #expect(result == nil)
    }

    /// Partial decimal
    do {
      var stream = JSON.DecodingStream()
      stream.push("12.")

      let result = try stream.decodeNumber { _ in return 42 }
      #expect(result == nil)
    }

    /// Partial exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("12e")

      let result = try stream.decodeNumber { _ in return 42 }
      #expect(result == nil)
    }

    /// Partial exponent with sign
    do {
      var stream = JSON.DecodingStream()
      stream.push("12e+")

      let result = try stream.decodeNumber { _ in return 42 }
      #expect(result == nil)
    }
  }

  @Test
  func incrementalParsingTest() async throws {
    /// Building up a complete number incrementally
    do {
      var stream = JSON.DecodingStream()
      stream.push("12")

      var result = try stream.decodeNumber { _ in return 42.0 }
      #expect(result == nil)

      stream.push("3.45")
      result = try stream.decodeNumber { _ in return 42.0 }
      #expect(result == nil)

      stream.push("e-2")
      stream.finish()
      result = try stream.decodeNumber { number in
        #expect(number.stringValue == "123.45e-2")
        return Double(number.stringValue)!
      }
      #expect(result == 1.2345)
    }

    /// Incremental negative number
    do {
      var stream = JSON.DecodingStream()
      stream.push("-")

      var result = try stream.decodeNumber { _ in return 42 }
      #expect(result == nil)

      stream.push("456")
      stream.finish()
      result = try stream.decodeNumber { number in
        #expect(number.stringValue == "-456")
        return Int(number.significand)!
      }
      #expect(result == -456)
    }
  }

  @Test
  func edgeCasesTest() async throws {
    /// Very large number
    do {
      var stream = JSON.DecodingStream()
      stream.push("999999999999999999")
      stream.finish()

      let result = try stream.decodeNumber { number in
        #expect(number.stringValue == "999999999999999999")
        #expect(number.significand == "999999999999999999")
        #expect(number.integerPart == "999999999999999999")
        #expect(number.fractionalPart == nil)
        #expect(number.exponent == nil)
        return number.stringValue
      }
      #expect(result == "999999999999999999")
    }

    /// Very small decimal
    do {
      var stream = JSON.DecodingStream()
      stream.push("0.000000000001")
      stream.finish()

      let result = try stream.decodeNumber { number in
        #expect(number.stringValue == "0.000000000001")
        #expect(number.significand == "0.000000000001")
        #expect(number.integerPart == "0")
        #expect(number.fractionalPart == "000000000001")
        #expect(number.exponent == nil)
        return Double(number.significand)!
      }
      #expect(result == 0.000000000001)
    }

    /// Large exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("1e100")
      stream.finish()

      let result = try stream.decodeNumber { number in
        #expect(number.stringValue == "1e100")
        #expect(number.significand == "1")
        #expect(number.integerPart == "1")
        #expect(number.fractionalPart == nil)
        #expect(number.exponent == "100")
        return number.stringValue
      }
      #expect(result == "1e100")
    }

    /// Negative large exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("1e-100")
      stream.finish()

      let result = try stream.decodeNumber { number in
        #expect(number.stringValue == "1e-100")
        #expect(number.significand == "1")
        #expect(number.integerPart == "1")
        #expect(number.fractionalPart == nil)
        #expect(number.exponent == "-100")
        return number.stringValue
      }
      #expect(result == "1e-100")
    }
  }

  @Test
  func boundaryConditionsTest() async throws {
    /// Just a minus sign
    do {
      var stream = JSON.DecodingStream()
      stream.push("-")
      stream.finish()

      let result = try stream.decodeNumber { _ in return 42 }
      #expect(result == nil)
    }

    /// Just a decimal point
    do {
      var stream = JSON.DecodingStream()
      stream.push(".")
      stream.finish()

      let result = try stream.decodeNumber { _ in return 42 }
      #expect(result == nil)
    }

    /// Decimal point without fractional part
    do {
      var stream = JSON.DecodingStream()
      stream.push("42.")
      stream.finish()

      let result = try stream.decodeNumber { _ in return 42 }
      #expect(result == nil)
    }

    /// E without digits
    do {
      var stream = JSON.DecodingStream()
      stream.push("42e")
      stream.finish()

      let result = try stream.decodeNumber { _ in return 42 }
      #expect(result == nil)
    }

    /// E with sign but no digits
    do {
      var stream = JSON.DecodingStream()
      stream.push("42e+")
      stream.finish()

      let result = try stream.decodeNumber { _ in return 42 }
      #expect(result == nil)
    }

    /// Multiple dots
    do {
      var stream = JSON.DecodingStream()
      stream.push("42.5.6")
      stream.finish()

      let result = try stream.decodeNumber { number in
        #expect(number.stringValue == "42.5")
        return Double(number.significand)!
      }
      #expect(result == 42.5)
    }
  }

  @Test
  func processingErrorTest() async throws {
    /// Error thrown in process closure
    do {
      var stream = JSON.DecodingStream()
      stream.push("42")
      stream.finish()

      struct TestError: Error {}

      #expect(throws: TestError.self) {
        try stream.decodeNumber { _ in
          throw TestError()
        }
      }
    }
  }
}
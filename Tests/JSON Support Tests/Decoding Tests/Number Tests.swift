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
      var value = JSON.Value()
      value.stream.push("42")
      value.stream.finish()

      let result = try value.decodeAsNumber { number in
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
      var value = JSON.Value()
      value.stream.push("-123")
      value.stream.finish()

      let result = try value.decodeAsNumber { number in
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
      var value = JSON.Value()
      value.stream.push("0")
      value.stream.finish()

      let result = try value.decodeAsNumber { number in
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
      var value = JSON.Value()
      value.stream.push("-0")
      value.stream.finish()

      let result = try value.decodeAsNumber { number in
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
      var value = JSON.Value()
      value.stream.push("42.5")
      value.stream.finish()

      let result = try value.decodeAsNumber { number in
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
      var value = JSON.Value()
      value.stream.push("-123.456")
      value.stream.finish()

      let result = try value.decodeAsNumber { number in
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
      var value = JSON.Value()
      value.stream.push("0.0")
      value.stream.finish()

      let result = try value.decodeAsNumber { number in
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
      var value = JSON.Value()
      value.stream.push("3.14159")
      value.stream.finish()

      let result = try value.decodeAsNumber { number in
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
      var value = JSON.Value()
      value.stream.push("1.23e4")
      value.stream.finish()

      let result = try value.decodeAsNumber { number in
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
      var value = JSON.Value()
      value.stream.push("1.23e-4")
      value.stream.finish()

      let result = try value.decodeAsNumber { number in
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
      var value = JSON.Value()
      value.stream.push("5E2")
      value.stream.finish()

      let result = try value.decodeAsNumber { number in
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
      var value = JSON.Value()
      value.stream.push("2.5e+3")
      value.stream.finish()

      let result = try value.decodeAsNumber { number in
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
      var value = JSON.Value()
      value.stream.push("7.5e0")
      value.stream.finish()

      let result = try value.decodeAsNumber { number in
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
      var value = JSON.Value()
      value.stream.push("42e2")
      value.stream.finish()

      let result = try value.decodeAsNumber { number in
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
      var value = JSON.Value()
      value.stream.push("  42")
      value.stream.finish()

      let result = try value.decodeAsNumber { number in
        #expect(number.stringValue == "42")
        return Int(number.significand)!
      }
      #expect(result == 42)
    }

    /// Multiple types of leading whitespace
    do {
      var value = JSON.Value()
      value.stream.push(" \t\n\r123.45")
      value.stream.finish()

      let result = try value.decodeAsNumber { number in
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
      var value = JSON.Value()
      value.stream.push("007")
      value.stream.finish()

      #expect(throws: JSON.Number.Error.leadingZeroes) {
        try value.decodeAsNumber { _ in return 0 }
      }
    }

    /// Multiple leading zeros
    do {
      var value = JSON.Value()
      value.stream.push("0000")
      value.stream.finish()

      #expect(throws: JSON.Number.Error.leadingZeroes) {
        try value.decodeAsNumber { _ in return 0 }
      }
    }

    /// Leading zero with decimal
    do {
      var value = JSON.Value()
      value.stream.push("007.5")
      value.stream.finish()

      #expect(throws: JSON.Number.Error.leadingZeroes) {
        try value.decodeAsNumber { _ in return 0 }
      }
    }

    /// Non-numeric input
    do {
      var value = JSON.Value()
      value.stream.push("abc")
      value.stream.finish()

      #expect(throws: Error.self) {
        _ = try value.decodeAsNumber { _ in return 42 }
      }
    }

    /// Empty input
    do {
      var value = JSON.Value()
      value.stream.push("")
      value.stream.finish()

      /// This fails because the stream is finished, meaning this can never be a number
      #expect(throws: Error.self) {
        _ = try value.decodeAsNumber { _ in return 42 }
      }
    }
  }

  @Test
  func partialNumberTest() async throws {
    /// Partial integer
    do {
      var value = JSON.Value()
      value.stream.push("12")

      let result = try value.decodeAsNumber { _ in return 42 }
      #expect(result == nil)
    }

    /// Partial decimal
    do {
      var value = JSON.Value()
      value.stream.push("12.")

      let result = try value.decodeAsNumber { _ in return 42 }
      #expect(result == nil)
    }

    /// Partial exponent
    do {
      var value = JSON.Value()
      value.stream.push("12e")

      let result = try value.decodeAsNumber { _ in return 42 }
      #expect(result == nil)
    }

    /// Partial exponent with sign
    do {
      var value = JSON.Value()
      value.stream.push("12e+")

      let result = try value.decodeAsNumber { _ in return 42 }
      #expect(result == nil)
    }
  }

  @Test
  func incrementalParsingTest() async throws {
    /// Building up a complete number incrementally
    do {
      var value = JSON.Value()
      value.stream.push("12")

      var result = try value.decodeAsNumber { _ in return 42.0 }
      #expect(result == nil)

      value.stream.push("3.45")
      result = try value.decodeAsNumber { _ in return 42.0 }
      #expect(result == nil)

      value.stream.push("e-2")
      value.stream.finish()
      result = try value.decodeAsNumber { number in
        #expect(number.stringValue == "123.45e-2")
        return Double(number.stringValue)!
      }
      #expect(result == 1.2345)
    }

    /// Incremental negative number
    do {
      var value = JSON.Value()
      value.stream.push("-")

      var result = try value.decodeAsNumber { _ in return 42 }
      #expect(result == nil)

      value.stream.push("456")
      value.stream.finish()
      result = try value.decodeAsNumber { number in
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
      var value = JSON.Value()
      value.stream.push("999999999999999999")
      value.stream.finish()

      let result = try value.decodeAsNumber { number in
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
      var value = JSON.Value()
      value.stream.push("0.000000000001")
      value.stream.finish()

      let result = try value.decodeAsNumber { number in
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
      var value = JSON.Value()
      value.stream.push("1e100")
      value.stream.finish()

      let result = try value.decodeAsNumber { number in
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
      var value = JSON.Value()
      value.stream.push("1e-100")
      value.stream.finish()

      let result = try value.decodeAsNumber { number in
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
      var value = JSON.Value()
      value.stream.push("-")
      value.stream.finish()

      #expect(throws: Error.self) {
        let result = try value.decodeAsNumber { _ in return 42 }
      }
    }

    /// Just a decimal point
    do {
      var value = JSON.Value()
      value.stream.push(".")
      value.stream.finish()

      #expect(throws: Error.self) {
        let result = try value.decodeAsNumber { _ in return 42 }
      }
    }

    /// Decimal point without fractional part
    do {
      var value = JSON.Value()
      value.stream.push("42.")
      value.stream.finish()

      #expect(throws: Error.self) {
        let result = try value.decodeAsNumber { _ in return 42 }
      }
    }

    /// E without digits
    do {
      var value = JSON.Value()
      value.stream.push("42e")
      value.stream.finish()

      /// We expect a number after the exponent
      #expect(throws: Error.self) {
        _ = try value.decodeAsNumber { _ in return 42 }
      }
    }

    /// E with sign but no digits
    do {
      var value = JSON.Value()
      value.stream.push("42e+")
      value.stream.finish()

      /// We expect a number after the exponent
      #expect(throws: Error.self) {
        let result = try value.decodeAsNumber { _ in return 42 }
      }
    }

    /// Multiple dots
    do {
      var value = JSON.Value()
      value.stream.push("42.5.6")
      value.stream.finish()

      /// The number is decoded, but and the stream remainder is ".6"
      let result = try value.decodeAsNumber { number in
        #expect(number.stringValue == "42.5")
        return Double(number.significand)!
      }
      #expect(result == 42.5)

      let nextCharacter = try value.stream.readCharacter()
      #expect(nextCharacter == ".")
    }
  }

  @Test
  func processingErrorTest() async throws {
    /// Error thrown in process closure
    do {
      var value = JSON.Value()
      value.stream.push("42")
      value.stream.finish()

      struct TestError: Error {}

      #expect(throws: TestError.self) {
        try value.decodeAsNumber { _ in
          throw TestError()
        }
      }
    }
  }
}

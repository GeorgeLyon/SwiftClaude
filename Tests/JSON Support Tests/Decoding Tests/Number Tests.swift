import Foundation
import Testing

@testable import JSONSupport

@Suite("Number Tests")
private struct NumberTests {

  @Test
  func basicIntegerTest() async throws {

    /// Complete integer
    do {
      var stream = JSON.DecodingStream()
      stream.push("42")
      stream.finish()

      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "42")
      #expect(number.integerPart == "42")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)
    }

    /// Partial read
    do {
      var stream = JSON.DecodingStream()
      stream.push("12")
      #expect(try stream.decodeNumber().needsMoreData)
      stream.push("34")
      #expect(try stream.decodeNumber().needsMoreData)
      stream.finish()

      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "1234")
      #expect(number.integerPart == "1234")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)
    }
  }

  @Test
  func negativeNumberTest() async throws {
    do {
      var stream = JSON.DecodingStream()
      stream.push("-42")
      stream.finish()

      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "-42")
      #expect(number.integerPart == "-42")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)
    }
  }

  @Test
  func zeroTest() async throws {
    do {
      var stream = JSON.DecodingStream()
      stream.push("0")
      stream.finish()

      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "0")
      #expect(number.integerPart == "0")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)
    }
  }

  @Test
  func decimalTest() async throws {
    /// Basic decimal
    do {
      var stream = JSON.DecodingStream()
      stream.push("123.456")
      stream.finish()

      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "123.456")
      #expect(number.significand == "123.456")
      #expect(number.integerPart == "123")
      #expect(number.fractionalPart == "456")
      #expect(number.exponent == nil)
    }

    /// Partial decimal read
    do {
      var stream = JSON.DecodingStream()
      stream.push("3.1")
      #expect(try stream.decodeNumber().needsMoreData)

      stream.push("415")
      #expect(try stream.decodeNumber().needsMoreData)

      stream.finish()
      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "3.1415")
      #expect(number.significand == "3.1415")
      #expect(number.integerPart == "3")
      #expect(number.fractionalPart == "1415")
      #expect(number.exponent == nil)
    }
  }

  @Test
  func negativeDecimalTest() async throws {
    do {
      var stream = JSON.DecodingStream()
      stream.push("-99.99")
      stream.finish()

      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "-99.99")
      #expect(number.significand == "-99.99")
      #expect(number.integerPart == "-99")
      #expect(number.fractionalPart == "99")
      #expect(number.exponent == nil)
    }
  }

  @Test
  func scientificNotationTest() async throws {
    /// Positive exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("1.23e10")
      stream.finish()

      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "1.23e10")
      #expect(number.significand == "1.23")
      #expect(number.integerPart == "1")
      #expect(number.fractionalPart == "23")
      #expect(number.exponent == "10")
    }

    /// Negative exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("1.23e-10")
      stream.finish()

      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "1.23e-10")
      #expect(number.significand == "1.23")
      #expect(number.integerPart == "1")
      #expect(number.fractionalPart == "23")
      #expect(number.exponent == "-10")
    }

    /// Explicit positive exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("2.5E+3")
      stream.finish()

      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "2.5E+3")
      #expect(number.significand == "2.5")
      #expect(number.integerPart == "2")
      #expect(number.fractionalPart == "5")
      #expect(number.exponent == "+3")
    }

    /// Integer with exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("42e2")
      stream.finish()

      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "42e2")
      #expect(number.significand == "42")
      #expect(number.integerPart == "42")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == "2")
    }
  }

  @Test
  func whitespaceBeforeNumberTest() async throws {
    /// Single space before number
    do {
      var stream = JSON.DecodingStream()
      stream.push(" 123")
      stream.finish()

      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "123")
      #expect(number.integerPart == "123")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)
    }

    /// Multiple spaces before number
    do {
      var stream = JSON.DecodingStream()
      stream.push("   456")
      stream.finish()

      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "456")
      #expect(number.integerPart == "456")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)
    }

    /// Tab before number
    do {
      var stream = JSON.DecodingStream()
      stream.push("\t789")
      stream.finish()

      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "789")
      #expect(number.integerPart == "789")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)
    }

    /// Newline before number
    do {
      var stream = JSON.DecodingStream()
      stream.push("\n123")
      stream.finish()

      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "123")
      #expect(number.integerPart == "123")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)
    }

    /// Mixed whitespace before number
    do {
      var stream = JSON.DecodingStream()
      stream.push(" \t\n456")
      stream.finish()

      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "456")
      #expect(number.integerPart == "456")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)
    }

    /// Incremental whitespace parsing
    do {
      var stream = JSON.DecodingStream()
      stream.push("  ")
      #expect(try stream.decodeNumber().needsMoreData)

      stream.push("789")
      #expect(try stream.decodeNumber().needsMoreData)

      stream.finish()
      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "789")
      #expect(number.integerPart == "789")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)
    }
  }

  @Test
  func incrementalParsingTest() async throws {
    /// Decimal point split across buffers
    do {
      var stream = JSON.DecodingStream()
      stream.push("123.")
      #expect(try stream.decodeNumber().needsMoreData)

      stream.push("456")
      #expect(try stream.decodeNumber().needsMoreData)

      stream.finish()
      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "123.456")
      #expect(number.significand == "123.456")
      #expect(number.integerPart == "123")
      #expect(number.fractionalPart == "456")
      #expect(number.exponent == nil)
    }

    /// Scientific notation split across buffers
    do {
      var stream = JSON.DecodingStream()
      stream.push("1.5e1")
      #expect(try stream.decodeNumber().needsMoreData)

      stream.push("0")
      #expect(try stream.decodeNumber().needsMoreData)

      stream.finish()
      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "1.5e10")
      #expect(number.significand == "1.5")
      #expect(number.integerPart == "1")
      #expect(number.fractionalPart == "5")
      #expect(number.exponent == "10")
    }

    /// Exponent sign split across buffers
    do {
      var stream = JSON.DecodingStream()
      stream.push("2.0E-")
      #expect(try stream.decodeNumber().needsMoreData)

      stream.push("5")
      #expect(try stream.decodeNumber().needsMoreData)

      stream.finish()
      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "2.0E-5")
      #expect(number.significand == "2.0")
      #expect(number.integerPart == "2")
      #expect(number.fractionalPart == "0")
      #expect(number.exponent == "-5")
    }
  }

  @Test
  func edgeCasesTest() async throws {
    /// Negative zero
    do {
      var stream = JSON.DecodingStream()
      stream.push("-0")
      stream.finish()

      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "-0")
      #expect(number.integerPart == "-0")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)
    }

    /// Zero with decimal part
    do {
      var stream = JSON.DecodingStream()
      stream.push("0.0")
      stream.finish()

      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "0.0")
      #expect(number.significand == "0.0")
      #expect(number.integerPart == "0")
      #expect(number.fractionalPart == "0")
      #expect(number.exponent == nil)
    }

    /// Zero with exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("0e0")
      stream.finish()

      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "0e0")
      #expect(number.significand == "0")
      #expect(number.integerPart == "0")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == "0")
    }

    /// Very large number
    do {
      var stream = JSON.DecodingStream()
      stream.push("123456789012345678901234567890")
      stream.finish()

      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "123456789012345678901234567890")
      #expect(number.integerPart == "123456789012345678901234567890")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == nil)
    }
  }

  @Test
  func additionalScientificNotationEdgeCasesTest() async throws {
    /// Number with just 'e' at end (incomplete)
    do {
      var stream = JSON.DecodingStream()
      stream.push("123e")
      #expect(try stream.decodeNumber().needsMoreData)

      stream.push("4")
      stream.finish()
      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "123e4")
      #expect(number.integerPart == "123")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == "4")
    }

    /// Number with 'E' and '+' but no exponent digits yet
    do {
      var stream = JSON.DecodingStream()
      stream.push("5.0E+")
      #expect(try stream.decodeNumber().needsMoreData)

      stream.push("2")
      stream.finish()
      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "5.0E+2")
      #expect(number.integerPart == "5")
      #expect(number.fractionalPart == "0")
      #expect(number.exponent == "+2")
    }

    /// Decimal with zero fractional part
    do {
      var stream = JSON.DecodingStream()
      stream.push("10.0")
      stream.finish()

      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "10.0")
      #expect(number.integerPart == "10")
      #expect(number.fractionalPart == "0")
      #expect(number.exponent == nil)
    }

    /// Number ending with decimal point
    do {
      var stream = JSON.DecodingStream()
      stream.push("42.")
      #expect(try stream.decodeNumber().needsMoreData)

      stream.push("0")
      stream.finish()
      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "42.0")
      #expect(number.integerPart == "42")
      #expect(number.fractionalPart == "0")
      #expect(number.exponent == nil)
    }

    /// Large exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("1e999")
      stream.finish()

      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "1e999")
      #expect(number.integerPart == "1")
      #expect(number.fractionalPart == nil)
      #expect(number.exponent == "999")
    }

    /// Negative number with positive exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("-3.14E+2")
      stream.finish()

      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "-3.14E+2")
      #expect(number.integerPart == "-3")
      #expect(number.fractionalPart == "14")
      #expect(number.exponent == "+2")
    }
  }

  @Test
  func numberStreamingEdgeCasesTest() async throws {
    /// Minus sign alone needs more data
    do {
      var stream = JSON.DecodingStream()
      stream.push("-")
      #expect(try stream.decodeNumber().needsMoreData)

      stream.push("7")
      stream.finish()
      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "-7")
      #expect(number.integerPart == "-7")
    }

    /// Just '0' could be followed by decimal
    do {
      var stream = JSON.DecodingStream()
      stream.push("0")
      #expect(try stream.decodeNumber().needsMoreData)

      stream.push(".5")
      stream.finish()
      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "0.5")
      #expect(number.integerPart == "0")
      #expect(number.fractionalPart == "5")
    }

    /// Number split at every character
    do {
      var stream = JSON.DecodingStream()
      stream.push("-")
      #expect(try stream.decodeNumber().needsMoreData)

      stream.push("1")
      #expect(try stream.decodeNumber().needsMoreData)

      stream.push(".")
      #expect(try stream.decodeNumber().needsMoreData)

      stream.push("2")
      #expect(try stream.decodeNumber().needsMoreData)

      stream.push("e")
      #expect(try stream.decodeNumber().needsMoreData)

      stream.push("-")
      #expect(try stream.decodeNumber().needsMoreData)

      stream.push("3")
      stream.finish()

      let number = try stream.decodeNumber().getValue()
      #expect(number.stringValue == "-1.2e-3")
      #expect(number.integerPart == "-1")
      #expect(number.fractionalPart == "2")
      #expect(number.exponent == "-3")
    }
  }

  @Test
  func integerDecodingTest() async throws {
    /// Decode various integer types
    do {
      var stream = JSON.DecodingStream()
      stream.push("42")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      let int8Value = try number.decode(as: Int8.self)
      #expect(int8Value == 42)

      let int16Value = try number.decode(as: Int16.self)
      #expect(int16Value == 42)

      let int32Value = try number.decode(as: Int32.self)
      #expect(int32Value == 42)

      let int64Value = try number.decode(as: Int64.self)
      #expect(int64Value == 42)

      let intValue = try number.decode(as: Int.self)
      #expect(intValue == 42)

      let uint8Value = try number.decode(as: UInt8.self)
      #expect(uint8Value == 42)

      let uint16Value = try number.decode(as: UInt16.self)
      #expect(uint16Value == 42)

      let uint32Value = try number.decode(as: UInt32.self)
      #expect(uint32Value == 42)

      let uint64Value = try number.decode(as: UInt64.self)
      #expect(uint64Value == 42)

      let uintValue = try number.decode(as: UInt.self)
      #expect(uintValue == 42)
    }

    /// Negative integers
    do {
      var stream = JSON.DecodingStream()
      stream.push("-123")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      let intValue = try number.decode(as: Int.self)
      #expect(intValue == -123)

      let int32Value = try number.decode(as: Int32.self)
      #expect(int32Value == -123)
    }

    /// Zero
    do {
      var stream = JSON.DecodingStream()
      stream.push("0")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      let intValue = try number.decode(as: Int.self)
      #expect(intValue == 0)

      let uintValue = try number.decode(as: UInt.self)
      #expect(uintValue == 0)
    }
  }

  @Test
  func integerDecodingErrorTest() async throws {
    /// Integer with fractional part should fail
    do {
      var stream = JSON.DecodingStream()
      stream.push("42.5")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      #expect(throws: (any Error).self) {
        try number.decode(as: Int.self)
      }
    }

    /// Integer with exponent should fail
    do {
      var stream = JSON.DecodingStream()
      stream.push("42e2")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      #expect(throws: (any Error).self) {
        try number.decode(as: Int.self)
      }
    }

    /// Number too large for type
    do {
      var stream = JSON.DecodingStream()
      stream.push("999999999999999999999999999999")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      #expect(throws: (any Error).self) {
        try number.decode(as: Int8.self)
      }
    }

    /// Negative number for unsigned type
    do {
      var stream = JSON.DecodingStream()
      stream.push("-42")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      #expect(throws: (any Error).self) {
        try number.decode(as: UInt.self)
      }
    }
  }

  @Test
  func binaryFloatingPointDecodingTest() async throws {
    /// Decode Float values
    do {
      var stream = JSON.DecodingStream()
      stream.push("3.14")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      let floatValue = try number.decode(as: Float.self)
      #expect(abs(floatValue - 3.14) < 0.001)

      let doubleValue = try number.decode(as: Double.self)
      #expect(abs(doubleValue - 3.14) < 0.001)
    }

    /// Integer values as floats
    do {
      var stream = JSON.DecodingStream()
      stream.push("42")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      let floatValue = try number.decode(as: Float.self)
      #expect(floatValue == 42.0)

      let doubleValue = try number.decode(as: Double.self)
      #expect(doubleValue == 42.0)
    }

    /// Negative values
    do {
      var stream = JSON.DecodingStream()
      stream.push("-1.5")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      let floatValue = try number.decode(as: Float.self)
      #expect(floatValue == -1.5)

      let doubleValue = try number.decode(as: Double.self)
      #expect(doubleValue == -1.5)
    }

    /// Zero values
    do {
      var stream = JSON.DecodingStream()
      stream.push("0.0")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      let floatValue = try number.decode(as: Float.self)
      #expect(floatValue == 0.0)

      let doubleValue = try number.decode(as: Double.self)
      #expect(doubleValue == 0.0)
    }

    /// Very small decimal
    do {
      var stream = JSON.DecodingStream()
      stream.push("0.000001")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      let doubleValue = try number.decode(as: Double.self)
      #expect(abs(doubleValue - 0.000001) < 0.0000001)
    }
  }

  @Test
  func binaryFloatingPointErrorTest() async throws {
    /// Generic BinaryFloatingPoint method with exponent should fail
    do {
      var stream = JSON.DecodingStream()
      stream.push("1.5e10")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      #expect(throws: (any Error).self) {
        _ = try number.decode(as: Float16.self)
      }
    }

    /// Invalid float format
    do {
      // This should never happen in practice since decodeNumber would fail first,
      // but we test the error handling in the decode method itself
      let number = JSON.Number(
        stringValue: "abc",
        significand: "abc",
        integerPart: "abc",
        fractionalPart: nil,
        exponent: nil
      )

      #expect(throws: (any Error).self) {
        try number.decode(as: Float.self)
      }
    }
  }

  @Test
  func floatWithExponentDecodingTest() async throws {
    /// Float with positive exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("1.5e2")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      let floatValue = try number.decode(as: Float.self)
      #expect(floatValue == 150.0)
    }

    /// Float with negative exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("2.5e-1")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      let floatValue = try number.decode(as: Float.self)
      #expect(abs(floatValue - 0.25) < 0.001)
    }

    /// Double with positive exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("1.25e3")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      let doubleValue = try number.decode(as: Double.self)
      #expect(doubleValue == 1250.0)
    }

    /// Double with negative exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("3.75e-2")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      let doubleValue = try number.decode(as: Double.self)
      #expect(abs(doubleValue - 0.0375) < 0.0001)
    }

    /// Integer with exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("5e1")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      let floatValue = try number.decode(as: Float.self)
      #expect(floatValue == 50.0)

      let doubleValue = try number.decode(as: Double.self)
      #expect(doubleValue == 50.0)
    }

    /// Zero exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("7.5e0")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      let floatValue = try number.decode(as: Float.self)
      #expect(floatValue == 7.5)
    }

    /// Large exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("1e10")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      let doubleValue = try number.decode(as: Double.self)
      #expect(doubleValue == 10000000000.0)
    }
  }

  @Test
  func decimalDecodingTest() async throws {
    /// Basic decimal
    do {
      var stream = JSON.DecodingStream()
      stream.push("123.456")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      let decimalValue = try number.decode(as: Decimal.self)
      #expect(decimalValue == Decimal(string: "123.456"))
    }

    /// Integer as decimal
    do {
      var stream = JSON.DecodingStream()
      stream.push("42")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      let decimalValue = try number.decode(as: Decimal.self)
      #expect(decimalValue == Decimal(42))
    }

    /// Negative decimal
    do {
      var stream = JSON.DecodingStream()
      stream.push("-99.99")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      let decimalValue = try number.decode(as: Decimal.self)
      #expect(decimalValue == Decimal(string: "-99.99"))
    }

    /// Zero
    do {
      var stream = JSON.DecodingStream()
      stream.push("0")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      let decimalValue = try number.decode(as: Decimal.self)
      #expect(decimalValue == Decimal(0))
    }

    /// Very large decimal
    do {
      var stream = JSON.DecodingStream()
      stream.push("123456789012345678901234567890.123456789")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      let decimalValue = try number.decode(as: Decimal.self)
      #expect(decimalValue == Decimal(string: "123456789012345678901234567890.123456789"))
    }
  }

  @Test
  func decimalWithExponentDecodingTest() async throws {
    /// Decimal with positive exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("1.23e2")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      let decimalValue = try number.decode(as: Decimal.self)
      #expect(decimalValue == Decimal(123))
    }

    /// Decimal with negative exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("1.5e-1")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      let decimalValue = try number.decode(as: Decimal.self)
      #expect(decimalValue == Decimal(string: "0.15"))
    }

    /// Integer with exponent as decimal
    do {
      var stream = JSON.DecodingStream()
      stream.push("5e3")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      let decimalValue = try number.decode(as: Decimal.self)
      #expect(decimalValue == Decimal(5000))
    }

    /// Zero exponent
    do {
      var stream = JSON.DecodingStream()
      stream.push("42.5e0")
      stream.finish()

      let number = try stream.decodeNumber().getValue()

      let decimalValue = try number.decode(as: Decimal.self)
      #expect(decimalValue == Decimal(string: "42.5"))
    }
  }

  @Test
  func decimalErrorTest() async throws {
    /// Invalid decimal format
    do {
      let number = JSON.Number(
        stringValue: "invalid",
        significand: "invalid",
        integerPart: "invalid",
        fractionalPart: nil,
        exponent: nil
      )

      #expect(throws: (any Error).self) {
        try number.decode(as: Decimal.self)
      }
    }

    /// Invalid exponent format
    do {
      let number = JSON.Number(
        stringValue: "1.5einvalid",
        significand: "1.5",
        integerPart: "1",
        fractionalPart: "5",
        exponent: "invalid"
      )

      #expect(throws: (any Error).self) {
        try number.decode(as: Decimal.self)
      }
    }
  }
}

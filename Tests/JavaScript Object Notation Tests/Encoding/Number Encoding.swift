import Foundation
import Testing

@testable import JavaScriptObjectNotation

@Suite
struct NumberEncoding {

  // MARK: - Integers

  @Test
  func zero() {
    let result = encode { stream in
      stream.encode(0)
    }
    #expect(result == "0")
  }

  @Test
  func positiveInteger() {
    let result = encode { stream in
      stream.encode(42)
    }
    #expect(result == "42")
  }

  @Test
  func negativeInteger() {
    let result = encode { stream in
      stream.encode(-1)
    }
    #expect(result == "-1")
  }

  @Test
  func largeInteger() {
    let result = encode { stream in
      stream.encode(Int.max)
    }
    #expect(result == "\(Int.max)")
  }

  @Test
  func largeNegativeInteger() {
    let result = encode { stream in
      stream.encode(Int.min)
    }
    #expect(result == "\(Int.min)")
  }

  @Test
  func int8() {
    let result = encode { stream in
      stream.encode(Int8(127))
    }
    #expect(result == "127")
  }

  @Test
  func int16() {
    let result = encode { stream in
      stream.encode(Int16(-32768))
    }
    #expect(result == "-32768")
  }

  @Test
  func int32() {
    let result = encode { stream in
      stream.encode(Int32(100_000))
    }
    #expect(result == "100000")
  }

  @Test
  func int64() {
    let result = encode { stream in
      stream.encode(Int64(-999))
    }
    #expect(result == "-999")
  }

  @Test
  func uint8() {
    let result = encode { stream in
      stream.encode(UInt8(255))
    }
    #expect(result == "255")
  }

  @Test
  func uint16() {
    let result = encode { stream in
      stream.encode(UInt16(65535))
    }
    #expect(result == "65535")
  }

  @Test
  func uint32() {
    let result = encode { stream in
      stream.encode(UInt32(0))
    }
    #expect(result == "0")
  }

  @Test
  func uint64() {
    let result = encode { stream in
      stream.encode(UInt64.max)
    }
    #expect(result == "\(UInt64.max)")
  }

  @Test
  func uint() {
    let result = encode { stream in
      stream.encode(UInt(42))
    }
    #expect(result == "42")
  }

  // MARK: - Floating Point

  @Test
  func double() throws {
    let result = try encode { stream in
      try stream.encode(3.14)
    }
    #expect(result == "3.14")
  }

  @Test
  func doubleWholeNumber() throws {
    let result = try encode { stream in
      try stream.encode(Double(42))
    }
    #expect(result == "42.0")
  }

  @Test
  func negativeDouble() throws {
    let result = try encode { stream in
      try stream.encode(-0.5)
    }
    #expect(result == "-0.5")
  }

  @Test
  func float32() throws {
    let result = try encode { stream in
      try stream.encode(Float32(1.5))
    }
    #expect(result == "1.5")
  }

  @Test
  func float16() throws {
    let result = try encode { stream in
      try stream.encode(Float16(1.0))
    }
    #expect(result == "1.0")
  }

  @Test
  func doubleNaN() {
    #expect(throws: EncodingError.numberIsNaN) {
      try encode { stream in
        try stream.encode(Double.nan)
      }
    }
  }

  @Test
  func doubleInfinity() {
    #expect(throws: EncodingError.numberIsInfinite) {
      try encode { stream in
        try stream.encode(Double.infinity)
      }
    }
  }

  @Test
  func doubleNegativeInfinity() {
    #expect(throws: EncodingError.numberIsInfinite) {
      try encode { stream in
        try stream.encode(-Double.infinity)
      }
    }
  }

  @Test
  func float32NaN() {
    #expect(throws: EncodingError.numberIsNaN) {
      try encode { stream in
        try stream.encode(Float32.nan)
      }
    }
  }

  @Test
  func float16NaN() {
    #expect(throws: EncodingError.numberIsNaN) {
      try encode { stream in
        try stream.encode(Float16.nan)
      }
    }
  }

  // MARK: - Decimal

  @Test
  func decimal() throws {
    let result = try encode { stream in
      try stream.encode(Decimal(string: "123.456")!)
    }
    #expect(result == "123.456")
  }

  @Test
  func decimalNaN() {
    #expect(throws: EncodingError.numberIsNaN) {
      try encode { stream in
        try stream.encode(Decimal.nan)
      }
    }
  }

}

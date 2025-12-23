import Foundation
import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Primitive Schemas")
struct PrimitiveSchemaTests {

  // MARK: - Boolean

  @Suite("Boolean")
  struct BooleanTests {

    @Test
    func trueValue() throws {
      try test(true, isCodedAs: "true")
    }

    @Test
    func falseValue() throws {
      try test(false, isCodedAs: "false")
    }

  }

  // MARK: - Integer

  @Suite("Integer")
  struct IntegerTests {

    @Test
    func zero() throws {
      try test(0, isCodedAs: "0")
    }

    @Test
    func positiveInt() throws {
      try test(42, isCodedAs: "42")
    }

    @Test
    func negativeInt() throws {
      try test(-123, isCodedAs: "-123")
    }

    @Test
    func largeInt() throws {
      try test(Int.max, isCodedAs: "\(Int.max)")
    }

    @Test
    func int8() throws {
      try test(Int8(127), isCodedAs: "127")
      try test(Int8(-128), isCodedAs: "-128")
    }

    @Test
    func int16() throws {
      try test(Int16(32767), isCodedAs: "32767")
    }

    @Test
    func int32() throws {
      try test(Int32(2_147_483_647), isCodedAs: "2147483647")
    }

    @Test
    func int64() throws {
      try test(Int64(9_223_372_036_854_775_807), isCodedAs: "9223372036854775807")
    }

    @Test
    func uint() throws {
      try test(UInt(42), isCodedAs: "42")
    }

    @Test
    func uint8() throws {
      try test(UInt8(255), isCodedAs: "255")
    }

    @Test
    func uint16() throws {
      try test(UInt16(65535), isCodedAs: "65535")
    }

    @Test
    func uint32() throws {
      try test(UInt32(4_294_967_295), isCodedAs: "4294967295")
    }

    @Test
    func uint64() throws {
      try test(UInt64(18_446_744_073_709_551_615), isCodedAs: "18446744073709551615")
    }

  }

  // MARK: - Number

  @Suite("Number")
  struct NumberTests {

    @Test
    func doubleZero() throws {
      try test(0.0, isCodedAs: "0.0")
    }

    @Test
    func positiveDouble() throws {
      try test(3.14159, isCodedAs: "3.14159")
    }

    @Test
    func negativeDouble() throws {
      try test(-2.71828, isCodedAs: "-2.71828")
    }

    @Test
    func floatValue() throws {
      try test(Float(1.5), isCodedAs: "1.5")
    }

    @Test
    func float16Value() throws {
      try test(Float16(2.5), isCodedAs: "2.5")
    }

    @Test
    func decimalValue() throws {
      try test(Decimal(string: "123.456")!, isCodedAs: "123.456")
    }

    @Test
    func decimalInteger() throws {
      try test(Decimal(42), isCodedAs: "42")
    }

  }

  // MARK: - Null

  @Suite("Null")
  struct NullTests {

    @Test
    func nullValue() throws {
      try SchemaCoding.Support.NullSchema().test((), isCodedAs: "null")
    }

  }

  // MARK: - String

  @Suite("String")
  struct StringTests {

    @Test
    func stringValue() throws {
      try test("hello", isCodedAs: "\"hello\"")
    }

  }

}

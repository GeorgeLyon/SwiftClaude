import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Integer")
struct IntegerSchemaTests {

  @Test("Int")
  private func testInt() throws {
    try test(42, isCodedAs: "42")
    try test(0, isCodedAs: "0")
    try test(-100, isCodedAs: "-100")
  }

  @Test("Int8")
  private func testInt8() throws {
    try test(Int8(127), isCodedAs: "127")
    try test(Int8(0), isCodedAs: "0")
    try test(Int8(-128), isCodedAs: "-128")
  }

  @Test("Int16")
  private func testInt16() throws {
    try test(Int16(32767), isCodedAs: "32767")
    try test(Int16(0), isCodedAs: "0")
    try test(Int16(-32768), isCodedAs: "-32768")
  }

  @Test("Int32")
  private func testInt32() throws {
    try test(Int32(2_147_483_647), isCodedAs: "2147483647")
    try test(Int32(0), isCodedAs: "0")
    try test(Int32(-2_147_483_648), isCodedAs: "-2147483648")
  }

  @Test("Int64")
  private func testInt64() throws {
    try test(Int64(9_223_372_036_854_775_807), isCodedAs: "9223372036854775807")
    try test(Int64(0), isCodedAs: "0")
    try test(Int64(-9_223_372_036_854_775_808), isCodedAs: "-9223372036854775808")
  }

  @Test("UInt")
  private func testUInt() throws {
    try test(UInt(42), isCodedAs: "42")
    try test(UInt(0), isCodedAs: "0")
    try test(UInt.max, isCodedAs: "\(UInt.max)")
  }

  @Test("UInt8")
  private func testUInt8() throws {
    try test(UInt8(255), isCodedAs: "255")
    try test(UInt8(0), isCodedAs: "0")
    try test(UInt8(128), isCodedAs: "128")
  }

  @Test("UInt16")
  private func testUInt16() throws {
    try test(UInt16(65535), isCodedAs: "65535")
    try test(UInt16(0), isCodedAs: "0")
    try test(UInt16(32768), isCodedAs: "32768")
  }

  @Test("UInt32")
  private func testUInt32() throws {
    try test(UInt32(4_294_967_295), isCodedAs: "4294967295")
    try test(UInt32(0), isCodedAs: "0")
    try test(UInt32(2_147_483_648), isCodedAs: "2147483648")
  }

  @Test("UInt64")
  private func testUInt64() throws {
    try test(UInt64(18_446_744_073_709_551_615), isCodedAs: "18446744073709551615")
    try test(UInt64(0), isCodedAs: "0")
    try test(UInt64(9_223_372_036_854_775_808), isCodedAs: "9223372036854775808")
  }

  @Test("Non-roundtripping exponential notation")
  private func testExponentialNotation() throws {
    // Integer values represented with exponential notation should decode correctly
    // even though they won't re-encode with the same notation
    try test("1e5", decodesAs: 100000)
    try test("1.5e3", decodesAs: 1500)
    try test("2e10", decodesAs: 20_000_000_000)
    try test("-1e4", decodesAs: -10000)
    try test("3.14e2", decodesAs: 314)
    try test("1.23456e6", decodesAs: 1_234_560)

    // Test with different integer types
    try test("1e2", decodesAs: Int8(100))
    try test("1.27e2", decodesAs: Int8(127))
    try test("3e4", decodesAs: Int16(30000))
    try test("2e9", decodesAs: Int32(2_000_000_000))
    try test("5e15", decodesAs: Int64(5_000_000_000_000_000))

    // Test with unsigned types
    try test("2.55e2", decodesAs: UInt8(255))
    try test("6e4", decodesAs: UInt16(60000))
    try test("4e9", decodesAs: UInt32(4_000_000_000))
    try test("1e19", decodesAs: UInt64(10_000_000_000_000_000_000))
  }

  @Test
  private func testSchema() throws {
    try SchemaCoding.Support
      .schema(
        representing: Int.self
      )
      .test(encodesAs: #"{"type":"integer"}"#)

    try SchemaCoding.Support
      .schema(
        representing: Int.self,
        description: "An integer"
      )
      .test(encodesAs: #"{"description":"An integer","type":"integer"}"#)

    try SchemaCoding.Support
      .schema(
        representing: UInt.self
      )
      .test(encodesAs: #"{"type":"integer"}"#)

    try SchemaCoding.Support
      .schema(
        representing: Int64.self
      )
      .test(encodesAs: #"{"type":"integer"}"#)
  }

}

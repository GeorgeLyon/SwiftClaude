import SchemaCodingTestSupport
import Testing

@testable import JSONSupport
@testable import SchemaCoding

@Suite("Constant")
struct ConstantSchemaTests {

  @Test
  private func testIntegerConstant() throws {
    let schema = SchemaCoding.Support.schema(
      constantValue: 42
    )
    try schema.test((), isCodedAs: "42")
  }

  @Test
  private func testStringConstant() throws {
    let schema = SchemaCoding.Support.schema(
      constantValue: "hello"
    )
    try schema.test((), isCodedAs: "\"hello\"")
  }

  @Test
  private func testBooleanConstant() throws {
    let trueSchema = SchemaCoding.Support.schema(
      constantValue: true
    )
    try trueSchema.test((), isCodedAs: "true")

    let falseSchema = SchemaCoding.Support.schema(
      constantValue: false
    )
    try falseSchema.test((), isCodedAs: "false")
  }

  @Test
  private func testDoubleConstant() throws {
    let schema = SchemaCoding.Support.schema(
      constantValue: 3.14
    )
    try schema.test((), isCodedAs: "3.14")
  }

  @Test
  private func testOptionalStringConstant() throws {
    let schema = SchemaCoding.Support.schema(
      constantValue: "value" as String?
    )
    try schema.test((), isCodedAs: "\"value\"")
  }

  @Test
  private func testEmptyStringConstant() throws {
    let schema = SchemaCoding.Support.schema(
      constantValue: ""
    )
    try schema.test((), isCodedAs: "\"\"")
  }

  @Test
  private func testNegativeIntegerConstant() throws {
    let schema = SchemaCoding.Support.schema(
      constantValue: -17
    )
    try schema.test((), isCodedAs: "-17")
  }

  @Test
  private func testZeroConstant() throws {
    let intSchema = SchemaCoding.Support.schema(
      constantValue: 0
    )
    try intSchema.test((), isCodedAs: "0")

    let doubleSchema = SchemaCoding.Support.schema(
      constantValue: 0.0
    )
    try doubleSchema.test((), isCodedAs: "0.0")
  }

  @Test
  private func testFloatConstant() throws {
    let schema = SchemaCoding.Support.schema(
      constantValue: Float(2.5)
    )
    try schema.test((), isCodedAs: "2.5")
  }

  @Test("Constant with special characters in string")
  private func testSpecialCharactersConstant() throws {
    let newlineSchema = SchemaCoding.Support.schema(
      constantValue: "hello\nworld"
    )
    try newlineSchema.test((), isCodedAs: "\"hello\\nworld\"")

    let tabSchema = SchemaCoding.Support.schema(
      constantValue: "tab\there"
    )
    try tabSchema.test((), isCodedAs: "\"tab\\there\"")

    let quoteSchema = SchemaCoding.Support.schema(
      constantValue: "quote\"here"
    )
    try quoteSchema.test((), isCodedAs: "\"quote\\\"here\"")

    let backslashSchema = SchemaCoding.Support.schema(
      constantValue: "backslash\\test"
    )
    try backslashSchema.test((), isCodedAs: "\"backslash\\\\test\"")
  }

  @Test("Constant with Unicode characters")
  private func testUnicodeConstant() throws {
    let schema = SchemaCoding.Support.schema(
      constantValue: "unicode: 👍"
    )
    try schema.test((), isCodedAs: "\"unicode: 👍\"")
  }

  @Test("Decoding constants from chunked JSON")
  private func testChunkedDecoding() throws {
    let intSchema = SchemaCoding.Support.schema(
      constantValue: 42
    )
    try intSchema.test(["4", "2"], decodesAs: ())

    let stringSchema = SchemaCoding.Support.schema(
      constantValue: "hello"
    )
    try stringSchema.test(["\"he", "llo\""], decodesAs: ())
    try stringSchema.test(["\"", "hello", "\""], decodesAs: ())
  }

  @Test
  private func testLargeIntegerConstant() throws {
    let schema = SchemaCoding.Support.schema(
      constantValue: 999_999_999
    )
    try schema.test((), isCodedAs: "999999999")
  }

  @Test
  private func testVerySmallDoubleConstant() throws {
    let schema = SchemaCoding.Support.schema(
      constantValue: 0.0000001
    )
    try schema.test((), isCodedAs: "1e-07")
    try schema.test("0.0000001", decodesAs: ())
  }

  @Test
  private func testConstantWithWhitespace() throws {
    let intSchema = SchemaCoding.Support.schema(
      constantValue: 42
    )
    try intSchema.test(" 42 ", decodesAs: ())
    try intSchema.test("\n42\n", decodesAs: ())
    try intSchema.test("\t42", decodesAs: ())

    let stringSchema = SchemaCoding.Support.schema(
      constantValue: "test"
    )
    try stringSchema.test(" \"test\" ", decodesAs: ())
    try stringSchema.test("\n\"test\"\n", decodesAs: ())
  }

  @Test
  private func testArrayConstant() throws {
    let constantSchema = SchemaCoding.Support.schema(
      constantValue: [1, 2, 3]
    )
    try constantSchema.test((), isCodedAs: "[1,2,3]")
    try constantSchema.test("[ 1 , 2 , 3 ]", decodesAs: ())
  }

  @Test
  private func testEmptyArrayConstant() throws {
    let constantSchema = SchemaCoding.Support.schema(
      constantValue: [] as [String]
    )
    try constantSchema.test((), isCodedAs: "[]")
    try constantSchema.test("[ ]", decodesAs: ())
  }

}

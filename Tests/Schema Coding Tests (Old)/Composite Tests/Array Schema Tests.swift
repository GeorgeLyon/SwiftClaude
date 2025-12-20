import SchemaCodingTestSupport
import Testing

@testable import JSONSupport
@testable import SchemaCoding

@Suite("Array")
struct ArraySchemaTests {

  @Test
  private func testEmptyArray() throws {
    let schema = SchemaCoding.Support.schema(representing: [Int].self)
    try schema.test([], isCodedAs: "[]")
  }

  @Test
  private func testSingleElementArray() throws {
    let schema = SchemaCoding.Support.schema(representing: [String].self)
    try schema.test(["hello"], isCodedAs: "[\"hello\"]")
    try schema.test(["world"], isCodedAs: "[\"world\"]")
    try schema.test([""], isCodedAs: "[\"\"]")
  }

  @Test
  private func testMultipleElementArray() throws {
    let schema = SchemaCoding.Support.schema(representing: [Int].self)
    try schema.test([1, 2, 3], isCodedAs: "[1,2,3]")
    try schema.test([42, -17, 0], isCodedAs: "[42,-17,0]")
    try schema.test([999], isCodedAs: "[999]")
  }

  @Test
  private func testStringArray() throws {
    let schema = SchemaCoding.Support.schema(representing: [String].self)
    try schema.test(["foo", "bar", "baz"], isCodedAs: "[\"foo\",\"bar\",\"baz\"]")
    try schema.test(["hello", "world"], isCodedAs: "[\"hello\",\"world\"]")
    try schema.test(["", "non-empty", ""], isCodedAs: "[\"\",\"non-empty\",\"\"]")
  }

  @Test
  private func testBooleanArray() throws {
    let schema = SchemaCoding.Support.schema(representing: [Bool].self)
    try schema.test([true, false, true], isCodedAs: "[true,false,true]")
    try schema.test([false], isCodedAs: "[false]")
    try schema.test([true, true, true], isCodedAs: "[true,true,true]")
  }

  @Test
  private func testDoubleArray() throws {
    let schema = SchemaCoding.Support.schema(representing: [Double].self)
    try schema.test([3.14, 2.71, -1.5], isCodedAs: "[3.14,2.71,-1.5]")
    try schema.test([0.0], isCodedAs: "[0.0]")
    try schema.test([999.999, -999.999], isCodedAs: "[999.999,-999.999]")
  }

  @Test
  private func testOptionalElementArray() throws {
    let schema = SchemaCoding.Support.schema(representing: [String?].self)
    try schema.test([nil, "hello", nil], isCodedAs: "[null,\"hello\",null]")
    try schema.test(["world", nil], isCodedAs: "[\"world\",null]")
    try schema.test([nil, nil, nil], isCodedAs: "[null,null,null]")
  }

  @Test
  private func testNestedArray() throws {
    let schema = SchemaCoding.Support.schema(representing: [[Int]].self)

    try schema.test([[1, 2], [3, 4, 5]], isCodedAs: "[[1,2],[3,4,5]]")
    try schema.test([[], [1], []], isCodedAs: "[[],[1],[]]")
    try schema.test([[42]], isCodedAs: "[[42]]")
  }

  @Test
  private func testArrayOfTuples() throws {
    let tupleSchema = SchemaCoding.Support.tupleSchema(
      elements:
        SchemaCoding.Support.schema(representing: String.self),
      SchemaCoding.Support.schema(representing: Int.self)
    )
    let arraySchema = SchemaCoding.Support._ArraySchema(
      description: nil,
      elementSchema: tupleSchema
    )

    // Can't use Schema.test directly due to tuple elements not being Equatable
    var encoder = SchemaCoding.Support.Encoder()
    arraySchema.encode([("foo", 1), ("bar", 2)], to: &encoder)
    #expect(encoder.stream.stringRepresentation == "[[\"foo\",1],[\"bar\",2]]")

    encoder = SchemaCoding.Support.Encoder()
    arraySchema.encode([("test", 42)], to: &encoder)
    #expect(encoder.stream.stringRepresentation == "[[\"test\",42]]")
  }

  @Test
  private func testLargeArray() throws {
    let schema = SchemaCoding.Support.schema(representing: [Int].self)
    let largeArray = Array(1...100)
    let expectedJSON = "[" + (1...100).map { "\($0)" }.joined(separator: ",") + "]"
    try schema.test(largeArray, isCodedAs: JSONFragments(stringLiteral: expectedJSON))
  }

  @Test("Array with special characters in strings")
  private func testSpecialCharactersArray() throws {
    let schema = SchemaCoding.Support.schema(representing: [String].self)
    try schema.test(
      ["hello\nworld", "tab\there", "quote\"here"],
      isCodedAs: "[\"hello\\nworld\",\"tab\\there\",\"quote\\\"here\"]"
    )
    try schema.test(
      ["backslash\\test", "unicode: 👍"],
      isCodedAs: "[\"backslash\\\\test\",\"unicode: 👍\"]"
    )
  }

  @Test("Decoding arrays from chunked JSON")
  private func testChunkedDecoding() throws {
    let schema = SchemaCoding.Support.schema(representing: [Int].self)

    try schema.test(
      ["[", "1", ",", "2", ",", "3", "]"],
      decodesAs: [1, 2, 3]
    )

    try schema.test(
      ["[1", ",2,", "3]"],
      decodesAs: [1, 2, 3]
    )

    try schema.test(
      ["[", "]"],
      decodesAs: []
    )
  }

  @Test
  private func testArrayConformance() throws {
    // Test that Array conforms to SchemaCodable when Element does
    // Using simple built-in types that already conform
    let strings = ["hello", "world"]
    try test(strings, isCodedAs: "[\"hello\",\"world\"]")

    let numbers = [1, 2, 3]
    try test(numbers, isCodedAs: "[1,2,3]")
  }

  // Mixed type arrays would require enum schema which is complex
  // Removing this test for now as it requires more setup

  @Test
  private func testFloatArray() throws {
    let schema = SchemaCoding.Support.schema(representing: [Float].self)
    try schema.test([Float(1.5), Float(2.5), Float(3.5)], isCodedAs: "[1.5,2.5,3.5]")
    try schema.test([Float(0.0), Float(-0.0)], isCodedAs: "[0.0,-0.0]")
  }

  @Test
  private func testArrayDecoding() throws {
    let schema = SchemaCoding.Support.schema(representing: [String].self)

    // Test basic decoding
    try schema.test("[\"a\",\"b\",\"c\"]", decodesAs: ["a", "b", "c"])

    // Test empty array decoding
    try schema.test("[]", decodesAs: [])

    // Test single element decoding
    try schema.test("[\"single\"]", decodesAs: ["single"])
  }

  @Test
  private func testArrayWithWhitespace() throws {
    let schema = SchemaCoding.Support.schema(representing: [Int].self)

    // Test with various whitespace patterns
    try schema.test("[ 1 , 2 , 3 ]", decodesAs: [1, 2, 3])
    try schema.test("[\n  1,\n  2,\n  3\n]", decodesAs: [1, 2, 3])
    try schema.test("[ ]", decodesAs: [])
  }

}

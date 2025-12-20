import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Array Schema")
struct ArraySchemaTests {

  @Test
  func emptyArray() throws {
    let schema = SchemaCoding.Support.schema(representing: [String].self)
    try schema.test([], isCodedAs: "[]")
  }

  @Test
  func singleElementArray() throws {
    let schema = SchemaCoding.Support.schema(representing: [String].self)
    try schema.test(["hello"], isCodedAs: "[\"hello\"]")
    try schema.test(["world"], isCodedAs: "[\"world\"]")
    try schema.test([""], isCodedAs: "[\"\"]")
  }

  @Test
  func multipleElementArray() throws {
    let schema = SchemaCoding.Support.schema(representing: [String].self)
    try schema.test(["foo", "bar", "baz"], isCodedAs: "[\"foo\",\"bar\",\"baz\"]")
    try schema.test(["hello", "world"], isCodedAs: "[\"hello\",\"world\"]")
  }

  @Test
  func nestedArray() throws {
    let schema = SchemaCoding.Support.schema(representing: [[String]].self)
    try schema.test([["a", "b"], ["c"]], isCodedAs: "[[\"a\",\"b\"],[\"c\"]]")
    try schema.test([[], ["x"], []], isCodedAs: "[[],[\"x\"],[]]")
    try schema.test([[]], isCodedAs: "[[]]")
  }

  @Test
  func arrayConformance() throws {
    try test(["hello", "world"], isCodedAs: "[\"hello\",\"world\"]")
    try test(["a", "b", "c"], isCodedAs: "[\"a\",\"b\",\"c\"]")
  }

  @Test
  func arrayDecoding() throws {
    let schema = SchemaCoding.Support.schema(representing: [String].self)
    try schema.test("[\"a\",\"b\",\"c\"]", decodesAs: ["a", "b", "c"])
    try schema.test("[]", decodesAs: [])
    try schema.test("[\"single\"]", decodesAs: ["single"])
  }

  @Test
  func arrayWithWhitespace() throws {
    let schema = SchemaCoding.Support.schema(representing: [String].self)
    try schema.test("[ \"a\" , \"b\" , \"c\" ]", decodesAs: ["a", "b", "c"])
    try schema.test("[\n  \"a\",\n  \"b\"\n]", decodesAs: ["a", "b"])
    try schema.test("[ ]", decodesAs: [])
  }

  @Test
  func chunkedDecoding() throws {
    let schema = SchemaCoding.Support.schema(representing: [String].self)

    try schema.test(
      ["[", "\"a\"", ",", "\"b\"", "]"],
      decodesAs: ["a", "b"]
    )

    try schema.test(
      ["[\"a", "\",\"b", "\"]"],
      decodesAs: ["a", "b"]
    )

    try schema.test(
      ["[", "]"],
      decodesAs: []
    )
  }

  @Test
  func specialCharactersInStrings() throws {
    let schema = SchemaCoding.Support.schema(representing: [String].self)
    try schema.test(
      ["hello\nworld", "tab\there"],
      isCodedAs: "[\"hello\\nworld\",\"tab\\there\"]"
    )
    try schema.test(
      ["quote\"here", "backslash\\test"],
      isCodedAs: "[\"quote\\\"here\",\"backslash\\\\test\"]"
    )
  }

  @Test
  func largeArray() throws {
    let schema = SchemaCoding.Support.schema(representing: [String].self)
    let elements = (1...50).map { "item\($0)" }
    let expectedJSON = "[" + elements.map { "\"\($0)\"" }.joined(separator: ",") + "]"
    try schema.test(elements, isCodedAs: JSONFragments(stringLiteral: expectedJSON))
  }

}

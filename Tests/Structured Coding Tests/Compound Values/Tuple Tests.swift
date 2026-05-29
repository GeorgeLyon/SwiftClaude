import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

@Suite("Tuple Decoding")
struct TupleDecodingTests {

  // MARK: - Empty

  @Test func decodesEmptyTuple() throws {
    try test("[]", decodesAs: StructuredTuple())
  }

  @Test func decodesEmptyTupleWithInternalWhitespace() throws {
    try test("[ ]", decodesAs: StructuredTuple())
  }

  // MARK: - Single Element

  @Test func decodesSingleIntElement() throws {
    try test("[42]", decodesAs: StructuredTuple<Int>(42))
  }

  @Test func decodesSingleStringElement() throws {
    try test(#"["hello"]"#, decodesAs: StructuredTuple<String>("hello"))
  }

  @Test func decodesSingleBoolElement() throws {
    try test("[true]", decodesAs: StructuredTuple<Bool>(true))
  }

  // MARK: - Multiple Elements

  @Test func decodesPairOfInts() throws {
    try test("[1,2]", decodesAs: StructuredTuple<Int, Int>(1, 2))
  }

  @Test func decodesMixedElementTypes() throws {
    try test(#"[1,"hello",true]"#, decodesAs: StructuredTuple<Int, String, Bool>(1, "hello", true))
  }

  @Test func decodesHeterogeneousNumericAndString() throws {
    try test(#"[1.5,"text",42]"#, decodesAs: StructuredTuple<Double, String, Int>(1.5, "text", 42))
  }

  // MARK: - Whitespace

  @Test func decodesWithSurroundingAndInternalWhitespace() throws {
    try test(#"[ 1 , "two" , 3 ]"#, decodesAs: StructuredTuple<Int, String, Int>(1, "two", 3))
  }

  @Test func decodesWithMultilineWhitespace() throws {
    try test(
      """
      [
        1,
        "two",
        3
      ]
      """,
      decodesAs: StructuredTuple<Int, String, Int>(1, "two", 3)
    )
  }

  @Test func decodesWithLeadingAndTrailingWhitespace() throws {
    try test(#"  [1,"two",3]  "#, decodesAs: StructuredTuple<Int, String, Int>(1, "two", 3))
  }

  // MARK: - Unicode & Escapes

  @Test func decodesUnicodeStringElement() throws {
    try test(#"["日本語",1]"#, decodesAs: StructuredTuple<String, Int>("日本語", 1))
  }

  @Test func decodesEscapedStringElement() throws {
    try test(#"["line1\nline2",42]"#, decodesAs: StructuredTuple<String, Int>("line1\nline2", 42))
  }

  // MARK: - Nested Compound Elements

  @Test func decodesTupleContainingArray() throws {
    try test(#"[[1,2,3],"end"]"#, decodesAs: StructuredTuple<[Int], String>([1, 2, 3], "end"))
  }

  @Test func decodesTupleContainingEmptyArray() throws {
    try test(#"[[],"end"]"#, decodesAs: StructuredTuple<[Int], String>([], "end"))
  }

  // MARK: - Errors

  @Test func tooFewElementsThrows() throws {
    #expect(throws: (any Error).self) {
      try test("[1,2]", decodesAs: StructuredTuple<Int, Int, Int>(1, 2, 3))
    }
  }

  @Test func tooManyElementsThrows() throws {
    #expect(throws: (any Error).self) {
      try test("[1,2,3]", decodesAs: StructuredTuple<Int, Int>(1, 2))
    }
  }

  @Test func emptyArrayWhenElementsExpectedThrows() throws {
    #expect(throws: (any Error).self) {
      try test("[]", decodesAs: StructuredTuple<Int>(0))
    }
  }

  @Test func wrongElementTypeThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#"[1,"two"]"#, decodesAs: StructuredTuple<Int, Int>(1, 2))
    }
  }

  @Test func unterminatedArrayThrows() throws {
    #expect(throws: (any Error).self) {
      try test("[1,2", decodesAs: StructuredTuple<Int, Int>(1, 2))
    }
  }

  @Test func missingOpenBracketThrows() throws {
    #expect(throws: (any Error).self) {
      try test("1,2]", decodesAs: StructuredTuple<Int, Int>(1, 2))
    }
  }

  // MARK: - Streaming (non-streaming type)

  /// `StructuredTuple` is not streamable, so it cannot expose a partial value mid-stream.
  @Test func partialBeforeCloseBracketIsIncomplete() throws {
    try test("[1,2", decodesAs: .incomplete as DecodingOutcome<StructuredTuple<Int, Int>>)
  }

  @Test func streamingChunkedAcrossElementValue() throws {
    try test([#"["hel"#, #"lo",4"#, #"2]"#], decodesAs: StructuredTuple<String, Int>("hello", 42))
  }

  @Test func streamingChunkedAcrossElementSeparator() throws {
    try test([#"[1"#, #",2,3]"#], decodesAs: StructuredTuple<Int, Int, Int>(1, 2, 3))
  }

  @Test func streamingChunkedAcrossOpenBracket() throws {
    try test([#"["#, #"1,2]"#], decodesAs: StructuredTuple<Int, Int>(1, 2))
  }

}

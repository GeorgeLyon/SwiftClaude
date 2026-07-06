import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// An object with a tuple-typed property — instantiating its property
/// descriptors forces `StructuredTuple`'s `Schema` witness. The witness is
/// safe to demangle because `StructuredTupleSchema` is non-generic: a schema
/// type parameterized by the element pack would put a pack expansion in the
/// witness mangling, which crashes the runtime demangler.
@StructuredCodable
private struct TuplePropertyObject {
  var pair: StructuredTuple<Int, String>
}

/// Resolves `Schema` through the protocol witness, the way generic code does —
/// this forces runtime demangling of the witness's mangled name.
private func resolvedSchemaType<T: StructuredEncodable>(of _: T.Type) -> Any.Type {
  T.Schema.self
}

/// Constructs a tuple's schema generically, without spelling the pack —
/// usable for the empty tuple, which has no explicit generic-argument syntax.
private func schema<each Element: StructuredDecodable>(
  of _: StructuredTuple<repeat each Element>
) -> StructuredTuple<repeat each Element>.Schema {
  StructuredTuple<repeat each Element>.schema(description: nil)
}

@Suite("Tuple Schema")
struct TupleSchemaTests {

  @Test func encodesPrefixItems() throws {
    try test(
      StructuredTuple<Int, String>.schema(description: nil),
      encodesAs: #"{"prefixItems":[{"type":"integer"},{"type":"string"}]}"#
    )
  }

  @Test func encodesDescription() throws {
    try test(
      StructuredTuple<Int, String>.schema(description: "A labeled pair"),
      encodesAs:
        #"{"description":"A labeled pair","prefixItems":[{"type":"integer"},{"type":"string"}]}"#
    )
  }

  @Test func encodesEmptyTupleSchema() throws {
    try test(
      schema(of: StructuredTuple()),
      encodesAs: #"{"prefixItems":[]}"#
    )
  }

  @Test func encodesNestedTupleSchema() throws {
    try test(
      StructuredTuple<Int, StructuredTuple<Bool, String>>.schema(description: nil),
      encodesAs:
        #"{"prefixItems":[{"type":"integer"},{"prefixItems":[{"type":"boolean"},{"type":"string"}]}]}"#
    )
  }
  
  /// Instantiating the property descriptor forces
  /// `Definition.CodingSchema == StructuredTuple<Int, String>.Schema`.
  @Test func tuplePropertyMetadataInstantiates() throws {
    _ = TuplePropertyObject.properties()
  }

  /// A tuple-typed property now contributes a structural schema rather than
  /// the `StructuredAnySchema` fallback's `{}`.
  @Test func tuplePropertySchemaEncodes() throws {
    try test(
      TuplePropertyObject.schema(description: nil),
      encodesAs:
        #"{"properties":{"pair":{"prefixItems":[{"type":"integer"},{"type":"string"}]}},"required":["pair"]}"#
    )
  }

  /// Schemas aren't `Equatable`, so decoding is verified by re-encoding —
  /// this exercises `PrefixItems`' hand-written `decode`.
  @Test func decodesByRoundTrip() throws {
    let json =
      #"{"description":"A labeled pair","prefixItems":[{"type":"integer"},{"type":"string"}]}"#
    try test(
      JSONFragments(stringLiteral: json),
      decodesAs: .complete(StructuredTuple<Int, String>.schema(description: nil)),
      testEquality: { decoded, _, sourceLocation in
        let decoded = try #require(decoded, sourceLocation: sourceLocation)
        var encoder = StructuredEncoder()
        try decoded.encode(to: &encoder)
        #expect(encoder.stringValue == json, sourceLocation: sourceLocation)
      }
    )
  }

}

@Suite("Tuple Encoding")
struct TupleEncodingTests {

  @Test func encodesEmptyTupleAsEmptyArray() throws {
    try test(StructuredTuple(), encodesAs: "[]")
  }

  @Test func encodesPairTuple() throws {
    try test(StructuredTuple<Int, String>(1, "two"), encodesAs: #"[1,"two"]"#)
  }

}

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

import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// An object with a tuple-typed property — instantiating its property
/// descriptors forces `StructuredTuple`'s `Schema` witness. The witness is
/// safe to demangle because the underlying schema type is non-generic: a
/// schema type parameterized by the element pack would put a pack expansion
/// in the witness mangling, which crashes the runtime demangler.
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
  StructuredTuple<repeat each Element>.schema
}

@Suite("Tuple Schema")
struct TupleSchemaTests {

  @Test func encodesPrefixItems() async throws {
    try await test(
      StructuredTuple<Int, String>.schema,
      encodesAs: #"{"prefixItems":[{"type":"integer"},{"type":"string"}]}"#
    )
  }

  @Test func encodesDescription() async throws {
    try await test(
      StructuredTuple<Int, String>.schema.prependDescription("A labeled pair"),
      encodesAs:
        #"{"description":"A labeled pair","prefixItems":[{"type":"integer"},{"type":"string"}]}"#
    )
  }

  @Test func encodesEmptyTupleSchema() async throws {
    try await test(
      schema(of: StructuredTuple()),
      encodesAs: #"{"prefixItems":[]}"#
    )
  }

  @Test func encodesNestedTupleSchema() async throws {
    try await test(
      StructuredTuple<Int, StructuredTuple<Bool, String>>.schema,
      encodesAs:
        #"{"prefixItems":[{"type":"integer"},{"prefixItems":[{"type":"boolean"},{"type":"string"}]}]}"#
    )
  }
  
  /// Instantiating the property descriptor forces
  /// `Definition.CodingSchema == StructuredTuple<Int, String>.Schema`.
  @Test func tuplePropertyMetadataInstantiates() async throws {
    _ = TuplePropertyObject.properties()
  }

  /// A tuple-typed property now contributes a structural schema rather than
  /// the any-schema fallback's `{}`.
  @Test func tuplePropertySchemaEncodes() async throws {
    try await test(
      TuplePropertyObject.schema,
      encodesAs:
        #"{"properties":{"pair":{"prefixItems":[{"type":"integer"},{"type":"string"}]}},"required":["pair"]}"#
    )
  }

  /// Schemas aren't `Equatable`, so decoding is verified by re-encoding —
  /// this exercises `PrefixItems`' hand-written `decode`.
  @Test func decodesByRoundTrip() async throws {
    let json =
      #"{"description":"A labeled pair","prefixItems":[{"type":"integer"},{"type":"string"}]}"#
    try await test(
      JSONFragments(stringLiteral: json),
      decodesAs: .complete(StructuredTuple<Int, String>.schema),
      testEquality: { decoded, _, sourceLocation in
        let decoded = try #require(decoded, sourceLocation: sourceLocation)
        var stream = StructuredEncodingStream()
        try decoded.encode(to: &stream)
        #expect(stream.stringValue == json, sourceLocation: sourceLocation)
      }
    )
  }

}

@Suite("Tuple Encoding")
struct TupleEncodingTests {

  @Test func encodesEmptyTupleAsEmptyArray() async throws {
    try await test(StructuredTuple(), encodesAs: "[]")
  }

  @Test func encodesPairTuple() async throws {
    try await test(StructuredTuple<Int, String>(1, "two"), encodesAs: #"[1,"two"]"#)
  }

}

@Suite("Tuple Decoding")
struct TupleDecodingTests {

  // MARK: - Empty

  @Test func decodesEmptyTuple() async throws {
    try await test("[]", decodesAs: StructuredTuple())
  }

  @Test func decodesEmptyTupleWithInternalWhitespace() async throws {
    try await test("[ ]", decodesAs: StructuredTuple())
  }

  // MARK: - Single Element

  @Test func decodesSingleIntElement() async throws {
    try await test("[42]", decodesAs: StructuredTuple<Int>(42))
  }

  @Test func decodesSingleStringElement() async throws {
    try await test(#"["hello"]"#, decodesAs: StructuredTuple<String>("hello"))
  }

  @Test func decodesSingleBoolElement() async throws {
    try await test("[true]", decodesAs: StructuredTuple<Bool>(true))
  }

  // MARK: - Multiple Elements

  @Test func decodesPairOfInts() async throws {
    try await test("[1,2]", decodesAs: StructuredTuple<Int, Int>(1, 2))
  }

  @Test func decodesMixedElementTypes() async throws {
    try await test(#"[1,"hello",true]"#, decodesAs: StructuredTuple<Int, String, Bool>(1, "hello", true))
  }

  @Test func decodesHeterogeneousNumericAndString() async throws {
    try await test(#"[1.5,"text",42]"#, decodesAs: StructuredTuple<Double, String, Int>(1.5, "text", 42))
  }

  // MARK: - Whitespace

  @Test func decodesWithSurroundingAndInternalWhitespace() async throws {
    try await test(#"[ 1 , "two" , 3 ]"#, decodesAs: StructuredTuple<Int, String, Int>(1, "two", 3))
  }

  @Test func decodesWithMultilineWhitespace() async throws {
    try await test(
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

  @Test func decodesWithLeadingAndTrailingWhitespace() async throws {
    try await test(#"  [1,"two",3]  "#, decodesAs: StructuredTuple<Int, String, Int>(1, "two", 3))
  }

  // MARK: - Unicode & Escapes

  @Test func decodesUnicodeStringElement() async throws {
    try await test(#"["日本語",1]"#, decodesAs: StructuredTuple<String, Int>("日本語", 1))
  }

  @Test func decodesEscapedStringElement() async throws {
    try await test(#"["line1\nline2",42]"#, decodesAs: StructuredTuple<String, Int>("line1\nline2", 42))
  }

  // MARK: - Nested Compound Elements

  @Test func decodesTupleContainingArray() async throws {
    try await test(#"[[1,2,3],"end"]"#, decodesAs: StructuredTuple<[Int], String>([1, 2, 3], "end"))
  }

  @Test func decodesTupleContainingEmptyArray() async throws {
    try await test(#"[[],"end"]"#, decodesAs: StructuredTuple<[Int], String>([], "end"))
  }

  // MARK: - Errors

  @Test func tooFewElementsThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test("[1,2]", decodesAs: StructuredTuple<Int, Int, Int>(1, 2, 3))
    }
  }

  @Test func tooManyElementsThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test("[1,2,3]", decodesAs: StructuredTuple<Int, Int>(1, 2))
    }
  }

  @Test func emptyArrayWhenElementsExpectedThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test("[]", decodesAs: StructuredTuple<Int>(0))
    }
  }

  @Test func wrongElementTypeThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test(#"[1,"two"]"#, decodesAs: StructuredTuple<Int, Int>(1, 2))
    }
  }

  @Test func unterminatedArrayThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test("[1,2", decodesAs: StructuredTuple<Int, Int>(1, 2))
    }
  }

  @Test func missingOpenBracketThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test("1,2]", decodesAs: StructuredTuple<Int, Int>(1, 2))
    }
  }

  // MARK: - Streaming (non-streaming type)

  /// `StructuredTuple` is not streamable, so it cannot expose a partial value mid-stream.
  @Test func partialBeforeCloseBracketIsIncomplete() async throws {
    try await test("[1,2", decodesAs: .incomplete as DecodingOutcome<StructuredTuple<Int, Int>>)
  }

  @Test func streamingChunkedAcrossElementValue() async throws {
    try await test([#"["hel"#, #"lo",4"#, #"2]"#], decodesAs: StructuredTuple<String, Int>("hello", 42))
  }

  @Test func streamingChunkedAcrossElementSeparator() async throws {
    try await test([#"[1"#, #",2,3]"#], decodesAs: StructuredTuple<Int, Int, Int>(1, 2, 3))
  }

  @Test func streamingChunkedAcrossOpenBracket() async throws {
    try await test([#"["#, #"1,2]"#], decodesAs: StructuredTuple<Int, Int>(1, 2))
  }

}

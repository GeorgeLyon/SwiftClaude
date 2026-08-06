import Testing

import StructuredCoding

@Suite("Optional")
struct OptionalTests {

  // MARK: - Encoding

  @Test
  func encodesNilAsEmptyObject() async throws {
    try await test(String?.none, encodesAs: "{}")
  }

  @Test
  func encodesSomeAsValueProperty() async throws {
    try await test(String?.some("hi"), encodesAs: #"{"value":"hi"}"#)
  }

  @Test
  func encodesSomeInt() async throws {
    try await test(Int?.some(42), encodesAs: #"{"value":42}"#)
  }

  @Test
  func encodesNestedOptional() async throws {
    try await test(Optional<Int?>.some(nil), encodesAs: #"{"value":{}}"#)
    try await test(Optional<Int?>.some(1), encodesAs: #"{"value":{"value":1}}"#)
  }

  // MARK: - Decoding

  @Test
  func decodesEmptyObjectAsNil() async throws {
    try await test("{}", decodesAs: String?.none)
  }

  @Test
  func decodesValuePropertyAsSome() async throws {
    try await test(#"{"value":"hi"}"#, decodesAs: String?.some("hi"))
  }

  @Test
  func decodesSomeInt() async throws {
    try await test(#"{"value":42}"#, decodesAs: Int?.some(42))
  }

  @Test
  func decodesNestedOptional() async throws {
    try await test(#"{"value":{}}"#, decodesAs: Optional<Int?>.some(nil))
    try await test(#"{"value":{"value":1}}"#, decodesAs: Optional<Int?>.some(1))
  }

  @Test
  func decodesWithWhitespace() async throws {
    try await test(#"{ "value" : "hi" }"#, decodesAs: String?.some("hi"))
  }

  @Test
  func decodesAcrossChunks() async throws {
    try await test([#"{"val"#, #"ue":"h"#, #"i"}"#], decodesAs: String?.some("hi"))
  }

  // MARK: - Partial Streaming

  @Test
  func isNilBeforeValueArrives() async throws {
    try await test("{", decodesAs: DecodingOutcome.partial(String?.none))
  }

  @Test
  func exposesPartialStreamingValue() async throws {
    // A streamed wrapped string surfaces all but the last buffered character.
    try await test(#"{"value":"hel"#, decodesAs: DecodingOutcome.partial(String?.some("he")))
  }

  // MARK: - Errors

  @Test
  func unknownPropertyThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test(#"{"other":1}"#, decodesAs: Int?.some(1))
    }
  }

  @Test
  func additionalPropertyThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test(#"{"value":1,"value":2}"#, decodesAs: Int?.some(1))
    }
  }

  @Test
  func bareValueThrows() async throws {
    // Optionals are encoded as objects, not bare values.
    await #expect(throws: (any Error).self) {
      try await test("42", decodesAs: Int?.some(42))
    }
  }

}

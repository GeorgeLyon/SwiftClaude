import Testing

import StructuredCoding

@Suite("Optional")
struct OptionalTests {

  // MARK: - Encoding

  @Test
  func encodesNilAsEmptyObject() throws {
    try test(String?.none, encodesAs: "{}")
  }

  @Test
  func encodesSomeAsValueProperty() throws {
    try test(String?.some("hi"), encodesAs: #"{"value":"hi"}"#)
  }

  @Test
  func encodesSomeInt() throws {
    try test(Int?.some(42), encodesAs: #"{"value":42}"#)
  }

  @Test
  func encodesNestedOptional() throws {
    try test(Optional<Int?>.some(nil), encodesAs: #"{"value":{}}"#)
    try test(Optional<Int?>.some(1), encodesAs: #"{"value":{"value":1}}"#)
  }

  // MARK: - Decoding

  @Test
  func decodesEmptyObjectAsNil() throws {
    try test("{}", decodesAs: String?.none)
  }

  @Test
  func decodesValuePropertyAsSome() throws {
    try test(#"{"value":"hi"}"#, decodesAs: String?.some("hi"))
  }

  @Test
  func decodesSomeInt() throws {
    try test(#"{"value":42}"#, decodesAs: Int?.some(42))
  }

  @Test
  func decodesNestedOptional() throws {
    try test(#"{"value":{}}"#, decodesAs: Optional<Int?>.some(nil))
    try test(#"{"value":{"value":1}}"#, decodesAs: Optional<Int?>.some(1))
  }

  @Test
  func decodesWithWhitespace() throws {
    try test(#"{ "value" : "hi" }"#, decodesAs: String?.some("hi"))
  }

  @Test
  func decodesAcrossChunks() throws {
    try test([#"{"val"#, #"ue":"h"#, #"i"}"#], decodesAs: String?.some("hi"))
  }

  // MARK: - Partial Streaming

  @Test
  func isNilBeforeValueArrives() throws {
    try test("{", decodesAs: DecodingOutcome.partial(String?.none))
  }

  @Test
  func exposesPartialStreamingValue() throws {
    // A streamed wrapped string surfaces all but the last buffered character.
    try test(#"{"value":"hel"#, decodesAs: DecodingOutcome.partial(String?.some("he")))
  }

  // MARK: - Errors

  @Test
  func unknownPropertyThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#"{"other":1}"#, decodesAs: Int?.some(1))
    }
  }

  @Test
  func additionalPropertyThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#"{"value":1,"value":2}"#, decodesAs: Int?.some(1))
    }
  }

  @Test
  func bareValueThrows() throws {
    // Optionals are encoded as objects, not bare values.
    #expect(throws: (any Error).self) {
      try test("42", decodesAs: Int?.some(42))
    }
  }

}

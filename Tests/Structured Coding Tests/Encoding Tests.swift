import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// Smoke tests for `StructuredEncodable` conformances. Each test encodes a value
/// and asserts the produced JSON exactly matches the format expected by the
/// corresponding `StructuredDecodable` implementation.

// MARK: - Primitives

@Suite("Encoding Primitives")
struct EncodingPrimitivesTests {

  @Test
  func encodesString() throws {
    try #expect(encode("hello") == #""hello""#)
  }

  @Test
  func encodesEmptyString() throws {
    try #expect(encode("") == #""""#)
  }

  @Test
  func encodesStringWithEscapes() throws {
    try #expect(encode("line1\nline2") == #""line1\nline2""#)
  }

  @Test
  func encodesTrue() throws {
    try #expect(encode(true) == "true")
  }

  @Test
  func encodesFalse() throws {
    try #expect(encode(false) == "false")
  }

  @Test
  func encodesPositiveInt() throws {
    try #expect(encode(42) == "42")
  }

  @Test
  func encodesNegativeInt() throws {
    try #expect(encode(-7) == "-7")
  }

  @Test
  func encodesZero() throws {
    try #expect(encode(0) == "0")
  }

  @Test
  func encodesDouble() throws {
    try #expect(encode(1.5) == "1.5")
  }

}

// MARK: - Compound

@Suite("Encoding Compound Values")
struct EncodingCompoundTests {

  @Test
  func encodesEmptyArray() throws {
    try #expect(encode([Int]()) == "[]")
  }

  @Test
  func encodesIntArray() throws {
    try #expect(encode([1, 2, 3]) == "[1,2,3]")
  }

  @Test
  func encodesStringArray() throws {
    try #expect(encode(["a", "b"]) == #"["a","b"]"#)
  }

  @Test
  func encodesNilOptionalAsEmptyObject() throws {
    try #expect(encode(Optional<String>.none) == "{}")
  }

  @Test
  func encodesSomeOptionalAsValueWrapped() throws {
    try #expect(encode(Optional<String>.some("hi")) == #"{"value":"hi"}"#)
  }

  @Test
  func encodesEmptyTupleAsEmptyArray() throws {
    try #expect(encode(StructuredTuple()) == "[]")
  }

  @Test
  func encodesPairTuple() throws {
    try #expect(encode(StructuredTuple<Int, String>(1, "two")) == #"[1,"two"]"#)
  }

}

// MARK: - Objects

@Suite("Encoding Objects")
struct EncodingObjectsTests {

  @Test
  func encodesObjectWithBothProperties() throws {
    let value = MutableStringObject(first: "hello", second: "world")
    try #expect(encode(value) == #"{"first":"hello","second":"world"}"#)
  }

  @Test
  func omitsNilOptionalProperty() throws {
    let value = MutableStringObject(first: "hello", second: nil)
    try #expect(encode(value) == #"{"first":"hello"}"#)
  }

  @Test
  func encodesEmptyObject() throws {
    try #expect(encode(EmptyObject()) == "{}")
  }

  @Test
  func encodesAllOptionalAsEmpty() throws {
    let value = OptionalMutableObject(a: nil, b: nil)
    try #expect(encode(value) == "{}")
  }

}

// MARK: - Helper

private func encode<Value: StructuredEncodable>(_ value: Value) throws -> String {
  var encoder = StructuredEncoder()
  try value.encode(to: &encoder)
  return encoder.stringValue
}

import Testing

import StructuredCoding

@Suite("Array")
struct ArrayTests {

  // MARK: - Encoding

  @Test
  func encodesEmptyArray() throws {
    try test([Int](), encodesAs: "[]")
  }

  @Test
  func encodesIntArray() throws {
    try test([1, 2, 3], encodesAs: "[1,2,3]")
  }

  @Test
  func encodesStringArray() throws {
    try test(["a", "b"], encodesAs: #"["a","b"]"#)
  }

  @Test
  func encodesNestedArray() throws {
    try test([[1], [2, 3]], encodesAs: "[[1],[2,3]]")
  }

  // MARK: - Decoding

  @Test
  func decodesEmptyArray() throws {
    try test("[]", decodesAs: [Int]())
  }

  @Test
  func decodesIntArray() throws {
    try test("[1,2,3]", decodesAs: [1, 2, 3])
  }

  @Test
  func decodesStringArray() throws {
    try test(#"["a","b"]"#, decodesAs: ["a", "b"])
  }

  @Test
  func decodesNestedArray() throws {
    try test("[[1],[2,3]]", decodesAs: [[1], [2, 3]])
  }

  @Test
  func decodesWithWhitespace() throws {
    try test("[ 1 , 2 , 3 ]", decodesAs: [1, 2, 3])
  }

  @Test
  func decodesAcrossChunks() throws {
    try test([#"["he"#, #"llo","wor"#, #"ld"]"#], decodesAs: ["hello", "world"])
  }

  // MARK: - Partial Streaming

  @Test
  func exposesEmptyArrayBeforeFirstElement() throws {
    try test("[", decodesAs: DecodingOutcome.partial([Int]()))
  }

  @Test
  func exposesElementsAsTheyComplete() throws {
    // "2" may still gain digits, so only the first element has been appended.
    try test("[1,2", decodesAs: DecodingOutcome.partial([1]))
  }

  @Test
  func exposesPartialStreamingElement() throws {
    // A streamed string element surfaces all but the last buffered character.
    try test(#"["hel"#, decodesAs: DecodingOutcome.partial(["he"]))
  }

  // MARK: - Errors

  @Test
  func unterminatedArrayThrows() throws {
    #expect(throws: (any Error).self) {
      try test("[1,2", decodesAs: [1, 2])
    }
  }

  @Test
  func mismatchedElementTypeThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#"[1,"two"]"#, decodesAs: [1, 2])
    }
  }

  @Test
  func missingOpenBracketThrows() throws {
    #expect(throws: (any Error).self) {
      try test("1,2]", decodesAs: [1, 2])
    }
  }

  // MARK: - Immutable Destinations

  /// A `let` property's accessor is immutable, so the array cannot be streamed
  /// into place — its elements are buffered and initialized all at once.
  @Test
  func decodesIntoImmutableProperty() throws {
    try test(
      #"{"strings":["a","b"]}"#,
      decodesAs: ImmutableArrayObject(strings: ["a", "b"])
    )
  }

  @Test
  func decodesIntoImmutableOptionalProperty() throws {
    try test(
      #"{"strings":["a","b"]}"#,
      decodesAs: ImmutableOptionalArrayObject(strings: ["a", "b"])
    )
  }

}

// MARK: - Fixtures

@StructuredCodable
private struct ImmutableArrayObject: Equatable {
  let strings: [String]
}

@StructuredCodable
private struct ImmutableOptionalArrayObject: Equatable {
  let strings: [String]?
}

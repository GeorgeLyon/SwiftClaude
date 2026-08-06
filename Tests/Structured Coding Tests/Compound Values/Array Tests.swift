import Testing

import StructuredCoding

@Suite("Array")
struct ArrayTests {

  // MARK: - Encoding

  @Test
  func encodesEmptyArray() async throws {
    try await test([Int](), encodesAs: "[]")
  }

  @Test
  func encodesIntArray() async throws {
    try await test([1, 2, 3], encodesAs: "[1,2,3]")
  }

  @Test
  func encodesStringArray() async throws {
    try await test(["a", "b"], encodesAs: #"["a","b"]"#)
  }

  @Test
  func encodesNestedArray() async throws {
    try await test([[1], [2, 3]], encodesAs: "[[1],[2,3]]")
  }

  // MARK: - Decoding

  @Test
  func decodesEmptyArray() async throws {
    try await test("[]", decodesAs: [Int]())
  }

  @Test
  func decodesIntArray() async throws {
    try await test("[1,2,3]", decodesAs: [1, 2, 3])
  }

  @Test
  func decodesStringArray() async throws {
    try await test(#"["a","b"]"#, decodesAs: ["a", "b"])
  }

  @Test
  func decodesNestedArray() async throws {
    try await test("[[1],[2,3]]", decodesAs: [[1], [2, 3]])
  }

  @Test
  func decodesWithWhitespace() async throws {
    try await test("[ 1 , 2 , 3 ]", decodesAs: [1, 2, 3])
  }

  @Test
  func decodesAcrossChunks() async throws {
    try await test([#"["he"#, #"llo","wor"#, #"ld"]"#], decodesAs: ["hello", "world"])
  }

  // MARK: - Partial Streaming

  @Test
  func exposesEmptyArrayBeforeFirstElement() async throws {
    try await test("[", decodesAs: DecodingOutcome.partial([Int]()))
  }

  @Test
  func exposesElementsAsTheyComplete() async throws {
    // "2" may still gain digits, so only the first element has been appended.
    try await test("[1,2", decodesAs: DecodingOutcome.partial([1]))
  }

  @Test
  func exposesPartialStreamingElement() async throws {
    // A streamed string element surfaces all but the last buffered character.
    try await test(#"["hel"#, decodesAs: DecodingOutcome.partial(["he"]))
  }

  // MARK: - Errors

  @Test
  func unterminatedArrayThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test("[1,2", decodesAs: [1, 2])
    }
  }

  @Test
  func mismatchedElementTypeThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test(#"[1,"two"]"#, decodesAs: [1, 2])
    }
  }

  @Test
  func missingOpenBracketThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test("1,2]", decodesAs: [1, 2])
    }
  }

  // MARK: - Immutable Destinations

  /// A `let` property's accessor is immutable, so the array cannot be streamed
  /// into place — its elements are buffered and initialized all at once.
  @Test
  func decodesIntoImmutableProperty() async throws {
    try await test(
      #"{"strings":["a","b"]}"#,
      decodesAs: ImmutableArrayObject(strings: ["a", "b"])
    )
  }

  @Test
  func decodesIntoImmutableOptionalProperty() async throws {
    try await test(
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

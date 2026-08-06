import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

@Suite("Basic Object Encoding")
struct BasicObjectEncodingTests {

  @Test func encodesObjectWithBothProperties() async throws {
    try await test(
      MutableStringObject(first: "hello", second: "world"),
      encodesAs: #"{"first":"hello","second":"world"}"#
    )
  }

  @Test func omitsNilOptionalProperty() async throws {
    try await test(
      MutableStringObject(first: "hello", second: nil),
      encodesAs: #"{"first":"hello"}"#
    )
  }

  @Test func encodesEmptyObject() async throws {
    try await test(EmptyObject(), encodesAs: "{}")
  }

  @Test func encodesAllOptionalAsEmpty() async throws {
    try await test(OptionalMutableObject(a: nil, b: nil), encodesAs: "{}")
  }

}

@Suite("Basic Object Decoding")
struct BasicObjectTests {

  // MARK: - Happy path

  @Test func decodesObject() async throws {
    try await test(
      #"{"first":"hello","second":"world"}"#,
      decodesAs: MutableStringObject(first: "hello", second: "world")
    )
  }

  @Test func decodesPropertiesInAnyOrder() async throws {
    try await test(
      #"{"second":"world","first":"hello"}"#,
      decodesAs: MutableStringObject(first: "hello", second: "world")
    )
  }

  @Test func decodesWithSurroundingAndInternalWhitespace() async throws {
    try await test(
      #"{ "first" : "hello" , "second" : "world" }"#,
      decodesAs: MutableStringObject(first: "hello", second: "world")
    )
  }

  @Test func decodesWithMultilineWhitespace() async throws {
    try await test(
      """
      {
        "first": "hello",
        "second": "world"
      }
      """,
      decodesAs: MutableStringObject(first: "hello", second: "world")
    )
  }

  @Test func decodesUnicodeValues() async throws {
    try await test(
      #"{"first":"日本語","second":"🎉"}"#,
      decodesAs: MutableStringObject(first: "日本語", second: "🎉")
    )
  }

  @Test func decodesEscapedValues() async throws {
    try await test(
      #"{"first":"line1\nline2","second":"tab\there"}"#,
      decodesAs: MutableStringObject(first: "line1\nline2", second: "tab\there")
    )
  }

  // MARK: - Omission

  @Test func omitsOptionalProperty() async throws {
    try await test(
      #"{"first":"hello"}"#,
      decodesAs: MutableStringObject(first: "hello", second: nil)
    )
  }

  @Test func allOptionalEmptyObjectDecodes() async throws {
    try await test(#"{}"#, decodesAs: OptionalMutableObject(a: nil, b: nil))
  }

  @Test func noPropertyEmptyObjectDecodes() async throws {
    try await test(#"{}"#, decodesAs: EmptyObject())
  }

  // MARK: - Errors

  @Test func missingRequiredPropertyThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test(#"{"second":"world"}"#, decodesAs: MutableStringObject(first: "", second: "world"))
    }
  }

  @Test func unknownPropertyThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test(
        #"{"first":"hello","mystery":"value"}"#,
        decodesAs: MutableStringObject(first: "hello", second: nil)
      )
    }
  }

  /// An unknown key appearing *before* any declared property must be rejected,
  /// not silently skipped (which would drop the valid `a` value and decode `nil`).
  @Test func unknownFirstPropertyThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test(
        #"{"mystery":"x","a":"y"}"#,
        decodesAs: OptionalMutableObject(a: "y", b: nil)
      )
    }
  }

  /// An unknown key appearing *after* the last matched property must be rejected,
  /// not silently accepted with the stream left positioned mid-object.
  @Test func unknownTrailingPropertyThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test(
        #"{"first":"a","second":"b","mystery":1}"#,
        decodesAs: MutableStringObject(first: "a", second: "b")
      )
    }
  }

  @Test func propertyOnEmptyObjectThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test(#"{"x":1}"#, decodesAs: EmptyObject())
    }
  }

  @Test func duplicatePropertyThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test(
        #"{"first":"a","first":"b"}"#,
        decodesAs: MutableStringObject(first: "a", second: nil)
      )
    }
  }

  // MARK: - Partial streaming

  /// A Branch-A object is observable mid-stream: its in-progress value reflects
  /// each property as it arrives, with per-property semantics (a streamed
  /// `String` lags by one buffered character).

  @Test func partialBeforeAnyProperty() async throws {
    try await test(#"{"#, decodesAs: .partial(MutableStringObject(first: "", second: nil)))
  }

  @Test func partialMidFirstProperty() async throws {
    try await test(#"{"first":"hel"#, decodesAs: .partial(MutableStringObject(first: "he", second: nil)))
  }

  @Test func partialAfterFirstPropertyComplete() async throws {
    try await test(
      #"{"first":"hello","#,
      decodesAs: .partial(MutableStringObject(first: "hello", second: nil))
    )
  }

  @Test func partialMidSecondProperty() async throws {
    try await test(
      #"{"first":"hello","second":"wor"#,
      decodesAs: .partial(MutableStringObject(first: "hello", second: "wo"))
    )
  }

  @Test func partialOptionalObject() async throws {
    try await test(#"{"a":"he"#, decodesAs: .partial(OptionalMutableObject(a: "h", b: nil)))
  }

  @Test func partialEmptyObject() async throws {
    try await test(#"{"#, decodesAs: .partial(EmptyObject()))
  }

  // MARK: - Chunk boundaries

  @Test func chunkedAcrossPropertyName() async throws {
    try await test(
      [#"{"fi"#, #"rst":"hello","second":"world"}"#],
      decodesAs: MutableStringObject(first: "hello", second: "world")
    )
  }

  @Test func chunkedAcrossPropertyValue() async throws {
    try await test(
      [#"{"first":"hel"#, #"lo","second":"wor"#, #"ld"}"#],
      decodesAs: MutableStringObject(first: "hello", second: "world")
    )
  }
}

import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

@Suite("Basic Object Decoding")
struct BasicObjectTests {

  // MARK: - Happy path

  @Test func decodesObject() throws {
    try test(
      #"{"first":"hello","second":"world"}"#,
      decodesAs: MutableStringObject(first: "hello", second: "world")
    )
  }

  @Test func decodesPropertiesInAnyOrder() throws {
    try test(
      #"{"second":"world","first":"hello"}"#,
      decodesAs: MutableStringObject(first: "hello", second: "world")
    )
  }

  @Test func decodesWithSurroundingAndInternalWhitespace() throws {
    try test(
      #"{ "first" : "hello" , "second" : "world" }"#,
      decodesAs: MutableStringObject(first: "hello", second: "world")
    )
  }

  @Test func decodesWithMultilineWhitespace() throws {
    try test(
      """
      {
        "first": "hello",
        "second": "world"
      }
      """,
      decodesAs: MutableStringObject(first: "hello", second: "world")
    )
  }

  @Test func decodesUnicodeValues() throws {
    try test(
      #"{"first":"日本語","second":"🎉"}"#,
      decodesAs: MutableStringObject(first: "日本語", second: "🎉")
    )
  }

  @Test func decodesEscapedValues() throws {
    try test(
      #"{"first":"line1\nline2","second":"tab\there"}"#,
      decodesAs: MutableStringObject(first: "line1\nline2", second: "tab\there")
    )
  }

  // MARK: - Omission

  @Test func omitsOptionalProperty() throws {
    try test(
      #"{"first":"hello"}"#,
      decodesAs: MutableStringObject(first: "hello", second: nil)
    )
  }

  @Test func allOptionalEmptyObjectDecodes() throws {
    try test(#"{}"#, decodesAs: OptionalMutableObject(a: nil, b: nil))
  }

  @Test func noPropertyEmptyObjectDecodes() throws {
    try test(#"{}"#, decodesAs: EmptyObject())
  }

  // MARK: - Errors

  @Test func missingRequiredPropertyThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#"{"second":"world"}"#, decodesAs: MutableStringObject(first: "", second: "world"))
    }
  }

  @Test func unknownPropertyThrows() throws {
    #expect(throws: (any Error).self) {
      try test(
        #"{"first":"hello","mystery":"value"}"#,
        decodesAs: MutableStringObject(first: "hello", second: nil)
      )
    }
  }

  /// An unknown key appearing *before* any declared property must be rejected,
  /// not silently skipped (which would drop the valid `a` value and decode `nil`).
  @Test func unknownFirstPropertyThrows() throws {
    #expect(throws: (any Error).self) {
      try test(
        #"{"mystery":"x","a":"y"}"#,
        decodesAs: OptionalMutableObject(a: "y", b: nil)
      )
    }
  }

  /// An unknown key appearing *after* the last matched property must be rejected,
  /// not silently accepted with the stream left positioned mid-object.
  @Test func unknownTrailingPropertyThrows() throws {
    #expect(throws: (any Error).self) {
      try test(
        #"{"first":"a","second":"b","mystery":1}"#,
        decodesAs: MutableStringObject(first: "a", second: "b")
      )
    }
  }

  @Test func propertyOnEmptyObjectThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#"{"x":1}"#, decodesAs: EmptyObject())
    }
  }

  @Test func duplicatePropertyThrows() throws {
    #expect(throws: (any Error).self) {
      try test(
        #"{"first":"a","first":"b"}"#,
        decodesAs: MutableStringObject(first: "a", second: nil)
      )
    }
  }

  // MARK: - Partial streaming

  /// A Branch-A object is observable mid-stream: its in-progress value reflects
  /// each property as it arrives, with per-property semantics (a streamed
  /// `String` lags by one buffered character).

  @Test func partialBeforeAnyProperty() throws {
    try test(#"{"#, decodesAs: .partial(MutableStringObject(first: "", second: nil)))
  }

  @Test func partialMidFirstProperty() throws {
    try test(#"{"first":"hel"#, decodesAs: .partial(MutableStringObject(first: "he", second: nil)))
  }

  @Test func partialAfterFirstPropertyComplete() throws {
    try test(
      #"{"first":"hello","#,
      decodesAs: .partial(MutableStringObject(first: "hello", second: nil))
    )
  }

  @Test func partialMidSecondProperty() throws {
    try test(
      #"{"first":"hello","second":"wor"#,
      decodesAs: .partial(MutableStringObject(first: "hello", second: "wo"))
    )
  }

  @Test func partialOptionalObject() throws {
    try test(#"{"a":"he"#, decodesAs: .partial(OptionalMutableObject(a: "h", b: nil)))
  }

  @Test func partialEmptyObject() throws {
    try test(#"{"#, decodesAs: .partial(EmptyObject()))
  }

  // MARK: - Chunk boundaries

  @Test func chunkedAcrossPropertyName() throws {
    try test(
      [#"{"fi"#, #"rst":"hello","second":"world"}"#],
      decodesAs: MutableStringObject(first: "hello", second: "world")
    )
  }

  @Test func chunkedAcrossPropertyValue() throws {
    try test(
      [#"{"first":"hel"#, #"lo","second":"wor"#, #"ld"}"#],
      decodesAs: MutableStringObject(first: "hello", second: "world")
    )
  }
}

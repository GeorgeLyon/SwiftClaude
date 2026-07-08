import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// A wrapper is a single-value struct that codes as its stored value, with no
/// object container around it — `MediaType(stringValue: "image/png")` encodes
/// as `"image/png"`. Decoding mirrors object-property semantics exactly: a
/// `var`-backed wrapper around a streamable value is seeded with the value's
/// initial value and streams through its key path, while a `let`-backed one
/// (or one wrapping a value with no initial value, like `Int`) buffers and is
/// constructed only once the value is complete.
@Suite("Wrapper")
struct WrapperTests {

  // MARK: - Schema

  /// A wrapper's schema is its wrapped value's schema — there is no object
  /// structure of its own.
  @Test func schemaIsWrappedValueSchema() throws {
    try test(MediaType.schema, encodesAs: #"{"type":"string"}"#)
    try test(Count.schema, encodesAs: #"{"type":"integer"}"#)
  }

  // MARK: - Encoding

  @Test func encodesAsBareString() throws {
    try test(MediaType(stringValue: "image/png"), encodesAs: #""image/png""#)
  }

  @Test func encodesAsBareInteger() throws {
    try test(Count(value: 42), encodesAs: #"42"#)
  }

  // MARK: - Happy path

  @Test func decodesFromBareString() throws {
    try test(#""image/png""#, decodesAs: MediaType(stringValue: "image/png"))
  }

  @Test func decodesFromBareInteger() throws {
    try test(#"42"#, decodesAs: Count(value: 42))
  }

  @Test func decodesWithSurroundingWhitespace() throws {
    try test(#"  "image/png"  "#, decodesAs: MediaType(stringValue: "image/png"))
  }

  // MARK: - Chunk boundaries

  @Test func chunkedAcrossStringValue() throws {
    try test([#""image"#, #"/png""#], decodesAs: MediaType(stringValue: "image/png"))
  }

  @Test func chunkedAcrossIntegerValue() throws {
    try test([#"4"#, #"2"#], decodesAs: Count(value: 42))
  }

  // MARK: - Partial streaming

  /// A `var`-backed `String` wrapper is seeded around the empty string the
  /// instant the opening quote arrives, exactly like a `var` object property.
  @Test func mutableWrapperSeedsOnceKindKnown() throws {
    try test(#"""#, decodesAs: .partial(Tag(text: "")))
  }

  /// Once characters arrive the wrapper reflects them (the streamed string
  /// lags by one buffered character).
  @Test func mutableWrapperStreams() throws {
    try test(#""hel"#, decodesAs: .partial(Tag(text: "he")))
  }

  /// A `let`-backed wrapper cannot be written through its key path, so — like
  /// a `let` object property — it buffers and stays unobservable until the
  /// value is complete.
  @Test func immutableWrapperNotObservableUntilComplete() throws {
    try test(#""imag"#, decodesAs: DecodingOutcome<MediaType>.incomplete)
  }

  /// An `Int` has no initial value, so the wrapper is unobservable until a
  /// delimiter terminates the number — a bare digit has none yet.
  @Test func integerWrapperNotObservableUntilTerminated() throws {
    try test(#"4"#, decodesAs: DecodingOutcome<Count>.incomplete)
  }

  // MARK: - Errors

  /// The wrapped value's own validation applies unchanged.
  @Test func wrongKindThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#"42"#, decodesAs: MediaType(stringValue: ""))
    }
  }

}

// MARK: - Fixtures

/// A `let`-backed `String` wrapper — decodes buffered.
private struct MediaType: StructuredWrapper, Equatable, Sendable {

  let stringValue: String

  init(stringValue: String) {
    self.stringValue = stringValue
  }

  typealias _StringValueProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<String>
  >
  static var schema: some StructuredCodingSchema {
    _schema()
  }
  typealias StructuredObjectProperties = _StringValueProperty
  static func properties() -> StructuredObjectProperties {
    _StringValueProperty(
      name: "stringValue",
      keyPath: \.stringValue,
      schema: _StringValueProperty.Definition.CodingValue.schema
    )
  }
  typealias ObjectDecoderValues = _StringValueProperty.ObjectDecoderValue
  static func decode(
    from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>
  ) -> sending Self {
    Self(stringValue: objectDecoder.values)
  }
}

/// A `var`-backed `String` wrapper — streams through its writable key path.
private struct Tag: StructuredWrapper, Equatable, Sendable {

  var text: String

  init(text: String) {
    self.text = text
  }

  typealias _TextProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<String>
  >
  static var schema: some StructuredCodingSchema {
    _schema()
  }
  typealias StructuredObjectProperties = _TextProperty
  static func properties() -> StructuredObjectProperties {
    _TextProperty(
      name: "text",
      keyPath: \.text,
      schema: _TextProperty.Definition.CodingValue.schema
    )
  }
  typealias ObjectDecoderValues = _TextProperty.ObjectDecoderValue
  static func decode(
    from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>
  ) -> sending Self {
    Self(text: objectDecoder.values)
  }
}

/// An `Int`-backed wrapper — `Int` has no initial value, so decoding always
/// buffers regardless of the property's mutability.
private struct Count: StructuredWrapper, Equatable, Sendable {

  let value: Int

  init(value: Int) {
    self.value = value
  }

  typealias _ValueProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<Int>
  >
  static var schema: some StructuredCodingSchema {
    _schema()
  }
  typealias StructuredObjectProperties = _ValueProperty
  static func properties() -> StructuredObjectProperties {
    _ValueProperty(
      name: "value",
      keyPath: \.value,
      schema: _ValueProperty.Definition.CodingValue.schema
    )
  }
  typealias ObjectDecoderValues = _ValueProperty.ObjectDecoderValue
  static func decode(
    from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>
  ) -> sending Self {
    Self(value: objectDecoder.values)
  }
}

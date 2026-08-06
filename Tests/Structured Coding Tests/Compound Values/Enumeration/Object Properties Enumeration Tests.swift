import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// An object-properties enumeration — the default `StructuredEnumeration` coding style — is
/// encoded as a single-property object: the property *name* is the case name and
/// its *value* is that case's associated value (e.g. `{"text":"hello"}`).
/// Decoding reads exactly one property; the name selects the case and the value
/// decodes into the case's associated value. An empty object (no case named), an
/// object carrying more than one property, and an unrecognized case name are all
/// rejected.
///
/// The case is unknown until its property name has been read, so the enumeration
/// cannot be observed before then. Once the case *is* known, the associated
/// value's own decoding semantics take over: a value that has an initial value (a
/// `String`, or a Branch-A `StructuredObject` whose every property defaults) seeds the case
/// immediately — observable mid-stream — while one that does not (an `Int`, or a
/// Branch-B `StructuredObject`) cannot be observed until it is fully constructed.
@Suite("Object-Properties Enumeration")
struct ObjectPropertiesEnumerationTests {

  // MARK: - Schema

  /// `Value`'s hand-written conformance declares the structural enumeration
  /// schema explicitly, covering every associated-value shape.
  @Test func encodesSchema() async throws {
    try await test(
      Value.schema,
      encodesAs:
        #"{"properties":{"text":{"type":"string"},"count":{"type":"integer"},"message":{"properties":{"body":{"type":"string"}},"required":["body"]},"move":{"properties":{"x":{"type":"integer"},"y":{"type":"integer"}},"required":["x","y"]},"ping":{"properties":{}}},"maxProperties":1}"#
    )
  }

  // MARK: - Happy path

  @Test func decodesPrimitiveCase() async throws {
    try await test(
      #"{"text":"hello"}"#,
      decodesAs: Value.text("hello")
    )
  }

  @Test func decodesSecondPrimitiveCase() async throws {
    try await test(
      #"{"count":42}"#,
      decodesAs: Value.count(42)
    )
  }

  /// A case whose associated value is a Branch-A object decodes from a nested
  /// object value.
  @Test func decodesObjectCase() async throws {
    try await test(
      #"{"message":{"body":"hi"}}"#,
      decodesAs: Value.message(Message(body: "hi"))
    )
  }

  /// A case whose associated value is a Branch-B object (no-initial-value `Int`
  /// properties) decodes through the deferred path.
  @Test func decodesDeferredObjectCase() async throws {
    try await test(
      #"{"move":{"x":1,"y":2}}"#,
      decodesAs: Value.move(Move(x: 1, y: 2))
    )
  }

  /// A case wrapping an object with no properties of its own decodes from an
  /// empty nested object.
  @Test func decodesEmptyObjectCase() async throws {
    try await test(
      #"{"ping":{}}"#,
      decodesAs: Value.ping(Ping())
    )
  }

  @Test func decodesWithSurroundingAndInternalWhitespace() async throws {
    try await test(
      #"{ "text" : "hello" }"#,
      decodesAs: Value.text("hello")
    )
  }

  // MARK: - Chunk boundaries

  @Test func chunkedAcrossCaseName() async throws {
    try await test(
      [#"{"me"#, #"ssage":{"body":"hi"}}"#],
      decodesAs: Value.message(Message(body: "hi"))
    )
  }

  @Test func chunkedAcrossValue() async throws {
    try await test(
      [#"{"text":"hel"#, #"lo"}"#],
      decodesAs: Value.text("hello")
    )
  }

  // MARK: - Errors

  /// An empty object names no case.
  @Test func emptyObjectThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test(#"{}"#, decodesAs: Value.ping(Ping()))
    }
  }

  @Test func unknownCaseThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test(#"{"explode":1}"#, decodesAs: Value.count(1))
    }
  }

  /// A second property has no case to belong to; the single-property invariant is
  /// enforced after the first property decodes.
  @Test func moreThanOnePropertyThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test(#"{"text":"hi","count":1}"#, decodesAs: Value.text("hi"))
    }
  }

  @Test func wrongValueTypeThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test(#"{"count":"not a number"}"#, decodesAs: Value.count(0))
    }
  }

  // MARK: - Partial streaming

  /// Before the property name has finished, the case cannot be selected, so the
  /// enumeration is not observable.
  @Test func incompleteBeforeCaseKnown() async throws {
    try await test(
      #"{"te"#,
      decodesAs: DecodingOutcome<Value>.incomplete
    )
  }

  /// The instant the case is known, a Branch-A associated value (`String`) is
  /// seeded with its initial value (`""`) — observable before any value
  /// characters arrive.
  @Test func seedsBranchACaseOnceValueBegins() async throws {
    try await test(
      #"{"text":""#,
      decodesAs: .partial(Value.text(""))
    )
  }

  /// Once associated-value characters arrive the case reflects them (the streamed
  /// string lags by one buffered character).
  @Test func reflectsStreamingAssociatedValue() async throws {
    try await test(
      #"{"text":"hel"#,
      decodesAs: .partial(Value.text("he"))
    )
  }

  /// A Branch-B primitive (`Int`) has no initial value, so the case is not
  /// observable until the value terminates — and a bare `4` has not been
  /// terminated by a delimiter yet.
  @Test func branchBPrimitiveNotObservableUntilTerminated() async throws {
    try await test(
      #"{"count":4"#,
      decodesAs: DecodingOutcome<Value>.incomplete
    )
  }

  /// A Branch-A object associated value is seeded the moment the case is known,
  /// even before its own properties stream in.
  @Test func seedsBranchAObjectCase() async throws {
    try await test(
      #"{"message":{"body":""#,
      decodesAs: .partial(Value.message(Message(body: "")))
    )
  }

  /// A Branch-B object cannot be constructed until its buffered properties are all
  /// present, so the case stays unobservable even with every byte but the brace
  /// that terminates the final property.
  @Test func branchBObjectNotObservableUntilBuilt() async throws {
    try await test(
      #"{"move":{"x":1,"y":2"#,
      decodesAs: DecodingOutcome<Value>.incomplete
    )
  }

  /// Once the nested object's closing brace terminates its final property, the
  /// Branch-B object is constructed and the case becomes observable — before the
  /// enumeration's own object closes.
  @Test func branchBObjectObservableOnceBuilt() async throws {
    try await test(
      #"{"move":{"x":1,"y":2}"#,
      decodesAs: .partial(Value.move(Move(x: 1, y: 2)))
    )
  }

  // MARK: - Macro-synthesized payloads

  /// A single labeled value is macro-synthesized into a one-property payload
  /// object, so the label survives as a property name in the JSON.
  @Test func encodesSingleLabeledValueCase() async throws {
    try await test(
      Feedback.rating(stars: 5),
      encodesAs: #"{"rating":{"stars":5}}"#
    )
  }

  @Test func decodesSingleLabeledValueCase() async throws {
    try await test(
      #"{"rating":{"stars":5}}"#,
      decodesAs: Feedback.rating(stars: 5)
    )
  }
}

// MARK: - Fixtures

/// A macro-expanded object-properties enumeration whose `rating` case carries
/// a single labeled value, synthesized into a one-property payload object.
@StructuredCodable
private enum Feedback: Equatable, Sendable {
  case rating(stars: Int)
  case comment(String)
}

/// An object-properties enumeration spanning every associated-value shape: a
/// Branch-A primitive (`text`), a Branch-B primitive (`count`), a Branch-A object
/// (`message`), a Branch-B object (`move`), and an empty object (`ping`). It takes
/// the default `StructuredEnumerationCodingStyleObjectProperties`, so no
/// `codingConfiguration` is declared.
private enum Value: StructuredEnumeration, Equatable, Sendable {

  case text(String)
  case count(Int)
  case message(Message)
  case move(Move)
  case ping(Ping)

  static var schema: some StructuredCodingSchema {
    _schema()
  }
  typealias Cases = (
    StructuredEnumerationCase<Self, String>,
    StructuredEnumerationCase<Self, Int>,
    StructuredEnumerationCase<Self, Message>,
    StructuredEnumerationCase<Self, Move>,
    StructuredEnumerationCase<Self, Ping>
  )
  static func cases() -> Cases {
    (
      StructuredEnumerationCase(
        name: "text",
        accessor: { value in
          guard case .text(let associated) = value else { return nil }
          return associated
        },
        initializer: { .text($0) }
      ),
      StructuredEnumerationCase(
        name: "count",
        accessor: { value in
          guard case .count(let associated) = value else { return nil }
          return associated
        },
        initializer: { .count($0) }
      ),
      StructuredEnumerationCase(
        name: "message",
        accessor: { value in
          guard case .message(let associated) = value else { return nil }
          return associated
        },
        initializer: { .message($0) }
      ),
      StructuredEnumerationCase(
        name: "move",
        accessor: { value in
          guard case .move(let associated) = value else { return nil }
          return associated
        },
        initializer: { .move($0) }
      ),
      StructuredEnumerationCase(
        name: "ping",
        accessor: { value in
          guard case .ping(let associated) = value else { return nil }
          return associated
        },
        initializer: { .ping($0) }
      )
    )
  }
}

/// Branch-A associated value: its sole `String` property defaults to `""`, so the
/// case is seeded the moment its name identifies it.
private struct Message: StructuredObject, Equatable, Sendable {

  var body: String

  init(body: String) {
    self.body = body
  }

  typealias _BodyProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<String>
  >
  static var schema: some StructuredCodingSchema {
    _schema()
  }
  typealias StructuredObjectProperties = _BodyProperty
  static func properties() -> StructuredObjectProperties {
    _BodyProperty(name: "body", keyPath: \.body, schema: _BodyProperty.Definition.CodingValue.schema)
  }

  typealias ObjectDecoderValues = _BodyProperty.ObjectDecoderValue
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>)
    -> sending Self
  {
    Self(body: objectDecoder.values)
  }
}

/// Branch-B associated value: `Int` properties have no initial value, so the case
/// cannot exist until both are buffered and the object is constructed.
private struct Move: StructuredObject, Equatable, Sendable {

  let x: Int
  let y: Int

  init(x: Int, y: Int) {
    self.x = x
    self.y = y
  }

  typealias _XProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<Int>
  >
  typealias _YProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<Int>
  >
  static var schema: some StructuredCodingSchema {
    _schema()
  }
  typealias StructuredObjectProperties = (_XProperty, _YProperty)
  static func properties() -> StructuredObjectProperties {
    (
      _XProperty(name: "x", keyPath: \.x, schema: _XProperty.Definition.CodingValue.schema),
      _YProperty(name: "y", keyPath: \.y, schema: _YProperty.Definition.CodingValue.schema)
    )
  }

  typealias ObjectDecoderValues = (
    _XProperty.ObjectDecoderValue, _YProperty.ObjectDecoderValue
  )
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>)
    -> sending Self
  {
    Self(x: objectDecoder.values.0, y: objectDecoder.values.1)
  }
}

/// An associated value with no properties — its object value is `{}`.
private struct Ping: StructuredObject, Equatable, Sendable {

  init() {}

  static var schema: some StructuredCodingSchema {
    _schema()
  }
  typealias StructuredObjectProperties = ()
  static func properties() -> StructuredObjectProperties { () }

  typealias ObjectDecoderValues = ()
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>)
    -> sending Self
  {
    Self()
  }
}

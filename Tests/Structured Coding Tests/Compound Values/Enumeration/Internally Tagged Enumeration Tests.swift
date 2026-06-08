import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// An internally-tagged enumeration is encoded as a single object: one property
/// (the *discriminator*, here `"type"`) names the case, and the object's
/// remaining properties are the case's associated `StructuredObject`. Decoding happens in
/// two passes — the discriminator is *peeked* (scanning the whole object, so it
/// may appear in any position) to identify the case, then the object is decoded
/// into that case's associated value with the discriminator property skipped and
/// validated.
///
/// Because the case is unknown until the discriminator has been read, the
/// enumeration cannot exist until then. Once the case *is* known, the associated
/// value's own decoding semantics take over: a Branch-A object (every property
/// has an initial value) is seeded immediately, while a Branch-B object (a
/// property with no initial value, e.g. `Int`) cannot be observed until its
/// buffered properties let it be constructed.
@Suite("Internally-Tagged Enumeration")
struct InternallyTaggedEnumerationTests {

  // MARK: - Happy path

  @Test func decodesDiscriminatorFirst() throws {
    try test(
      #"{"type":"message","body":"hi"}"#,
      decodesAs: Event.message(Message(body: "hi"))
    )
  }

  @Test func decodesDiscriminatorLast() throws {
    try test(
      #"{"body":"hi","type":"message"}"#,
      decodesAs: Event.message(Message(body: "hi"))
    )
  }

  @Test func decodesSecondCase() throws {
    try test(
      #"{"type":"move","x":1,"y":2}"#,
      decodesAs: Event.move(Move(x: 1, y: 2))
    )
  }

  /// The discriminator sits between two associated-value properties; the peek
  /// still finds it and the remaining properties decode around it.
  @Test func decodesDiscriminatorBetweenProperties() throws {
    try test(
      #"{"x":1,"type":"move","y":2}"#,
      decodesAs: Event.move(Move(x: 1, y: 2))
    )
  }

  @Test func decodesDiscriminatorAfterMultipleProperties() throws {
    try test(
      #"{"x":1,"y":2,"type":"move"}"#,
      decodesAs: Event.move(Move(x: 1, y: 2))
    )
  }

  /// A case whose associated value has no properties of its own decodes from an
  /// object containing only the discriminator.
  @Test func decodesCaseWithNoAssociatedProperties() throws {
    try test(
      #"{"type":"ping"}"#,
      decodesAs: Event.ping(Ping())
    )
  }

  @Test func decodesWithSurroundingAndInternalWhitespace() throws {
    try test(
      #"{ "type" : "message" , "body" : "hi" }"#,
      decodesAs: Event.message(Message(body: "hi"))
    )
  }

  // MARK: - Chunk boundaries

  @Test func chunkedAcrossDiscriminatorName() throws {
    try test(
      [#"{"ty"#, #"pe":"message","body":"hi"}"#],
      decodesAs: Event.message(Message(body: "hi"))
    )
  }

  @Test func chunkedAcrossDiscriminatorValue() throws {
    try test(
      [#"{"type":"mes"#, #"sage","body":"hi"}"#],
      decodesAs: Event.message(Message(body: "hi"))
    )
  }

  @Test func chunkedWithTrailingDiscriminator() throws {
    try test(
      [#"{"x":1,"y":2,"ty"#, #"pe":"move"}"#],
      decodesAs: Event.move(Move(x: 1, y: 2))
    )
  }

  // MARK: - Errors

  @Test func unknownDiscriminatorThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#"{"type":"explode"}"#, decodesAs: Event.ping(Ping()))
    }
  }

  @Test func missingDiscriminatorThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#"{"body":"hi"}"#, decodesAs: Event.message(Message(body: "hi")))
    }
  }

  @Test func nonStringDiscriminatorThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#"{"type":5,"body":"hi"}"#, decodesAs: Event.message(Message(body: "hi")))
    }
  }

  /// A non-discriminator property the case's associated value doesn't declare is
  /// still rejected.
  @Test func unknownAssociatedPropertyThrows() throws {
    #expect(throws: (any Error).self) {
      try test(
        #"{"type":"message","body":"hi","mystery":"x"}"#,
        decodesAs: Event.message(Message(body: "hi"))
      )
    }
  }

  // MARK: - Partial streaming

  /// Before the discriminator has been read the case is unknown, so the
  /// enumeration cannot be observed yet.
  @Test func incompleteBeforeDiscriminatorKnown() throws {
    try test(
      #"{"type":"mess"#,
      decodesAs: DecodingOutcome<Event>.incomplete
    )
  }

  /// Reading the discriminator property is not done until its trailing
  /// delimiter arrives, so even a fully-quoted discriminator value leaves the
  /// case unidentified — and the enumeration unobservable.
  @Test func incompleteUntilDiscriminatorDelimiter() throws {
    try test(
      #"{"type":"message"#,
      decodesAs: DecodingOutcome<Event>.incomplete
    )
  }

  /// The instant the discriminator identifies a Branch-A case, that case is
  /// seeded with its associated value's initial value (`Message(body: "")`),
  /// even though no associated-value characters have arrived. Reading the
  /// discriminator requires its trailing delimiter (the `,`), so a bare
  /// `{"type":"message"` would not yet identify the case.
  @Test func seedsBranchACaseOnceDiscriminatorKnown() throws {
    try test(
      #"{"type":"message","#,
      decodesAs: .partial(Event.message(Message(body: "")))
    )
  }

  /// Once associated-value characters arrive the case reflects them (the
  /// streamed string lags by one buffered character).
  @Test func reflectsStreamingAssociatedValue() throws {
    try test(
      #"{"type":"message","body":"hel"#,
      decodesAs: .partial(Event.message(Message(body: "he")))
    )
  }

  /// A Branch-B associated value (`Move` has no-initial-value `Int` properties)
  /// cannot be constructed until its buffered properties are all present, so the
  /// case is not observable even with every byte but the closing brace — the
  /// final `2` has not yet been terminated.
  @Test func branchBCaseNotObservableUntilBuilt() throws {
    try test(
      #"{"type":"move","x":1,"y":2"#,
      decodesAs: DecodingOutcome<Event>.incomplete
    )
  }

  /// Once the buffered properties terminate (here the trailing comma terminates
  /// `2`), the Branch-B object is constructed and the case becomes observable —
  /// before the object itself closes.
  @Test func branchBCaseObservableOnceBuilt() throws {
    try test(
      #"{"type":"move","x":1,"y":2,"#,
      decodesAs: .partial(Event.move(Move(x: 1, y: 2)))
    )
  }
}

// MARK: - Fixtures

/// An internally-tagged enumeration: each case wraps an `StructuredObject`, distinguished
/// by the `"type"` discriminator property.
private enum Event: StructuredEnumeration, Equatable, Sendable {

  typealias Schema = StructuredAnySchema

  case message(Message)
  case move(Move)
  case ping(Ping)

  static var codingStyle: StructuredEnumerationCodingStyleInternallyTagged {
    StructuredEnumerationCodingStyleInternallyTagged(discriminatorPropertyName: "type")
  }

  typealias Cases = (
    StructuredEnumerationCase<Self, Message>,
    StructuredEnumerationCase<Self, Move>,
    StructuredEnumerationCase<Self, Ping>
  )
  static func cases() -> Cases {
    (
      StructuredEnumerationCase(
        name: "message",
        accessor: { event in
          guard case .message(let value) = event else { return nil }
          return value
        },
        initializer: { .message($0) }
      ),
      StructuredEnumerationCase(
        name: "move",
        accessor: { event in
          guard case .move(let value) = event else { return nil }
          return value
        },
        initializer: { .move($0) }
      ),
      StructuredEnumerationCase(
        name: "ping",
        accessor: { event in
          guard case .ping(let value) = event else { return nil }
          return value
        },
        initializer: { .ping($0) }
      )
    )
  }
}

/// Branch-A associated value: its sole `String` property has an initial value
/// (`""`), so the case is seeded the moment the discriminator identifies it.
private struct Message: StructuredObject, Equatable, Sendable {

  var body: String

  init(body: String) {
    self.body = body
  }

  typealias _BodyProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<String>
  >
  typealias Schema = StructuredObjectSchema<Self, _BodyProperty.Definition>
  typealias StructuredObjectProperties = _BodyProperty
  static func properties() -> StructuredObjectProperties {
    _BodyProperty(name: "body", keyPath: \.body, schema: _BodyProperty.CodingSchema())
  }

  typealias ObjectDecoderValues = _BodyProperty.ObjectDecoderValue
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self
  {
    Self(body: objectDecoder.values)
  }
}

/// Branch-B associated value: `Int` properties have no initial value, so the
/// case cannot exist until both are buffered and the object is constructed.
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
  typealias Schema = StructuredObjectSchema<Self, _XProperty.Definition, _YProperty.Definition>
  typealias StructuredObjectProperties = (_XProperty, _YProperty)
  static func properties() -> StructuredObjectProperties {
    (
      _XProperty(name: "x", keyPath: \.x, schema: _XProperty.CodingSchema()),
      _YProperty(name: "y", keyPath: \.y, schema: _YProperty.CodingSchema())
    )
  }

  typealias ObjectDecoderValues = (
    _XProperty.ObjectDecoderValue, _YProperty.ObjectDecoderValue
  )
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self
  {
    Self(x: objectDecoder.values.0, y: objectDecoder.values.1)
  }
}

/// An associated value with no properties — its object carries only the
/// discriminator.
private struct Ping: StructuredObject, Equatable, Sendable {

  init() {}

  typealias Schema = StructuredObjectSchema<Self>
  typealias StructuredObjectProperties = ()
  static func properties() -> StructuredObjectProperties { () }

  typealias ObjectDecoderValues = ()
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self
  {
    Self()
  }
}

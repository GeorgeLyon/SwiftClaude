import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// An `StructuredEnumeration` has no initial value, so an object containing one decodes
/// through the deferred (Branch B) path. But an enumeration *partially*
/// initializes the moment its case name is known: it seeds the case with the
/// associated value's initial value (e.g. `""` for `String`) before streaming
/// the rest. That `initializeValue` flows out through `InitializingAccessor`
/// and constructs the *outer* object mid-stream — so the outer value becomes
/// observable as soon as the inner case is identified, well before the
/// associated value finishes.
@Suite("Enumeration Property")
struct EnumerationPropertyTests {

  @Test func decodesObjectWithEnumProperty() throws {
    try test(
      #"{"x":4,"choice":{"text":"hello"}}"#,
      decodesAs: EnumHolder(x: 4, choice: .text("hello"))
    )
  }

  @Test func decodesObjectWithEnumPropertyChunked() throws {
    try test(
      [#"{"x":4,"choice":{"te"#, #"xt":"hel"#, #"lo"}}"#],
      decodesAs: EnumHolder(x: 4, choice: .text("hello"))
    )
  }

  /// The key case: as soon as the inner case name is read, the enum seeds
  /// `.text("")`, which constructs the outer object. The associated string has
  /// not produced any characters yet, so the observable value is `.text("")`.
  @Test func outerObjectInitializesOnceInnerCaseKnown() throws {
    try test(
      #"{"x":4,"choice":{"text":""#,
      decodesAs: .partial(EnumHolder(x: 4, choice: .text("")))
    )
  }

  /// Once associated-value characters arrive, the outer object reflects them
  /// (lagging by one buffered character, like any streamed string).
  @Test func outerObjectReflectsStreamingAssociatedValue() throws {
    try test(
      #"{"x":4,"choice":{"text":"hel"#,
      decodesAs: .partial(EnumHolder(x: 4, choice: .text("he")))
    )
  }

  /// Before the inner case is known, the outer object cannot exist yet.
  @Test func outerObjectIncompleteBeforeInnerCaseKnown() throws {
    try test(
      #"{"x":4,"choice":{"#,
      decodesAs: DecodingOutcome<EnumHolder>.incomplete
    )
  }

  /// A case with an Optional associated value initializes twice during its
  /// decode — once to seed the wrapper and once for the wrapped value — so the
  /// re-entrant `initializeValue` must not re-stream already-streaming siblings.
  @Test func decodesObjectWithEnumPropertyCarryingOptionalPayload() throws {
    try test(
      #"{"x":4,"choice":{"maybe":{"value":7}}}"#,
      decodesAs: OptionalPayloadHolder(x: 4, choice: .maybe(7))
    )
  }
}

// MARK: - Fixtures

private enum Choice: StructuredEnumeration, Equatable, Sendable {

  typealias Schema = StructuredAnySchema

  case text(String)
  case number(Int)

  typealias Cases = (
    StructuredEnumerationCase<Self, String>,
    StructuredEnumerationCase<Self, Int>
  )
  static func cases() -> Cases {
    (
      StructuredEnumerationCase(
        name: "text",
        accessor: { choice in
          guard case .text(let value) = choice else { return nil }
          return value
        },
        initializer: { .text($0) }
      ),
      StructuredEnumerationCase(
        name: "number",
        accessor: { choice in
          guard case .number(let value) = choice else { return nil }
          return value
        },
        initializer: { .number($0) }
      )
    )
  }
}

/// Branch-B outer object whose `choice` is an enumeration: neither `x` nor
/// `choice` can be supplied up front.
private struct EnumHolder: StructuredObject, Equatable, Sendable {

  var x: Int
  var choice: Choice

  init(x: Int, choice: Choice) {
    self.x = x
    self.choice = choice
  }

  typealias _XProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<Int>
  >
  typealias _ChoiceProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<Choice>
  >
  typealias Schema = StructuredObjectSchema<Self, _XProperty.Definition, _ChoiceProperty.Definition>
  typealias StructuredObjectProperties = (_XProperty, _ChoiceProperty)
  static func properties() -> StructuredObjectProperties {
    (
      _XProperty(name: "x", keyPath: \.x, schema: _XProperty.CodingSchema()),
      _ChoiceProperty(name: "choice", keyPath: \.choice, schema: _ChoiceProperty.CodingSchema())
    )
  }

  typealias ObjectDecoderValues = (
    _XProperty.ObjectDecoderValue, _ChoiceProperty.ObjectDecoderValue
  )
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
    Self(x: objectDecoder.values.0, choice: objectDecoder.values.1)
  }
}

/// An object-properties enumeration with a single case carrying an Optional
/// payload, which initializes twice during its decode (seed, then wrapped value).
private enum MaybeChoice: StructuredEnumeration, Equatable, Sendable {

  typealias Schema = StructuredAnySchema

  case maybe(Int?)

  typealias Cases = StructuredEnumerationCase<Self, Int?>
  static func cases() -> Cases {
    StructuredEnumerationCase(
      name: "maybe",
      accessor: { choice in
        guard case .maybe(let value) = choice else { return nil }
        return value
      },
      initializer: { .maybe($0) }
    )
  }
}

/// Branch-B holder whose last unavailable property is an enumeration with an
/// Optional associated value, exercising the re-entrant case initialization.
private struct OptionalPayloadHolder: StructuredObject, Equatable, Sendable {

  var x: Int
  var choice: MaybeChoice

  init(x: Int, choice: MaybeChoice) {
    self.x = x
    self.choice = choice
  }

  typealias _XProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<Int>
  >
  typealias _ChoiceProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<MaybeChoice>
  >
  typealias Schema = StructuredObjectSchema<Self, _XProperty.Definition, _ChoiceProperty.Definition>
  typealias StructuredObjectProperties = (_XProperty, _ChoiceProperty)
  static func properties() -> StructuredObjectProperties {
    (
      _XProperty(name: "x", keyPath: \.x, schema: _XProperty.CodingSchema()),
      _ChoiceProperty(name: "choice", keyPath: \.choice, schema: _ChoiceProperty.CodingSchema())
    )
  }

  typealias ObjectDecoderValues = (
    _XProperty.ObjectDecoderValue, _ChoiceProperty.ObjectDecoderValue
  )
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
    Self(x: objectDecoder.values.0, choice: objectDecoder.values.1)
  }
}

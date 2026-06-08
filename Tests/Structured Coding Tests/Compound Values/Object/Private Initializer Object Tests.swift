import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// Mirrors the shape the `@StructuredCodable` macro now generates: the `StructuredObject`
/// conformance lives in an extension and `decode(from:)` delegates to a
/// `private init(from:)` that assigns the stored properties directly — rather than
/// relying on a memberwise initializer the type may not expose. Each fixture
/// defines its own `init`, suppressing the implicit memberwise one, to prove the
/// generated decoder does not depend on it. Together they exercise an extension
/// initializer assigning a required `let`, a constant `let`, a required `var`, an
/// optional `var`, and default-initialized `var`s (the `if let` path) on both the
/// buffered (Branch B) and streamed (Branch A) decode routes.
@Suite("Private-Initializer Object")
struct PrivateInitializerObjectTests {

  // MARK: - Branch B (required `let`)

  @Test func decodesAllPropertyKinds() throws {
    try test(
      #"{"id":1,"name":"a","note":"b","kind":"fixed","count":5}"#,
      decodesAs: PrivateInitObject(id: 1, name: "a", note: "b", count: 5)
    )
  }

  /// The optional `note` may be omitted (decoding to `nil`); the constant `kind`
  /// is supplied by the type's own initializer.
  @Test func omittedOptionalDecodesAsNil() throws {
    try test(
      #"{"id":1,"name":"a","kind":"fixed","count":5}"#,
      decodesAs: PrivateInitObject(id: 1, name: "a", note: nil, count: 5)
    )
  }

  /// `count` (a `var = 10` wrapping a required definition) must still be present —
  /// its default is the streaming seed, not a JSON-omittable default.
  @Test func omittedRequiredDefaultThrows() throws {
    #expect(throws: (any Error).self) {
      try test(
        #"{"id":1,"name":"a","kind":"fixed"}"#,
        decodesAs: PrivateInitObject(id: 1, name: "a", note: nil, count: 10)
      )
    }
  }

  @Test func presentMismatchedConstantThrows() throws {
    #expect(throws: (any Error).self) {
      try test(
        #"{"id":1,"name":"a","kind":"other","count":5}"#,
        decodesAs: PrivateInitObject(id: 1, name: "a", note: nil, count: 5)
      )
    }
  }

  // MARK: - Branch A (streamed required/optional `var`)

  @Test func streamsInPlace() throws {
    try test(
      #"{"first":"hello","second":"world"}"#,
      decodesAs: StreamingObject(first: "hello", second: "world")
    )
  }

  @Test func partialReflectsStreaming() throws {
    try test(
      #"{"first":"hel"#,
      decodesAs: .partial(StreamingObject(first: "he", second: nil))
    )
  }

  // MARK: - Branch A (default-initialized `var` — the `if let` seed path)

  /// Constructed up front seeded with its property defaults, so before any value
  /// streams in the `if let` bindings see `nil` and keep `count == 10` / `note == nil`.
  @Test func partialExposesDefaults() throws {
    try test(#"{"#, decodesAs: .partial(DefaultStreamingObject(count: 10, note: nil)))
  }

  @Test func streamedValuesOverrideDefaults() throws {
    try test(
      #"{"count":5,"note":"hi"}"#,
      decodesAs: DefaultStreamingObject(count: 5, note: "hi")
    )
  }

  @Test func omittedOptionalKeepsDefault() throws {
    try test(#"{"count":5}"#, decodesAs: DefaultStreamingObject(count: 5, note: nil))
  }
}

// MARK: - Fixtures

/// A Branch-B object (`let id` has no initial value) spanning every property kind:
/// required `let`, required `var`, optional `var`, constant `let`, default `var`.
private struct PrivateInitObject: Equatable, Sendable {

  let id: Int
  var name: String
  var note: String?
  let kind: String = "fixed"
  var count: Int = 10

  /// A custom initializer, so there is no implicit memberwise initializer to rely on.
  init(id: Int, name: String, note: String?, count: Int) {
    self.id = id
    self.name = name
    self.note = note
    self.count = count
  }
}

extension PrivateInitObject: StructuredObject {

  typealias _IDProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<Int>
  >
  typealias _NameProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<String>
  >
  typealias _NoteProperty = StructuredObjectProperty<
    Self, StructuredOptionalObjectPropertyDefinition<String>
  >
  typealias _KindProperty = StructuredObjectProperty<
    Self,
    StructuredImmutableDefaultInitializedPropertyDefinition<
      StructuredRequiredObjectPropertyDefinition<String>
    >
  >
  typealias _CountProperty = StructuredObjectProperty<
    Self,
    StructuredMutableDefaultInitializedPropertyDefinition<
      StructuredRequiredObjectPropertyDefinition<Int>
    >
  >
  typealias Schema = StructuredObjectSchema<Self, _IDProperty.Definition, _NameProperty.Definition, _NoteProperty.Definition, _KindProperty.Definition, _CountProperty.Definition>
  typealias StructuredObjectProperties = (_IDProperty, _NameProperty, _NoteProperty, _KindProperty, _CountProperty)
  static func properties() -> StructuredObjectProperties {
    (
      _IDProperty(name: "id", keyPath: \.id, schema: _IDProperty.CodingSchema()),
      _NameProperty(name: "name", keyPath: \.name, schema: _NameProperty.CodingSchema()),
      _NoteProperty(name: "note", keyPath: \.note, schema: _NoteProperty.CodingSchema()),
      _KindProperty(name: "kind", keyPath: \.kind, schema: _KindProperty.CodingSchema()),
      _CountProperty(name: "count", keyPath: \.count, schema: _CountProperty.CodingSchema())
    )
  }

  typealias ObjectDecoderValues = (
    _IDProperty.ObjectDecoderValue, _NameProperty.ObjectDecoderValue,
    _NoteProperty.ObjectDecoderValue, _KindProperty.ObjectDecoderValue,
    _CountProperty.ObjectDecoderValue
  )
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>)
    -> sending Self
  {
    Self(from: objectDecoder)
  }
  private init(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>) {
    self.id = objectDecoder.values.0
    self.name = objectDecoder.values.1
    self.note = objectDecoder.values.2
    // `kind` is a default-initialized `let`; its declared value is kept.
    if let count = objectDecoder.values.4 {
      self.count = count
    }
  }
}

/// A Branch-A object (both properties have initial values) so it is constructed up
/// front and streamed in place — exercising the private initializer on the
/// streaming path.
private struct StreamingObject: Equatable, Sendable {

  var first: String
  var second: String?

  init(first: String, second: String?) {
    self.first = first
    self.second = second
  }
}

extension StreamingObject: StructuredObject {

  typealias _FirstProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<String>
  >
  typealias _SecondProperty = StructuredObjectProperty<
    Self, StructuredOptionalObjectPropertyDefinition<String>
  >
  typealias Schema = StructuredObjectSchema<Self, _FirstProperty.Definition, _SecondProperty.Definition>
  typealias StructuredObjectProperties = (_FirstProperty, _SecondProperty)
  static func properties() -> StructuredObjectProperties {
    (
      _FirstProperty(name: "first", keyPath: \.first, schema: _FirstProperty.CodingSchema()),
      _SecondProperty(name: "second", keyPath: \.second, schema: _SecondProperty.CodingSchema())
    )
  }

  typealias ObjectDecoderValues = (
    _FirstProperty.ObjectDecoderValue, _SecondProperty.ObjectDecoderValue
  )
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>)
    -> sending Self
  {
    Self(from: objectDecoder)
  }
  private init(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>) {
    self.first = objectDecoder.values.0
    self.second = objectDecoder.values.1
  }
}

/// A Branch-A object whose `var`s carry property-level defaults, so the private
/// initializer takes the `if let` path: when a decoded value is absent (the
/// initial seed) the property keeps its declared default.
private struct DefaultStreamingObject: Equatable, Sendable {

  var count: Int = 10
  var note: String? = nil

  init(count: Int = 10, note: String? = nil) {
    self.count = count
    self.note = note
  }
}

extension DefaultStreamingObject: StructuredObject {

  typealias _CountProperty = StructuredObjectProperty<
    Self,
    StructuredMutableDefaultInitializedPropertyDefinition<
      StructuredRequiredObjectPropertyDefinition<Int>
    >
  >
  typealias _NoteProperty = StructuredObjectProperty<
    Self,
    StructuredMutableDefaultInitializedPropertyDefinition<
      StructuredOptionalObjectPropertyDefinition<String>
    >
  >
  typealias Schema = StructuredObjectSchema<Self, _CountProperty.Definition, _NoteProperty.Definition>
  typealias StructuredObjectProperties = (_CountProperty, _NoteProperty)
  static func properties() -> StructuredObjectProperties {
    (
      _CountProperty(name: "count", keyPath: \.count, schema: _CountProperty.CodingSchema()),
      _NoteProperty(name: "note", keyPath: \.note, schema: _NoteProperty.CodingSchema())
    )
  }

  typealias ObjectDecoderValues = (
    _CountProperty.ObjectDecoderValue, _NoteProperty.ObjectDecoderValue
  )
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>)
    -> sending Self
  {
    Self(from: objectDecoder)
  }
  private init(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>) {
    if let count = objectDecoder.values.0 {
      self.count = count
    }
    if let note = objectDecoder.values.1 {
      self.note = note
    }
  }
}

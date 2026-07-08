import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// Constant (`let … = default`) properties are modelled by
/// `StructuredImmutableDefaultInitializedPropertyDefinition`. Whether the property must appear in
/// the JSON is driven by `shouldOmit` of its constant value:
///
/// - `let kind: String = "fixed"` — `shouldOmit("fixed") == false`, so the
///   property must be present and equal the constant.
/// - `let opt: String? = nil` — `shouldOmit(nil) == true`, so the property must
///   be omitted; any present value can never equal the `nil` constant.
@Suite("Constant Properties")
struct ConstantPropertyTests {

  @Test func presentMatchingConstantDecodes() throws {
    try test(#"{"kind":"fixed"}"#, decodesAs: ConstantObject())
  }

  @Test func presentMismatchedConstantThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#"{"kind":"other"}"#, decodesAs: ConstantObject())
    }
  }

  @Test func omittedRequiredConstantThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#"{}"#, decodesAs: ConstantObject())
    }
  }

  @Test func omittedNilOptionalConstantDecodes() throws {
    try test(#"{"kind":"fixed"}"#, decodesAs: ConstantObject())
  }

  @Test func presentNilOptionalConstantThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#"{"kind":"fixed","opt":"x"}"#, decodesAs: ConstantObject())
    }
  }

  /// A constant in a deferred (Branch B) object whose constant property arrives
  /// *before* the object is constructed must decode identically to the
  /// sibling-first order — its buffered state must not be left `.seeded` and
  /// rejected as `uninitializedValue`.
  @Test func constantBeforeDeferredScalarDecodes() throws {
    try test(#"{"kind":"fixed","id":1}"#, decodesAs: TaggedConstantObject(id: 1))
  }

  @Test func deferredScalarBeforeConstantDecodes() throws {
    try test(#"{"id":1,"kind":"fixed"}"#, decodesAs: TaggedConstantObject(id: 1))
  }

  // MARK: - Partial streaming

  /// Constants are seeded up front and never mutated while streaming (the
  /// property value is decoded into a throwaway for validation), so the object
  /// is observable as its constant value throughout — even mid-property.
  @Test func partialExposesConstantValue() throws {
    try test(#"{"kind":"fix"#, decodesAs: .partial(ConstantObject()))
  }
}

// MARK: - Fixture

private struct ConstantObject: StructuredObject, Equatable, Sendable {

  let kind: String
  let opt: String?

  init(kind: String = "fixed", opt: String? = nil) {
    self.kind = kind
    self.opt = opt
  }

  typealias _KindProperty = StructuredObjectProperty<
    Self,
    StructuredImmutableDefaultInitializedPropertyDefinition<
      StructuredRequiredObjectPropertyDefinition<String>
    >
  >
  typealias _OptProperty = StructuredObjectProperty<
    Self,
    StructuredImmutableDefaultInitializedPropertyDefinition<
      StructuredOptionalObjectPropertyDefinition<String>
    >
  >
  static var schema: some StructuredCodingSchema {
    _schema()
  }
  typealias StructuredObjectProperties = (_KindProperty, _OptProperty)
  static func properties() -> StructuredObjectProperties {
    (
      _KindProperty(name: "kind", keyPath: \.kind, schema: _KindProperty.Definition.CodingValue.schema),
      _OptProperty(name: "opt", keyPath: \.opt, schema: _OptProperty.Definition.CodingValue.schema)
    )
  }

  typealias ObjectDecoderValues = (
    _KindProperty.ObjectDecoderValue, _OptProperty.ObjectDecoderValue
  )
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>)
    -> sending Self
  {
    Self()
  }
}

/// A deferred scalar (`let id: Int`, get-only) plus a constant
/// (`let kind: String = "fixed"`, default-initialised) — exercises a constant in
/// a Branch B object, where construction is deferred until `id` arrives.
private struct TaggedConstantObject: StructuredObject, Equatable, Sendable {

  let id: Int
  let kind: String

  init(id: Int, kind: String = "fixed") {
    self.id = id
    self.kind = kind
  }

  typealias _IDProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<Int>
  >
  typealias _KindProperty = StructuredObjectProperty<
    Self,
    StructuredImmutableDefaultInitializedPropertyDefinition<
      StructuredRequiredObjectPropertyDefinition<String>
    >
  >
  static var schema: some StructuredCodingSchema {
    _schema()
  }
  typealias StructuredObjectProperties = (_IDProperty, _KindProperty)
  static func properties() -> StructuredObjectProperties {
    (
      _IDProperty(name: "id", keyPath: \.id, schema: _IDProperty.Definition.CodingValue.schema),
      _KindProperty(name: "kind", keyPath: \.kind, schema: _KindProperty.Definition.CodingValue.schema)
    )
  }

  typealias ObjectDecoderValues = (
    _IDProperty.ObjectDecoderValue, _KindProperty.ObjectDecoderValue
  )
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>)
    -> sending Self
  {
    Self(id: objectDecoder.values.0)
  }
}

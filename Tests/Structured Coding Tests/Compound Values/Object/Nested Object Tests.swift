import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

@Suite("Nested Object Decoding")
struct NestedObjectTests {

  // MARK: - Branch-A child

  @Test func decodesNestedObject() throws {
    try test(
      #"{"label":"outer","inner":{"first":"hello","second":"world"}}"#,
      decodesAs: NestingObject(
        label: "outer",
        inner: MutableStringObject(first: "hello", second: "world")
      )
    )
  }

  @Test func decodesNestedObjectChunked() throws {
    try test(
      [
        #"{"label":"out"#,
        #"er","inner":{"first":"hel"#,
        #"lo","second":"world"}}"#,
      ],
      decodesAs: NestingObject(
        label: "outer",
        inner: MutableStringObject(first: "hello", second: "world")
      )
    )
  }

  @Test func partialMidInnerObject() throws {
    try test(
      #"{"label":"outer","inner":{"first":"hel"#,
      decodesAs: .partial(
        NestingObject(
          label: "outer",
          inner: MutableStringObject(first: "he", second: nil)
        )
      )
    )
  }

  // MARK: - Branch-B child

  /// The inner object cannot be constructed up front (its `value` is an `Int`),
  /// so the whole tree decodes through the deferred path — a Branch-B object
  /// nested inside a Branch-B object.
  @Test func decodesNestedDeferredObject() throws {
    try test(
      #"{"inner":{"value":7}}"#,
      decodesAs: DeferredParent(inner: SingleScalarObject(value: 7))
    )
  }

  @Test func decodesNestedDeferredObjectChunked() throws {
    try test(
      [#"{"inner":{"val"#, #"ue":7}}"#],
      decodesAs: DeferredParent(inner: SingleScalarObject(value: 7))
    )
  }
}

// MARK: - Fixtures

/// Branch-A parent wrapping a Branch-A child (`var inner`).
private struct NestingObject: StructuredObject, Equatable, Sendable {

  var label: String
  var inner: MutableStringObject

  init(label: String, inner: MutableStringObject) {
    self.label = label
    self.inner = inner
  }

  typealias _LabelProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<String>
  >
  typealias _InnerProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<MutableStringObject>
  >
  typealias StructuredObjectProperties = (_LabelProperty, _InnerProperty)
  static func properties() -> StructuredObjectProperties {
    (
      _LabelProperty(name: "label", keyPath: \.label, schema: _LabelProperty.Definition.CodingValue.schema(description: nil)),
      _InnerProperty(name: "inner", keyPath: \.inner, schema: _InnerProperty.Definition.CodingValue.schema(description: nil))
    )
  }

  typealias ObjectDecoderValues = (
    _LabelProperty.ObjectDecoderValue, _InnerProperty.ObjectDecoderValue
  )
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
    Self(label: objectDecoder.values.0, inner: objectDecoder.values.1)
  }
}

/// Branch-B parent wrapping a Branch-B child: neither can be built up front.
private struct DeferredParent: StructuredObject, Equatable, Sendable {

  let inner: SingleScalarObject

  init(inner: SingleScalarObject) {
    self.inner = inner
  }

  typealias _InnerProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<SingleScalarObject>
  >
  typealias StructuredObjectProperties = _InnerProperty
  static func properties() -> StructuredObjectProperties {
    _InnerProperty(name: "inner", keyPath: \.inner, schema: _InnerProperty.Definition.CodingValue.schema(description: nil))
  }

  typealias ObjectDecoderValues = _InnerProperty.ObjectDecoderValue
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
    Self(inner: objectDecoder.values)
  }
}

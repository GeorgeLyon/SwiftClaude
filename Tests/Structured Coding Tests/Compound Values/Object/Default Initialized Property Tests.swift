import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// `var … = default` properties (`StructuredMutableDefaultInitializedPropertyDefinition`) let the
/// object be constructed up front — seeded with the default — and then have the
/// JSON value streamed in. As with constants, whether the property may be
/// omitted follows `shouldOmit`: the required `count` must be present, while the
/// optional `note` may be omitted (keeping its default).
@Suite("Default Initialized Properties")
struct DefaultInitializedPropertyTests {

  @Test func presentValuesOverrideDefaults() throws {
    try test(#"{"count":5,"note":"hi"}"#, decodesAs: DefaultObject(count: 5, note: "hi"))
  }

  @Test func omittedOptionalKeepsDefault() throws {
    try test(#"{"count":5}"#, decodesAs: DefaultObject(count: 5, note: nil))
  }

  @Test func omittedRequiredThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#"{"note":"hi"}"#, decodesAs: DefaultObject(count: 10, note: "hi"))
    }
  }

  @Test func emptyObjectThrowsForRequiredDefault() throws {
    #expect(throws: (any Error).self) {
      try test(#"{}"#, decodesAs: DefaultObject(count: 10, note: nil))
    }
  }

  // MARK: - Partial streaming

  /// The object is constructed up front seeded with its defaults, so before any
  /// property arrives it is observable with those defaults.
  @Test func partialExposesDefaults() throws {
    try test(#"{"#, decodesAs: .partial(DefaultObject(count: 10, note: nil)))
  }

  /// Once properties stream in, the observable value reflects the overrides.
  @Test func partialReflectsStreamedOverrides() throws {
    try test(
      #"{"count":5,"note":"he"#,
      decodesAs: .partial(DefaultObject(count: 5, note: "h"))
    )
  }
}

// MARK: - Fixture

/// `count` defaults to `10` (required → must be present); `note` defaults to
/// `nil` (optional → may be omitted).
private struct DefaultObject: StructuredObject, Equatable, Sendable {

  var count: Int
  var note: String?

  init(count: Int = 10, note: String? = nil) {
    self.count = count
    self.note = note
  }

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
  static func schema(description: String?) -> some StructuredCodable {
    _schema(description: description)
  }
  typealias StructuredObjectProperties = (_CountProperty, _NoteProperty)
  static func properties() -> StructuredObjectProperties {
    (
      _CountProperty(name: "count", keyPath: \.count, schema: _CountProperty.Definition.CodingValue.schema(description: nil)),
      _NoteProperty(name: "note", keyPath: \.note, schema: _NoteProperty.Definition.CodingValue.schema(description: nil))
    )
  }

  typealias ObjectDecoderValues = (
    _CountProperty.ObjectDecoderValue, _NoteProperty.ObjectDecoderValue
  )
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>)
    -> sending Self
  {
    Self(
      count: objectDecoder.values.0 ?? 10,
      note: objectDecoder.values.1 ?? nil
    )
  }
}

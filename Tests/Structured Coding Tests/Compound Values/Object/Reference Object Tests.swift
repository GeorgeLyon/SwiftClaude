import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// A class-backed object exercises `ReferenceWritableKeyPath` properties: the
/// `.referenceWritable` tag makes the accessor always mutable, and streaming
/// mutates the class instance in place.
@Suite("Reference Object Decoding")
struct ReferenceObjectTests {

  @Test func decodesReferenceObject() throws {
    try test(#"{"name":"abc"}"#, decodesAs: ReferenceObject(name: "abc"))
  }

  @Test func decodesReferenceObjectChunked() throws {
    try test([#"{"na"#, #"me":"ab"#, #"c"}"#], decodesAs: ReferenceObject(name: "abc"))
  }

  @Test func partialMidProperty() throws {
    try test(#"{"name":"ab"#, decodesAs: .partial(ReferenceObject(name: "a")))
  }
}

// MARK: - Fixture

private final class ReferenceObject: StructuredObject, @unchecked Sendable, Equatable {

  var name: String

  init(name: String = "") {
    self.name = name
  }

  static func == (lhs: ReferenceObject, rhs: ReferenceObject) -> Bool {
    lhs.name == rhs.name
  }

  typealias _NameProperty = StructuredObjectProperty<
    ReferenceObject, StructuredRequiredObjectPropertyDefinition<String>
  >
  static var schema: some StructuredCodingSchema {
    _schema()
  }
  typealias StructuredObjectProperties = _NameProperty
  static func properties() -> StructuredObjectProperties {
    _NameProperty(name: "name", keyPath: \.name, schema: _NameProperty.Definition.CodingValue.schema)
  }

  typealias ObjectDecoderValues = _NameProperty.ObjectDecoderValue
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
    Self(name: objectDecoder.values)
  }
}

import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// A pack-generic object — exercises
/// `@StructuredCodable(compatibilityMode: [.variadicGenerics, .omitSchema])`:
/// `.variadicGenerics` accesses properties through getter closures because key
/// path literals rooted in a pack-generic type crash at runtime, and
/// `.omitSchema` falls back to `StructuredAnySchema` because the structural
/// schema's witness mangling contains pack expansions the runtime demangler
/// cannot resolve (see `StructuredCodingCompatibilityMode`).
@StructuredCodable(compatibilityMode: [.variadicGenerics, .omitSchema])
private struct PackGenericObject<each T>: Equatable {
  var first: String
  var second: String?
}

/// Resolves `Schema` through the protocol witness, the way generic code does —
/// this forces runtime demangling of the witness's mangled name, which is
/// exactly what aborts for pack-expansion-bearing structural schemas.
private func resolvedSchemaType<T: StructuredEncodable>(of _: T.Type) -> Any.Type {
  T.Schema.self
}

@Suite("Variadic Generic Objects")
struct VariadicGenericObjectTests {

  /// Instantiating the property descriptors crashed with the default key-path
  /// emission ("Pack expansion count type should be a pack").
  @Test func propertiesMetadataInstantiates() throws {
    _ = PackGenericObject<Int, String>.properties()
  }

  /// `.omitSchema` makes the witness the concrete associated-type default.
  @Test func schemaWitnessResolves() throws {
    #expect(resolvedSchemaType(of: PackGenericObject<Int, String>.self) is StructuredAnySchema.Type)
  }

  /// The `.omitSchema` trade-off: the type's JSON schema degrades to
  /// "any value" — an empty schema — rather than a structural description.
  @Test func schemaEncodesAsAny() throws {
    try test(PackGenericObject<Int, String>.Schema(), encodesAs: "{}")
  }

  @Test func encodes() throws {
    try test(
      PackGenericObject<Int, String>(first: "hello", second: "world"),
      encodesAs: #"{"first":"hello","second":"world"}"#
    )
  }

  @Test func decodes() throws {
    try test(
      #"{"first":"hello","second":"world"}"#,
      decodesAs: PackGenericObject<Int, String>(first: "hello", second: "world")
    )
  }

}

/// `StructuredObjectSchema` is itself pack-generic, so the schema of a
/// concrete type exercises both compatibility modes plus the hand-applied
/// `omitSchema` fallback on its nested `Properties` type.
@Suite("Object Schema Metadata")
struct ObjectSchemaMetadataTests {

  @Test func constructsSchema() throws {
    _ = MutableStringObject.Schema()
  }

  /// Crashed twice historically: first instantiating the macro-generated key
  /// paths, then resolving `Properties`' structural `Schema` witness while
  /// completing `StructuredObjectProperty` metadata.
  @Test func schemaPropertiesMetadataInstantiates() throws {
    _ = MutableStringObject.Schema.properties()
  }

}

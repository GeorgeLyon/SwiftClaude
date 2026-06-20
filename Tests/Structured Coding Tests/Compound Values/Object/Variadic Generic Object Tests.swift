import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// A pack-generic object — exercises
/// `@StructuredCodable(compatibilityMode: .variadicGenerics)`, which accesses
/// properties through getter closures because key path literals rooted in a
/// pack-generic type crash at runtime (see `StructuredCodingCompatibilityMode`).
/// Instead of a structural `Schema`, the macro emits a type-erased
/// `schema(description:) -> StructuredAnySchema`, so `Schema` is inferred as
/// `StructuredAnySchema` — a structural schema's witness mangling would contain
/// a pack expansion the runtime demangler cannot resolve.
@StructuredCodable(compatibilityMode: .variadicGenerics)
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

  /// The macro emits a type-erased `schema(description:)`, so `Schema` is
  /// inferred as `StructuredAnySchema`.
  @Test func schemaWitnessResolves() throws {
    #expect(resolvedSchemaType(of: PackGenericObject<Int, String>.self) is StructuredAnySchema.Type)
  }

  /// The trade-off of not emitting a structural schema: the type's JSON schema
  /// degrades to "any value" — an empty schema — rather than a structural
  /// description.
  @Test func schemaEncodesAsAny() throws {
    // `.variadicGenerics` resolves `schema(description:)` to the type-erased
    // overload; the explicit `Schema` type selects it over the structural
    // `StructuredObject.schema` extension.
    let schema: PackGenericObject<Int, String>.Schema =
      PackGenericObject<Int, String>.schema(description: nil)
    try test(schema, encodesAs: "{}")
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
/// concrete type exercises `.variadicGenerics` plus the `StructuredAnySchema`
/// default that stands in for its (and its nested `Properties`') schema.
@Suite("Object Schema Metadata")
struct ObjectSchemaMetadataTests {

  @Test func constructsSchema() throws {
    _ = MutableStringObject.schema(description: nil)
  }

  /// Crashed twice historically: first instantiating the macro-generated key
  /// paths, then resolving `Properties`' structural `Schema` witness while
  /// completing `StructuredObjectProperty` metadata.
  @Test func schemaPropertiesMetadataInstantiates() throws {
    _ = MutableStringObject.Schema.properties()
  }

}

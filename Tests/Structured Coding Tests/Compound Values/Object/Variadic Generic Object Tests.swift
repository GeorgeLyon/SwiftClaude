import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// A pack-generic object — exercises
/// `@StructuredCodable(compatibilityMode: .variadicGenerics)`, which accesses
/// properties through getter closures because key path literals rooted in a
/// pack-generic type crash at runtime (see `StructuredCodingCompatibilityMode`).
/// The JSON schema is the shared non-generic `StructuredObjectSchema` built by
/// the `StructuredObject` extension — because the schema type carries no pack,
/// its witness mangling is safe to demangle even for pack-generic objects.
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

  /// `Schema` is inferred as the non-generic `StructuredObjectSchema` from the
  /// `StructuredObject` extension's `schema(description:)` witness.
  @Test func schemaWitnessResolves() throws {
    #expect(resolvedSchemaType(of: PackGenericObject<Int, String>.self) is StructuredObjectSchema.Type)
  }

  /// `.variadicGenerics` no longer degrades the schema: pack-generic objects
  /// get the same structural description as ordinary objects.
  @Test func schemaEncodesStructurally() throws {
    try test(
      PackGenericObject<Int, String>.schema(description: nil),
      encodesAs:
        #"{"properties":{"first":{"type":"string"},"second":{"type":"string"}},"required":["first"]}"#
    )
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

/// `StructuredObjectSchema` must stay non-generic — naming a schema type
/// parameterized by the property-definition pack crashes the runtime
/// demangler — so its own meta-schema erases to `StructuredAnySchema`.
@Suite("Object Schema Metadata")
struct ObjectSchemaMetadataTests {

  @Test func constructsSchema() throws {
    _ = MutableStringObject.schema(description: nil)
  }

  @Test func metaSchemaWitnessResolves() throws {
    #expect(resolvedSchemaType(of: StructuredObjectSchema.self) is StructuredAnySchema.Type)
  }

}

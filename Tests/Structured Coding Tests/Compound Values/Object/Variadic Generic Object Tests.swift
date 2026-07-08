import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// A pack-generic object — the macro infers `.variadicGenerics`
/// compatibility from the parameter pack and accesses properties through
/// getter closures, because key path literals rooted in a pack-generic type
/// crash at runtime (see `StructuredCodingCompatibilityMode`).
/// The JSON schema is built by the shared `StructuredObject._schema`
/// extension — because the underlying schema type carries no pack, its
/// witness mangling is safe to demangle even for pack-generic objects.
@StructuredCodable
private struct PackGenericObject<each T>: Equatable {
  var first: String
  var second: String?
}

/// A non-generic object *nested in* a pack-generic type: its generic
/// signature inherits the pack, so key paths rooted in it crash just the
/// same. The macro infers `.variadicGenerics` from the lexical context.
/// (Internal rather than `private` — the generated extension members cannot
/// reference a type nested inside a private declaration.)
struct PackGenericOuter<each T> {
  @StructuredCodable
  struct Inner: Equatable {
    var name: String
  }
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

  /// `Schema` is inferred as the opaque type of the macro-generated
  /// `schema` trampoline; resolving it through the witness
  /// exercises the runtime demangling that pack-parameterized schema types
  /// used to crash. (The underlying type is deliberately not pinned.)
  @Test func schemaWitnessResolves() throws {
    _ = resolvedSchemaType(of: PackGenericObject<Int, String>.self)
  }

  /// `.variadicGenerics` no longer degrades the schema: pack-generic objects
  /// get the same structural description as ordinary objects.
  @Test func schemaEncodesStructurally() throws {
    try test(
      PackGenericObject<Int, String>.schema,
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

  /// Instantiating the property descriptors of a type nested in a
  /// pack-generic type crashes with key-path emission exactly like the
  /// directly pack-generic case — inference through the lexical context
  /// must kick in.
  @Test func nestedPropertiesMetadataInstantiates() throws {
    _ = PackGenericOuter<Int, String>.Inner.properties()
  }

  @Test func nestedEncodes() throws {
    try test(
      PackGenericOuter<Int, String>.Inner(name: "nested"),
      encodesAs: #"{"name":"nested"}"#
    )
  }

  @Test func nestedDecodes() throws {
    try test(
      #"{"name":"nested"}"#,
      decodesAs: PackGenericOuter<Int, String>.Inner(name: "nested")
    )
  }

}

/// The schema type behind the witnesses must stay non-generic — naming a
/// schema type parameterized by the property-definition pack crashes the
/// runtime demangler.
@Suite("Object Schema Metadata")
struct ObjectSchemaMetadataTests {

  @Test func constructsSchema() throws {
    _ = MutableStringObject.schema
  }

}

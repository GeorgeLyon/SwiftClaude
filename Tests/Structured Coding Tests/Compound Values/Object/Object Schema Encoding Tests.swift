import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// Covers every `isRequired` disposition: plain required and optional
/// properties, a default-initialized constant (`let` — required, the decoder
/// rejects omission), a default-initialized required `var` (also required),
/// and a default-initialized optional `var` (omittable).
@StructuredCodable
private struct DefaultedObject {
  var first: String
  var second: String?
  let kind: String = "fixed"
  var count: Int = 10
  var note: String? = "hello"
}

/// An object whose property is itself an object — its schema embeds the
/// child's object schema (with the child's own `required` array) recursively.
@StructuredCodable
private struct ParentObject {
  var label: String
  var child: MutableStringObject
}

@Suite("Object Schema Encoding")
struct ObjectSchemaEncodingTests {

  @Test func encodesPropertiesAndRequired() async throws {
    try await test(
      MutableStringObject.schema,
      encodesAs:
        #"{"properties":{"first":{"type":"string"},"second":{"type":"string"}},"required":["first"]}"#
    )
  }

  @Test func encodesDescription() async throws {
    try await test(
      MutableStringObject.schema.prependDescription("A mutable pair of strings"),
      encodesAs:
        #"{"description":"A mutable pair of strings","properties":{"first":{"type":"string"},"second":{"type":"string"}},"required":["first"]}"#
    )
  }

  /// Every property is omittable, so the `required` key is omitted entirely.
  @Test func omitsEmptyRequired() async throws {
    try await test(
      OptionalMutableObject.schema,
      encodesAs:
        #"{"properties":{"a":{"type":"string"},"b":{"type":"string"}}}"#
    )
  }

  @Test func encodesEmptyObjectSchema() async throws {
    try await test(
      EmptyObject.schema,
      encodesAs: #"{"properties":{}}"#
    )
  }

  /// `required` mirrors the decoder: default-initialized properties with a
  /// required core (`kind`, `count`) may not be omitted, while optional cores
  /// (`second`, `note`) may.
  @Test func requiredReflectsDefaultedProperties() async throws {
    try await test(
      DefaultedObject.schema,
      encodesAs:
        #"{"properties":{"first":{"type":"string"},"second":{"type":"string"},"kind":{"type":"string"},"count":{"type":"integer"},"note":{"type":"string"}},"required":["first","kind","count"]}"#
    )
  }

  @Test func encodesNestedObjectSchema() async throws {
    try await test(
      ParentObject.schema,
      encodesAs:
        #"{"properties":{"label":{"type":"string"},"child":{"properties":{"first":{"type":"string"},"second":{"type":"string"}},"required":["first"]}},"required":["label","child"]}"#
    )
  }

  // MARK: - Decoding

  /// Schemas aren't `Equatable`, so decoding is verified by re-encoding.
  @Test func decodesByRoundTrip() async throws {
    let json =
      #"{"properties":{"first":{"type":"string"},"second":{"type":"string"}},"required":["first"]}"#
    try await test(
      JSONFragments(stringLiteral: json),
      decodesAs: .complete(MutableStringObject.schema),
      testEquality: { decoded, _, sourceLocation in
        let decoded = try #require(decoded, sourceLocation: sourceLocation)
        var stream = StructuredEncodingStream()
        try decoded.encode(to: &stream)
        #expect(stream.stringValue == json, sourceLocation: sourceLocation)
      }
    )
  }

  /// The empty-pack edge: no property schemas to decode, `required` omitted.
  @Test func decodesEmptyObjectSchemaByRoundTrip() async throws {
    let json = #"{"properties":{}}"#
    try await test(
      JSONFragments(stringLiteral: json),
      decodesAs: .complete(EmptyObject.schema),
      testEquality: { decoded, _, sourceLocation in
        let decoded = try #require(decoded, sourceLocation: sourceLocation)
        var stream = StructuredEncodingStream()
        try decoded.encode(to: &stream)
        #expect(stream.stringValue == json, sourceLocation: sourceLocation)
      }
    )
  }

}

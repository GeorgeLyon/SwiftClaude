import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// Spans the associated-value shapes of an object-properties enumeration: a
/// primitive case, an object case (macro-synthesized from an all-labeled
/// case), and a value-less case (`StructuredEmptyObject`).
@StructuredCodable
private enum Reaction: Equatable {
  case text(String)
  case point(x: Int, y: Int)
  case ping
}

/// An object with an enumeration-typed property — its schema embeds the
/// enumeration's `maxProperties: 1` object schema. Instantiating its property
/// descriptors also forces the enumeration's structural `Schema` witness.
@StructuredCodable
private struct Container: Equatable {
  var reaction: Reaction
}

/// A `String`-backed raw-value enumeration, whose `enum` members encode as
/// JSON strings.
private enum Alignment: String, CaseIterable, StructuredEnumeration, Sendable {
  case left
  case center
  case right
}

/// An integer-backed raw-value enumeration, whose `enum` members encode as
/// JSON numbers.
private enum Level: Int, CaseIterable, StructuredEnumeration, Sendable {
  case low = 1
  case medium = 2
  case high = 3
}

@Suite("Enumeration Schema Encoding")
struct EnumerationSchemaEncodingTests {

  @Test func encodesCaseProperties() throws {
    try test(
      Reaction.schema(description: nil),
      encodesAs:
        #"{"properties":{"text":{"type":"string"},"point":{"properties":{"x":{"type":"integer"},"y":{"type":"integer"}},"required":["x","y"]},"ping":{"properties":{}}},"maxProperties":1}"#
    )
  }

  @Test func encodesDescription() throws {
    try test(
      Reaction.schema(description: "A reaction"),
      encodesAs:
        #"{"description":"A reaction","properties":{"text":{"type":"string"},"point":{"properties":{"x":{"type":"integer"},"y":{"type":"integer"}},"required":["x","y"]},"ping":{"properties":{}}},"maxProperties":1}"#
    )
  }

  /// An enumeration-typed property contributes its structural schema to the
  /// containing object's schema (and the property descriptor's metadata
  /// instantiation resolves the enumeration's `Schema` witness).
  @Test func encodesAsObjectProperty() throws {
    try test(
      Container.schema(description: nil),
      encodesAs:
        #"{"properties":{"reaction":{"properties":{"text":{"type":"string"},"point":{"properties":{"x":{"type":"integer"},"y":{"type":"integer"}},"required":["x","y"]},"ping":{"properties":{}}},"maxProperties":1}},"required":["reaction"]}"#
    )
  }

  // MARK: - Raw Value

  /// A `CaseIterable` raw-value enumeration encodes as the `enum` keyword
  /// listing every case's raw value in declaration order — no `type` keyword.
  @Test func encodesStringRawValues() throws {
    try test(
      Alignment.schema(description: nil),
      encodesAs: #"{"enum":["left","center","right"]}"#
    )
  }

  @Test func encodesIntegerRawValues() throws {
    try test(
      Level.schema(description: nil),
      encodesAs: #"{"enum":[1,2,3]}"#
    )
  }

  @Test func encodesRawValueDescription() throws {
    try test(
      Alignment.schema(description: "Text alignment"),
      encodesAs: #"{"description":"Text alignment","enum":["left","center","right"]}"#
    )
  }

  // MARK: - Decoding

  /// Schemas aren't `Equatable`, so decoding is verified by re-encoding — this
  /// exercises the case-properties carrier's hand-written decoding.
  @Test func decodesByRoundTrip() throws {
    let json =
      #"{"description":"A reaction","properties":{"text":{"type":"string"},"point":{"properties":{"x":{"type":"integer"},"y":{"type":"integer"}},"required":["x","y"]},"ping":{"properties":{}}},"maxProperties":1}"#
    try test(
      JSONFragments(stringLiteral: json),
      decodesAs: .complete(Reaction.schema(description: nil)),
      testEquality: { decoded, _, sourceLocation in
        let decoded = try #require(decoded, sourceLocation: sourceLocation)
        var encoder = StructuredEncoder()
        try decoded.encode(to: &encoder)
        #expect(encoder.stringValue == json, sourceLocation: sourceLocation)
      }
    )
  }

}

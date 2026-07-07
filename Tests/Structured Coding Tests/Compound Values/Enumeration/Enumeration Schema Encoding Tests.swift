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

/// An object-properties enumeration mixing a labeled single value (which
/// synthesizes a one-property payload object) and an unlabeled one (whose
/// type is used directly).
@StructuredCodable
private enum Feedback: Equatable {
  case rating(stars: Int)
  case comment(String)
}

/// An internally-tagged enumeration discriminated by `"kind"`. Every case
/// payload must be an object for the discriminator to live alongside its
/// properties, so labeled values — even a single one — are macro-synthesized
/// into payload objects.
@StructuredCodable(style: .internallyTagged(discriminatorPropertyName: "kind"))
private enum Shape: Equatable {
  case circle(radius: Double)
  case rectangle(width: Double, height: Double)
}

/// Case descriptions across the associated-value shapes of the
/// object-properties style: a primitive case, an object case, and a
/// value-less case. `rating` is left undescribed.
@StructuredCodable
private enum DescribedFeedback: Equatable {
  @StructuredCase(description: "A free-form comment")
  case comment(String)
  case rating(stars: Int)
  @StructuredCase(description: "A 2D point")
  case point(x: Int, y: Int)
  @StructuredCase(description: "An empty ping")
  case ping
}

/// A described case of an internally-tagged enumeration — the description
/// lands on the case's `oneOf` branch.
@StructuredCodable(style: .internallyTagged(discriminatorPropertyName: "kind"))
private enum DescribedShape: Equatable {
  @StructuredCase(description: "A circle")
  case circle(radius: Double)
  case rectangle(width: Double, height: Double)
}

/// A described case of a type-discriminated enumeration — the description
/// lands on the case's `oneOf` branch.
@StructuredCodable(style: .typeDiscriminated)
private enum DescribedNode: Equatable {
  @StructuredCase(description: "A leaf string")
  case string(String)
  case point(x: Int, y: Int)
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

  /// A single labeled value synthesizes a one-property payload object in the
  /// default style too, so the label survives as a schema property name.
  @Test func encodesSingleLabeledValueAsObject() throws {
    try test(
      Feedback.schema(description: nil),
      encodesAs:
        #"{"properties":{"rating":{"properties":{"stars":{"type":"integer"}},"required":["stars"]},"comment":{"type":"string"}},"maxProperties":1}"#
    )
  }

  /// A `@StructuredCase` description becomes the description of the case's
  /// property schema, whatever the associated-value shape; undescribed cases
  /// are unchanged.
  @Test func encodesCaseDescriptions() throws {
    try test(
      DescribedFeedback.schema(description: nil),
      encodesAs:
        #"{"properties":{"comment":{"description":"A free-form comment","type":"string"},"rating":{"properties":{"stars":{"type":"integer"}},"required":["stars"]},"point":{"description":"A 2D point","properties":{"x":{"type":"integer"},"y":{"type":"integer"}},"required":["x","y"]},"ping":{"description":"An empty ping","properties":{}}},"maxProperties":1}"#
    )
  }

  // MARK: - Internally Tagged

  /// Each `oneOf` branch is the case's object schema with the discriminator
  /// property spliced in first, pinned to the case's name by `const` and
  /// always required. A single labeled value (`circle(radius:)`) synthesizes
  /// a one-property payload object just as multi-value cases do.
  @Test func encodesInternallyTaggedBranches() throws {
    try test(
      Shape.schema(description: nil),
      encodesAs:
        #"{"oneOf":[{"properties":{"kind":{"const":"circle"},"radius":{"type":"number"}},"required":["kind","radius"]},{"properties":{"kind":{"const":"rectangle"},"width":{"type":"number"},"height":{"type":"number"}},"required":["kind","width","height"]}]}"#
    )
  }

  @Test func encodesInternallyTaggedDescription() throws {
    try test(
      Shape.schema(description: "A shape"),
      encodesAs:
        #"{"description":"A shape","oneOf":[{"properties":{"kind":{"const":"circle"},"radius":{"type":"number"}},"required":["kind","radius"]},{"properties":{"kind":{"const":"rectangle"},"width":{"type":"number"},"height":{"type":"number"}},"required":["kind","width","height"]}]}"#
    )
  }

  /// A `@StructuredCase` description becomes the description of the case's
  /// `oneOf` branch, alongside the spliced-in discriminator.
  @Test func encodesInternallyTaggedCaseDescriptions() throws {
    try test(
      DescribedShape.schema(description: nil),
      encodesAs:
        #"{"oneOf":[{"description":"A circle","properties":{"kind":{"const":"circle"},"radius":{"type":"number"}},"required":["kind","radius"]},{"properties":{"kind":{"const":"rectangle"},"width":{"type":"number"},"height":{"type":"number"}},"required":["kind","width","height"]}]}"#
    )
  }

  // MARK: - Type Discriminated

  /// A `@StructuredCase` description becomes the description of the case's
  /// `oneOf` branch.
  @Test func encodesTypeDiscriminatedCaseDescriptions() throws {
    try test(
      DescribedNode.schema(description: nil),
      encodesAs:
        #"{"oneOf":[{"description":"A leaf string","type":"string"},{"properties":{"x":{"type":"integer"},"y":{"type":"integer"}},"required":["x","y"]}]}"#
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

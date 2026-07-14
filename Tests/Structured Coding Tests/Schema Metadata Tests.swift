import Testing

@testable import StructuredCoding

@Suite("Schema Metadata")
struct SchemaMetadataTests {

  // MARK: - Combine Descriptions

  @Test func combinesUseSiteBeforeTypeDescription() {
    #expect(combineDescriptions("use site", "type") == "use site\n\ntype")
  }

  @Test func passesThroughLoneDescriptions() {
    #expect(combineDescriptions("use site", nil) == "use site")
    #expect(combineDescriptions(nil, "type") == "type")
  }

  /// Two `nil`s combine to `nil` — not an empty or separator-only string,
  /// which would put an empty `description` in the encoded schema.
  @Test func combinesNilsToNil() {
    #expect(combineDescriptions(nil, nil) == nil)
  }

  // MARK: - Metadata

  /// `metadata` is the read/write channel for a schema's description.
  @Test func metadataDescriptionIsReadWrite() throws {
    var schema = String.schema.prependDescription("before")
    #expect(schema.metadata.description == "before")
    schema.metadata.description = "after"
    try test(schema, encodesAs: #"{"description":"after","type":"string"}"#)
  }

  // MARK: - Shape

  /// Object schemas declare the `.object` shape through metadata; every
  /// other schema's shape is unspecified. This is the signal a tool
  /// definition uses to decide whether a single action's input schema can
  /// stand alone or needs the `{"input": ...}` envelope.
  @Test func objectSchemasDeclareTheObjectShape() {
    #expect(MetaSchema.object(description: nil).metadata.shape == .object)
    #expect(
      MetaSchema.object(
        description: nil,
        properties: ("name", String.schema, true)
      ).metadata.shape == .object
    )
  }

  @Test func nonObjectSchemasDeclareNoShape() {
    #expect(String.schema.metadata.shape == nil)
    #expect(Int.schema.metadata.shape == nil)
    #expect(MetaSchema.any(description: nil).metadata.shape == nil)
    #expect(
      MetaSchema.array(description: nil, items: Int.schema).metadata.shape == nil
    )
    #expect(
      MetaSchema.tuple(description: nil, prefixItems: Bool.schema).metadata.shape == nil
    )
    #expect(
      MetaSchema.oneOf(description: nil, subschemas: String.schema).metadata.shape == nil
    )
  }

}

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

}

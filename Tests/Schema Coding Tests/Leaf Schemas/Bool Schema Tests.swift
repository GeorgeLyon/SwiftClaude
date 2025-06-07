import Testing

@testable import SchemaCoding

@Suite("Bool")
struct BoolSchemaTests {

  @Test
  private func testSchemaEncoding() throws {
    #expect(
      SchemaCoding.SchemaResolver.schema(representing: Bool.self).schemaJSON == """
        {
          "type": "boolean"
        }
        """
    )
  }

  @Test
  private func testValueEncoding() throws {
    #expect(
      SchemaCoding.SchemaResolver.schema(representing: Bool.self).encodedJSON(for: true) == """
        true
        """
    )
    #expect(
      SchemaCoding.SchemaResolver.schema(representing: Bool.self).encodedJSON(for: false) == """
        false
        """
    )
  }

  @Test
  private func testValueDecoding() throws {
    #expect(
      SchemaCoding.SchemaResolver.schema(representing: Bool.self).value(fromJSON: "true") == true
    )
    #expect(
      SchemaCoding.SchemaResolver.schema(representing: Bool.self).value(fromJSON: "false") == false
    )
  }

}

import Testing

@testable import SchemaCoding

@Suite("Bool")
struct BoolSchemaTests {

  @Test
  private func testSchemaEncoding() throws {
    #expect(
      SchemaSupport.schema(representing: Bool.self).schemaJSON == """
        {
          "type": "boolean"
        }
        """
    )
  }

  @Test
  private func testValueEncoding() throws {
    #expect(
      SchemaSupport.schema(representing: Bool.self).encodedJSON(for: true) == """
        true
        """
    )
    #expect(
      SchemaSupport.schema(representing: Bool.self).encodedJSON(for: false) == """
        false
        """
    )
  }

  @Test
  private func testValueDecoding() throws {
    #expect(
      SchemaSupport.schema(representing: Bool.self).value(fromJSON: "true") == true
    )
    #expect(
      SchemaSupport.schema(representing: Bool.self).value(fromJSON: "false") == false
    )
  }

}

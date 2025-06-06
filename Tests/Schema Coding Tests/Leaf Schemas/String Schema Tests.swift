import Testing

@testable import SchemaCoding

@Suite("String")
struct StringSchemaTests {

  @Test
  private func testSchemaEncoding() throws {
    #expect(
      SchemaProvider.schema(representing: String.self).schemaJSON == """
        {
          "type": "string"
        }
        """
    )
  }

  @Test
  private func testValueEncoding() throws {
    #expect(
      SchemaProvider.schema(representing: String.self).encodedJSON(for: "foo") == """
        "foo"
        """
    )
    #expect(
      SchemaProvider.schema(representing: String.self).encodedJSON(for: "bar") == """
        "bar"
        """
    )
  }

  @Test
  private func testValueDecoding() throws {
    #expect(
      SchemaProvider.schema(representing: String.self).value(fromJSON: "\"foo\"") == "foo"
    )
    #expect(
      SchemaProvider.schema(representing: String.self).value(fromJSON: "\"bar\"") == "bar"
    )
  }

}

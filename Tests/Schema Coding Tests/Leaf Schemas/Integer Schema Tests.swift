import Testing

@testable import SchemaCoding

@Suite("Integer")
struct IntegerSchemaTests {

  @Test
  private func testSchemaEncoding() throws {
    #expect(
      SchemaProvider.schema(representing: Int.self).schemaJSON == """
        {
          "type": "integer"
        }
        """
    )
  }

  @Test
  private func testValueEncoding() throws {
    #expect(
      SchemaProvider.schema(representing: Int.self).encodedJSON(for: 42) == """
        42
        """
    )
    #expect(
      SchemaProvider.schema(representing: Int.self).encodedJSON(for: -7) == """
        -7
        """
    )
  }

  @Test
  private func testValueDecoding() throws {
    #expect(
      SchemaProvider.schema(representing: Int.self).value(fromJSON: "42") == 42
    )
    #expect(
      SchemaProvider.schema(representing: Int.self).value(fromJSON: "-7") == -7
    )
  }

}

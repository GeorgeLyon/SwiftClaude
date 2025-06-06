import Testing

@testable import SchemaCoding

@Suite("Number")
struct NumberSchemaTests {

  @Test
  private func testSchemaEncoding() throws {
    #expect(
      SchemaProvider.schema(representing: Double.self).schemaJSON == """
        {
          "type": "number"
        }
        """
    )
  }

  @Test
  private func testValueEncoding() throws {
    #expect(
      SchemaProvider.schema(representing: Double.self).encodedJSON(for: 3.14) == """
        3.14
        """
    )
    #expect(
      SchemaProvider.schema(representing: Double.self).encodedJSON(for: -2.5) == """
        -2.5
        """
    )
  }

  @Test
  private func testValueDecoding() throws {
    #expect(
      SchemaProvider.schema(representing: Double.self).value(fromJSON: "3.14") == 3.14
    )
    #expect(
      SchemaProvider.schema(representing: Double.self).value(fromJSON: "-2.5") == -2.5
    )
  }

}

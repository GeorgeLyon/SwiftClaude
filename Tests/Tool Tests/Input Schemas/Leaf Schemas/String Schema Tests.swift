import Testing

@testable import Tool

@Suite("String")
struct StringSchemaTests {

  @Test
  private func testSchemaEncoding() throws {
    #expect(
      ToolInput.schema(representing: String.self).schemaJSON == """
        {
          "type": "string"
        }
        """
    )
  }

  @Test
  private func testValueEncoding() throws {
    #expect(
      ToolInput.schema(representing: String.self).encodedJSON(for: "foo") == """
        "foo"
        """
    )
    #expect(
      ToolInput.schema(representing: String.self).encodedJSON(for: "bar") == """
        "bar"
        """
    )
  }

  @Test
  private func testValueDecoding() throws {
    #expect(
      ToolInput.schema(representing: String.self).value(fromJSON: "\"foo\"") == "foo"
    )
    #expect(
      ToolInput.schema(representing: String.self).value(fromJSON: "\"bar\"") == "bar"
    )
  }

}

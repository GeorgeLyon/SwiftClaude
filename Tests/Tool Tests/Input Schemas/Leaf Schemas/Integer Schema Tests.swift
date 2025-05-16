import Testing

@testable import Tool

@Suite("Integer")
struct IntegerSchemaTests {

  @Test
  private func testSchemaEncoding() throws {
    #expect(
      ToolInput.schema(representing: Int.self).schemaJSON == """
        {
          "type" : "integer"
        }
        """
    )
  }

  @Test
  private func testValueDecoding() throws {
    #expect(
      ToolInput.schema(representing: Int.self).encodedJSON(for: 42) == """
        42
        """
    )
    #expect(
      ToolInput.schema(representing: Int.self).encodedJSON(for: -7) == """
        -7
        """
    )
  }

}

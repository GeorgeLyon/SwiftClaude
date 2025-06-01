import Testing

@testable import Tool

@Suite("Bool")
struct BoolSchemaTests {

  @Test
  private func testSchemaEncoding() throws {
    #expect(
      ToolInput.schema(representing: Bool.self).schemaJSON == """
        {
          "type":"boolean"
        }
        """
    )
  }

  @Test
  private func testValueDecoding() throws {
    #expect(
      ToolInput.schema(representing: Bool.self).encodedJSON(for: true) == """
        true
        """
    )
    #expect(
      ToolInput.schema(representing: Bool.self).encodedJSON(for: false) == """
        false
        """
    )
  }

}

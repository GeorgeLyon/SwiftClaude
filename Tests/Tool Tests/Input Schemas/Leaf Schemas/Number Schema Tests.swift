import Testing

@testable import Tool

@Suite("Number")
struct NumberSchemaTests {

  @Test
  private func testSchemaEncoding() throws {
    #expect(
      ToolInput.schema(representing: Double.self).schemaJSON == """
        {
          "type":"number"
        }
        """
    )
  }

  @Test
  private func testValueEncoding() throws {
    #expect(
      ToolInput.schema(representing: Double.self).encodedJSON(for: 3.14) == """
        3.14
        """
    )
    #expect(
      ToolInput.schema(representing: Double.self).encodedJSON(for: -2.5) == """
        -2.5
        """
    )
  }

  @Test
  private func testValueDecoding() throws {
    #expect(
      ToolInput.schema(representing: Double.self).value(fromJSON: "3.14") == 3.14
    )
    #expect(
      ToolInput.schema(representing: Double.self).value(fromJSON: "-2.5") == -2.5
    )
  }

}

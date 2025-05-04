import Testing

@testable import Tool

@Suite("Array")
struct ArraySchemaTests {

  @Test
  private func testSchemaEncoding() throws {
    #expect(
      ToolInput.schema(representing: [String].self).schemaJSON == """
        {
          "items" : {
            "type" : "string"
          },
          "type" : "array"
        }
        """
    )
  }

  @Test
  private func testValueEncoding() throws {
    #expect(
      ToolInput.schema(representing: [String].self).encodedJSON(for: ["foo", "bar", "baz"]) == """
        [
          "foo",
          "bar",
          "baz"
        ]
        """
    )

    #expect(
      ToolInput.schema(representing: [Int].self).encodedJSON(for: [1, 2, 3]) == """
        [
          1,
          2,
          3
        ]
        """
    )

    #expect(
      ToolInput.schema(representing: [Double].self).encodedJSON(for: []) == """
        [

        ]
        """
    )
  }
  
  @Test
  private func testValueDecoding() throws {
    let stringSchema = ToolInput.schema(representing: [String].self)
    #expect(
      stringSchema.value(fromJSON: """
        [
          "foo",
          "bar",
          "baz"
        ]
        """) == ["foo", "bar", "baz"]
    )
    
    let intSchema = ToolInput.schema(representing: [Int].self)
    #expect(
      intSchema.value(fromJSON: """
        [
          1,
          2,
          3
        ]
        """) == [1, 2, 3]
    )
    
    let doubleSchema = ToolInput.schema(representing: [Double].self)
    #expect(
      doubleSchema.value(fromJSON: """
        [

        ]
        """) == []
    )
    
    #expect(
      doubleSchema.value(fromJSON: """
        [
          1.5,
          2.25,
          3.75
        ]
        """) == [1.5, 2.25, 3.75]
    )
  }

}

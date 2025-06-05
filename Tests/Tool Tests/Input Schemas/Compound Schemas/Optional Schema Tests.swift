import Testing

@testable import Tool

@Suite("Optional")
struct OptionalSchemaTests {

  @Test
  private func testSchemaEncodingWithPrimitiveTypes() throws {
    // Test with String
    #expect(
      ToolInput.schema(representing: String?.self).schemaJSON == """
        {
          "type": [
            "null",
            "string"
          ]
        }
        """
    )

    // Test with Int
    #expect(
      ToolInput.schema(representing: Int?.self).schemaJSON == """
        {
          "type": [
            "null",
            "integer"
          ]
        }
        """
    )

    // Test with Bool
    #expect(
      ToolInput.schema(representing: Bool?.self).schemaJSON == """
        {
          "type": [
            "null",
            "boolean"
          ]
        }
        """
    )
  }

  @Test
  private func testSchemaEncodingWithComplexTypes() throws {
    // Test with Array type
    let arraySchema = ToolInput.schema(representing: [String]?.self)
    #expect(
      arraySchema.schemaJSON == """
        {
          "oneOf": [
            {
              "type": "null"
            },
            {
              "items": {
                "type": "string"
              }
            }
          ]
        }
        """)

    // Test with wrapped schema that can accept null (Optional of Optional)
    let nestedOptionalSchema = ToolInput.schema(representing: String??.self)
    #expect(
      nestedOptionalSchema.schemaJSON == """
        {
          "oneOf": [
            {
              "type": "null"
            },
            {
              "properties": {
                "value": {
                  "type": [
                    "null",
                    "string"
                  ]
                }
              }
            }
          ]
        }
        """)
  }

  @Test
  private func testValueEncoding() throws {
    let stringSchema = ToolInput.schema(representing: String?.self)

    // Test with non-nil value
    #expect(
      stringSchema.encodedJSON(for: "hello") == """
        "hello"
        """)

    // Test with nil value
    #expect(
      stringSchema.encodedJSON(for: nil) == """
        null
        """)
  }

  @Test
  private func testValueDecoding() throws {
    let stringSchema = ToolInput.schema(representing: String?.self)

    // Test decoding non-nil value
    #expect(stringSchema.value(fromJSON: "\"test\"") == "test")

    // Test decoding nil value
    #expect(stringSchema.value(fromJSON: "null") == nil)
  }
}

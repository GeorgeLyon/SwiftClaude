import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Object Properties")
struct ObjectPropertiesSchemaTests {

  private let testSchema: some SchemaCoding.Schema<(String, Int, Bool?)> =
    ObjectPropertiesSchema(
      description: "A user object",
      properties: ObjectPropertySchema(
        key: "name",
        description: "User's name",
        schema: SchemaCoding.SchemaCodingSupport.schema(representing: String.self)
      ),
      ObjectPropertySchema(
        key: "age",
        description: "User's age",
        schema: SchemaCoding.SchemaCodingSupport.schema(representing: Int.self)
      ),
      ObjectPropertySchema(
        key: "isActive",
        description: "Whether the user is active",
        schema: SchemaCoding.SchemaCodingSupport.schema(representing: Bool?.self)
      )
    )

  @Test
  private func testSchemaEncoding() throws {
    #expect(
      testSchema.schemaJSON == """
        {
          "description": "A user object",
          "properties": {
            "name": {
              "description": "User's name",
              "type": "string"
            },
            "age": {
              "description": "User's age",
              "type": "integer"
            },
            "isActive": {
              "description": "Whether the user is active",
              "type": "boolean"
            }
          },
          "required": [
            "name",
            "age"
          ]
        }
        """
    )
  }

  @Test
  private func testValueEncoding() throws {
    #expect(
      testSchema.encodedJSON(for: ("John Doe", 30, nil)) == """
        {
          "name": "John Doe",
          "age": 30
        }
        """
    )
  }

  @Test
  private func testValueDecoding() throws {
    let decodedValue = testSchema.value(
      fromJSON: """
        {
          "name": "Jane Smith",
          "age": 25,
          "isActive": true
        }
        """
    )

    #expect(decodedValue.0 == "Jane Smith")
    #expect(decodedValue.1 == 25)
    #expect(decodedValue.2 == true)
  }

}

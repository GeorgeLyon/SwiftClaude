import Foundation
import Testing

@testable import Tool

@Suite("Object Properties")
struct ObjectPropertiesSchemaTests {

  private enum PropertyKey: String, CodingKey {
    case name
    case age
    case isActive
  }

  private let testSchema: some ToolInput.Schema<(String, Int, Bool?)> =
    ObjectPropertiesSchema(
      description: "A user object",
      properties: ObjectPropertySchema(
        key: PropertyKey.name,
        description: "User's name",
        schema: ToolInput.schema(representing: String.self)
      ),
      ObjectPropertySchema(
        key: PropertyKey.age,
        description: "User's age",
        schema: ToolInput.schema(representing: Int.self)
      ),
      ObjectPropertySchema(
        key: PropertyKey.isActive,
        description: "Whether the user is active",
        schema: ToolInput.schema(representing: Bool?.self)
      )
    )

  @Test
  private func testSchemaEncoding() throws {
    #expect(
      testSchema.schemaJSON == """
        {
          "description" : "A user object",
          "properties" : {
            "name" : {
              "description" : "User's name",
              "type" : "string"
            },
            "age" : {
              "description" : "User's age",
              "type" : "integer"
            },
            "isActive" : {
              "description" : "Whether the user is active",
              "type" : "boolean"
            }
          },
          "required" : [
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
          "age" : 30,
          "name" : "John Doe"
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

import SchemaCodingTestSupport
import Testing

@testable import Tools

/// A person object
@ToolInput(
  description: "A person object"
)
private struct Person: Equatable {
  let `name`: String

  @ToolInputDetails(
    description: "The person's age"
  )
  let age: Int

  @ToolInputDetails(
    description: "Whether the person is active"
  )
  let isActive: Bool?
}

/// Single-property Struct
@ToolInput
private struct SinglePropertyStruct {
  let property: String
}

@Suite("@ToolInput Struct")
struct ToolInputStructTests {

  @Test
  private func testSchemaEncoding() throws {
    try Person.schema.test(encodesAs: """
      {
        "description": "A person object",
        "properties": {
          "name": {
            "type": "string"
          },
          "age": {
            "description": "The person's age",
            "type": "integer"
          },
          "isActive": {
            "description": "Whether the person is active",
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
    try Person.schema.test(
      Person(name: "John Doe", age: 30, isActive: nil),
      encodesAs: """
        {
          "name": "John Doe",
          "age": 30
        }
        """
    )
  }

  @Test
  private func testValueEncodingWithOptional() throws {
    try Person.schema.test(
      Person(name: "Jane Smith", age: 25, isActive: true),
      encodesAs: """
        {
          "name": "Jane Smith",
          "age": 25,
          "isActive": true
        }
        """
    )
  }

  @Test
  private func testValueDecoding() throws {
    try Person.schema.test(
      """
      {
        "name": "Jane Smith",
        "age": 25,
        "isActive": true
      }
      """,
      decodesAs: Person(name: "Jane Smith", age: 25, isActive: true)
    )
  }

  @Test
  private func testValueDecodingWithoutOptional() throws {
    try Person.schema.test(
      """
      {
        "name": "John Doe",
        "age": 30
      }
      """,
      decodesAs: Person(name: "John Doe", age: 30, isActive: nil)
    )
  }
}

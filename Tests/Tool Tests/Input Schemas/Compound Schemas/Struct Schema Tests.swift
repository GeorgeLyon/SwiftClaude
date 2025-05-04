import Testing

@testable import Tool

private struct Person: ToolInput.SchemaCodable {

  let name: String
  let age: Int
  let isActive: Bool?

}

extension Person {

  static let toolInputSchema: some ToolInput.Schema<Self> =
    ToolInput.structSchema(
      representing: Self.self,
      description: "A person object",
      keyedBy: PropertyKey.self,
      properties: (
        (
          description: nil,
          keyPath: \.name,
          key: .name,
          schema: ToolInput.schema()
        ),
        (
          description: "The person's age",
          keyPath: \.age,
          key: .age,
          schema: ToolInput.schema()
        ),
        (
          description: "Whether the person is active",
          keyPath: \.isActive,
          key: .isActive,
          schema: ToolInput.schema()
        )
      ),
      initializer: Self.init(structSchemaDecoder:)
    )

  private enum PropertyKey: CodingKey {
    case name, age, isActive
  }

  private init(structSchemaDecoder: ToolInput.StructSchemaDecoder<String, Int, Bool?>) {
    name = structSchemaDecoder.propertyValues.0
    age = structSchemaDecoder.propertyValues.1
    isActive = structSchemaDecoder.propertyValues.2
  }
}

@Suite("Struct")
struct StructSchemaTests {

  @Test
  private func testSchemaEncoding() throws {
    let schema = ToolInput.schema(representing: Person.self)
    #expect(
      schema.schemaJSON == """
        {
          "additionalProperties" : false,
          "description" : "A person object",
          "properties" : {
            "age" : {
              "description" : "The person's age",
              "type" : "integer"
            },
            "isActive" : {
              "description" : "Whether the person is active",
              "type" : "boolean"
            },
            "name" : {
              "type" : "string"
            }
          },
          "required" : [
            "name",
            "age"
          ],
          "type" : "object"
        }
        """
    )
  }

  @Test
  private func testValueEncoding() throws {
    let schema = ToolInput.schema(representing: Person.self)
    #expect(
      schema.encodedJSON(for: Person(name: "John Doe", age: 30, isActive: nil))
        == """
        {
          "age" : 30,
          "name" : "John Doe"
        }
        """
    )
  }

  @Test
  private func testValueEncodingWithOptional() throws {
    let schema = ToolInput.schema(representing: Person.self)
    #expect(
      schema.encodedJSON(for: Person(name: "Jane Smith", age: 25, isActive: true))
        == """
        {
          "age" : 25,
          "isActive" : true,
          "name" : "Jane Smith"
        }
        """
    )
  }

  @Test
  private func testValueDecoding() throws {
    let schema = ToolInput.schema(representing: Person.self)
    let decodedPerson = schema.value(
      fromJSON: """
        {
          "name": "Jane Smith",
          "age": 25,
          "isActive": true
        }
        """
    )

    #expect(decodedPerson.name == "Jane Smith")
    #expect(decodedPerson.age == 25)
    #expect(decodedPerson.isActive == true)
  }

  @Test
  private func testValueDecodingWithoutOptional() throws {
    let schema = ToolInput.schema(representing: Person.self)
    let decodedPerson = schema.value(
      fromJSON: """
        {
          "name": "John Doe",
          "age": 30
        }
        """
    )

    #expect(decodedPerson.name == "John Doe")
    #expect(decodedPerson.age == 30)
    #expect(decodedPerson.isActive == nil)
  }
}

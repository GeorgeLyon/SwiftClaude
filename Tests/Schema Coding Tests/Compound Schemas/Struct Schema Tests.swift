import Testing

@testable import SchemaCoding

private struct Person: SchemaCodable {

  let name: String
  let age: Int
  let isActive: Bool?

}

extension Person {

  static let schema: some SchemaCoding.Schema<Self> =
    SchemaCoding.SchemaResolver.structSchema(
      representing: Self.self,
      description: "A person object",
      properties: (
        (
          description: nil,
          keyPath: \.name,
          key: "name" as SchemaCoding.SchemaCodingKey,
          schema: SchemaCoding.SchemaResolver.schema(representing: String.self)
        ),
        (
          description: "The person's age",
          keyPath: \.age,
          key: "age" as SchemaCoding.SchemaCodingKey,
          schema: SchemaCoding.SchemaResolver.schema(representing: Int.self)
        ),
        (
          description: "Whether the person is active",
          keyPath: \.isActive,
          key: "isActive" as SchemaCoding.SchemaCodingKey,
          schema: SchemaCoding.SchemaResolver.schema(representing: Bool?.self)
        )
      ),
      initializer: Self.init(structSchemaDecoder:)
    )

  private init(structSchemaDecoder: SchemaCoding.StructSchemaDecoder<String, Int, Bool?>) {
    name = structSchemaDecoder.propertyValues.0
    age = structSchemaDecoder.propertyValues.1
    isActive = structSchemaDecoder.propertyValues.2
  }
}

@Suite("Struct")
struct StructSchemaTests {

  @Test
  private func testSchemaEncoding() throws {
    let schema = SchemaCoding.SchemaResolver.schema(representing: Person.self)
    #expect(
      schema.schemaJSON == """
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
    let schema = SchemaCoding.SchemaResolver.schema(representing: Person.self)
    #expect(
      schema.encodedJSON(for: Person(name: "John Doe", age: 30, isActive: nil))
        == """
        {
          "name": "John Doe",
          "age": 30
        }
        """
    )
  }

  @Test
  private func testValueEncodingWithOptional() throws {
    let schema = SchemaCoding.SchemaResolver.schema(representing: Person.self)
    #expect(
      schema.encodedJSON(for: Person(name: "Jane Smith", age: 25, isActive: true))
        == """
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
    let schema = SchemaCoding.SchemaResolver.schema(representing: Person.self)
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
    let schema = SchemaCoding.SchemaResolver.schema(representing: Person.self)
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

import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

/// A person object
@SchemaCodable
private struct Person {
  let `name`: String

  /// The person's age
  let age: Int

  // Whether the person is active
  let isActive: Bool?
}

/// Single-property Struct
@SchemaCodable
private struct SinglePropertyStruct {
  let property: String
}

@Suite("@SchemaCodable Struct")
struct SchemaCodableStructTests {

  @Test
  private func testSchemaEncoding() throws {
    let schema = SchemaCoding.SchemaCodingSupport.schema(representing: Person.self)
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
    let schema = SchemaCoding.SchemaCodingSupport.schema(representing: Person.self)
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
    let schema = SchemaCoding.SchemaCodingSupport.schema(representing: Person.self)
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
    let schema = SchemaCoding.SchemaCodingSupport.schema(representing: Person.self)
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
    let schema = SchemaCoding.SchemaCodingSupport.schema(representing: Person.self)
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

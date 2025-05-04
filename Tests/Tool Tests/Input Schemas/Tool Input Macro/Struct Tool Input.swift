import Testing

@testable import Tool

#if os(macOS)
  /// A person object
  @ToolInput
  private struct Person {
    let name: String

    /// The person's age
    let age: Int

    // Whether the person is active
    let isActive: Bool?
  }

  @Suite("Struct Tool Input")
  struct StructToolInputTests {

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
#endif

import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Struct Schema")
struct StructSchemaTests {

  @Suite("Coding")
  struct CodingTests {

    @Test
    func testSimpleStruct() throws {
      struct SimpleStruct: Equatable {
        let name: String
        let age: Int
      }

      let schema = SchemaCoding.Support.structSchema(
        representing: SimpleStruct.self,
        properties: {
          SchemaCoding.Support.structProperty(
            name: "name",
            keyPath: \SimpleStruct.name,
            schema: SchemaCoding.Support.schema(representing: String.self)
          )
          SchemaCoding.Support.structProperty(
            name: "age",
            keyPath: \SimpleStruct.age,
            schema: SchemaCoding.Support.schema(representing: Int.self)
          )
        },
        initializer: { (decoder: SchemaCoding.StructDecoder<String, Int>) in
          SimpleStruct(
            name: decoder.propertyValues.0,
            age: decoder.propertyValues.1
          )
        }
      )

      try schema.test(
        SimpleStruct(name: "Alice", age: 30),
        isCodedAs: """
          {
            "name": "Alice",
            "age": 30
          }
          """
      )
    }

    @Test
    func testStructWithOptionalProperty() throws {
      struct StructWithOptional: Equatable {
        let required: String
        let optional: Int?
      }

      let schema = SchemaCoding.Support.structSchema(
        representing: StructWithOptional.self,
        properties: {
          SchemaCoding.Support.structProperty(
            name: "required",
            keyPath: \StructWithOptional.required,
            schema: SchemaCoding.Support.schema(representing: String.self)
          )
          SchemaCoding.Support.structProperty(
            name: "optional",
            keyPath: \StructWithOptional.optional,
            schema: Int?.schema
          )
        },
        initializer: { (decoder: SchemaCoding.StructDecoder<String, Int?>) in
          StructWithOptional(
            required: decoder.propertyValues.0,
            optional: decoder.propertyValues.1
          )
        }
      )

      // With optional value present
      try schema.test(
        StructWithOptional(required: "test", optional: 42),
        isCodedAs: """
          {
            "required": "test",
            "optional": 42
          }
          """
      )

      // With optional value nil (property is omitted)
      try schema.test(
        StructWithOptional(required: "test", optional: nil),
        isCodedAs: """
          {
            "required": "test"
          }
          """
      )
    }

    @Test
    func testSinglePropertyStruct() throws {
      struct SingleProperty: Equatable {
        let value: Bool
      }

      let schema = SchemaCoding.Support.structSchema(
        representing: SingleProperty.self,
        properties: {
          SchemaCoding.Support.structProperty(
            name: "value",
            keyPath: \SingleProperty.value,
            schema: SchemaCoding.Support.BooleanSchema()
          )
        },
        initializer: { decoder in
          SingleProperty(value: decoder.propertyValues.0)
        }
      )

      try schema.test(
        SingleProperty(value: true),
        isCodedAs: """
          {
            "value": true
          }
          """
      )
    }

    @Test
    func testWrapperStyleWithBool() throws {
      struct BoolWrapper: Equatable {
        let value: Bool
      }

      let schema = SchemaCoding.Support.structSchema(
        representing: BoolWrapper.self,
        style: .wrapper,
        properties: {
          SchemaCoding.Support.structProperty(
            name: "value",
            keyPath: \BoolWrapper.value,
            schema: SchemaCoding.Support.BooleanSchema()
          )
        },
        initializer: { decoder in
          BoolWrapper(value: decoder.propertyValues.0)
        }
      )

      try schema.test(
        BoolWrapper(value: true),
        isCodedAs: "true"
      )

      try schema.test(
        BoolWrapper(value: false),
        isCodedAs: "false"
      )
    }

    @Test
    func testWrapperStyleWithString() throws {
      struct StringWrapper: Equatable {
        let text: String
      }

      let schema = SchemaCoding.Support.structSchema(
        representing: StringWrapper.self,
        style: .wrapper,
        properties: {
          SchemaCoding.Support.structProperty(
            name: "text",
            keyPath: \StringWrapper.text,
            schema: SchemaCoding.Support.schema(representing: String.self)
          )
        },
        initializer: { decoder in
          StringWrapper(text: decoder.propertyValues.0)
        }
      )

      try schema.test(
        StringWrapper(text: "hello"),
        isCodedAs: "\"hello\""
      )
    }

    @Test
    func testWrapperStyleWithInt() throws {
      struct IntWrapper: Equatable {
        let number: Int
      }

      let schema = SchemaCoding.Support.structSchema(
        representing: IntWrapper.self,
        style: .wrapper,
        properties: {
          SchemaCoding.Support.structProperty(
            name: "number",
            keyPath: \IntWrapper.number,
            schema: SchemaCoding.Support.schema(representing: Int.self)
          )
        },
        initializer: { decoder in
          IntWrapper(number: decoder.propertyValues.0)
        }
      )

      try schema.test(
        IntWrapper(number: 42),
        isCodedAs: "42"
      )
    }

    @Test
    func testWrapperStyleWithOptional() throws {
      struct OptionalWrapper: Equatable {
        let value: Int?
      }

      let schema = SchemaCoding.Support.structSchema(
        representing: OptionalWrapper.self,
        style: .wrapper,
        properties: {
          SchemaCoding.Support.structProperty(
            name: "value",
            keyPath: \OptionalWrapper.value,
            schema: Int?.schema
          )
        },
        initializer: { decoder in
          OptionalWrapper(value: decoder.propertyValues.0)
        }
      )

      try schema.test(
        OptionalWrapper(value: 123),
        isCodedAs: #"""
          {
            "value": 123
          }
          """#
      )

      try schema.test(
        OptionalWrapper(value: nil),
        isCodedAs: """
          {

          }
          """
      )
    }

  }

  @Suite("Meta Schema")
  struct MetaSchemaTests {

    @Test
    func testMetaSchema() throws {
      struct Person: Equatable {
        let name: String
      }

      let schema = SchemaCoding.Support.structSchema(
        representing: Person.self,
        description: "A person",
        properties: {
          SchemaCoding.Support.structProperty(
            name: "name",
            keyPath: \Person.name,
            schema: SchemaCoding.Support.schema(representing: String.self)
          )
        },
        initializer: { decoder in
          Person(name: decoder.propertyValues.0)
        }
      )

      try schema.test(
        encodesAs: """
          {
            "description": "A person",
            "properties": {
              "name": {
                "type": "string"
              }
            },
            "required": [
              "name"
            ]
          }
          """
      )
    }

    @Test
    func testWrapperStyleMetaSchema() throws {
      struct BoolWrapper: Equatable {
        let value: Bool
      }

      let schema = SchemaCoding.Support.structSchema(
        representing: BoolWrapper.self,
        style: .wrapper,
        properties: {
          SchemaCoding.Support.structProperty(
            name: "value",
            keyPath: \BoolWrapper.value,
            schema: SchemaCoding.Support.BooleanSchema()
          )
        },
        initializer: { decoder in
          BoolWrapper(value: decoder.propertyValues.0)
        }
      )

      try schema.test(
        encodesAs: """
          {
            "type": "boolean"
          }
          """
      )
    }

    @Test
    func testWrapperStyleMetaSchemaWithDescription() throws {
      struct DescribedWrapper: Equatable {
        let value: String
      }

      let schema = SchemaCoding.Support.structSchema(
        representing: DescribedWrapper.self,
        style: .wrapper,
        properties: {
          SchemaCoding.Support.structProperty(
            name: "value",
            description: "A descriptive text",
            keyPath: \DescribedWrapper.value,
            schema: SchemaCoding.Support.schema(representing: String.self)
          )
        },
        initializer: { decoder in
          DescribedWrapper(value: decoder.propertyValues.0)
        }
      )

      try schema.test(
        encodesAs: """
          {
            "description": "A descriptive text",
            "type": "string"
          }
          """
      )
    }

  }

}

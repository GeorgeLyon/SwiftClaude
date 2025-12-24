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
        isCodedAs: #"{"name":"Alice","age":30}"#
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
        isCodedAs: #"{"required":"test","optional":42}"#
      )

      // With optional value nil (property is omitted)
      try schema.test(
        StructWithOptional(required: "test", optional: nil),
        isCodedAs: #"{"required":"test"}"#
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
        isCodedAs: #"{"value":true}"#
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
        encodesAs:
          #"{"description":"A person","properties":{"name":{"type":"string"}},"required":["name"]}"#
      )
    }

  }

}

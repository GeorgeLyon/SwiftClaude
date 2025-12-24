import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

/// Tests for meta-schemas of complex schema types.
/// These test the schema-of-schemas functionality for non-primitive types.
@Suite("Meta Schema")
struct MetaSchemaTests {

  @Suite("Array Meta Schema")
  struct ArrayMetaSchemaTests {

    @Test
    func testArrayOfStructsMetaSchema() throws {
      struct Item: Equatable {
        let name: String
      }

      let itemSchema = SchemaCoding.Support.structSchema(
        representing: Item.self,
        properties: {
          SchemaCoding.Support.structProperty(
            name: "name",
            keyPath: \Item.name,
            schema: SchemaCoding.Support.schema(representing: String.self)
          )
        },
        initializer: { decoder in
          Item(name: decoder.propertyValues.0)
        }
      )

      let arraySchema = SchemaCoding.Support.ArraySchema(
        elementSchema: itemSchema
      )

      // The meta-schema should describe an array whose items are object schemas
      try arraySchema.test(
        encodesAs: #"{"items":{"properties":{"name":{"type":"string"}},"required":["name"]}}"#
      )
    }

  }

  @Suite("Struct Meta Schema")
  struct StructMetaSchemaTests {

    @Test
    func testNestedStructMetaSchema() throws {
      struct Inner: Equatable {
        let value: Int
      }

      struct Outer: Equatable {
        let inner: Inner
      }

      let innerSchema = SchemaCoding.Support.structSchema(
        representing: Inner.self,
        properties: {
          SchemaCoding.Support.structProperty(
            name: "value",
            keyPath: \Inner.value,
            schema: SchemaCoding.Support.schema(representing: Int.self)
          )
        },
        initializer: { decoder in
          Inner(value: decoder.propertyValues.0)
        }
      )

      let outerSchema = SchemaCoding.Support.structSchema(
        representing: Outer.self,
        properties: {
          SchemaCoding.Support.structProperty(
            name: "inner",
            keyPath: \Outer.inner,
            schema: innerSchema
          )
        },
        initializer: { decoder in
          Outer(inner: decoder.propertyValues.0)
        }
      )

      try outerSchema.test(
        encodesAs:
          #"{"properties":{"inner":{"properties":{"value":{"type":"integer"}},"required":["value"]}},"required":["inner"]}"#
      )
    }

  }

  @Suite("Enum Meta Schema")
  struct EnumMetaSchemaTests {

    @Test
    func testEnumWithStructCasesMetaSchema() throws {
      struct Payload: Equatable {
        let data: String
      }

      enum Message: Equatable {
        case text(content: String)
        case payload(Payload)
      }

      let payloadSchema = SchemaCoding.Support.structSchema(
        representing: Payload.self,
        properties: {
          SchemaCoding.Support.structProperty(
            name: "data",
            keyPath: \Payload.data,
            schema: SchemaCoding.Support.schema(representing: String.self)
          )
        },
        initializer: { decoder in
          Payload(data: decoder.propertyValues.0)
        }
      )

      let textCase = SchemaCoding.Support.enumSchemaCase(
        name: "text",
        associatedValues: {
          SchemaCoding.Support.enumSchemaCaseAssociatedValue(
            label: "content",
            schema: SchemaCoding.Support.schema(representing: String.self)
          )
        },
        finishDecoding: { (decoder: SchemaCoding.EnumDecoder<String>) in
          Message.text(content: decoder.associatedValues)
        }
      )

      let payloadCase = SchemaCoding.Support.enumSchemaCase(
        name: "payload",
        associatedValues: {
          SchemaCoding.Support.enumSchemaCaseAssociatedValue(
            schema: payloadSchema
          )
        },
        finishDecoding: { (decoder: SchemaCoding.EnumDecoder<Payload>) in
          Message.payload(decoder.associatedValues)
        }
      )

      let schema = SchemaCoding.Support.enumSchema(
        representing: Message.self,
        cases: {
          textCase
          payloadCase
        },
        encodeValue: { value, encoder in
          switch value {
          case .text(let content):
            encoder.encode(content, using: encoder.encodings.0)
          case .payload(let payload):
            encoder.encode(payload, using: encoder.encodings.1)
          }
        }
      )

      // Meta schema for enum with struct-based associated values
      try schema.test(
        encodesAs:
          #"{"properties":{"text":{"properties":{"content":{"type":"string"}},"required":["content"]},"payload":{"properties":{"data":{"type":"string"}},"required":["data"]}}}"#
      )
    }

  }

  @Suite("Optional Meta Schema")
  struct OptionalMetaSchemaTests {

    @Test
    func testOptionalOfStructMetaSchema() throws {
      struct Config: Equatable {
        let enabled: Bool
      }

      let configSchema = SchemaCoding.Support.structSchema(
        representing: Config.self,
        properties: {
          SchemaCoding.Support.structProperty(
            name: "enabled",
            keyPath: \Config.enabled,
            schema: SchemaCoding.Support.BooleanSchema()
          )
        },
        initializer: { decoder in
          Config(enabled: decoder.propertyValues.0)
        }
      )

      let schema = SchemaCoding.Support.OptionalSchema(
        wrappedSchema: configSchema
      )

      try schema.test(
        encodesAs:
          #"{"properties":{"value":{"properties":{"enabled":{"type":"boolean"}},"required":["enabled"]}}}"#
      )
    }

  }

  /// Tests for meta-meta-meta schemas - the schema of the schema of the schema.
  /// These exercise the recursive nature of the meta-schema system with complex types.
  @Suite("Meta Meta Meta Schema")
  struct MetaMetaMetaSchemaTests {

    @Test
    func testArrayOfStructsMetaMetaSchema() throws {
      struct Person: Equatable {
        let name: String
        let age: Int
      }

      let personSchema = SchemaCoding.Support.structSchema(
        representing: Person.self,
        properties: {
          SchemaCoding.Support.structProperty(
            name: "name",
            keyPath: \Person.name,
            schema: SchemaCoding.Support.schema(representing: String.self)
          )
          SchemaCoding.Support.structProperty(
            name: "age",
            keyPath: \Person.age,
            schema: SchemaCoding.Support.schema(representing: Int.self)
          )
        },
        initializer: { (decoder: SchemaCoding.StructDecoder<String, Int>) in
          Person(name: decoder.propertyValues.0, age: decoder.propertyValues.1)
        }
      )

      let arraySchema = SchemaCoding.Support.ArraySchema(
        elementSchema: personSchema
      )

      // Meta-meta-schema of array-of-structs
      try arraySchema.metaSchema.test(
        encodesAs:
          #"{"properties":{"description":{"type":"string"},"items":{"properties":{"description":{"type":"string"},"properties":{"properties":{"name":{"properties":{"description":{"type":"string"},"type":{"const":"string"}},"required":["type"]},"age":{"properties":{"description":{"type":"string"},"type":{"const":"integer"}},"required":["type"]}},"required":["name","age"]},"required":{"const":["name","age"]}},"required":["properties","required"]}},"required":["items"]}"#
      )
    }

    @Test
    func testNestedStructsMetaMetaSchema() throws {
      struct Address: Equatable {
        let city: String
        let zip: Int
      }

      struct Contact: Equatable {
        let name: String
        let address: Address
      }

      let addressSchema = SchemaCoding.Support.structSchema(
        representing: Address.self,
        properties: {
          SchemaCoding.Support.structProperty(
            name: "city",
            keyPath: \Address.city,
            schema: SchemaCoding.Support.schema(representing: String.self)
          )
          SchemaCoding.Support.structProperty(
            name: "zip",
            keyPath: \Address.zip,
            schema: SchemaCoding.Support.schema(representing: Int.self)
          )
        },
        initializer: { (decoder: SchemaCoding.StructDecoder<String, Int>) in
          Address(city: decoder.propertyValues.0, zip: decoder.propertyValues.1)
        }
      )

      let contactSchema = SchemaCoding.Support.structSchema(
        representing: Contact.self,
        properties: {
          SchemaCoding.Support.structProperty(
            name: "name",
            keyPath: \Contact.name,
            schema: SchemaCoding.Support.schema(representing: String.self)
          )
          SchemaCoding.Support.structProperty(
            name: "address",
            keyPath: \Contact.address,
            schema: addressSchema
          )
        },
        initializer: { (decoder: SchemaCoding.StructDecoder<String, Address>) in
          Contact(name: decoder.propertyValues.0, address: decoder.propertyValues.1)
        }
      )

      // Meta-meta-schema of nested structs
      try contactSchema.metaSchema.test(
        encodesAs:
          #"{"properties":{"description":{"type":"string"},"properties":{"properties":{"name":{"properties":{"description":{"type":"string"},"type":{"const":"string"}},"required":["type"]},"address":{"properties":{"description":{"type":"string"},"properties":{"properties":{"city":{"properties":{"description":{"type":"string"},"type":{"const":"string"}},"required":["type"]},"zip":{"properties":{"description":{"type":"string"},"type":{"const":"integer"}},"required":["type"]}},"required":["city","zip"]},"required":{"const":["city","zip"]}},"required":["properties","required"]}},"required":["name","address"]},"required":{"const":["name","address"]}},"required":["properties","required"]}"#
      )
    }

    @Test
    func testOptionalOfArrayOfStructsMetaMetaSchema() throws {
      struct Item: Equatable {
        let id: Int
        let active: Bool
      }

      let itemSchema = SchemaCoding.Support.structSchema(
        representing: Item.self,
        properties: {
          SchemaCoding.Support.structProperty(
            name: "id",
            keyPath: \Item.id,
            schema: SchemaCoding.Support.schema(representing: Int.self)
          )
          SchemaCoding.Support.structProperty(
            name: "active",
            keyPath: \Item.active,
            schema: SchemaCoding.Support.BooleanSchema()
          )
        },
        initializer: { (decoder: SchemaCoding.StructDecoder<Int, Bool>) in
          Item(id: decoder.propertyValues.0, active: decoder.propertyValues.1)
        }
      )

      let arraySchema = SchemaCoding.Support.ArraySchema(
        elementSchema: itemSchema
      )

      let optionalSchema = SchemaCoding.Support.OptionalSchema(
        wrappedSchema: arraySchema
      )

      // Meta-meta-schema of optional-array-of-structs
      try optionalSchema.metaSchema.test(
        encodesAs:
          #"{"properties":{"description":{"type":"string"},"properties":{"properties":{"value":{"properties":{"description":{"type":"string"},"items":{"properties":{"description":{"type":"string"},"properties":{"properties":{"id":{"properties":{"description":{"type":"string"},"type":{"const":"integer"}},"required":["type"]},"active":{"properties":{"description":{"type":"string"},"type":{"const":"boolean"}},"required":["type"]}},"required":["id","active"]},"required":{"const":["id","active"]}},"required":["properties","required"]}},"required":["items"]}},"required":["value"]}},"required":["properties"]}"#
      )
    }

  }

}
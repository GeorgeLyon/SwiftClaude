import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Object Schema")
struct ObjectSchemaTests {

  struct SimpleObject {

    let a: String
    let b: String

    static var schema: Schema {
      Schema(
        _properties: (
          SchemaCoding.Support.DirectObjectProperty(
            description: "Property A",
            schema: String.Schema()
          ),
          SchemaCoding.Support.DirectObjectProperty(
            description: "Property B",
            schema: String.Schema()
          )
        )
      )
    }

    struct Schema: SchemaCoding.ObjectSchema {

      typealias Value = SimpleObject

      typealias PropertyA = SchemaCoding.Support.DirectObjectProperty<String.Schema>
      typealias PropertyB = SchemaCoding.Support.DirectObjectProperty<String.Schema>

      typealias PropertyTypeMetadatas = (
        SchemaCoding.Support.PropertyTypeMetadata<PropertyA>,
        SchemaCoding.Support.PropertyTypeMetadata<PropertyB>
      )
      static func propertyTypeMetadatas() -> PropertyTypeMetadatas {
        (
          SchemaCoding.Support.PropertyTypeMetadata(name: "a"),
          SchemaCoding.Support.PropertyTypeMetadata(name: "b")
        )
      }

      typealias Properties = (PropertyA, PropertyB)
      static func create(from properties: (PropertyA, PropertyB))
        -> ObjectSchemaTests.SimpleObject.Schema
      {
        Self(_properties: properties)
      }

      fileprivate let _properties: Properties
      func properties() -> Properties {
        (
          SchemaCoding.Support.DirectObjectProperty<String.Schema>(
            propertySchema: String.schema
          ),
          SchemaCoding.Support.DirectObjectProperty<String.Schema>(
            propertySchema: String.schema
          )
        )
      }

      typealias PropertyValues = (String, String)
      static func value(from propertyValues: PropertyValues) throws -> Value {
        Value(a: propertyValues.0, b: propertyValues.1)
      }
      static func propertyValues(from value: Value) -> (String, String) {
        (value.a, value.b)
      }

      var metadata = SchemaCoding.Support.SchemaMetadata()

      typealias ValueDecodingState = SchemaCoding.Support.ObjectSchemaValueDecodingState<Self>

      typealias PropertiesDecoder = SchemaCoding.Support.ObjectPropertiesDecoder<
        Self,
        SchemaCoding.Support.DirectObjectProperty<String.Schema>,
        SchemaCoding.Support.DirectObjectProperty<String.Schema>
      >

      typealias MetaSchema = SchemaCoding.Support.ObjectMetaSchema<
        Self,
        PropertyA,
        PropertyB
      >
      var metaSchema: MetaSchema {
        _metaSchema()
      }

    }

  }

}

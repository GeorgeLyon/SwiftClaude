import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Object Schema")
struct ObjectSchemaTests {

  struct SimpleObject {

    let a: String
    let b: String

    /*
    struct Schema: SchemaCoding.ObjectSchema {
    
      typealias Value = SimpleObject
    
      typealias PropertyA = SchemaCoding.Support.DirectObjectProperty<String.Schema>
      typealias PropertyB = SchemaCoding.Support.DirectObjectProperty<String.Schema>
    
      typealias PropertyNames = (
        SchemaCoding.Support.PropertyName<PropertyA>,
        SchemaCoding.Support.PropertyName<PropertyB>
      )
      static func propertyNames() -> PropertyNames {
        ("a", "b")
      }
    
      typealias Properties = (PropertyA, PropertyB)
      init(
        properties: Properties
      ) {
        self._properties = properties
      }
    
      private let _properties: Properties
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
    
    }
    */
  }

}

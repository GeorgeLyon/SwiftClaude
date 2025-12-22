import JSONSupport

// MARK: - Creating Object Schemas

extension SchemaCoding.Support {

  // static func objectSchema<each Property>(
  //   description: String? = nil,
  //   @ObjectPropertiesBuilder properties:
  //     () -> ObjectProperties<repeat each Property>
  // ) -> ConcreteObjectSchema<
  //   TupleObjectSchemaProperties<repeat each Property>
  // > {
  //   ConcreteObjectSchema(
  //     description: description,
  //     properties: TupleObjectSchemaProperties(
  //       repeat each properties().properties
  //     )
  //   )
  // }

}

// MARK: - Object Schema Protocol

extension SchemaCoding.Support {

  public protocol ObjectSchema<Value>: Schema {

    associatedtype Properties: ObjectSchemaProperties where Properties.Value == Value
    var properties: Properties { get }

    var objectSchemaMetadata: ObjectSchemaMetadata { get }

  }

  public struct ObjectSchemaMetadata {
    fileprivate let description: String?
  }

}

// MARK: - Concerete Object Schema

extension SchemaCoding.Support {

  struct ConcreteObjectSchema<Properties: ObjectSchemaProperties>: ObjectSchema {

    typealias Value = Properties.Value

    func encode(_ value: Value, to encoder: inout SchemaCoding.Support.Encoder) {
      encoder.stream.encodeObject { encoder in
        var objectEncoder = SchemaCoding.Support.ObjectPropertiesEncoder(encoder: encoder)
        properties.encodeProperties(of: value, to: &objectEncoder)
        encoder = objectEncoder.encoder
      }
    }

    struct ValueDecodingState {
      fileprivate let propertiesState: ObjectPropertiesDecodingState<Value>
      fileprivate var objectState = JSON.ObjectDecodingState()
      fileprivate var activePropertyDecoder: (any ObjectPropertyDecoder)?
    }

    func beginDecodingValue(from decoder: borrowing Decoder) -> ValueDecodingState {
      ValueDecodingState(
        propertiesState: properties.beginDecodingProperties(from: decoder)
      )
    }

    func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Properties.Value> {
      while true {
        if let propertyDecoder = state.activePropertyDecoder {
          switch try propertyDecoder.decode(from: &decoder).kind {
          case .incomplete:
            return .incomplete
          case .decoded:
            state.activePropertyDecoder = nil
          }
        }

        switch try decoder.stream.decodeObjectComponent(state: &state.objectState) {
        case .incomplete:
          return .incomplete
        case .decoded(.propertyValueStart(let name)):
          guard let propertyDecoder = state.propertiesState.decoders[name] else {
            throw Error.unknownProperty(name: String(name))
          }
          state.activePropertyDecoder = propertyDecoder
        case .decoded(.end):
          return .decoded(try state.propertiesState.finishDecoding(decoder))
        }
      }
    }

    func metaSchema(in context: SchemaContext) -> some Schema<Self> {
      let propertiesMetadata = properties.metadata
      let objectSchema = ConcreteObjectSchema<_> {
        OptionalObjectProperty(
          name: .description,
          schema: String.schema
        )
        RequiredObjectProperty(
          name: .properties,
          schema: ConcreteObjectSchema<_>(properties: properties.metaProperties)
        )
        RequiredObjectProperty(
          name: .required,
          schema: schema(
            constantValue: propertiesMetadata.requiredPropertyNames
          )
        )
      }
      return objectSchema.wrap { (description, properties, _) in
        Self(description: description, properties: properties)
      } unwrap: { schema in
        (schema.description, schema.properties, ())
      }
    }

    var objectSchemaMetadata: ObjectSchemaMetadata {
      ObjectSchemaMetadata(description: description)
    }

    init<each Component>(
      description: String? = nil,
      components: repeat each Component
    ) where Properties == CompositeObjectSchemaProperties<repeat each Component> {
      self.init(
        description: description,
        properties: Properties(repeat each components)
      )
    }

    init<each Property>(
      description: String? = nil,
      @ObjectPropertiesBuilder properties: () -> ObjectProperties<repeat each Property>
    ) where Properties == TupleObjectSchemaProperties<repeat each Property> {
      self.init(
        description: description,
        properties: repeat each properties().properties
      )
    }

    init<each Property>(
      description: String? = nil,
      properties: repeat each Property
    ) where Properties == TupleObjectSchemaProperties<repeat each Property> {
      self.init(
        description: description,
        properties: Properties(repeat each properties)
      )
    }

    init(
      description: String? = nil,
      properties: Properties
    ) {
      self.description = description
      self.properties = properties
    }
    var description: String?
    let properties: Properties

  }

}

// MARK: - Errors

private enum Error: Swift.Error {
  case unknownProperty(name: String)
}

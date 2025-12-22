import JSONSupport

// MARK: - Creating Object Schemas

extension SchemaCoding.Support {

  static func objectSchema<each Property>(
    description: String? = nil,
    @ObjectPropertiesBuilder properties:
      () -> ObjectProperties<repeat each Property>
  ) -> some ObjectSchema<(repeat (each Property).Value)> {
    ConcereteObjectSchema(
      description: description,
      properties: TupleObjectSchemaProperties(
        repeat each properties().properties
      )
    )
  }

  static func objectSchema<each Property: ObjectProperty>(
    description: String? = nil,
    properties: repeat each Property
  ) -> some ObjectSchema<(repeat (each Property).Value)> {
    ConcereteObjectSchema(
      description: description,
      properties: TupleObjectSchemaProperties(
        repeat each properties
      )
    )
  }

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

  struct ConcereteObjectSchema<Properties: ObjectSchemaProperties>: ObjectSchema {

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
      let objectSchema = ConcereteObjectSchema<_> {
        OptionalObjectProperty(
          name: .description,
          schema: String.schema
        )
        RequiredObjectProperty(
          name: .properties,
          schema: ConcereteObjectSchema<_>(properties: properties.metaProperties)
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

// MARK: - Tuple Object Schema

extension SchemaCoding.Support {

  struct TupleObjectSchema<each Property: ObjectProperty>:
    PrivateObjectSchema
  {

    init(
      description: String? = nil,
      @ObjectPropertiesBuilder properties: () -> ObjectProperties<
        repeat each Property
      >
    ) {
      self.init(
        description: description,
        properties: repeat each properties().properties
      )
    }

    init(
      description: String? = nil,
      properties: repeat each Property
    ) {
      self.init(
        description: description,
        properties: Properties(repeat each properties)
      )
    }

    fileprivate init(
      description: String? = nil,
      properties: Properties
    ) {
      self.description = description
      self.properties = properties
    }

    typealias Value = Properties.Value
    typealias Properties = TupleObjectSchemaProperties<repeat each Property>

    let description: String?
    let properties: Properties

  }

}

// MARK: - Shared Logic

extension SchemaCoding.Support {

  fileprivate protocol PrivateObjectSchema: ObjectSchema
  where
    ValueDecodingState == ObjectSchemaPropertiesSchema<Properties>.ValueDecodingState
  {
    associatedtype ValueDecodingState = ObjectSchemaPropertiesSchema<Properties>.ValueDecodingState

    var description: String? { get }

    init(description: String?, properties: Properties)
  }

}

extension SchemaCoding.Support.PrivateObjectSchema {

  func encode(_ value: Value, to encoder: inout SchemaCoding.Support.Encoder) {
    encoder.stream.encodeObject { encoder in
      var objectEncoder = SchemaCoding.Support.ObjectPropertiesEncoder(encoder: encoder)
      properties.encodeProperties(of: value, to: &objectEncoder)
      encoder = objectEncoder.encoder
    }
  }

  func beginDecodingValue(from decoder: borrowing SchemaCoding.Support.Decoder)
    -> ValueDecodingState
  {
    ValueDecodingState(
      propertiesState: properties.beginDecodingProperties(from: decoder)
    )
  }

  func decodeValue(
    from decoder: inout SchemaCoding.Support.Decoder,
    state: inout ValueDecodingState
  ) throws -> SchemaCoding.Support.DecodingResult<Value> {
    try state.decode(from: &decoder)
  }

  func metaSchema(
    in context: SchemaCoding.Support.SchemaContext
  ) -> SchemaCoding.Support.TypeErasedSchema<Self> {
    let properties = self.properties
    let requiredPropertyNames = properties.metadata.requiredPropertyNames
    if requiredPropertyNames.isEmpty {
      return SchemaCoding.Support.TupleObjectSchema<_, _>(
        description: nil,
        properties: {
          SchemaCoding.Support.objectProperty(
            name: .description,
            schema: String?.schema
          )
          SchemaCoding.Support.objectProperty(
            name: .properties,
            schema: properties.schema.metaSchema(in: SchemaCoding.Support.SchemaContext())
          )
        }
      )
      .wrap { (description, propertiesSchema) in
        Self(description: description, properties: propertiesSchema.properties)
      } unwrap: { schema in
        (schema.description, schema.properties.schema)
      }
      .typeErased()
    } else {
      return SchemaCoding.Support.TupleObjectSchema<_, _, _>(
        description: nil,
        properties: {
          SchemaCoding.Support.objectProperty(
            name: .description,
            schema: String?.schema
          )
          SchemaCoding.Support.objectProperty(
            name: .properties,
            schema: properties.schema.metaSchema(in: SchemaCoding.Support.SchemaContext())
          )
          SchemaCoding.Support.objectProperty(
            name: .required,
            schema: SchemaCoding.Support.schema(
              constantValue: properties.metadata.requiredPropertyNames
            )
          )
        }
      )
      .wrap { (description, propertiesSchema, _) in
        Self(description: description, properties: propertiesSchema.properties)
      } unwrap: { schema in
        (schema.description, schema.properties.schema, ())
      }
      .typeErased()
    }
  }

  var objectSchemaMetadata: SchemaCoding.Support.ObjectSchemaMetadata {
    SchemaCoding.Support.ObjectSchemaMetadata(description: description)
  }

}

// MARK: - Errors

private enum Error: Swift.Error {
  case unknownProperty(name: String)
}

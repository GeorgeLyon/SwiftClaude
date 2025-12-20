import JSONSupport

// MARK: - Creating Object Schemas

extension SchemaCoding.Support {

  public static func objectSchema<PropertyName: CodingKey, each Property>(
    description: String? = nil,
    propertyName: PropertyName.Type = PropertyName.self,
    @ObjectPropertiesBuilder<PropertyName> properties:
      () -> ObjectProperties<PropertyName, repeat each Property>
  ) -> some ObjectSchema<(repeat (each Property).Value)> {
    TupleObjectSchema(
      description: description,
      propertyName: propertyName,
      properties: properties
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

// MARK: - Tuple Object Schema

extension SchemaCoding.Support {

  struct TupleObjectSchema<PropertyName: CodingKey, each Property: ObjectProperty>:
    PrivateObjectSchema
  {

    init(
      description: String? = nil,
      propertyName: PropertyName.Type = PropertyName.self,
      @ObjectPropertiesBuilder<PropertyName> properties: () -> ObjectProperties<
        PropertyName, repeat each Property
      >
    ) {
      self.init(
        description: description,
        propertyName: propertyName,
        properties: repeat each properties().properties
      )
    }

    init(
      description: String? = nil,
      propertyName: PropertyName.Type = PropertyName.self,
      properties: repeat each Property
    ) {
      self.init(
        description: description,
        propertyName: propertyName,
        properties: Properties(repeat each properties))
    }

    private init(
      description: String? = nil,
      propertyName: PropertyName.Type = PropertyName.self,
      properties: Properties
    ) {
      self.description = description
      self.properties = properties
    }

    typealias Value = Properties.Value
    typealias Properties = TupleObjectSchemaProperties<PropertyName, repeat each Property>

    let description: String?
    let properties: Properties

    func metaSchema(in context: SchemaContext) -> TypeErasedSchema<Self> {
      let properties = self.properties
      let tupleSchema = TupleObjectSchema<
        MetaSchemaCodingKey,
        _,
        _,
        _
      >(
        propertyName: MetaSchemaCodingKey.self,
        properties: {
          objectProperty(
            name: MetaSchemaCodingKey.description,
            schema: String?.schema
          )
          objectProperty(
            name: MetaSchemaCodingKey.properties,
            schema: properties.schema.metaSchema(in: SchemaContext())
          )
          objectProperty(
            name: MetaSchemaCodingKey.required,
            schema: SchemaCoding.Support.schema(
              constantValue: properties.metadata.requiredPropertyNames
            )
          )
        }
      )
      let wrappedSchema =
        tupleSchema.wrap { (description, propertiesSchema, _) in
          Self(
            description: description,
            propertyName: PropertyName.self,
            properties: propertiesSchema.properties
          )
        } unwrap: { schema in
          (schema.description, schema.properties.schema, ())
        }
      return wrappedSchema.typeErased()
    }

  }

}

// MARK: - Composite Object Schema

extension SchemaCoding.Support {

  struct CompositeObjectSchema<each Component: ObjectSchema>: PrivateObjectSchema {

    typealias Value = (repeat (each Component).Value)
    typealias Properties = CompositeObjectSchemaProperties<repeat (each Component).Properties>

    init(
      _ components: repeat each Component
    ) {
      var componentDescriptions: [String?] = []
      for component in repeat each components {
        componentDescriptions.append(component.objectSchemaMetadata.description)
      }
      self.init(
        description: combineDescriptions(componentDescriptions),
        properties: Properties(repeat (each components).properties)
      )
    }

    init(
      description: String? = nil,
      properties: Properties
    ) {
      self.description = description
      self.properties = properties
    }

    let description: String?
    let properties: Properties

    func metaSchema(in context: SchemaContext) -> TypeErasedSchema<Self> {
      let properties = self.properties
      let tupleSchema = TupleObjectSchema<
        MetaSchemaCodingKey,
        _,
        _,
        _
      >(
        description: nil,
        propertyName: MetaSchemaCodingKey.self,
        properties: {
          objectProperty(
            name: MetaSchemaCodingKey.description,
            schema: String?.schema
          )
          objectProperty(
            name: MetaSchemaCodingKey.properties,
            schema: properties.schema.metaSchema(in: SchemaContext())
          )
          objectProperty(
            name: MetaSchemaCodingKey.required,
            schema: SchemaCoding.Support.schema(
              constantValue: properties.metadata.requiredPropertyNames
            )
          )
        }
      )
      let wrapperSchema = tupleSchema.wrap { (description, propertiesSchema, _) in
        Self(description: description, properties: propertiesSchema.properties)
      } unwrap: { schema in
        (schema.description, schema.properties.schema, ())
      }
      return wrapperSchema.typeErased()
    }

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

  var objectSchemaMetadata: SchemaCoding.Support.ObjectSchemaMetadata {
    SchemaCoding.Support.ObjectSchemaMetadata(description: description)
  }

}

// MARK: - Implementation Details

private enum MetaSchemaCodingKey: CodingKey {
  case description, properties, required
}

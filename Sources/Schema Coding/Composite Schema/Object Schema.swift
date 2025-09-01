import JSONSupport

// MARK: - API

extension SchemaCoding.Support {

  public static func objectSchema<PropertyName, each Property: ObjectProperty>(
    description: String? = nil,
    propertyName: PropertyName.Type = PropertyName.self,
    properties: repeat each Property
  ) -> _TupleObjectSchema<PropertyName, repeat each Property> {
    _TupleObjectSchema(
      description: description,
      properties: (repeat each properties)
    )
  }

  static func objectSchema(
    description: String? = nil
  ) -> _TupleObjectSchema<EmptyCodingKey> {
    objectSchema(
      description: description,
      propertyName: EmptyCodingKey.self
    )
  }
}

extension SchemaCoding.Support {

  static func objectSchema<PropertyName, each PropertySchema>(
    description: String? = nil,
    propertyName: PropertyName.Type = PropertyName.self,
    @ObjectPropertiesBuilder<PropertyName>
    properties: () -> ObjectProperties<PropertyName, repeat each PropertySchema>
  ) -> _TupleObjectSchema<PropertyName, repeat each PropertySchema> {
    objectSchema(
      description: description,
      properties: repeat each properties().properties
    )
  }

  static func objectSchema(
    description: String? = nil,
    @ObjectPropertiesBuilder<EmptyCodingKey>
    properties: () -> ObjectProperties<EmptyCodingKey>
  ) -> _TupleObjectSchema<EmptyCodingKey> {
    objectSchema(
      description: description,
      propertyName: EmptyCodingKey.self
    )
  }

}

// MARK: - Protocol

extension SchemaCoding {

  public typealias ObjectSchema = Support.ObjectSchema

}

extension SchemaCoding.Support {

  public protocol ObjectSchema<Value>: Schema
  where
    ValueDecodingState == ObjectSchemaValueDecodingState<PropertyStates>
  {

    func encodeProperties(
      of value: Value,
      to encoder: inout ObjectEncoder
    )

    associatedtype PropertyStates: Sendable
    func finishDecoding(_ states: PropertyStates) throws -> Value

    var objectSchemaMetadata: ObjectSchemaMetadata { get }

    #if ENABLE_META_SCHEMA
      associatedtype PropertiesMetaSchema: ObjectSchema where PropertiesMetaSchema.Value == Self
      var propertiesMetaSchema: PropertiesMetaSchema { get }
    #endif

  }

  public struct ObjectEncoder: ~Copyable {
    var objectEncoder: JSON.ObjectEncoder
  }

  public struct ObjectSchemaMetadata {
    let description: String?
    let requiredPropertyNames: [String]?
  }

}

// MARK: - Tuple Object Schema

extension SchemaCoding.Support {

  /// This type is only public to work around the following issues:
  /// https://forums.swift.org/t/opaque-return-type-fails-when-using-variadic-generics/81120
  /// https://github.com/swiftlang/swift/issues/83055
  public struct _TupleObjectSchema<
    PropertyName: CodingKey,
    each Property: ObjectProperty
  >: ObjectSchema {

    public typealias Value = (repeat (each Property).PropertyValue)

    public func encodeProperties(of value: Value, to encoder: inout ObjectEncoder) {
      func encode<T: ObjectProperty>(_ property: T, _ value: T.PropertyValue) {
        if let schemaValue = type(of: property).coerceToSchemaValue(from: value) {
          guard let name = property.name else {
            /// This is a constant omitted property
            return
          }
          encoder.objectEncoder.encodeProperty(name: name.stringValue) { stream in
            stream.encode(schemaValue, using: property.schema)
          }
        }
      }
      repeat encode(each properties, each value)
    }

    public struct PropertyStates: Sendable {
      fileprivate var state = Archetype.DecodingState()
    }

    public typealias ValueDecodingState = ObjectSchemaValueDecodingState<PropertyStates>

    public var initialValueDecodingState: ValueDecodingState {
      typealias Archetype = SchemaCoding.Support.SchemaTupleArchetype<repeat (each Property).Schema>
      let archetype = Archetype(
        repeat SchemaTupleElementDefinition(
          label: (each properties).name,
          schema: (each properties).schema
        )
      )
      var propertyDecoders = PropertyDecoders<PropertyStates, Void>()
      func process<T>(_ element: Archetype.Element<T>) {
        guard let label = element.label else {
          /// This is a constant omitted property
          return
        }
        propertyDecoders[Substring(label)] = { decoder, states in
          try archetype.decode(
            element,
            from: &decoder,
            state: &states.state
          ).map { _ in }
        }
      }
      repeat process(each archetype.elements)
      return ValueDecodingState(
        propertyDecoders: propertyDecoders,
        propertyStates: PropertyStates()
      )
    }

    public func finishDecoding(_ states: PropertyStates) throws -> Value {
      let archetype = SchemaTupleArchetype(
        repeat SchemaTupleElementDefinition(
          label: (each properties).name,
          schema: (each properties).schema
        )
      )
      let schemaValues = try archetype.finishDecoding(
        state: states.state,
        allowMissingValues: true
      )
      return try (repeat (each properties).finishDecoding(each schemaValues))
    }

    public var objectSchemaMetadata: SchemaCoding.Support.ObjectSchemaMetadata {
      SchemaCoding.Support.ObjectSchemaMetadata(
        description: description,
        requiredPropertyNames: requiredPropertyNames
      )
    }

    #if ENABLE_META_SCHEMA
      public typealias PropertiesMetaSchema =
        _WrapperSchema<
          Self,
          _TupleObjectSchema<
            PropertyName,
            repeat _RequiredObjectProperty<(each Property).Name, (each Property).Schema.MetaSchema>
          >
        >
      public var propertiesMetaSchema: PropertiesMetaSchema {
        PropertiesMetaSchema.WrappedSchema(
          description: nil,
          properties: (repeat _RequiredObjectProperty(
            name: (each properties).name,
            schema: (each properties).schema.metaSchema(in: (each properties).metaSchemaContext)
          ))
        ).wrap { wrapped in
          Self(
            description: nil,
            properties: (repeat (each Property).init(
              metadata: (each properties).metadata,
              schema: each wrapped))
          )
        } unwrap: { wrapper in
          (repeat (each wrapper.properties).schema)
        }
      }

      public typealias MetaSchema =
        _WrapperSchema<
          Self,
          _TupleObjectSchema<
            _ObjectMetaSchemaPropertyNames,
            _SchemaDescriptionProperty<_ObjectMetaSchemaPropertyNames>,
            _RequiredObjectProperty<_ObjectMetaSchemaPropertyNames, PropertiesMetaSchema>,
            _OptionalObjectProperty<
              _ObjectMetaSchemaPropertyNames,
              _ConstantSchema<
                OptionalSchema<_ArraySchema<String.Schema>>
              >
            >
          >
        >
      public func metaSchema(in context: SchemaContext) -> MetaSchema {
        MetaSchema.WrappedSchema(
          description: nil,
          properties: {
            objectProperty(
              name: _ObjectMetaSchemaPropertyNames.description,
              constantValue: context.contextualDescription(for: description)
            )
            _RequiredObjectProperty(
              name: _ObjectMetaSchemaPropertyNames.properties,
              schema: propertiesMetaSchema
            )
            objectProperty(
              name: _ObjectMetaSchemaPropertyNames.required,
              constantValue: requiredPropertyNames
            )
          }
        ).wrap { wrapped in
          Self(
            description: description,
            properties: (repeat each wrapped.1.properties)
          )
        } unwrap: { wrapper in
          (
            (),
            wrapper,
            ()
          )
        }
      }
    #endif

    fileprivate init(
      description: String?,
      @ObjectPropertiesBuilder<PropertyName>
      properties: () -> ObjectProperties<PropertyName, repeat each Property>
    ) {
      self.init(
        description: description,
        properties: (repeat each properties().properties)
      )
    }

    fileprivate init(
      description: String?,
      properties: (repeat each Property)
    ) {
      self.description = description
      let x = (repeat each properties)
      self.properties = x
      // self.description = description
      // self.properties =
    }

    fileprivate var requiredPropertyNames: [String]? {
      var requiredProperties: [String] = []
      func process<T: ObjectProperty>(_ property: T) {
        if property.isRequired {
          guard let name = property.name else {
            /// This is a constant omitted property
            return
          }
          requiredProperties.append(name.stringValue)
        }
      }
      repeat process(each properties)
      return requiredProperties.isEmpty ? nil : requiredProperties
    }

    fileprivate typealias Archetype = SchemaTupleArchetype<
      repeat (each Property).Schema
    >

    fileprivate let description: String?
    fileprivate let properties: (repeat each Property)

  }

}

// MARK: - Merged Object Schema

extension SchemaCoding.Support {

  public struct _MergedObjectSchema<each Component: ObjectSchema>: ObjectSchema {

    public typealias Value = (repeat (each Component).Value)

    public func encodeProperties(of value: Value, to encoder: inout ObjectEncoder) {
      func encode<T: ObjectSchema>(_ value: T.Value, using component: T) {
        component.encodeProperties(of: value, to: &encoder)
      }
      repeat encode(each value, using: each components)
    }

    public typealias PropertyStates = (repeat (each Component).PropertyStates)

    public typealias ValueDecodingState = ObjectSchemaValueDecodingState<
      PropertyStates
    >

    public var initialValueDecodingState: ValueDecodingState {
      ValueDecodingState(repeat (each components).initialValueDecodingState)
    }

    public func finishDecoding(_ states: PropertyStates) throws -> Value {
      try (repeat (each components).finishDecoding(each states))
    }

    public var objectSchemaMetadata: SchemaCoding.Support.ObjectSchemaMetadata {
      SchemaCoding.Support.ObjectSchemaMetadata(
        description: description,
        requiredPropertyNames: requiredPropertyNames
      )
    }

    #if ENABLE_META_SCHEMA
      public typealias PropertiesMetaSchema =
        _WrapperSchema<
          Self,
          _MergedObjectSchema<repeat (each Component).PropertiesMetaSchema>
        >
      public var propertiesMetaSchema: PropertiesMetaSchema {
        PropertiesMetaSchema.WrappedSchema(
          repeat (each components).propertiesMetaSchema
        ).wrap { wrapped in
          Self(repeat each wrapped)
        } unwrap: { wrapper in
          (repeat each wrapper.components)
        }
      }

      public typealias MetaSchema =
        _WrapperSchema<
          Self,
          _TupleObjectSchema<
            _ObjectMetaSchemaPropertyNames,
            _SchemaDescriptionProperty<_ObjectMetaSchemaPropertyNames>,
            _RequiredObjectProperty<_ObjectMetaSchemaPropertyNames, PropertiesMetaSchema>,
            _OptionalObjectProperty<
              _ObjectMetaSchemaPropertyNames,
              _ConstantSchema<
                OptionalSchema<_ArraySchema<String.Schema>>
              >
            >
          >
        >

      public func metaSchema(in context: SchemaContext) -> MetaSchema {
        MetaSchema.WrappedSchema(
          description: nil,
          properties: {
            objectProperty(
              name: _ObjectMetaSchemaPropertyNames.description,
              constantValue: context.contextualDescription(for: description)
            )
            _RequiredObjectProperty(
              name: _ObjectMetaSchemaPropertyNames.properties,
              schema: propertiesMetaSchema
            )
            objectProperty(
              name: _ObjectMetaSchemaPropertyNames.required,
              constantValue: requiredPropertyNames
            )
          }
        ).wrap { wrapped in
          Self(repeat each wrapped.1.components)
        } unwrap: { wrapper in
          (
            (),
            wrapper,
            ()
          )
        }
      }
    #endif

    init(
      _ components: repeat each Component
    ) {
      self.components = (repeat each components)
    }

    private var requiredPropertyNames: [String]? {
      var requiredPropertyNames: [String] = []
      func process<T: ObjectSchema>(_ component: T) {
        guard let names = component.objectSchemaMetadata.requiredPropertyNames else {
          return
        }
        requiredPropertyNames.append(contentsOf: names)
      }
      repeat process(each components)
      return requiredPropertyNames.isEmpty ? nil : requiredPropertyNames
    }

    var description: String? {
      var descriptions: [String?] = []
      func process<T: ObjectSchema>(_ component: T) {
        if let description = component.objectSchemaMetadata.description {
          descriptions.append(description)
        }
      }
      repeat process(each components)
      return combineDescriptions(descriptions)
    }
    let components: (repeat each Component)

  }

}

// MARK: - Shared

extension SchemaCoding.Support.ObjectSchema {

  public func encode(_ value: Value, to encoder: inout SchemaCoding.Support.Encoder) {
    encoder.stream.encodeObject { objectEncoder in
      var encoder = SchemaCoding.Support.ObjectEncoder(objectEncoder: objectEncoder)
      encodeProperties(of: value, to: &encoder)
      objectEncoder = encoder.objectEncoder
    }
  }

  public func decodeValue(
    from decoder: inout SchemaCoding.Support.Decoder,
    state: inout ValueDecodingState
  ) throws -> SchemaCoding.Support.DecodingResult<Value> {
    while true {
      if let activeDecoder = state.activePropertyDecoder {
        switch try activeDecoder(&decoder, &state.propertyStates).kind {
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
        guard let decoder = state.propertyDecoders[name] else {
          throw Error.unknownPropertyName(String(name))
        }
        state.activePropertyDecoder = decoder
      case .decoded(.end):
        return .decoded(try finishDecoding(state.propertyStates))
      }

    }
  }

  public var schemaMetadata: SchemaCoding.Support.SchemaMetadata {
    SchemaCoding.Support.SchemaMetadata(
      primitiveRepresentation: nil,
      mayAcceptNull: false
    )
  }

}

// MARK: - Meta Schema

extension SchemaCoding.Support {

  public enum _ObjectMetaSchemaPropertyNames: CodingKey {
    case description
    case properties
    case required
  }

}

// MARK: - Decoding

extension SchemaCoding.Support {

  public struct ObjectSchemaValueDecodingState<PropertyStates: Sendable>: Sendable {

    fileprivate init<each ComponentPropertyStates>(
      _ components: repeat ObjectSchemaValueDecodingState<
        each ComponentPropertyStates
      >
    )
    where
      PropertyStates == (repeat each ComponentPropertyStates)
    {
      let components = (repeat each components)
      self.propertyStates = (repeat (each components).propertyStates)

      do {
        typealias Archetype = VariadicTupleArchetype<repeat each ComponentPropertyStates>
        let archetype = Archetype()
        var propertyDecoders = PropertyDecoders()
        func process<T>(
          _ component: ObjectSchemaValueDecodingState<T>,
          _ accessor: Archetype.ElementAccessor<T>
        ) {
          for (name, propertyDecoder) in component.propertyDecoders {
            propertyDecoders[name] = { decoder, states in
              try accessor.mutate(&states) { states in
                try propertyDecoder(&decoder, &states)
              }
            }
          }
        }
        repeat process(each components, each archetype.elementAccessors)
        self.propertyDecoders = propertyDecoders
      }
    }

    fileprivate init(
      propertyDecoders: PropertyDecoders,
      propertyStates: PropertyStates,
    ) {
      self.propertyDecoders = propertyDecoders
      self.propertyStates = propertyStates
    }

    fileprivate let propertyDecoders: PropertyDecoders

    fileprivate var objectState = JSON.ObjectDecodingState()
    fileprivate var propertyStates: PropertyStates
    fileprivate var activePropertyDecoder: PropertyDecoder?

    typealias PropertyDecoder = PropertyDecoders.Decoder
    typealias PropertyDecoders = SchemaCoding.Support.PropertyDecoders<
      PropertyStates, Void
    >

  }

}

// MARK: - Object Schema Properties

extension SchemaCoding.Support {

}

// MARK: - Errors

private enum Error: Swift.Error {
  case unknownPropertyName(String)
  case multiplePropertiesWithSameName(String)
  case missingRequiredProperty(String)
}

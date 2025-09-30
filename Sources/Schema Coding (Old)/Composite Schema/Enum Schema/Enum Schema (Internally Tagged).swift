import JSONSupport

// MARK: - API

extension SchemaCoding.Support {

  public static func enumSchema<
    Value,
    CaseName: CodingKey,
    each AssociatedValuesSchema: SchemaCoding.Schema
  >(
    description: String? = nil,
    style: EnumSchemaStyleInternallyTagged,
    caseName: CaseName.Type = CaseName.self,
    @EnumSchemaCasesBuilder<Value, CaseName>
    cases: () -> EnumSchemaCases<Value, CaseName, repeat each AssociatedValuesSchema>,
    encodeValue:
      @escaping @Sendable (
        Value,
        inout EnumSchemaInternallyTaggedEncoder<repeat each AssociatedValuesSchema>
      ) -> Void
  ) -> _EnumSchemaInternallyTagged<Value, CaseName, repeat each AssociatedValuesSchema> {
    let cases = cases().cases
    return _EnumSchemaInternallyTagged(
      description: description,
      discriminatorPropertyName: style.discriminatorPropertyName,
      cases: repeat each cases,
      encodeValue: encodeValue
    )
  }

}

// MARK: - Encoding

extension SchemaCoding.Support {

  public struct EnumSchemaInternallyTaggedCaseEncoding<Schema: ObjectSchema> {
    fileprivate let name: String
    fileprivate let schema: _EnumSchemaInternallyTaggedSchema<Schema>
  }
  public struct EnumSchemaInternallyTaggedEncoder<each AssociatedValueSchema: ObjectSchema>:
    ~Copyable
  {

    public typealias Encoding = EnumSchemaInternallyTaggedCaseEncoding
    public let encodings: (repeat Encoding<each AssociatedValueSchema>)

    public mutating func encode<Schema: SchemaCoding.Schema>(
      _ value: Schema.Value,
      using encoding: Encoding<Schema>,
    ) {
      // TODO: This logic whould be in `EncodingStream`
      guard !isEncoded else {
        assertionFailure()
        return
      }
      isEncoded = true

      valueEncoder.stream.encode(((), value), using: encoding.schema)
    }

    fileprivate var isEncoded = false
    fileprivate var valueEncoder: Encoder

  }
}

// MARK: - Style

extension SchemaCoding.Support {

  public struct EnumSchemaStyleInternallyTagged: Style {
    fileprivate let discriminatorPropertyName: String
  }

}

extension SchemaCoding.Support.Style
where Self == SchemaCoding.Support.EnumSchemaStyleInternallyTagged {
  public static func internallyTagged(discriminatorPropertyName: String) -> Self {
    Self(discriminatorPropertyName: discriminatorPropertyName)
  }
}

// MARK: - Schema

extension SchemaCoding.Support {

  public struct _EnumSchemaInternallyTagged<
    Value: Sendable,
    CaseName: CodingKey,
    each AssociatedValuesSchema: SchemaCoding.ObjectSchema
  >: Schema {

    public func encode(_ value: Value, to encoder: inout Encoder) {
      var enumEncoder = EnumSchemaInternallyTaggedEncoder(
        encodings: (repeat EnumSchemaInternallyTaggedCaseEncoding(
          name: (each cases).name.stringValue,
          schema: (each cases).element.schema
        )),
        valueEncoder: encoder
      )
      encodeValue(value, &enumEncoder)
      encoder = enumEncoder.valueEncoder
    }

    public struct ValueDecodingState: Sendable {
      fileprivate var tupleState = TupleArchetype.DecodingState()
      fileprivate var valueDecoder: ValueDecoder?
    }

    public var initialValueDecodingState: ValueDecodingState {
      ValueDecodingState()
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value> {
      let valueDecoder: ValueDecoder
      if let decoder = state.valueDecoder {
        valueDecoder = decoder
      } else {
        let peekResult = try decoder.stream.peekObjectProperty(discriminatorPropertyName) {
          stream in
          try stream.decodeString()
        }
        switch peekResult {
        case .incomplete:
          return .incomplete
        case .decoded(.none):
          throw Error.casePropertyNotFound
        case .decoded(let discriminator?):
          guard let decoder = valueDecoders[discriminator] else {
            throw Error.unknownPropertyName(String(discriminator))
          }
          state.valueDecoder = decoder
          valueDecoder = decoder
        }
      }

      return try valueDecoder(&decoder, &state.tupleState)
    }

    public var schemaMetadata: SchemaCoding.Support.SchemaMetadata {
      SchemaCoding.Support.SchemaMetadata(
        primitiveRepresentation: nil,
        mayAcceptNull: false
      )
    }

    #if ENABLE_META_SCHEMA
      public typealias MetaSchema = _WrapperSchema<
        Self,
        _TupleObjectSchema<
          _EnumSchemaInternallyTaggedSchemaCodingKey,
          _SchemaDescriptionProperty<_EnumSchemaInternallyTaggedSchemaCodingKey>,
          _RequiredObjectProperty<
            _EnumSchemaInternallyTaggedSchemaCodingKey,
            _TupleSchema<
              repeat _EnumSchemaInternallyTaggedSchema<each AssociatedValuesSchema>.MetaSchema
            >
          >
        >
      >
      public func metaSchema(in context: SchemaContext) -> MetaSchema {
        let schema = objectSchema(
          propertyName: _EnumSchemaInternallyTaggedSchemaCodingKey.self
        ) {
          objectProperty(
            name: _EnumSchemaInternallyTaggedSchemaCodingKey.description,
            constantValue: context.contextualDescription(for: description)
          )
          _RequiredObjectProperty(
            name: _EnumSchemaInternallyTaggedSchemaCodingKey.oneOf,
            schema: tupleSchema(
              elements: repeat (each cases).schema.metaSchema
            )
          )
        }
        return schema.wrap { wrapped in
          let schemas = (repeat (each wrapped.1).components.1)
          let cases =
            (repeat EnumSchemaCase<Value, CaseName, each AssociatedValuesSchema>(
              name: (each cases).name,
              associatedValuesSchema: (each schemas),
              finishDecoding: (each cases).finishDecoding
            ))
          return Self(
            description: description,
            discriminatorPropertyName: discriminatorPropertyName,
            cases: repeat each cases,
            encodeValue: encodeValue
          )
        } unwrap: { (wrapper: Self) in
          ((), (repeat (each wrapper.cases).schema))
        }
      }
    #endif

    fileprivate init(
      description: String?,
      discriminatorPropertyName: String,
      cases: repeat EnumSchemaCase<Value, CaseName, each AssociatedValuesSchema>,
      encodeValue:
        @escaping @Sendable (
          Value,
          inout EnumSchemaInternallyTaggedEncoder<repeat each AssociatedValuesSchema>
        ) -> Void
    ) {
      self.description = description
      self.discriminatorPropertyName = discriminatorPropertyName

      let taggedSchemas =
        (repeat (each cases).associatedValuesSchema.internallyTagged(
          discriminatorPropertyName: discriminatorPropertyName,
          discriminatorPropertyValue: (each cases).name.stringValue))

      let archetype = TupleArchetype(
        repeat SchemaTupleElementDefinition(
          label: (each cases).name,
          schema: each taggedSchemas
        )
      )
      self.cases =
        (repeat Case(
          name: (each cases).name,
          element: (each archetype.elements),
          finishDecoding: (each cases).finishDecoding
        ))
      self.encodeValue = encodeValue

      do {
        var decoders = ValueDecoders()
        func process<T>(_ enumCase: Case<T>) {
          decoders[enumCase.name] = { decoder, state in
            try archetype.decode(
              enumCase.element,
              from: &decoder,
              state: &state
            ).map { value in
              enumCase.finishDecoding(value.1)
            }
          }
        }
        repeat process(each self.cases)
        self.valueDecoders = decoders
      }
    }
    fileprivate typealias TupleArchetype = SchemaTupleArchetype<
      repeat _EnumSchemaInternallyTaggedSchema<each AssociatedValuesSchema>
    >
    fileprivate struct Case<Schema: ObjectSchema> {
      let name: CaseName
      var schema: _EnumSchemaInternallyTaggedSchema<Schema> {
        element.schema
      }
      let element:
        TupleArchetype.Element<
          _EnumSchemaInternallyTaggedSchema<Schema>
        >
      let finishDecoding: @Sendable (Schema.Value) -> Value
    }

    fileprivate let description: String?
    fileprivate let discriminatorPropertyName: String
    fileprivate let cases: (repeat Case<each AssociatedValuesSchema>)
    fileprivate let valueDecoders: ValueDecoders
    fileprivate let encodeValue:
      @Sendable (
        Value,
        inout EnumSchemaInternallyTaggedEncoder<repeat each AssociatedValuesSchema>
      ) -> Void

    fileprivate typealias ValueDecoder = ValueDecoders.Decoder
    fileprivate typealias ValueDecoders = SchemaCoding.Support.PropertyDecoders<
      TupleArchetype.DecodingState,
      Value
    >
  }

}

// MARK: - Internally Tagged Schemas

extension SchemaCoding.ObjectSchema {

  fileprivate func internallyTagged(
    discriminatorPropertyName: String,
    discriminatorPropertyValue: String
  ) -> SchemaCoding.Support._EnumSchemaInternallyTaggedSchema<Self> {
    SchemaCoding.Support._MergedObjectSchema(
      SchemaCoding.Support.objectSchema(
        propertyName: SchemaCoding.Support
          ._EnumSchemaInternallyTaggedDiscriminatorPropertyKey.self
      ) {
        SchemaCoding.Support._RequiredObjectProperty(
          name: SchemaCoding.Support
            ._EnumSchemaInternallyTaggedDiscriminatorPropertyKey(
              stringValue: discriminatorPropertyName
            ),
          schema: SchemaCoding.Support._ConstantSchema(
            wrappedSchema: String.schema,
            constantValue: discriminatorPropertyValue
          )
        )
      },
      self
    )
  }

}

extension SchemaCoding.Support {

  public typealias _EnumSchemaInternallyTaggedSchema<Schema: ObjectSchema> = _MergedObjectSchema<
    _TupleObjectSchema<
      _EnumSchemaInternallyTaggedDiscriminatorPropertyKey,
      _RequiredObjectProperty<
        _EnumSchemaInternallyTaggedDiscriminatorPropertyKey,
        _ConstantSchema<String.Schema>
      >
    >,
    Schema
  >

  public struct _EnumSchemaInternallyTaggedDiscriminatorPropertyKey: CodingKey {
    public init(stringValue: String) {
      self.stringValue = stringValue
    }
    public let stringValue: String

    public init?(intValue: Int) {
      return nil
    }
    public var intValue: Int? {
      return nil
    }
  }

}

// MARK: - Coding Keys

extension SchemaCoding.Support {

  public enum _EnumSchemaInternallyTaggedSchemaCodingKey: CodingKey {
    case description, oneOf
  }

}

// MARK: - Errors

private enum Error: Swift.Error {
  case unknownPropertyName(String)
  case multiplePropertiesWithSameName(String)
  case casePropertyNotFound
}

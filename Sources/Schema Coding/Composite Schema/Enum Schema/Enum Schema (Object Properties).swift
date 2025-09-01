import JSONSupport

// MARK: - API

extension SchemaCoding.Support {

  public static func enumSchema<
    Value,
    CaseName: CodingKey,
    each AssociatedValuesSchema: SchemaCoding.Schema
  >(
    description: String? = nil,
    style: EnumSchemaStyleObjectProperties = .objectProperties,
    caseName: CaseName.Type = CaseName.self,
    @EnumSchemaCasesBuilder<Value, CaseName>
    cases: () -> EnumSchemaCases<Value, CaseName, repeat each AssociatedValuesSchema>,
    encodeValue:
      @escaping @Sendable (
        Value,
        inout EnumSchemaObjectPropertiesEncoder<repeat each AssociatedValuesSchema>
      ) -> Void
  ) -> _EnumSchemaObjectProperties<Value, CaseName, repeat each AssociatedValuesSchema> {
    let cases = cases().cases
    return _EnumSchemaObjectProperties(
      description: description,
      cases: repeat each cases,
      encodeValue: encodeValue
    )
  }

}

// MARK: - Encoding

extension SchemaCoding.Support {

  public struct EnumSchemaObjectPropertiesCaseEncoding<Schema: SchemaCoding.Schema> {
    fileprivate let name: String
    fileprivate let schema: Schema
  }
  public struct EnumSchemaObjectPropertiesEncoder<each AssociatedValueSchema: Schema>: ~Copyable {

    public typealias Encoding = EnumSchemaObjectPropertiesCaseEncoding
    public let encodings: (repeat Encoding<each AssociatedValueSchema>)

    public mutating func encode<Schema: SchemaCoding.Schema>(
      _ value: Schema.Value,
      using encoding: Encoding<Schema>,
    ) {
      guard !isEncoded else {
        assertionFailure()
        return
      }
      isEncoded = true

      valueEncoder.stream.encodeObject { objectEncoder in
        objectEncoder.encodeProperty(name: encoding.name) { stream in
          stream.encode(value, using: encoding.schema)
        }
      }
    }

    fileprivate var isEncoded = false
    fileprivate var valueEncoder: Encoder

  }
}

// MARK: - Style

extension SchemaCoding.Support {

  public struct EnumSchemaStyleObjectProperties: Style {
    fileprivate init() {}
  }

}

extension SchemaCoding.Support.Style
where Self == SchemaCoding.Support.EnumSchemaStyleObjectProperties {
  public static var objectProperties: Self {
    Self()
  }
}

// MARK: - Schema

extension SchemaCoding.Support {

  public struct _EnumSchemaObjectProperties<
    Value: Sendable,
    CaseName: CodingKey,
    each AssociatedValuesSchema: SchemaCoding.Schema
  >: Schema {

    public func encode(_ value: Value, to encoder: inout Encoder) {
      var enumEncoder = EnumSchemaObjectPropertiesEncoder(
        encodings: (repeat EnumSchemaObjectPropertiesCaseEncoding(
          name: (each cases).name.stringValue,
          schema: (each cases).element.schema
        )),
        valueEncoder: encoder
      )
      encodeValue(value, &enumEncoder)
      encoder = enumEncoder.valueEncoder
    }

    public struct ValueDecodingState: Sendable {
      fileprivate var objectState = JSON.ObjectDecodingState()
      fileprivate var tupleState = TupleArchetype.DecodingState()
      fileprivate var phase: EnumSchemaObjectPropertiesDecodingPhase<ValueDecoder, Value> =
        .decodingObject(nil)
    }
    public var initialValueDecodingState: ValueDecodingState {
      ValueDecodingState()
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value> {
      while true {
        switch state.phase {
        case .decodingObject(let value):
          switch try decoder.stream.decodeObjectComponent(state: &state.objectState) {
          case .incomplete:
            return .incomplete
          case .decoded(.propertyValueStart(let name)):
            guard value == nil else {
              throw Error.multiplePropertiesWithSameName(String(name))
            }
            guard let decoder = caseDecoders[name] else {
              throw Error.unknownPropertyName(String(name))
            }
            state.phase = .decodingValue(decoder)
          case .decoded(.end):
            guard let value = value else {
              throw Error.casePropertyNotFound
            }
            return .decoded(value)
          }
        case .decodingValue(let valueDecoder):
          switch try valueDecoder(&decoder, &state.tupleState).kind {
          case .incomplete:
            return .incomplete
          case .decoded(let value):
            state.phase = .decodingObject(value)
          }
        }
      }
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
          _EnumSchemaObjectPropertiesCodingKeys,
          _SchemaDescriptionProperty<_EnumSchemaObjectPropertiesCodingKeys>,
          _RequiredObjectProperty<
            _EnumSchemaObjectPropertiesCodingKeys,
            _ConstantSchema<Int.Schema>
          >,
          _RequiredObjectProperty<
            _EnumSchemaObjectPropertiesCodingKeys,
            _TupleObjectSchema<
              CaseName,
              repeat _RequiredObjectProperty<CaseName, (each AssociatedValuesSchema).MetaSchema>
            >
          >
        >
      >
      private var propertiesMetaSchema:
        (repeat _RequiredObjectProperty<CaseName, (each AssociatedValuesSchema).MetaSchema>)
      {
        (repeat _RequiredObjectProperty(
          name: (each cases).name,
          schema: (each cases).schema.metaSchema
        ))
      }
      public func metaSchema(in context: SchemaContext) -> MetaSchema {
        let schema = objectSchema(propertyName: _EnumSchemaObjectPropertiesCodingKeys.self) {
          objectProperty(
            name: _EnumSchemaObjectPropertiesCodingKeys.description,
            constantValue: context.contextualDescription(for: description)
          )
          _RequiredObjectProperty(
            name: _EnumSchemaObjectPropertiesCodingKeys.maxProperties,
            schema: _ConstantSchema(
              wrappedSchema: Int.schema,
              constantValue: 1
            )
          )
          _RequiredObjectProperty(
            name: _EnumSchemaObjectPropertiesCodingKeys.properties,
            schema: objectSchema(
              propertyName: CaseName.self,
              properties: repeat each propertiesMetaSchema
            )
          )
        }
        return schema.wrap { wrapped in
          Self(
            description: description,
            cases: repeat EnumSchemaCase(
              name: (each cases).name,
              associatedValuesSchema: each wrapped.2,
              finishDecoding: (each cases).finishDecoding
            ),
            encodeValue: encodeValue
          )
        } unwrap: { (wrapper: Self) in
          ((), (), (repeat (each cases).schema))
        }
      }
    #endif

    fileprivate init(
      description: String?,
      cases: repeat EnumSchemaCase<Value, CaseName, each AssociatedValuesSchema>,
      encodeValue:
        @escaping @Sendable (
          Value,
          inout EnumSchemaObjectPropertiesEncoder<repeat each AssociatedValuesSchema>
        ) -> Void
    ) {
      self.description = description

      let archetype = TupleArchetype(
        repeat SchemaTupleElementDefinition(
          label: (each cases).name,
          schema: (each cases).associatedValuesSchema
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
        var decoders = CaseDecoders()
        func process<T>(
          _ enumCase: Case<T>
        ) {
          decoders[enumCase.name] = { decoder, state in
            try archetype.decode(
              enumCase.element,
              from: &decoder,
              state: &state
            ).map(enumCase.finishDecoding)
          }
        }
        repeat process(each self.cases)
        self.caseDecoders = decoders
      }
    }
    fileprivate typealias TupleArchetype = SchemaTupleArchetype<
      repeat each AssociatedValuesSchema
    >
    fileprivate struct Case<Schema: SchemaCoding.Schema> {
      let name: CaseName
      var schema: Schema {
        element.schema
      }
      let element: TupleArchetype.Element<Schema>
      let finishDecoding: @Sendable (Schema.Value) -> Value
    }

    fileprivate let description: String?
    fileprivate let cases: (repeat Case<each AssociatedValuesSchema>)
    fileprivate typealias ValueDecoder = CaseDecoders.Decoder
    fileprivate typealias CaseDecoders = SchemaCoding.Support.PropertyDecoders<
      TupleArchetype.DecodingState, Value
    >
    fileprivate let caseDecoders: CaseDecoders
    fileprivate let encodeValue:
      @Sendable (
        Value,
        inout EnumSchemaObjectPropertiesEncoder<repeat each AssociatedValuesSchema>
      ) -> Void
  }

  fileprivate enum EnumSchemaObjectPropertiesDecodingPhase<Decoder: Sendable, Value: Sendable> {
    case decodingObject(Value?)
    case decodingValue(Decoder)
  }

  // MARK: - Coding Keys

  public enum _EnumSchemaObjectPropertiesCodingKeys: CodingKey {
    case description, properties, maxProperties
  }

}

// MARK: - Errors

private enum Error: Swift.Error {
  case unknownPropertyName(String)
  case multiplePropertiesWithSameName(String)
  case casePropertyNotFound
}

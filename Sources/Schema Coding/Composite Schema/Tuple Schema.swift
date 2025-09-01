import JSONSupport

// MARK: - API

extension SchemaCoding.Support {

  public static func schema<each Element: SchemaCodable>(
    representing: (repeat each Element).Type = (repeat each Element).self,
    description: String? = nil
  ) -> _TupleSchema<repeat (each Element).Schema> {
    _TupleSchema(
      description: description,
      archetype: SchemaTupleArchetype(
        repeat SchemaTupleElementDefinition(
          schema: (each Element).schema
        )
      )
    )
  }

}

// MARK: - API (Builder)

extension SchemaCoding.Support {

  static func tupleSchema<each ElementSchema>(
    @TupleElementsBuilder
    elements: () -> TupleElements<repeat each ElementSchema>
  ) -> _TupleSchema<repeat each ElementSchema> {
    _TupleSchema(
      description: nil,
      archetype: SchemaTupleArchetype(
        repeat SchemaTupleElementDefinition(
          schema: each elements().elements
        )
      )
    )
  }

  static func tupleSchema<each ElementSchema>(
    description: String? = nil,
    elements: repeat each ElementSchema
  ) -> _TupleSchema<repeat each ElementSchema> {
    _TupleSchema(
      description: description,
      archetype: SchemaTupleArchetype(
        repeat SchemaTupleElementDefinition(
          schema: each elements
        )
      )
    )
  }

  struct TupleElements<each ElementSchema: Schema>: Sendable {
    let elements: (repeat each ElementSchema)
    fileprivate init(
      _ elements: repeat each ElementSchema
    ) {
      self.elements = (repeat each elements)
    }
  }

  @resultBuilder
  struct TupleElementsBuilder {

    public static func buildBlock() -> TupleElements<> {
      TupleElements()
    }

    public static func buildPartialBlock<Schema>(
      first: Schema
    ) -> TupleElements<Schema> {
      TupleElements(first)
    }

    public static func buildPartialBlock<each Schema, NextSchema>(
      accumulated: TupleElements<repeat each Schema>,
      next: NextSchema
    ) -> TupleElements<repeat each Schema, NextSchema> {
      TupleElements(repeat each accumulated.elements, next)
    }

  }

}

// MARK: - Schema

extension SchemaCoding.Support {

  public struct _TupleSchema<each ElementSchema: Schema>: Schema {

    public typealias Value = (repeat (each ElementSchema).Value)

    public func encode(
      _ value: Value,
      to encoder: inout Encoder
    ) {
      encoder.stream.encodeArray { arrayEncoder in
        func process<T>(_ value: T.Value, _ element: Archetype.Element<T>) {
          arrayEncoder.encodeElement { stream in
            stream.encode(value, using: element.schema)
          }
        }
        repeat process(each value, each archetype.elements)
      }
    }

    public struct ValueDecodingState: Sendable {
      fileprivate var arrayState = JSON.ArrayDecodingState()
      fileprivate var tupleState = Archetype.DecodingState()
      fileprivate var elementDecoders: [ElementDecoder].SubSequence
      fileprivate var isDecodingArrayComponent = true
    }

    public var initialValueDecodingState: ValueDecodingState {
      var elementDecoders: [ElementDecoder] = []
      func process<T>(_ element: Archetype.Element<T>) {
        elementDecoders.append { decoder, state in
          try archetype.decode(
            element,
            from: &decoder,
            state: &state
          ).map { _ in () }
        }
      }
      repeat process(each archetype.elements)
      return ValueDecodingState(
        elementDecoders: elementDecoders[...]
      )
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value> {
      while true {
        if state.isDecodingArrayComponent {
          switch try decoder.stream.decodeArrayComponent(state: &state.arrayState) {
          case .incomplete:
            return .incomplete
          case .decoded(.elementStart):
            state.isDecodingArrayComponent = false
          case .decoded(.end):
            let values = try archetype.finishDecoding(state: state.tupleState)
            return .decoded((repeat each values))
          }
        }

        guard let elementDecoder = state.elementDecoders.first else {
          throw Error.additionalElementsPresent
        }
        switch try elementDecoder(&decoder, &state.tupleState).kind {
        case .incomplete:
          return .incomplete
        case .decoded:
          state.elementDecoders.removeFirst()
          state.isDecodingArrayComponent = true
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
          _TupleSchemaCodingKey,
          _OptionalObjectProperty<
            _TupleSchemaCodingKey,
            _ConstantSchema<
              OptionalSchema<String.Schema>
            >
          >,
          _RequiredObjectProperty<
            _TupleSchemaCodingKey, _TupleSchema<repeat (each ElementSchema).MetaSchema>
          >
        >
      >
      public func metaSchema(in context: SchemaContext) -> MetaSchema {
        let objectSchema = objectSchema {
          objectProperty(
            name: _TupleSchemaCodingKey.description,
            constantValue: context.contextualDescription(for: description)
          )
          _RequiredObjectProperty(
            name: _TupleSchemaCodingKey.prefixItems,
            schema: _TupleSchema<repeat (each ElementSchema).MetaSchema>(
              description: nil,
              archetype: SchemaTupleArchetype(
                repeat SchemaTupleElementDefinition(
                  schema: (each elementSchemas).metaSchema
                )
              )
            )
          )
        }
        return objectSchema.wrap { wrapped -> Self in
          Self(
            description: description,
            archetype: archetype
          )
        } unwrap: { (wrapper: Self) in
          (
            (),
            (repeat (each wrapper.archetype.elements).schema)
          )
        }
      }
    #endif

    var elementSchemas: (repeat each ElementSchema) {
      (repeat (each archetype.elements).schema)
    }

    fileprivate typealias ElementDecoder =
      @Sendable (
        inout Decoder,
        inout Archetype.DecodingState
      ) throws -> DecodingResult<Void>

    fileprivate let description: String?

    fileprivate typealias Archetype = SchemaTupleArchetype<repeat each ElementSchema>
    fileprivate let archetype: Archetype

  }

  public enum _TupleSchemaCodingKey: CodingKey {
    case description, prefixItems
  }

}

// MARK: - Coding Keys

// MARK: - Errors

private enum Error: Swift.Error {
  case additionalElementsPresent
}

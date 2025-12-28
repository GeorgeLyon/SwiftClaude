private import JSONSupport
private import SchemaCodingSupport

extension SchemaCoding.Support {

  struct TupleSchema<each ElementSchema: Schema>: Schema {

    typealias Value = (repeat (each ElementSchema).Value)

    func encode(_ value: Value, to encoder: inout Encoder) {
      encoder.stream.encodeArray { arrayEncoder in
        for (element, value) in repeat (each elements, each value) {
          if case .required = element.kind {
            arrayEncoder.encodeElement { elementEncoder in
              elementEncoder.encode(value, using: element.schema)
            }
          }
        }
      }
    }

    struct ValueDecodingState {
      fileprivate var arrayState = JSON.ArrayDecodingState()
      fileprivate var elementDecoders: ArraySlice<ElementDecoderProtocol>
      fileprivate var isDecodingElement = false
      fileprivate var finishDecoding: (borrowing Decoder) throws -> Value
    }

    func beginDecodingValue(
      from decoder: borrowing Decoder
    ) -> ValueDecodingState {
      let elementDecoders =
        (repeat ElementDecoder(
          element: each elements,
          decoder: decoder
        ))
      var elementDecodersArray: [ElementDecoderProtocol] = []
      for elementDecoder in repeat each elementDecoders {
        if elementDecoder.isRequired {
          elementDecodersArray.append(elementDecoder)
        }
      }
      return ValueDecodingState(
        elementDecoders: elementDecodersArray[...],
        finishDecoding: { decoder in
          try (repeat (each elementDecoders).finishDecoding(from: decoder))
        }
      )
    }

    func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value> {
      while true {
        if state.isDecodingElement {
          guard let elementDecoder = state.elementDecoders.first else {
            throw Error.tooManyElements
          }
          switch try elementDecoder.decodeValue(from: &decoder).kind {
          case .incomplete:
            return .incomplete
          case .decoded:
            state.elementDecoders.removeFirst()
            state.isDecodingElement = false
            continue
          }
        }

        assert(!state.isDecodingElement)
        switch try decoder.stream.decodeArrayComponent(state: &state.arrayState) {
        case .incomplete:
          return .incomplete
        case .decoded(.elementStart):
          state.isDecodingElement = true
          continue
        case .decoded(.end):
          guard state.elementDecoders.isEmpty else {
            throw Error.tooFewElements
          }
          return try .decoded(state.finishDecoding(decoder))
        }

      }
    }

    typealias MetaSchema = WrapperSchema<
      Self,
      ConcreteObjectSchema<
        TupleObjectSchemaProperties<
          OptionalObjectProperty<StringSchema>,
          DirectObjectProperty<
            TupleSchema<repeat (each ElementSchema).MetaSchema>
          >
        >
      >
    >
    var metaSchema: MetaSchema {
      let objectSchema = ConcreteObjectSchema {
        OptionalObjectProperty(
          name: .description,
          schema: OptionalSchema(wrappedSchema: StringSchema())
        )
        DirectObjectProperty(
          name: .prefixItems,
          schema: TupleSchema<repeat (each ElementSchema).MetaSchema>(
            elements: repeat (each elements).metaElement
          )
        )
      }
      return objectSchema.wrap { (description, elementSchemas) in
        Self(
          description: description,
          elements: repeat TupleSchemaElement(
            schema: each elementSchemas,
            kind: (each elements).kind
          )
        )
      } unwrap: { schema in
        (schema.description, (repeat (each schema.elements).schema))
      }
    }

    init(
      description: String? = nil,
      elementSchemas: repeat each ElementSchema
    ) {
      self.init(
        description: description,
        elements: repeat TupleSchemaElement(
          schema: each elementSchemas,
          kind: .required
        )
      )
    }

    init(
      description: String? = nil,
      elements: repeat TupleSchemaElement<each ElementSchema>
    ) {
      self.metadata = SchemaMetadata(description: description)
      self.elements = (repeat each elements)
    }

    var metadata: SchemaMetadata
    let elements: (repeat TupleSchemaElement<each ElementSchema>)
  }

  struct TupleSchemaElement<Schema: SchemaCoding.Schema> {

    let schema: Schema

    enum Kind {
      case required
      case omitted(constantValue: Schema.Value)
    }
    let kind: Kind

    typealias MetaElement = TupleSchemaElement<Schema.MetaSchema>
    var metaElement: MetaElement {
      let metaKind: MetaElement.Kind =
        switch kind {
        case .required:
          .required
        case .omitted:
          .omitted(constantValue: schema)
        }
      return MetaElement(
        schema: schema.metaSchema,
        kind: metaKind
      )
    }
  }

}

// MARK: - Element Decoders

extension SchemaCoding.Support {

  fileprivate struct ElementDecoder<Schema: SchemaCoding.Schema>: ElementDecoderProtocol {

    init(
      element: TupleSchemaElement<Schema>,
      decoder: borrowing Decoder
    ) {
      switch element.kind {
      case .required:
        let schema = element.schema
        kind = .required(
          schema,
          decoder.arena.push(.decoding(schema.beginDecodingValue(from: decoder)))
        )
      case .omitted(let constantValue):
        kind = .omitted(constantValue: constantValue)
      }
    }

    func decodeValue(
      from decoder: inout SchemaCoding.Support.Decoder
    ) throws -> DecodingResult<Void> {
      guard case .required(let schema, let reference) = kind else {
        return .decoded(())
      }
      return try decoder.arena.withValue(reference) { state in
        switch state {
        case .decoded:
          throw Error.valueAlreadyDecoded
        case .decoding(var decodingState):
          switch try schema.decodeValue(from: &decoder, state: &decodingState).kind {
          case .incomplete:
            state = .decoding(decodingState)
            return .incomplete
          case .decoded(let value):
            state = .decoded(value)
            return .decoded
          }
        }
      }
    }

    func finishDecoding(
      from decoder: borrowing SchemaCoding.Support.Decoder
    ) throws -> Schema.Value {
      switch kind {
      case .omitted(let constantValue):
        return constantValue
      case .required(_, let reference):
        switch decoder.arena[reference] {
        case .decoded(let value):
          return value
        case .decoding:
          throw Error.partiallyDecodedValue
        }
      }
    }

    var isRequired: Bool {
      switch kind {
      case .required:
        return true
      case .omitted:
        return false
      }
    }

    private enum State {
      case decoding(Schema.ValueDecodingState)
      case decoded(Schema.Value)
    }
    private enum Kind {
      case required(Schema, Arena.Reference<State>)
      case omitted(constantValue: Schema.Value)
    }
    private let kind: Kind

  }

  fileprivate protocol ElementDecoderProtocol {
    func decodeValue(
      from decoder: inout SchemaCoding.Support.Decoder
    ) throws -> DecodingResult<Void>
  }

}

// MARK: - Errors

private enum Error: Swift.Error {
  case tooFewElements
  case tooManyElements
  case partiallyDecodedValue
  case valueAlreadyDecoded
}

private import JSONSupport
private import SchemaCodingSupport

extension SchemaCoding.Support {

  struct TupleSchema<each ElementSchema: Schema>: Schema {

    typealias Value = (repeat (each ElementSchema).Value)

    func encode(_ value: Value, to encoder: inout Encoder) {
      encoder.stream.encodeArray { arrayEncoder in
        for (schema, value) in repeat (each elementSchemas, each value) {
          arrayEncoder.encodeElement { elementEncoder in
            elementEncoder.encode(value, using: schema)
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
          schema: each elementSchemas,
          decoder: decoder
        ))
      var elementDecodersArray: [ElementDecoderProtocol] = []
      for elementDecoder in repeat each elementDecoders {
        elementDecodersArray.append(elementDecoder)
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
          RequiredObjectProperty<
            TupleSchema<repeat (each ElementSchema).MetaSchema>
          >
        >
      >
    >
    var metaSchema: MetaSchema {
      let objectSchema = ConcreteObjectSchema {
        OptionalObjectProperty(
          name: .description,
          schema: StringSchema()
        )
        RequiredObjectProperty(
          name: .prefixItems,
          schema: TupleSchema<repeat (each ElementSchema).MetaSchema>(
            elementSchemas: repeat (each elementSchemas).metaSchema
          )
        )
      }
      return objectSchema.wrap { (description, elementSchemas) in
        Self(description: description, elementSchemas: repeat each elementSchemas)
      } unwrap: { schema in
        (schema.description, (repeat each schema.elementSchemas))
      }
    }

    init(
      description: String? = nil,
      elementSchemas: repeat each ElementSchema
    ) {
      self.metadata = SchemaMetadata(description: description)
      self.elementSchemas = (repeat each elementSchemas)
    }
    var metadata: SchemaMetadata
    let elementSchemas: (repeat each ElementSchema)
  }

}

// MARK: - Element Decoders

extension SchemaCoding.Support {

  fileprivate struct ElementDecoder<Schema: SchemaCoding.Schema>: ElementDecoderProtocol {

    init(
      schema: Schema,
      decoder: borrowing Decoder
    ) {
      self.schema = schema
      self.reference = decoder.arena.push(.decoding(schema.beginDecodingValue(from: decoder)))
    }

    func decodeValue(
      from decoder: inout SchemaCoding.Support.Decoder
    ) throws -> DecodingResult<Void> {
      try decoder.arena.withValue(reference) { state in
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
      switch decoder.arena[reference] {
      case .decoded(let value):
        return value
      case .decoding:
        throw Error.partiallyDecodedValue
      }
    }

    private let schema: Schema

    private enum State {
      case decoding(Schema.ValueDecodingState)
      case decoded(Schema.Value)
    }
    private let reference: Arena.Reference<State>

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

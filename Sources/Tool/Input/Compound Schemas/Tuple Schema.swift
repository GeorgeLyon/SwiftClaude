import JSONSupport

extension ToolInput {

  // Needs to be disfavored because otherwise it catches single-element tuples
  @_disfavoredOverload
  public static func schema<each Element: ToolInput.SchemaCodable>(
    representing _: (repeat each Element).Type = (repeat each Element).self
  ) -> some Schema<(repeat each Element)> {
    TupleSchema(
      elements: (repeat (
        name: String?.none,
        schema: (each Element).toolInputSchema
      ))
    )
  }

}

// MARK: - Implementation Details

/// A schema for ordered collection of typed values
/// Also used for enum associated values
struct TupleSchema<each ElementSchema: ToolInput.Schema>: InternalSchema {

  typealias Value = (repeat (each ElementSchema).Value)

  init(
    elements: (
      repeat
        (
          name: String?,
          schema: each ElementSchema
        )
    )
  ) {
    provider = ValueDecodingStateProvider(
      elements: (repeat TupleElement(name: (each elements).name, schema: (each elements).schema))
    )
  }

  func encodeSchemaDefinition(to encoder: ToolInput.SchemaEncoder<Self>) throws {
    var container = encoder.wrapped.container(keyedBy: SchemaCodingKey.self)
    try container.encode("array", forKey: .type)

    if let description = encoder.contextualDescription(nil) {
      try container.encode(description, forKey: .description)
    }

    /// No additional items
    try container.encode(false, forKey: .items)

    var itemsCount = 0

    var prefixItems = container.nestedUnkeyedContainer(forKey: .prefixItems)
    for element in repeat each elements {
      itemsCount += 1

      try element.schema.encodeSchemaDefinition(
        to: ToolInput.SchemaEncoder(
          wrapped: prefixItems.superEncoder(),
          descriptionPrefix: element.name
        )
      )
    }

    try container.encode(itemsCount, forKey: .minItems)
  }

  func encodeSchemaDefinition(to encoder: inout ToolInput.NewSchemaEncoder<Self>) {
    let description = encoder.contextualDescription(nil)
    encoder.stream.encodeObject { encoder in
      if let description {
        encoder.encodeProperty(name: "description") { $0.encode(description) }
      }

      /// This is implied by `prefixItems`, and we're being economic with tokens.
      // encoder.encodeProperty(name: "type") { $0.encode("array") }

      encoder.encodeProperty(name: "prefixItems") { stream in
        stream.encodeArray { encoder in
          for element in repeat each elements {
            encoder.encodeElement { encoder in
              encoder.encodeSchemaDefinition(
                element.schema,
                descriptionPrefix: element.name
              )
            }
          }
        }
      }
    }
  }

  func encode(_ value: Value, to encoder: ToolInput.Encoder<Self>) throws {
    var container = encoder.wrapped.unkeyedContainer()
    repeat try (each elements).schema.encode(
      each value,
      to: ToolInput.Encoder(wrapped: container.superEncoder())
    )
  }

  func decodeValue(from decoder: ToolInput.Decoder<Self>) throws -> Value {
    var container = try decoder.wrapped.unkeyedContainer()
    return try
      (repeat (each elements).schema.decodeValue(
        from: ToolInput.Decoder(wrapped: container.superDecoder())
      ))
  }

  struct ValueDecodingState {
    fileprivate var arrayState = JSON.ArrayDecodingState()
    fileprivate var elementStates: (repeat TupleElement<each ElementSchema>.DecodingState)
    fileprivate var elementDecoders: ArraySlice<ElementDecoder>
  }

  var initialValueDecodingState: ValueDecodingState {
    ValueDecodingState(
      elementStates: (repeat (each elements).initialDecodingState),
      elementDecoders: provider.decoders[0...]
    )
  }

  func decodeValue(
    from stream: inout JSON.DecodingStream,
    state: inout ValueDecodingState
  ) throws -> JSON.DecodingResult<(repeat (each ElementSchema).Value)> {
    while true {

      switch try stream.decodeArrayComponent(&state.arrayState) {
      case .needsMoreData:
        return .needsMoreData
      case .decoded(.elementStart):
        break
      case .decoded(.end):
        func getElement<Schema>(from state: TupleElement<Schema>.DecodingState) throws
          -> Schema.Value
        {
          guard case .decoded(let element) = state else {
            assertionFailure()
            throw Error.invalidState
          }
          return element
        }
        return .decoded(try (repeat getElement(from: each state.elementStates)))
      }

      guard let decoder = state.elementDecoders.first else {
        assertionFailure()
        throw Error.invalidState
      }

      switch try decoder(&stream, &state.elementStates) {
      case .needsMoreData:
        return .needsMoreData
      case .decoded:
        state.elementDecoders.removeFirst()
        continue
      }
    }
  }

  private var elements: (repeat TupleElement<each ElementSchema>) {
    provider.elements
  }

  fileprivate typealias ElementStates = (repeat TupleElement<each ElementSchema>.DecodingState)

  fileprivate typealias ElementDecoder = @Sendable (
    inout JSON.DecodingStream,
    inout ElementStates
  ) throws -> JSON.DecodingResult<Void>

  private struct ValueDecodingStateProvider: Sendable {
    init(elements: (repeat TupleElement<each ElementSchema>)) {
      self.elements = elements

      var decoders: [ElementDecoder] = []
      var tupleArchetype =
        VariadicTupleArchetype<(repeat TupleElement<each ElementSchema>.DecodingState)>()
      for element in repeat each elements {
        let accessor = tupleArchetype.nextElementAccessor(of: element.decodingStateType)
        decoders.append { stream, states in
          try accessor.mutate(&states) { decodingState in
            while true {
              switch decodingState {
              case .decoding(var state):
                switch try element.schema.decodeValue(from: &stream, state: &state) {
                case .needsMoreData:
                  decodingState = .decoding(state)
                  return .needsMoreData
                case .decoded(let value):
                  decodingState = .decoded(value)
                  return .decoded(())
                }
              case .decoded:
                assertionFailure()
                return .decoded(())
              }
            }
          }
        }
      }
      self.decoders = decoders
    }
    let elements: (repeat TupleElement<each ElementSchema>)
    let decoders: [ElementDecoder]
  }
  private let provider: ValueDecodingStateProvider

}

private struct TupleElement<Schema: ToolInput.Schema> {
  enum DecodingState {
    case decoding(Schema.ValueDecodingState)
    case decoded(Schema.Value)
  }
  var initialDecodingState: DecodingState {
    .decoding(schema.initialValueDecodingState)
  }

  var decodingStateType: DecodingState.Type {
    DecodingState.self
  }

  let name: String?
  let schema: Schema
}

private enum SchemaCodingKey: Swift.CodingKey {
  case type
  case description
  case prefixItems
  case minItems
  case items
}

private enum Error: Swift.Error {
  case invalidState
}

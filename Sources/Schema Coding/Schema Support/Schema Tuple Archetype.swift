extension SchemaCoding.Support {

  struct SchemaTupleElementDefinition<
    Schema: SchemaCoding.Schema
  >: Sendable {

    init<Label: CodingKey>(
      label: Label?,
      schema: Schema
    ) {
      self.label = label?.stringValue
      self.schema = schema
    }

    init(
      schema: Schema
    ) {
      self.label = nil
      self.schema = schema
    }

    let label: String?
    let schema: Schema

  }

  /// Storing this type in a public type cases a runtime crash 🫠
  struct SchemaTupleArchetype<each ElementSchema: Schema>: Sendable {

    init(_ elements: repeat SchemaTupleElementDefinition<each ElementSchema>) {
      let variadicArchetype = VariadicArchetype()
      self.elements =
        (repeat Element(
          definition: (each elements),
          accessor: each variadicArchetype.elementAccessors
        ))
    }

    struct DecodingState: Sendable {
      init() {
        elementStates = (repeat SchemaTupleElementDecodingState<each ElementSchema>())
      }
      fileprivate var elementStates: (repeat SchemaTupleElementDecodingState<each ElementSchema>)
    }

    struct Element<Schema: SchemaCoding.Schema> {

      var label: String? {
        definition.label
      }

      var schema: Schema {
        definition.schema
      }

      fileprivate let definition: SchemaTupleElementDefinition<Schema>
      fileprivate let accessor:
        VariadicArchetype.ElementAccessor<SchemaTupleElementDecodingState<Schema>>

    }
    let elements: (repeat Element<each ElementSchema>)

    func decode<Schema>(
      _ element: Element<Schema>,
      from decoder: inout Decoder,
      state: inout DecodingState
    ) throws -> DecodingResult<Schema.Value> {
      try element.accessor.mutate(&state.elementStates) { elementState in
        if case .uninitialized = elementState.kind {
          elementState.kind = .decoding(element.schema.initialValueDecodingState)
        }
        switch elementState.kind {
        case .uninitialized:
          assertionFailure()
          throw Error.invalidState
        case .decoding(var state):
          switch try element.schema.decodeValue(from: &decoder, state: &state).kind {
          case .incomplete:
            elementState.kind = .decoding(state)
            return .incomplete
          case .decoded(let value):
            elementState.kind = .decoded(value)
            return .decoded(value)
          }
        case .decoded:
          throw Error.decodingTupleElementMultipleTimes(element.label)
        }
      }
    }

    func finishDecoding(
      state: DecodingState,
      allowMissingValues: Bool
    ) throws -> (repeat (each ElementSchema).Value?) {
      try
        (repeat (each state.elementStates).finishDecoding(
          as: (each elements).definition, allowMissingValues: allowMissingValues))
    }

    func finishDecoding(
      state: DecodingState
    ) throws -> (repeat (each ElementSchema).Value) {
      try (repeat (each state.elementStates).finishDecoding(as: (each elements).definition))
    }

    fileprivate typealias VariadicArchetype = VariadicTupleArchetype<
      repeat SchemaTupleElementDecodingState<each ElementSchema>
    >

  }

  /// This should be fileprivate, but for some reason making it so crashes the compiler.
  struct SchemaTupleElementDecodingState<Schema: SchemaCoding.Schema>: Sendable {
    fileprivate enum Kind {
      case uninitialized
      case decoding(Schema.ValueDecodingState)
      case decoded(Schema.Value)
    }
    fileprivate var kind: Kind = .uninitialized

    fileprivate func finishDecoding(
      as element: SchemaTupleElementDefinition<Schema>,
      allowMissingValues: Bool
    ) throws -> (Schema.Value)? {
      switch kind {
      case .uninitialized:
        if allowMissingValues {
          return nil
        } else {
          throw Error.missingRequiredValue(element.label)
        }
      case .decoding:
        assertionFailure()
        throw Error.invalidState
      case .decoded(let value):
        return value
      }
    }

    fileprivate func finishDecoding(
      as element: SchemaTupleElementDefinition<Schema>,
    ) throws -> Schema.Value {
      guard let value = try finishDecoding(as: element, allowMissingValues: false) else {
        assertionFailure()
        throw Error.missingRequiredValue(element.label)
      }
      return value
    }

  }

}

// MARK: - Errors

private enum Error: Swift.Error {
  case invalidState
  case missingRequiredValue(Sendable)
  case decodingTupleElementMultipleTimes(Sendable)
}

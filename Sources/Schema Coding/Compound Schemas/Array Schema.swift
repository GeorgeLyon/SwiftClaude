import JSONSupport

extension SchemaCoding.SchemaCodingSupport {

  public static func schema<Element: SchemaCodable>(
    representing: [Element].Type = [Element].self
  ) -> some SchemaCoding.Schema<[Element]> {
    ArraySchema(elementSchema: Element.schema)
  }

}

extension Array: SchemaCoding.SchemaCodable where Element: SchemaCoding.SchemaCodable {

  public static var schema: some SchemaCoding.Schema<Self> {
    SchemaCoding.SchemaCodingSupport.schema(representing: Self.self)
  }

}

// MARK: - Schema

private struct ArraySchema<ElementSchema: SchemaCoding.Schema>: InternalSchema {

  typealias Value = [ElementSchema.Value]

  let elementSchema: ElementSchema

  func encodeSchemaDefinition(to encoder: inout SchemaCoding.SchemaEncoder) {
    let description = encoder.contextualDescription(nil)
    encoder.stream.encodeObject { encoder in
      if let description {
        encoder.encodeProperty(name: "description") { $0.encode(description) }
      }

      /// This is implied by `items`, and we're being economic with tokens.
      // encoder.encodeProperty(name: "type") { $0.encode("array") }

      encoder.encodeProperty(name: "items") { stream in
        stream.encodeSchemaDefinition(elementSchema)
      }
    }
  }

  struct ValueDecodingState {
    var elements: Value = []
    var arrayState = JSON.ArrayDecodingState()
    var elementState: ElementSchema.ValueDecodingState?
  }

  var initialValueDecodingState: ValueDecodingState {
    ValueDecodingState()
  }

  func decodeValue(
    from decoder: inout SchemaCoding.SchemaValueDecoder,
    state: inout ValueDecodingState
  ) throws -> SchemaCoding.DecodingResult<Value> {
    while true {
      if var elementState = state.elementState {
        switch try elementSchema.decodeValue(from: &decoder, state: &elementState) {
        case .needsMoreData:
          state.elementState = elementState
          return .needsMoreData
        case .decoded(let element):
          state.elements.append(element)
          state.elementState = nil
        }
      }

      switch try decoder.stream.decodeArrayComponent(&state.arrayState) {
      case .needsMoreData:
        return .needsMoreData
      case .decoded(.elementStart):
        state.elementState = elementSchema.initialValueDecodingState
      case .decoded(.end):
        return .decoded(state.elements)
      }
    }
  }

  func encode(_ value: Value, to encoder: inout SchemaCoding.SchemaValueEncoder) {
    encoder.stream.encodeArray { encoder in
      for element in value {
        encoder.encodeElement { stream in
          stream.encode(element, using: elementSchema)
        }
      }
    }
  }

}

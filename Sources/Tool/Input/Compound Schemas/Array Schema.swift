import JSONSupport

extension ToolInput {

  public static func schema<Element: ToolInput.SchemaCodable>(
    representing: [Element].Type = [Element].self
  ) -> some ToolInput.Schema<[Element]> {
    ArraySchema(elementSchema: Element.toolInputSchema)
  }

}

extension Array: ToolInput.SchemaCodable where Element: ToolInput.SchemaCodable {

  public static var toolInputSchema: some ToolInput.Schema<Self> {
    ToolInput.schema()
  }

}

// MARK: - Schema

private struct ArraySchema<ElementSchema: ToolInput.Schema>: InternalSchema {

  typealias Value = [ElementSchema.Value]

  let elementSchema: ElementSchema

  func encodeSchemaDefinition(to encoder: inout ToolInput.SchemaEncoder) {
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
    from stream: inout JSON.DecodingStream,
    state: inout ValueDecodingState
  ) throws -> JSON.DecodingResult<Value> {
    while true {
      if var elementState = state.elementState {
        switch try elementSchema.decodeValue(from: &stream, state: &elementState) {
        case .needsMoreData:
          state.elementState = elementState
          return .needsMoreData
        case .decoded(let element):
          state.elements.append(element)
          state.elementState = nil
        }
      }

      switch try stream.decodeArrayComponent(&state.arrayState) {
      case .needsMoreData:
        return .needsMoreData
      case .decoded(.elementStart):
        state.elementState = elementSchema.initialValueDecodingState
      case .decoded(.end):
        return .decoded(state.elements)
      }
    }
  }

  func encode(_ value: Value, to stream: inout JSON.EncodingStream) {
    stream.encodeArray { encoder in
      for element in value {
        encoder.encodeElement { stream in
          elementSchema.encode(element, to: &stream)
        }
      }
    }
  }

}

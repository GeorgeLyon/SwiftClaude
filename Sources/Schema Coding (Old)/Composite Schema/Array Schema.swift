import JSONSupport

// MARK: - API

extension SchemaCoding.Support {

  public static func schema<Element: SchemaCodable>(
    representing _: [Element].Type,
    description: String? = nil
  ) -> some SchemaCoding.Schema<[Element]> {
    _ArraySchema(
      description: description,
      elementSchema: Element.schema
    )
  }

}

// MARK: - Schema Codable Conformance

extension Array: SchemaCoding.SchemaCodable where Element: SchemaCoding.SchemaCodable {

  public static var schema: SchemaCoding.Support._ArraySchema<Element.Schema> {
    SchemaCoding.Support._ArraySchema(
      description: nil,
      elementSchema: Element.schema
    )
  }

}

// MARK: - Schema

extension SchemaCoding.Support {

  public struct _ArraySchema<ElementSchema: Schema>: Schema {

    public typealias Value = [ElementSchema.Value]

    public func encode(
      _ value: Value,
      to encoder: inout Encoder
    ) {
      encoder.stream.encodeArray { arrayEncoder in
        for element in value {
          arrayEncoder.encodeElement { stream in
            stream.encode(element, using: elementSchema)
          }
        }
      }
    }

    public struct ValueDecodingState: Sendable {
      fileprivate var arrayState = JSON.ArrayDecodingState()
      fileprivate var decodedElements: [ElementSchema.Value] = []
      fileprivate var elementState: ElementSchema.ValueDecodingState
      fileprivate var isDecodingArrayComponent = true
    }

    public var initialValueDecodingState: ValueDecodingState {
      ValueDecodingState(
        elementState: elementSchema.initialValueDecodingState
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
            state.elementState = elementSchema.initialValueDecodingState
          case .decoded(.end):
            return .decoded(state.decodedElements)
          }
        } else {
          // Decode an element

          switch try elementSchema.decodeValue(from: &decoder, state: &state.elementState).kind {
          case .incomplete:
            return .incomplete
          case .decoded(let value):
            state.decodedElements.append(value)
            state.isDecodingArrayComponent = true
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
      public func metaSchema(in context: SchemaContext) -> some SchemaCoding.Schema<Self> {
        let schema = SchemaCoding.Support.objectSchema {
          SchemaCoding.Support.objectProperty(
            name: SchemaCodingKey.description,
            constantValue: context.contextualDescription(for: description)
          )
          SchemaCoding.Support.objectProperty(
            name: SchemaCodingKey.items,
            schema: elementSchema.metaSchema
          )
        }
        return schema.wrap { (wrapped: (Void?, ElementSchema)) -> Self in
          Self(description: description, elementSchema: elementSchema)
        } unwrap: { (wrapper: Self) -> (Void?, ElementSchema) in
          ((), wrapper.elementSchema)
        }
      }
    #endif

    init(
      description: String?,
      elementSchema: ElementSchema
    ) {
      self.description = description
      self.elementSchema = elementSchema
    }

    fileprivate let description: String?
    fileprivate let elementSchema: ElementSchema

  }

}

// MARK: - Coding Keys

private enum SchemaCodingKey: CodingKey {
  case description, items
}

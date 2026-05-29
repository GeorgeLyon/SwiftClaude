import JSONSupport

extension Array: SchemaCoding.SchemaCodable where Element: SchemaCoding.SchemaCodable {

  public static var schema: SchemaCoding.Support.ArraySchema<Element.Schema> {
    SchemaCoding.Support.ArraySchema(
      description: nil,
      elementSchema: Element.schema
    )
  }

}

// MARK: - Schema

extension SchemaCoding.Support {

  public struct ArraySchema<ElementSchema: Schema>: InternalSchema {

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

    public struct ValueDecodingState {
      fileprivate var arrayState = JSON.ArrayDecodingState()
      fileprivate var decodedElements: [ElementSchema.Value] = []
      fileprivate var elementState: ElementSchema.ValueDecodingState
      fileprivate var isDecodingArrayComponent = true
    }

    public func beginDecodingValue(
      from decoder: borrowing Decoder
    ) -> ValueDecodingState {
      ValueDecodingState(
        elementState: elementSchema.beginDecodingValue(from: decoder)
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
            state.elementState = elementSchema.beginDecodingValue(from: decoder)
            continue
          case .decoded(.end):
            return .decoded(state.decodedElements)
          }
        } else {
          switch try elementSchema.decodeValue(from: &decoder, state: &state.elementState).kind {
          case .incomplete:
            return .incomplete
          case .decoded(let value):
            state.decodedElements.append(value)
            state.isDecodingArrayComponent = true
            continue
          }
        }
      }
    }

    public struct MetaSchema: WrapperSchema {
      public typealias Value = ArraySchema
      var wrappedSchema: UnimplementedSchema<Never>
      static func wrap(_ wrappedValue: Never) -> Value {
      }
      static func unwrap(_ value: Value) -> Never {
        fatalError()
      }
    }
    public var metaSchema: MetaSchema {
      fatalError()
    }

    var description: String?

    fileprivate let elementSchema: ElementSchema

  }

}

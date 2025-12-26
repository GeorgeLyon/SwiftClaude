import JSONSupport

extension Array: SchemaCoding.SchemaCodable where Element: SchemaCoding.SchemaCodable {

  public static var schema: some SchemaCoding.Schema<[Element]> {
    SchemaCoding.Support.ArraySchema(
      description: nil,
      elementSchema: Element.schema
    )
  }

}

// MARK: - Schema

extension SchemaCoding.Support {

  struct ArraySchema<ElementSchema: Schema>: Schema {

    typealias Value = [ElementSchema.Value]

    func encode(
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

    struct ValueDecodingState {
      fileprivate var arrayState = JSON.ArrayDecodingState()
      fileprivate var decodedElements: [ElementSchema.Value] = []
      fileprivate var elementState: ElementSchema.ValueDecodingState
      fileprivate var isDecodingArrayComponent = true
    }

    func beginDecodingValue(
      from decoder: borrowing Decoder
    ) -> ValueDecodingState {
      ValueDecodingState(
        elementState: elementSchema.beginDecodingValue(from: decoder)
      )
    }

    func decodeValue(
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

    typealias MetaSchema = WrapperSchema<
      Self,
      ConcreteObjectSchema<
        TupleObjectSchemaProperties<
          OptionalObjectProperty<StringSchema>,
          DirectObjectProperty<ElementSchema.MetaSchema>
        >
      >
    >
    var metaSchema: MetaSchema {
      let schema = ConcreteObjectSchema {
        OptionalObjectProperty(
          name: .description,
          schema: OptionalSchema(wrappedSchema: StringSchema())
        )
        DirectObjectProperty(
          name: .items,
          schema: elementSchema.metaSchema
        )
      }
      return schema.wrap { (description, elementSchema: ElementSchema) -> Self in
        Self(description: description, elementSchema: elementSchema)
      } unwrap: { (wrapper: Self) -> (String?, ElementSchema) in
        (wrapper.description, wrapper.elementSchema)
      }
    }

    init(
      description: String? = nil,
      elementSchema: ElementSchema
    ) {
      self.metadata = SchemaMetadata(description: description)
      self.elementSchema = elementSchema
    }

    var metadata: SchemaMetadata
    fileprivate let elementSchema: ElementSchema

  }

}

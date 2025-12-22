import JSONSupport

// MARK: - API

extension SchemaCoding.Support {

  public static func schema<Element: SchemaCodable>(
    representing _: [Element].Type,
    description: String? = nil
  ) -> some SchemaCoding.Schema<[Element]> {
    ArraySchema(
      description: description,
      elementSchema: Element.schema
    )
  }

}

// MARK: - Schema Codable Conformance

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
          }
        }
      }
    }

    typealias MetaSchema = WrapperSchema<
      Self,
      ConcreteObjectSchema<
        TupleObjectSchemaProperties<
          OptionalObjectProperty<StringSchema>,
          RequiredObjectProperty<ElementSchema.MetaSchema>
        >
      >
    >
    func metaSchema(in context: SchemaContext) -> MetaSchema {
      let schema = ConcreteObjectSchema {
        OptionalObjectProperty(
          name: .description,
          schema: StringSchema()
        )
        RequiredObjectProperty(
          name: .items,
          schema: elementSchema.metaSchema(in: context)
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
      self.description = description
      self.elementSchema = elementSchema
    }

    fileprivate let description: String?
    fileprivate let elementSchema: ElementSchema

  }

}

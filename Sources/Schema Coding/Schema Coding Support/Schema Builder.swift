extension SchemaCoding.Support {

  @resultBuilder
  struct SchemaBuilder {

    static func buildBlock<Schema: SchemaCoding.Schema>(
      _ schema: Schema
    ) -> Schema {
      schema
    }

    static func buildEither<First, Second>(first component: First) -> EitherSchema<
      First, Second
    > {
      .first(component)
    }

    static func buildEither<First, Second>(second component: Second)
      -> EitherSchema<First, Second>
    {
      .second(component)
    }

  }

  enum EitherSchema<
    First: SchemaCoding.Schema,
    Second: SchemaCoding.Schema
  >: Schema where First.Value == Second.Value {
    case first(First)
    case second(Second)

    typealias Value = First.Value

    func encode(_ value: Value, to encoder: inout Encoder) {
      switch self {
      case .first(let schema):
        schema.encode(value, to: &encoder)
      case .second(let schema):
        schema.encode(value, to: &encoder)
      }
    }

    enum ValueDecodingState {
      case first(First.ValueDecodingState)
      case second(Second.ValueDecodingState)
    }

    func beginDecodingValue(from decoder: borrowing Decoder) -> ValueDecodingState {
      switch self {
      case .first(let schema):
        return .first(schema.beginDecodingValue(from: decoder))
      case .second(let schema):
        return .second(schema.beginDecodingValue(from: decoder))
      }
    }

    func decodeValue(
      from decoder: inout Decoder,
      state outerState: inout ValueDecodingState
    ) throws -> DecodingResult<Value> {
      switch (self, outerState) {
      case (.first(let schema), .first(var state)):
        defer { outerState = .first(state) }
        return try schema.decodeValue(from: &decoder, state: &state)
      case (.second(let schema), .second(var state)):
        defer { outerState = .second(state) }
        return try schema.decodeValue(from: &decoder, state: &state)
      default:
        assertionFailure()
        throw Error.invalidState
      }
    }

    @SchemaBuilder
    public func metaSchema(in context: SchemaContext) -> some SchemaCoding.Schema<Self> {
      switch self {
      case .first(let schema):
        let metaSchema = schema.metaSchema(in: context)
        metaSchema.wrap { (wrapped: First) in
          .first(wrapped)
        } unwrap: { (_: Self) in
          schema
        }
      case .second(let schema):
        let metaSchema = schema.metaSchema(in: context)
        metaSchema.wrap { (wrapped: Second) in
          .second(wrapped)
        } unwrap: { (_: Self) in
          schema
        }
      }
    }

  }

}

private enum Error: Swift.Error {
  case invalidState
}

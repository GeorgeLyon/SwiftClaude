extension SchemaCoding.Support {

  @resultBuilder
  struct SchemaBuilder {

    static func buildBlock<Schema: SchemaCoding.Schema>(
      _ schema: Schema
    ) -> Schema {
      schema
    }

    static func buildEither<First, Second>(first component: First) -> _EitherSchema<
      First, Second
    > {
      .first(component)
    }

    static func buildEither<First, Second>(second component: Second)
      -> _EitherSchema<First, Second>
    {
      .second(component)
    }

  }

  public enum _EitherSchema<
    First: SchemaCoding.Schema,
    Second: SchemaCoding.Schema
  >: Schema where First.Value == Second.Value {
    case first(First)
    case second(Second)

    public typealias Value = First.Value

    public func encode(_ value: Value, to encoder: inout Encoder) {
      switch self {
      case .first(let schema):
        schema.encode(value, to: &encoder)
      case .second(let schema):
        schema.encode(value, to: &encoder)
      }
    }

    public enum ValueDecodingState: Sendable {
      case first(First.ValueDecodingState)
      case second(Second.ValueDecodingState)
    }

    public var initialValueDecodingState: ValueDecodingState {
      switch self {
      case .first(let schema):
        return .first(schema.initialValueDecodingState)
      case .second(let schema):
        return .second(schema.initialValueDecodingState)
      }
    }

    public func decodeValue(
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

    #if ENABLE_META_SCHEMA
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
    #endif

    public var schemaMetadata: SchemaCoding.Support.SchemaMetadata {
      switch self {
      case .first(let schema):
        return schema.schemaMetadata
      case .second(let schema):
        return schema.schemaMetadata
      }
    }

  }

}

private enum Error: Swift.Error {
  case invalidState
}

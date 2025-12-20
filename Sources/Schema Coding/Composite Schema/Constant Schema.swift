// MARK: - API

extension SchemaCoding.Support {

  public static func schema<Value: SchemaCodable & Equatable & Sendable>(
    representing: Value.Type = Value.self,
    description: String? = nil,
    constantValue: Value,
  ) -> some SchemaCoding.Schema<Void> {
    ConstantSchema(
      description: description,
      wrappedSchema: Value.schema,
      constantValue: constantValue
    )
  }

}

// MARK: - Schema

extension SchemaCoding.Support {

  private struct ConstantSchema<
    WrappedSchema: SchemaCoding.Schema
  >: Schema where WrappedSchema.Value: Equatable & Sendable {

    public typealias Value = Void

    public func encode(
      _ value: Value,
      to encoder: inout Encoder
    ) {
      encoder.stream.encode(constantValue, using: wrappedSchema)
    }

    public typealias ValueDecodingState = WrappedSchema.ValueDecodingState

    public func beginDecodingValue(from decoder: borrowing Decoder) -> ValueDecodingState {
      wrappedSchema.beginDecodingValue(from: decoder)
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout WrappedSchema.ValueDecodingState
    ) throws -> DecodingResult<Value> {
      switch try wrappedSchema.decodeValue(from: &decoder, state: &state).kind {
      case .incomplete:
        return .incomplete
      case .decoded(let value):
        guard value == constantValue else {
          throw Error.constantValueMismatch(
            decoded: value,
            expected: constantValue
          )
        }
        return .decoded(())
      }
    }

    public func metaSchema(in context: SchemaContext) -> some Schema<Self> {
      TupleObjectSchema(
        description: nil,
        properties: {
          objectProperty(
            name: .description,
            schema: String?.schema
          )
          objectProperty(
            name: .const,
            schema: wrappedSchema
          )
        }
      )
      .wrap { (description, constantValue) in
        Self(
          description: description,
          wrappedSchema: wrappedSchema,
          constantValue: constantValue
        )
      } unwrap: { schema in
        (schema.description, schema.constantValue)
      }
    }

    init(
      description: String?,
      wrappedSchema: WrappedSchema,
      constantValue: WrappedSchema.Value
    ) {
      self.description = description
      self.wrappedSchema = wrappedSchema
      self.constantValue = constantValue
    }

    private let description: String?
    private let wrappedSchema: WrappedSchema
    private let constantValue: WrappedSchema.Value

  }

  private enum Error: Swift.Error {
    case constantValueMismatch(decoded: Sendable, expected: Sendable)
  }

}

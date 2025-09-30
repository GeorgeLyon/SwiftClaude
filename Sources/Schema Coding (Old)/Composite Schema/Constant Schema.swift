// MARK: - API

extension SchemaCoding.Support {

  public static func schema<Value: SchemaCodable & Equatable>(
    representing: Value.Type = Value.self,
    constantValue: Value,
  ) -> some SchemaCoding.Schema<Void> {
    _ConstantSchema(
      wrappedSchema: Value.schema,
      constantValue: constantValue
    )
  }

}

// MARK: - Schema

extension SchemaCoding.Support {

  public struct _ConstantSchema<WrappedSchema: SchemaCoding.Schema>: Schema
  where WrappedSchema.Value: Equatable {

    public typealias Value = Void

    public func encode(
      _ value: Value,
      to encoder: inout Encoder
    ) {
      encoder.stream.encode(constantValue, using: wrappedSchema)
    }

    public typealias ValueDecodingState = WrappedSchema.ValueDecodingState

    public var initialValueDecodingState: WrappedSchema.ValueDecodingState {
      wrappedSchema.initialValueDecodingState
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

    public var schemaMetadata: SchemaCoding.Support.SchemaMetadata {
      SchemaCoding.Support.SchemaMetadata(
        primitiveRepresentation: nil,
        mayAcceptNull: wrappedSchema.schemaMetadata.mayAcceptNull
      )
    }

    public typealias MetaSchema = _WrapperSchema<
      Self,
      _TupleObjectSchema<
        _ConstantSchemaCodingKey,
        _SchemaDescriptionProperty<_ConstantSchemaCodingKey>,
        _RequiredObjectProperty<
          _ConstantSchemaCodingKey,
          Self
        >
      >
    >

    public func metaSchema(in context: SchemaContext) -> MetaSchema {
      let objectSchema = objectSchema {
        objectProperty(
          name: _ConstantSchemaCodingKey.description,
          constantValue: context.contextualDescription(for: nil)
        )
        objectProperty(
          name: _ConstantSchemaCodingKey.const,
          schema: self
        )
      }
      return objectSchema.wrap { (wrapped: (Void?, Void)) in
        self
      } unwrap: { (wrapper: Self) in
        ((), ())
      }
    }

    init(
      wrappedSchema: WrappedSchema,
      constantValue: WrappedSchema.Value
    ) {
      self.wrappedSchema = wrappedSchema
      self.constantValue = constantValue
    }

    private let wrappedSchema: WrappedSchema
    private let constantValue: WrappedSchema.Value

  }

  public enum _ConstantSchemaCodingKey: CodingKey {
    case description, const
  }
}

// MARK: - Errors

private enum Error: Swift.Error {
  case constantValueMismatch(decoded: Sendable, expected: Sendable)
}

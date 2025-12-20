import JSONSupport

extension Optional: SchemaCoding.Support.SchemaCodable where Wrapped: SchemaCoding.SchemaCodable {

  public static var schema: SchemaCoding.Support.OptionalSchema<Wrapped.Schema> {
    SchemaCoding.Support.OptionalSchema(wrappedSchema: Wrapped.schema)
  }

}

extension SchemaCoding.Support {

  public struct OptionalSchema<WrappedSchema: Schema>: Schema {

    var wrappedSchema: WrappedSchema {
      effectiveSchema.properties.properties.schema
    }

    public typealias Value = WrappedSchema.Value?

    public func encode(_ value: Value, to encoder: inout Encoder) {
      effectiveSchema.encode(value, to: &encoder)
    }

    public struct ValueDecodingState {
      fileprivate var effectiveState: EffectiveSchema.ValueDecodingState
    }

    public func beginDecodingValue(
      from decoder: borrowing Decoder
    ) -> ValueDecodingState {
      ValueDecodingState(
        effectiveState: effectiveSchema.beginDecodingValue(from: decoder)
      )
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value> {
      try effectiveSchema.decodeValue(from: &decoder, state: &state.effectiveState)
    }

    public func metaSchema(in context: SchemaContext) -> some Schema<Self> {
      effectiveSchema.metaSchema(in: context).wrap { effectiveSchema in
        Self(effectiveSchema: effectiveSchema)
      } unwrap: { schema in
        schema.effectiveSchema
      }
    }

    init(
      wrappedSchema: WrappedSchema
    ) {
      effectiveSchema = TupleObjectSchema {
        OptionalObjectProperty(name: .value, schema: wrappedSchema)
      }
    }
    private init(
      effectiveSchema: EffectiveSchema
    ) {
      self.effectiveSchema = effectiveSchema
    }
    fileprivate typealias EffectiveSchema = TupleObjectSchema<
      OptionalObjectProperty<WrappedSchema>
    >
    private let effectiveSchema: EffectiveSchema

  }

}

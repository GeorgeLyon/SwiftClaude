extension SchemaCoding.Support {

  protocol WrapperSchema: Schema {

    associatedtype WrappedSchema: Schema
    where WrappedSchema.ValueDecodingState == ValueDecodingState

    init(wrappedSchema: WrappedSchema)
    var wrappedSchema: WrappedSchema { get set }

    static func wrap(_ value: WrappedSchema.Value) throws -> Value
    static func unwrap(_ value: Value) -> WrappedSchema.Value

  }

  struct WrapperMetaSchema<Value: WrapperSchema>: WrapperSchema {
    var wrappedSchema: Value.WrappedSchema.MetaSchema
    static func wrap(_ value: WrappedSchema.Value) throws -> Value {
      Value(wrappedSchema: value)
    }
    static func unwrap(_ value: Value) -> Value.WrappedSchema.MetaSchema.Value {
      value.wrappedSchema
    }
  }

}

extension SchemaCoding.Support.WrapperSchema {

  public func encode(_ value: Value, to encoder: inout SchemaCoding.Support.Encoder) {
    wrappedSchema.encode(Self.unwrap(value), to: &encoder)
  }

  public func beginDecodingValue(from decoder: borrowing SchemaCoding.Support.Decoder)
    -> WrappedSchema.ValueDecodingState
  {
    wrappedSchema.beginDecodingValue(from: decoder)
  }

  public func decodeValue(
    from decoder: inout SchemaCoding.Support.Decoder,
    state: inout ValueDecodingState
  ) throws -> SchemaCoding.Support.DecodingResult<Value> {
    try wrappedSchema
      .decodeValue(from: &decoder, state: &state)
      .map(Self.wrap)
  }

  public var metaSchema: SchemaCoding.Support.WrapperMetaSchema<Self> {
    SchemaCoding.Support.WrapperMetaSchema(wrappedSchema: wrappedSchema.metaSchema)
  }

  public var metadata: SchemaCoding.Support.SchemaMetadata {
    get { wrappedSchema.metadata }
    set { wrappedSchema.metadata = newValue }
  }

}

extension SchemaCoding.Support {

  protocol WrapperSchema: Schema {
    associatedtype WrappedSchema: Schema
    where WrappedSchema.ValueDecodingState == ValueDecodingState
    init(wrappedSchema: WrappedSchema)
    var wrappedSchema: WrappedSchema { get set }

    static func wrap(_ wrappedValue: WrappedSchema.Value) -> Value
    static func unwrap(_ value: Value) -> WrappedSchema.Value
  }

  #if ENABLE_META_SCHEMA
    struct WrapperMetaSchema<Value: WrapperSchema>: WrapperSchema {
      typealias WrappedSchema = Value.WrappedSchema.MetaSchema
      var wrappedSchema: WrappedSchema
      static func wrap(_ wrappedValue: WrappedSchema.Value) -> Value {
        Value(wrappedSchema: wrappedValue)
      }
      static func unwrap(_ value: Value) -> WrappedSchema.Value {
        value.wrappedSchema
      }
    }
  #endif

}

extension SchemaCoding.Support.WrapperSchema {

  public func encode(
    _ value: Value,
    to encoder: inout SchemaCoding.Support.Encoder
  ) {
    wrappedSchema.encode(Self.unwrap(value), to: &encoder)
  }

  public func beginDecodingValue(
    from decoder: borrowing SchemaCoding.Support.Decoder
  ) -> ValueDecodingState {
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

  public var metadata: SchemaCoding.Support.SchemaMetadata {
    get { wrappedSchema.metadata }
    set { wrappedSchema.metadata = newValue }
  }

  #if ENABLE_META_SCHEMA
    public var metaSchema: SchemaCoding.Support.WrapperMetaSchema<Self> {
      SchemaCoding.Support.WrapperMetaSchema(wrappedSchema: wrappedSchema.metaSchema)
    }
  #endif

}

extension Optional: SchemaCoding.Support.SchemaCodable where Wrapped: SchemaCoding.SchemaCodable {

  public static var schema: SchemaCoding.Support.OptionalSchema<Wrapped.Schema> {
    SchemaCoding.Support.OptionalSchema(wrapped: Wrapped.schema)
  }

}

extension SchemaCoding.Support {

  public struct OptionalSchema<Wrapped: Schema>: Schema {

    let wrapped: Wrapped

    public typealias Value = Wrapped.Value?

    public func encode(_ value: Value, to encoder: inout Encoder) {
      fatalError()
    }

    public struct ValueDecodingState {
    }

    public func beginDecodingValue(
      from decoder: borrowing Decoder
    ) -> ValueDecodingState {
      fatalError()
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value> {
      fatalError()
    }

    public func metaSchema(in context: SchemaContext) -> some Schema<Self> {
      NeverSchema<Self>()
    }

  }

  private enum NeverSchema<Value>: Schema {
    init() {
      fatalError()
    }
    func encode(_ value: Value, to encoder: inout SchemaCoding.Support.Encoder) {

    }
    struct ValueDecodingState {

    }
    func beginDecodingValue(from decoder: borrowing SchemaCoding.Support.Decoder)
      -> ValueDecodingState
    {
      switch self {

      }
    }
    func decodeValue(
      from decoder: inout SchemaCoding.Support.Decoder, state: inout ValueDecodingState
    ) throws -> SchemaCoding.Support.DecodingResult<Value> {
      switch self {

      }
    }
    func metaSchema(in context: SchemaCoding.Support.SchemaContext) -> some SchemaCoding.Support
      .Schema<Self>
    {
      NeverSchema<Self>()
    }
  }

}

extension SchemaCoding.Support {

  public struct OptionalSchema<Wrapped: Schema>: Schema {

    public typealias Value = Wrapped.Value?

    public func encode(_ value: Value, to encoder: inout Encoder) {
      fatalError()
    }

    public struct ValueDecodingState {

    }

    public var initialValueDecodingState: ValueDecodingState {
      ValueDecodingState()
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value> {
      fatalError()
    }

    let wrapped: Wrapped

  }

}

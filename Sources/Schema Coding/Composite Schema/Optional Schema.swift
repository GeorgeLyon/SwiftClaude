extension SchemaCoding.Support {

  public struct OptionalSchema<Wrapped: Schema>: Schema {

    public typealias Value = Wrapped.Value?

    public struct ValueDecodingState: Sendable {
    }

    public func beginDecodingValue(
      from decoder: inout SchemaCoding.Support.Decoder
    ) -> ValueDecodingState {
      ValueDecodingState()
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> Value {
      fatalError()
    }

    var propertySchema: OptionalPropertySchema<Wrapped> {
      OptionalPropertySchema()
    }

  }

  public struct OptionalPropertySchema<Wrapped: Schema>: Schema {

    public typealias Value = Wrapped.Value?

    public struct ValueDecodingState: Sendable {

    }

    public func beginDecodingValue(
      from decoder: inout SchemaCoding.Support.Decoder
    ) -> ValueDecodingState {
      ValueDecodingState()
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> Value {
      fatalError()
    }

  }

}

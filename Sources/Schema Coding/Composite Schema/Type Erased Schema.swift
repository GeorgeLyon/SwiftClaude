extension SchemaCoding.Schema {

  func typeErased() -> SchemaCoding.Support.TypeErasedSchema<Value> {
    SchemaCoding.Support.TypeErasedSchema(wrapped: self)
  }

}

extension SchemaCoding.Support {
  
  @_semantics("optimize.no.specialize")
  public struct TypeErasedSchema<Value>: Schema {

    public func encode(_ value: Value, to encoder: inout Encoder) {
      wrapped.encode(value, to: &encoder)
    }

    public struct ValueDecodingState {
      fileprivate var wrapped: Any
    }

    public func beginDecodingValue(from decoder: borrowing Decoder) -> ValueDecodingState {
      ValueDecodingState(wrapped: wrapped.beginDecodingValue(from: decoder))
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value> {
      try wrapped.decodeValue(from: &decoder, state: &state)
    }

    public func metaSchema(in context: SchemaContext) -> some Schema<Self> {
      wrapped.typeErasedMetaSchema(in: context).typeErased()
    }

    fileprivate init<Wrapped: SchemaCoding.Schema<Value>>(
      wrapped: Wrapped
    ) {
      self.wrapped = wrapped
    }
    fileprivate let wrapped: any Schema<Value>

  }

}

extension SchemaCoding.Schema {

  fileprivate func decodeValue(
    from decoder: inout SchemaCoding.Support.Decoder,
    state: inout SchemaCoding.Support.TypeErasedSchema<Value>.ValueDecodingState
  ) throws -> SchemaCoding.Support.DecodingResult<Value> {
    guard var typedState = state.wrapped as? ValueDecodingState else {
      assertionFailure()
      throw Error.invalidDecodingState
    }
    defer { state.wrapped = typedState }
    return try decodeValue(from: &decoder, state: &typedState)
  }

  fileprivate func typeErasedMetaSchema(
    in context: SchemaCoding.Support.SchemaContext
  ) -> some SchemaCoding.Schema<SchemaCoding.Support.TypeErasedSchema<Value>> {
    metaSchema(in: context).wrap { wrapped in
      wrapped.typeErased()
    } unwrap: { schema in
      schema.wrapped as! Self
    }
  }

}

private enum Error: Swift.Error {
  case invalidDecodingState
}

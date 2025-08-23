import JSONSupport

extension JSON.EncodingStream {

  mutating func encode<Schema: SchemaCoding.Schema>(_ value: Schema.Value, using schema: Schema) {
    var encoder = SchemaCoding.Support.Encoder(stream: self)
    schema.encode(value, to: &encoder)
    self = encoder.stream
  }

}

extension JSON.DecodingStream {

  mutating func decodeValue<Schema: SchemaCoding.Schema>(
    using schema: Schema,
    state: inout Schema.ValueDecodingState
  ) throws -> SchemaCoding.Support.DecodingResult<Schema.Value> {
    var decoder = SchemaCoding.Support.Decoder(stream: self)
    do {
      let result = try schema.decodeValue(
        from: &decoder,
        state: &state
      )
      self = decoder.stream
      return result
    } catch {
      self = decoder.stream
      throw error
    }
  }

}

extension JSON.DecodingResult where Value: Sendable {
  var schemaDecodingResult: SchemaCoding.Support.DecodingResult<Value> {
    switch self {
    case .incomplete:
      return .incomplete
    case .decoded(let value):
      return .decoded(value)
    }
  }
}

import JSONSupport

extension JSON.EncodingStream {
  mutating func encode<Schema: SchemaCoding.Schema>(_ value: Schema.Value, using schema: Schema) {
    var encoder = SchemaCoding.Support.Encoder(stream: self)
    schema.encode(value, to: &encoder)
    self = encoder.stream
  }
}

extension JSON.DecodingResult {
  var schemaDecodingResult: SchemaCoding.Support.DecodingResult<Value> {
    switch self {
    case .incomplete:
      return .incomplete
    case .decoded(let value):
      return .decoded(value)
    }
  }
}

extension JSON.ObjectEncoder {
  mutating func encodeProperty(
    name: SchemaCoding.Support.SchemaCodingKey,
    encodeValue: (inout JSON.EncodingStream) -> Void
  ) {
    self.encodeProperty(name: name.stringValue, encodeValue: encodeValue)
  }
}

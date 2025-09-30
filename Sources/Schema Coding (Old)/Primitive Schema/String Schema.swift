import JSONSupport

extension SchemaCoding.Support {

  public static func schema(
    representing: String.Type = String.self,
    description: String? = nil
  ) -> _StringSchema {
    _StringSchema(description: description)
  }

}

extension String: SchemaCoding.SchemaCodable {

  public static var schema: SchemaCoding.Support._StringSchema {
    SchemaCoding.Support._StringSchema(description: nil)
  }

}

extension SchemaCoding.Support {

  public struct _StringSchema: PrimitiveSchema {

    public typealias Value = String

    public func encode(_ value: String, to encoder: inout Encoder) {
      encoder.stream.encode(value)
    }

    public struct ValueDecodingState: Sendable {
      var stringState = JSON.StringDecodingState()
    }

    public var initialValueDecodingState: ValueDecodingState {
      ValueDecodingState()
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<String> {
      try decoder.stream.decodeString(state: &state.stringState)
        .map(String.init)
        .schemaDecodingResult
    }

    let description: String?
    let type = "string"

  }

}

private enum SchemaPropertyName: CodingKey {
  case description, type
}

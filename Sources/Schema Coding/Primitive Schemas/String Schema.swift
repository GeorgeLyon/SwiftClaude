import JSONSupport

extension String: SchemaCoding.SchemaCodable {

  public static var schema: SchemaCoding.Support.StringSchema {
    SchemaCoding.Support.StringSchema(description: nil)
  }

}

extension SchemaCoding.Support {

  public struct StringSchema: InternalSchema {

    public typealias Value = String

    public func encode(_ value: String, to encoder: inout Encoder) {
      encoder.stream.encode(value)
    }

    public struct ValueDecodingState {
      var stringState = JSON.StringDecodingState()
    }

    public func beginDecodingValue(
      from decoder: borrowing Decoder
    ) -> ValueDecodingState {
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

    var description: String?

    public struct MetaSchema: WrapperSchema {
      public typealias Value = StringSchema
      var wrappedSchema: UnimplementedSchema<Never>
      static func wrap(_ wrappedValue: Never) -> Value {
      }
      static func unwrap(_ value: Value) -> Never {
        fatalError()
      }
    }
    public var metaSchema: MetaSchema {
      fatalError()
    }

  }

}

import JSONSupport

extension SchemaCoding.Support {

  public struct NeverSchema: InternalSchema {

    public typealias Value = Never

    public func encode(_ value: Never, to encoder: inout Encoder) {

    }

    public typealias ValueDecodingState = Void

    public func beginDecodingValue(
      from decoder: borrowing Decoder
    ) -> ValueDecodingState {
      ()
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Never> {
      throw Error.neverSchemaCannotDecode
    }

    var description: String?

    public struct MetaSchema: WrapperSchema {
      public typealias Value = NeverSchema
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

private enum Error: Swift.Error {
  case neverSchemaCannotDecode
}

extension SchemaCoding.Support {

  public struct ConstantSchema<
    WrappedSchema: SchemaCoding.Schema
  >: InternalSchema where WrappedSchema.Value: Equatable {

    public typealias Value = Void

    public func encode(
      _ value: Value,
      to encoder: inout Encoder
    ) {
      encoder.stream.encode(constantValue, using: wrappedSchema)
    }

    public typealias ValueDecodingState = WrappedSchema.ValueDecodingState

    public func beginDecodingValue(from decoder: borrowing Decoder) -> ValueDecodingState {
      wrappedSchema.beginDecodingValue(from: decoder)
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout WrappedSchema.ValueDecodingState
    ) throws -> DecodingResult<Value> {
      switch try wrappedSchema.decodeValue(from: &decoder, state: &state).kind {
      case .incomplete:
        return .incomplete
      case .decoded(let value):
        guard value == constantValue else {
          throw Error.constantValueMismatch
        }
        return .decoded(())
      }
    }

    public struct MetaSchema: WrapperSchema {
      public typealias Value = ConstantSchema
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

    let wrappedSchema: WrappedSchema

    var description: String?
    let constantValue: WrappedSchema.Value

  }

  private enum Error: Swift.Error {
    case constantValueMismatch
  }

}

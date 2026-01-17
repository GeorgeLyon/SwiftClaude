import JSONSupport

extension Optional: SchemaCoding.Support.SchemaCodable where Wrapped: SchemaCoding.SchemaCodable {

  public static var schema: SchemaCoding.Support.OptionalSchema<Wrapped.Schema> {
    SchemaCoding.Support.OptionalSchema(wrappedSchema: Wrapped.schema)
  }

}

extension SchemaCoding.Support {

  public struct OptionalSchema<WrappedSchema: Schema>: InternalSchema {

    public typealias Value = WrappedSchema.Value?

    public func encode(_ value: Value, to encoder: inout Encoder) {
      encoder.stream.encodeObject { objectEncoder in
        if let value {
          objectEncoder.encodeProperty(name: .value) { stream in
            stream.encode(value, using: wrappedSchema)
          }
        }
      }
    }

    public struct ValueDecodingState {
      fileprivate var objectState = JSON.ObjectDecodingState()
      fileprivate var wrappedState: WrappedSchema.ValueDecodingState
      fileprivate var isDecodingValue = false
      fileprivate var decodedValue: WrappedSchema.Value?
    }

    public func beginDecodingValue(
      from decoder: borrowing Decoder
    ) -> ValueDecodingState {
      ValueDecodingState(
        wrappedState: wrappedSchema.beginDecodingValue(from: decoder)
      )
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value> {
      while true {
        if state.isDecodingValue {
          switch try wrappedSchema.decodeValue(from: &decoder, state: &state.wrappedState).kind {
          case .incomplete:
            return .incomplete
          case .decoded(let value):
            state.isDecodingValue = false
            state.decodedValue = value
          }
        }

        switch try decoder.stream.decodeObjectComponent(state: &state.objectState) {
        case .incomplete:
          return .incomplete
        case .decoded(.propertyValueStart(let name)):
          guard name == SchemaCodingKey.value.stringValue else {
            throw Error.unknownPropertyName(String(name))
          }
          guard state.decodedValue == nil else {
            throw Error.multipleValueProperties
          }
          state.isDecodingValue = true
        case .decoded(.end):
          return .decoded(state.decodedValue)
        }
      }
    }

    public struct MetaSchema: WrapperSchema {
      public typealias Value = OptionalSchema
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

    var description: String?
    let wrappedSchema: WrappedSchema

  }

}

// MARK: - Errors

private enum Error: Swift.Error {
  case unknownPropertyName(String)
  case multipleValueProperties
}

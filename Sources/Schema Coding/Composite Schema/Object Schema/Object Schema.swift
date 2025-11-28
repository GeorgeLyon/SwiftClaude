import JSONSupport

extension SchemaCoding.Support {

  public struct ObjectSchema<Value>: Schema {

    public init<Name: CodingKey, each PropertySchema: Schema>(
      context: inout SchemaContext,
      properties: repeat ObjectProperty<Name, each PropertySchema>,
      compose: @escaping @Sendable (repeat (each PropertySchema).Value) throws -> Value,
      decompose: @escaping @Sendable (Value) -> (repeat (each PropertySchema).Value)
    ) {

      do {
        var propertiesByName: [Substring: ObjectPropertyProtocol] = [:]
        for property in repeat each properties {
          let key = Substring(property.name)
          /// Multiple properties with the same name are not allowed.
          /// With assertions disabled, the last property takes precedence.
          assert(!propertiesByName.keys.contains(key))
          propertiesByName[key] = property
        }
        self.properties = propertiesByName
      }

      self.encode = { value, encoder in
        encoder.stream.encodeObject { encoder in
          for (value, property) in repeat (each decompose(value), each properties) {
            property.encode(value, to: &encoder)
          }
        }
      }

      self.finishDecoding = { decoder in
        try compose(repeat (each properties).finishDecoding(decoder))
      }
    }

    public func encode(
      _ value: Value,
      to encoder: inout Encoder
    ) {
      encode(value, &encoder)
    }

    public struct ValueDecodingState {
      fileprivate var objectState = JSON.ObjectDecodingState()
      fileprivate var decodingProperty: ObjectPropertyProtocol?
    }

    public var initialValueDecodingState: ValueDecodingState {
      ValueDecodingState()
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value> {
      while true {
        if let decodingProperty = state.decodingProperty {
          switch try decodingProperty.decodeValue(from: &decoder).kind {
          case .incomplete:
            return .incomplete
          case .decoded:
            break
          }
        }

        switch try decoder.stream.decodeObjectComponent(state: &state.objectState) {
        case .incomplete:
          return .incomplete
        case .decoded(.propertyValueStart(let name)):
          guard let property = properties[name] else {
            throw Error.unknownProperty(name: String(name))
          }
          state.decodingProperty = property
          continue
        case .decoded(.end):
          return try .decoded(finishDecoding(decoder))
        }

      }
    }

    private let properties: [Substring: ObjectPropertyProtocol]
    private let encode: @Sendable (Value, inout Encoder) -> Void
    private let finishDecoding: @Sendable (borrowing Decoder) throws -> Value

  }

}

// MARK: - Implementation Details

private enum MetaSchemaCodingKey: CodingKey {
  case description, properties
}

private enum Error: Swift.Error {
  case unknownProperty(name: String)
}

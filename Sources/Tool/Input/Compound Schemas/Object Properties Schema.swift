import JSONSupport

/// This schema is not instantiated directly by a user.
/// Instead it is used in the implementation of `StructSchema` and `EnumSchema`
struct ObjectPropertiesSchema<
  PropertyKey: CodingKey,
  each PropertySchema: ToolInput.Schema
>: InternalSchema {

  typealias Value = (repeat (each PropertySchema).Value)

  init(
    description: String?,
    properties: repeat ObjectPropertySchema<PropertyKey, each PropertySchema>
  ) {
    self.description = description
    self.properties = (repeat each properties)
    self.propertyDecoderProvider = PropertyDecoderProvider(
      properties: (repeat each properties)
    )
  }

  private let description: String?
  private let properties: Properties
  private let propertyDecoderProvider: PropertyDecoderProvider

  func encodeSchemaDefinition(to encoder: ToolInput.SchemaEncoder<Self>) throws {
    var container = encoder.wrapped.container(keyedBy: SchemaCodingKey.self)
    try container.encode("object", forKey: .type)

    if let description = encoder.contextualDescription(description) {
      try container.encodeIfPresent(description, forKey: .description)
    }

    /// Since properties can only be decoded if they are created ahead of time, additional properties are disallowed.
    try container.encode(false, forKey: .additionalProperties)

    fatalError()
  }

  func encodeSchemaDefinition(to encoder: inout ToolInput.NewSchemaEncoder<Self>) {
    let description = encoder.contextualDescription(description)
    encoder.stream.encodeObject { encoder in

      /// This is implied by `properties`, and we're being economic with tokens.
      // encoder.encodeProperty(name: "type") { $0.encode("object") }

      if let description {
        encoder.encodeProperty(name: "description") { $0.encode(description) }
      }

      /// We can add this if Claude begins to hallucinate additional properties.
      // encoder.encodeProperty(name: "additionalProperties") { $0.encode(false) }

      encoder.encodeSchemaDefinitionProperties(for: repeat each properties)
    }
  }

  func encode(_ value: Value, to encoder: ToolInput.Encoder<Self>) throws {
    fatalError()
  }

  func decodeValue(from decoder: ToolInput.Decoder<Self>) throws -> Value {
    let container = try decoder.wrapped.container(keyedBy: PropertyKey.self)
    return (try container.decodeProperties(repeat each properties))
  }

  struct ValueDecodingState {
    fileprivate var objectState = JSON.ObjectDecodingState()
    fileprivate var propertyStates: PropertyStates
  }

  var initialValueDecodingState: ValueDecodingState {
    ValueDecodingState(
      propertyStates: (repeat .decoding((each properties).schema.initialValueDecodingState))
    )
  }

  func decodeValue(
    from stream: inout JSON.DecodingStream,
    state: inout ValueDecodingState
  ) throws -> JSON.DecodingResult<(repeat (each PropertySchema).Value)> {
    decodeProperties: while true {
      switch try stream.decodeObjectComponent(&state.objectState) {
      case .needsMoreData:
        return .needsMoreData
      case .decoded(.end):
        break decodeProperties
      case .decoded(.propertyValueStart(let name)):
        switch try propertyDecoderProvider.decoder(for: name)(&stream, &state.propertyStates) {
        case .needsMoreData:
          return .needsMoreData
        case .decoded:
          break
        }
      }
    }

    func getPropertyValue<Schema: ToolInput.Schema>(
      name: String,
      schema: Schema,
      decodedValue: Schema.Value?
    ) throws -> Schema.Value {
      if let decodedValue {
        decodedValue
      } else if let optionalSchema = schema as? any OptionalSchemaProtocol<Schema.Value> {
        optionalSchema.valueWhenOmitted
      } else {
        throw Error.missingRequiredPropertyValue(name)
      }
    }

    return .decoded(
      (repeat try getPropertyValue(
        name: (each properties).key.stringValue,
        schema: (each properties).schema,
        decodedValue: (each state.propertyStates).decodedValue
      ))
    )
  }

  func encode(_ value: Value, to stream: inout JSON.EncodingStream) {
    stream.encodeObject { encoder in
      func encodeProperty<S: ToolInput.Schema>(
        _ property: ObjectPropertySchema<PropertyKey, S>, _ value: S.Value
      ) {
        // Check if this is an optional schema that should omit the value
        if let optionalSchema = property.schema as? any OptionalSchemaProtocol<S.Value>,
          optionalSchema.shouldOmit(value)
        {
          // Skip encoding this property
          return
        }

        encoder.encodeProperty(name: property.key.stringValue) { stream in
          property.schema.encode(value, to: &stream)
        }
      }

      repeat encodeProperty(each properties, each value)
    }
  }

  fileprivate typealias Properties = (repeat ObjectPropertySchema<PropertyKey, each PropertySchema>)
  fileprivate typealias PropertyStates = (
    repeat ObjectPropertySchema<PropertyKey, (each PropertySchema)>.DecodingState
  )
  private typealias PropertyDecoder = @Sendable (
    inout JSON.DecodingStream,
    inout PropertyStates
  ) throws -> JSON.DecodingResult<Void>

}

struct ObjectPropertySchema<PropertyKey: CodingKey, Schema: ToolInput.Schema> {
  let key: PropertyKey
  let description: String?
  let schema: Schema

  fileprivate enum DecodingState {
    case missing
    case decoding(Schema.ValueDecodingState)
    case decoded(Schema.Value)

    var decodedValue: Schema.Value? {
      if case .decoded(let value) = self {
        value
      } else {
        nil
      }
    }
  }
  fileprivate var decodingStateType: DecodingState.Type {
    DecodingState.self
  }
}

// MARK: - Decoding

extension ObjectPropertiesSchema {

  private struct PropertyDecoderProvider: Sendable {

    init(properties: Properties) {
      var decoders: [Substring: PropertyDecoder] = [:]
      var tupleArchetype = VariadicTupleArchetype<PropertyStates>()
      for property in repeat each properties {
        let accessor = tupleArchetype.nextElementAccessor(of: property.decodingStateType)
        let key = Substring(property.key.stringValue)
        let decoder: PropertyDecoder = { stream, states in
          try accessor.mutate(&states) { decodingState in
            while true {
              switch decodingState {
              case .missing:
                decodingState = .decoding(property.schema.initialValueDecodingState)
              case .decoding(var state):
                switch try property.schema.decodeValue(from: &stream, state: &state) {
                case .needsMoreData:
                  decodingState = .decoding(state)
                  return .needsMoreData
                case .decoded(let value):
                  decodingState = .decoded(value)
                  return .decoded(())
                }
              case .decoded:
                throw Error.repeatedPropertyName(property.key.stringValue)
              }
            }
          }
        }
        if decoders.updateValue(decoder, forKey: key) != nil {
          assertionFailure()
          decoders[key] = { _, _ in
            throw Error.multiplePropertiesWithSameName(property.key.stringValue)
          }
        }
      }
      self.decoders = decoders
    }

    func decoder(for propertyName: Substring) throws -> PropertyDecoder {
      guard let decoder = decoders[propertyName] else {
        /// We conservatively fail parsing on unknown properties, since Claude should be good at recovering from this type of error and Claude can become confused if it hallucinates a property that is then either dropped or silently passed through
        throw Error.unknownProperty(String(propertyName))
      }
      return decoder
    }

    private let decoders: [Substring: PropertyDecoder]

  }

}

// MARK: - Implementation Details

private enum SchemaCodingKey: Swift.CodingKey {
  case type
  case description
  case properties
  case additionalProperties
  case required
}

private enum Error: Swift.Error {
  case unknownProperty(String)
  case missingRequiredPropertyValue(String)
  case repeatedPropertyName(String)
  case multiplePropertiesWithSameName(String)
}

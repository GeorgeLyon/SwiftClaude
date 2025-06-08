import JSONSupport

protocol ObjectPropertiesSchemaProtocol<Value, ValueDecodingState>: InternalSchema {

  func encodeSchemaDefinition(
    to stream: inout SchemaCoding.SchemaEncoder,
    discriminator: Discriminator?
  )

  func decodeValue(
    from decoder: inout JSON.DecodingStream,
    state: inout ValueDecodingState,
    discriminator: Discriminator?
  ) throws -> JSON.DecodingResult<Value>

  func encode(
    _ value: Value,
    discriminator: Discriminator?,
    to encoder: inout JSON.EncodingStream
  )

}
extension ObjectPropertiesSchemaProtocol {
  typealias Discriminator = (name: String, value: String)
}

/// This schema is not instantiated directly by a user.
/// Instead it is used in the implementation of `StructSchema` and `EnumSchema`
struct ObjectPropertiesSchema<
  each PropertySchema: SchemaCoding.Schema
>: ObjectPropertiesSchemaProtocol {

  typealias Value = (repeat (each PropertySchema).Value)

  init(
    description: String?,
    properties: repeat ObjectPropertySchema<each PropertySchema>
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

  func encodeSchemaDefinition(to encoder: inout SchemaCoding.SchemaEncoder) {
    encodeSchemaDefinition(to: &encoder, discriminator: nil)
  }

  /// - Parameters:
  ///   - discriminator: If provided, this schema will encode an additional property with this specified value. This is used for internally-tagged enums
  func encodeSchemaDefinition(
    to encoder: inout SchemaCoding.SchemaEncoder,
    discriminator: Discriminator?
  ) {
    let description = encoder.contextualDescription(description)
    encoder.stream.encodeObject { encoder in

      /// This is implied by `properties`, and we're being economic with tokens.
      // encoder.encodeProperty(name: "type") { $0.encode("object") }

      if let description {
        encoder.encodeProperty(name: "description") { $0.encode(description) }
      }

      /// We can add this if Claude begins to hallucinate additional properties.
      // encoder.encodeProperty(name: "additionalProperties") { $0.encode(false) }

      var requiredProperties: [String] = []

      encoder.encodeProperty(name: "properties") { encoder in
        encoder.encodeObject { encoder in
          /// Encode discriminator if one was specified
          if let discriminator {
            requiredProperties.append(discriminator.name)
            encoder.encodeProperty(name: discriminator.name) { stream in
              stream.encodeObject { encoder in
                encoder.encodeProperty(name: "const") { stream in
                  stream.encode(discriminator.value)
                }
              }
            }
          }

          /// Encode properties
          for property in repeat each properties {
            assert(property.key.stringValue != discriminator?.name)
            if let optionalSchema = property.schema as? any OptionalSchemaProtocol {
              encoder.encodeProperty(name: property.key.stringValue) { stream in
                optionalSchema.encodeWrappedSchemaDefinition(
                  to: &stream,
                  descriptionPrefix: property.description,
                  descriptionSuffix: nil
                )
              }
            } else {
              requiredProperties.append(property.key.stringValue)
              encoder.encodeProperty(name: property.key.stringValue) { stream in
                stream.encodeSchemaDefinition(
                  property.schema,
                  descriptionPrefix: property.description,
                  descriptionSuffix: nil
                )
              }
            }
          }
        }
      }

      if !requiredProperties.isEmpty {
        /// An empty `required` array is invalid in JSONSchema
        /// https://json-schema.org/understanding-json-schema/reference/object#required
        encoder.encodeProperty(name: "required") { encoder in
          encoder.encodeArray { encoder in
            for key in requiredProperties {
              encoder.encodeElement { $0.encode(key) }
            }
          }
        }
      }

    }
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
    from decoder: inout SchemaCoding.SchemaValueDecoder,
    state: inout ValueDecodingState
  ) throws -> JSON.DecodingResult<(repeat (each PropertySchema).Value)> {
    try decodeValue(from: &decoder.stream, state: &state, discriminator: nil)
  }

  func decodeValue(
    from stream: inout JSON.DecodingStream,
    state: inout ValueDecodingState,
    discriminator: Discriminator?
  ) throws -> JSON.DecodingResult<(repeat (each PropertySchema).Value)> {
    decodeProperties: while true {
      switch try stream.decodeObjectComponent(&state.objectState) {
      case .needsMoreData:
        return .needsMoreData
      case .decoded(.end):
        break decodeProperties
      case .decoded(.propertyValueStart(let name)):
        if let discriminator, name == discriminator.name {
          switch try stream.decodeString() {
          case .needsMoreData:
            return .needsMoreData
          case .decoded(let value):
            guard value == discriminator.value else {
              throw Error.invalidDiscriminatorValue(String(value))
            }
          }
        } else {
          switch try propertyDecoderProvider.decoder(for: name)(&stream, &state.propertyStates) {
          case .needsMoreData:
            return .needsMoreData
          case .decoded:
            break
          }
        }
      }
    }

    func getPropertyValue<Schema: SchemaCoding.Schema>(
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

  func encode(
    _ value: Value,
    to encoder: inout SchemaCoding.SchemaValueEncoder
  ) {
    encode((repeat each value), discriminator: nil, to: &encoder.stream)
  }

  func encode(
    _ value: Value,
    discriminator: Discriminator?,
    to stream: inout JSON.EncodingStream
  ) {
    stream.encodeObject { objectEncoder in

      if let discriminator {
        objectEncoder.encodeProperty(name: discriminator.name) { stream in
          stream.encode(discriminator.value)
        }
      }

      func encodeProperty<S: SchemaCoding.Schema>(
        _ property: ObjectPropertySchema<S>, _ value: S.Value
      ) {
        assert(discriminator?.name != property.key.stringValue)

        if let optionalSchema = property.schema as? any OptionalSchemaProtocol<S.Value>,
          optionalSchema.shouldOmit(value)
        {
          return
        }

        objectEncoder.encodeProperty(name: property.key.stringValue) { stream in
          stream.encode(value, using: property.schema)
        }
      }
      repeat encodeProperty(each properties, each value)
    }
  }

  fileprivate typealias Properties = (repeat ObjectPropertySchema<each PropertySchema>)
  fileprivate typealias PropertyStates = (
    repeat ObjectPropertySchema<(each PropertySchema)>.DecodingState
  )
  private typealias PropertyDecoder = @Sendable (
    inout JSON.DecodingStream,
    inout PropertyStates
  ) throws -> JSON.DecodingResult<Void>

}

struct ObjectPropertySchema<Schema: SchemaCoding.Schema> {
  let key: SchemaCoding.SchemaCodingKey
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
                switch try stream.decodeValue(using: property.schema, state: &state) {
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

private enum Error: Swift.Error {
  case unknownProperty(String)
  case invalidDiscriminatorValue(String)
  case missingRequiredPropertyValue(String)
  case repeatedPropertyName(String)
  case multiplePropertiesWithSameName(String)
}

import JSONSupport

/// This schema is not instantiated directly by a user.
/// Instead it is used in the implementation of `StructSchema` and `EnumSchema`
struct ObjectPropertiesSchema<
  each PropertySchema: SchemaCoding.Schema
>: SchemaCoding.ExtendableSchema {

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
  private let propertyDecoderProvider: PropertyDecoderProvider<repeat each PropertySchema>

  func encodeSchemaDefinition<each AdditionalPropertySchema>(
    to encoder: inout SchemaCoding.SchemaEncoder,
    additionalProperties: SchemaCoding.AdditionalPropertiesSchema<
      repeat each AdditionalPropertySchema
    >
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
          /// Encode additional properties
          for property in repeat each additionalProperties.properties {
            property.encodeSchemaDefinition(to: &encoder, requiredProperties: &requiredProperties)
          }

          /// Encode properties
          for property in repeat each properties {
            property.encodeSchemaDefinition(to: &encoder, requiredProperties: &requiredProperties)
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

  func decodeValue<each AdditionalPropertySchema>(
    from decoder: inout SchemaCoding.SchemaValueDecoder,
    state: inout SchemaCoding.AdditionalPropertiesSchema<
      repeat each AdditionalPropertySchema
    >.ValueDecodingState<ValueDecodingState>,
    additionalProperties: SchemaCoding.AdditionalPropertiesSchema<
      repeat each AdditionalPropertySchema
    >
  ) throws
    -> SchemaCoding.SchemaDecodingResult<
      (
        Value,
        (repeat (each AdditionalPropertySchema).Value)
      )
    >
  {
    decodeProperties: while true {
      switch try decoder.stream.decodeObjectComponent(&state.baseState.objectState) {
      case .needsMoreData:
        return .needsMoreData
      case .decoded(.end):
        break decodeProperties
      case .decoded(.propertyValueStart(let name)):
        if let propertyDecoder = propertyDecoderProvider.decoder(for: name) {
          switch try propertyDecoder(&decoder.stream, &state.baseState.propertyStates) {
          case .needsMoreData:
            return .needsMoreData
          case .decoded:
            break
          }
        } else if let propertyDecoder = additionalProperties.decoderProvider.decoder(for: name) {
          switch try propertyDecoder(&decoder.stream, &state.propertyStates) {
          case .needsMoreData:
            return .needsMoreData
          case .decoded:
            break
          }
        } else {
          /// We conservatively fail parsing on unknown properties, since Claude should be good at recovering from this type of error and Claude can become confused if it hallucinates a property that is then either dropped or silently passed through
          throw Error.unknownProperty(String(name))
        }
      }
    }

    return try .decoded(
      (
        (repeat (each properties)
          .getFinalDecodedValue(from: (each state.baseState.propertyStates))),
        (repeat (each additionalProperties.properties).getFinalDecodedValue(
          from: (each state.propertyStates)
        ))
      )
    )
  }

  func encode<each AdditionalPropertySchema>(
    _ value: (repeat (each PropertySchema).Value),
    additionalProperties: SchemaCoding.AdditionalPropertiesSchema<
      repeat each AdditionalPropertySchema
    >,
    additionalPropertyValues: SchemaCoding.AdditionalPropertiesSchema<
      repeat each AdditionalPropertySchema
    >.Values,
    to encoder: inout SchemaCoding.SchemaValueEncoder
  ) {
    encoder.stream.encodeObject { objectEncoder in
      repeat (each additionalProperties.properties).encode(
        each additionalPropertyValues.values,
        to: &objectEncoder,
      )
      repeat (each properties).encode(each value, to: &objectEncoder)
    }
  }

  fileprivate typealias Properties = (repeat ObjectPropertySchema<each PropertySchema>)
  fileprivate typealias PropertyStates = (
    repeat ObjectPropertySchema<(each PropertySchema)>.DecodingState
  )
  private typealias PropertyDecoder = @Sendable (
    inout JSON.DecodingStream,
    inout PropertyStates
  ) throws -> SchemaCoding.SchemaDecodingResult<Void>

}

struct ObjectPropertySchema<Schema: SchemaCoding.Schema> {
  let key: SchemaCoding.SchemaCodingKey
  let description: String?
  let schema: Schema

  fileprivate enum DecodingState {
    case missing
    case decoding(Schema.ValueDecodingState)
    case decoded(Schema.Value)
  }
  fileprivate var decodingStateType: DecodingState.Type {
    DecodingState.self
  }

  fileprivate func encodeSchemaDefinition(
    to encoder: inout JSON.ObjectEncoder,
    requiredProperties: inout [String]
  ) {
    if let optionalSchema = schema as? any OptionalSchemaProtocol {
      encoder.encodeProperty(name: key.stringValue) { stream in
        optionalSchema.encodeWrappedSchemaDefinition(
          to: &stream,
          descriptionPrefix: description,
          descriptionSuffix: nil
        )
      }
    } else {
      requiredProperties.append(key.stringValue)
      encoder.encodeProperty(name: key.stringValue) { stream in
        stream.encodeSchemaDefinition(
          schema,
          descriptionPrefix: description,
          descriptionSuffix: nil
        )
      }
    }
  }

  fileprivate func encode(
    _ value: Schema.Value,
    to encoder: inout JSON.ObjectEncoder
  ) {
    if let optionalSchema = schema as? any OptionalSchemaProtocol<Schema.Value>,
      optionalSchema.shouldOmit(value)
    {
      return
    }

    encoder.encodeProperty(name: key.stringValue) { stream in
      stream.encode(value, using: schema)
    }
  }

  fileprivate func getFinalDecodedValue(
    from state: DecodingState
  ) throws -> Schema.Value {
    switch state {
    case .missing:
      if let optionalSchema = schema as? any OptionalSchemaProtocol<Schema.Value> {
        return optionalSchema.valueWhenOmitted
      } else {
        throw Error.missingRequiredPropertyValue(key.stringValue)
      }
    case .decoding:
      throw Error.incompletePropertyValue(key.stringValue)
    case .decoded(let value):
      return value
    }
  }
}

// MARK: - Additional Properties

extension SchemaCoding {

  public struct AdditionalPropertiesSchema<
    each PropertySchema: SchemaCoding.Schema
  >: Sendable {

    public struct Values {
      init(_ values: repeat (each PropertySchema).Value) {
        self.values = (repeat each values)
      }
      fileprivate let values: (repeat (each PropertySchema).Value)
    }

    public struct ValueDecodingState<BaseSchemaState> {
      var baseState: BaseSchemaState
      fileprivate var propertyStates:
        (repeat ObjectPropertySchema<(each PropertySchema)>.DecodingState)
    }

    init(
      properties: repeat ObjectPropertySchema<each PropertySchema>
    ) {
      self.properties = (repeat each properties)
      self.decoderProvider = PropertyDecoderProvider(properties: (repeat each properties))
    }

    func initialValueDecodingState<BaseSchemaState>(
      base: BaseSchemaState
    ) -> ValueDecodingState<BaseSchemaState> {
      ValueDecodingState(
        baseState: base,
        propertyStates: (repeat .decoding((each properties).schema.initialValueDecodingState))
      )
    }

    let properties: (repeat ObjectPropertySchema<each PropertySchema>)

    fileprivate let decoderProvider: PropertyDecoderProvider<repeat each PropertySchema>
  }

}

// MARK: - Implementation Details

private struct PropertyDecoderProvider<
  each PropertySchema: SchemaCoding.Schema
>: Sendable {

  typealias Properties = (repeat ObjectPropertySchema<each PropertySchema>)
  typealias PropertyStates = (
    repeat ObjectPropertySchema<(each PropertySchema)>.DecodingState
  )
  typealias PropertyDecoder = @Sendable (
    inout JSON.DecodingStream,
    inout PropertyStates
  ) throws -> SchemaCoding.SchemaDecodingResult<Void>

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

  func decoder(for propertyName: Substring) -> PropertyDecoder? {
    return decoders[propertyName]
  }

  private let decoders: [Substring: PropertyDecoder]

}

// MARK: Errors

private enum Error: Swift.Error {
  case unknownProperty(String)
  case invalidDiscriminatorValue(String)
  case incompletePropertyValue(String)
  case missingRequiredPropertyValue(String)
  case repeatedPropertyName(String)
  case multiplePropertiesWithSameName(String)
}

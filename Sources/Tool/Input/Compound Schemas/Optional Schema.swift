import JSONSupport

extension ToolInput {

  public static func schema<Wrapped: ToolInput.SchemaCodable>(
    representing: Wrapped?.Type = Wrapped?.self
  ) -> some Schema<Wrapped?> {
    OptionalSchema(
      wrappedSchema: Wrapped.toolInputSchema
    )
  }

}

extension Optional: ToolInput.SchemaCodable where Wrapped: ToolInput.SchemaCodable {

  public static var toolInputSchema: some ToolInput.Schema<Self> {
    ToolInput.schema()
  }

}

// MARK: - Internal Logic

/**
 Optionals have different representations based on whether or not they are properties of an object.
 Object properties have a special representation which **does not** accept `null`, instead requiring the property to be omitted.
 Optionals outside of objects are represented as a value that can either be `null` or the wrapped value.
 If the wrapped value is itself nullable and thr optional is not an object property, we add a wrapper struct to disambiguate between wrapping and wrapped `nil`.
 */

extension JSON.ObjectEncoder {

  mutating func encodeSchemaDefinitionProperties<
    PropertyKey: CodingKey, each PropertySchema: ToolInput.Schema
  >(
    for objectProperties: repeat ObjectPropertySchema<PropertyKey, each PropertySchema>
  ) {
    var requiredProperties: [PropertyKey] = []

    encodeProperty(name: "properties") { encoder in
      encoder.encodeObject { encoder in
        for property in repeat each objectProperties {
          if let optionalSchema = property.schema as? any OptionalSchemaProtocol {
            encoder.encodeProperty(name: property.key.stringValue) { stream in
              optionalSchema.encodeWrappedSchemaDefinition(
                to: &stream,
                descriptionPrefix: property.description,
                descriptionSuffix: nil
              )
            }
          } else {
            requiredProperties.append(property.key)
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
      encodeProperty(name: "required") { encoder in
        encoder.encodeArray { encoder in
          for key in requiredProperties {
            encoder.encodeElement { $0.encode(key.stringValue) }
          }
        }
      }
    }

  }

}

extension KeyedEncodingContainer {

  mutating func encodeSchemaDefinition<
    PropertyKey: CodingKey, each PropertySchema: ToolInput.Schema
  >(
    properties: repeat ObjectPropertySchema<PropertyKey, each PropertySchema>,
    propertiesKey: Key,
    requiredPropertiesKey: Key
  ) throws {
    var requiredProperties: [PropertyKey] = []
    var propertiesContainer = nestedContainer(keyedBy: PropertyKey.self, forKey: propertiesKey)

    for property in repeat each properties {
      let encoder = propertiesContainer.superEncoder(forKey: property.key)
      if let optionalSchema = property.schema as? any OptionalSchemaProtocol {
        try optionalSchema.encodeWrappedSchemaDefinition(
          to: encoder,
          descriptionPrefix: property.description,
          descriptionSuffix: nil
        )
      } else {
        requiredProperties.append(property.key)
        try property.schema.encodeSchemaDefinition(
          to: ToolInput.SchemaEncoder(
            wrapped: encoder,
            descriptionPrefix: property.description,
            descriptionSuffix: nil
          )
        )
      }
    }

    if !requiredProperties.isEmpty {
      /// An empty `required` array is invalid in JSONSchema
      /// https://json-schema.org/understanding-json-schema/reference/object#required
      try encode(
        /// - note: Replacing the closure with a keypath crashes the compiler
        requiredProperties.map { $0.stringValue },
        forKey: requiredPropertiesKey
      )
    }

  }

  mutating func encode<
    each PropertySchema: ToolInput.Schema
  >(
    properties: repeat ObjectPropertySchema<Key, each PropertySchema>,
    values: repeat (each PropertySchema).Value
  ) throws {
    repeat try encodeProperty(
      each values,
      forKey: (each properties).key,
      using: (each properties).schema
    )
  }

  private mutating func encodeProperty<Schema: ToolInput.Schema>(
    _ value: Schema.Value,
    forKey key: Key,
    using schema: Schema
  ) throws {
    if let propertySchema = schema as? any OptionalSchemaProtocol<Schema.Value>,
      propertySchema.shouldOmit(value)
    {
      return
    } else {
      return try schema.encode(
        value,
        to: ToolInput.Encoder(wrapped: superEncoder(forKey: key))
      )
    }
  }

}

extension KeyedDecodingContainer {

  func decodeProperties<each PropertySchema: ToolInput.Schema>(
    _ properties: repeat ObjectPropertySchema<Key, each PropertySchema>
  ) throws -> (repeat (each PropertySchema).Value) {
    return try
      (repeat (decodeProperty(forKey: (each properties).key, using: (each properties).schema)))
  }

  private func decodeProperty<Schema: ToolInput.Schema>(
    forKey key: Key,
    using schema: Schema
  ) throws -> Schema.Value {
    if let optionalSchema = schema as? any OptionalSchemaProtocol<Schema.Value>,
      !contains(key)
    {
      return optionalSchema.valueWhenOmitted
    } else {
      return try schema.decodeValue(
        from: ToolInput.Decoder(wrapped: superDecoder(forKey: key))
      )
    }
  }

}

// MARK: - Decoding Properties

extension JSON.DecodingStream {

  mutating func decodeProperties<Key, each PropertySchema>(
    _ state: inout ObjectPropertiesDecodingState<Key, repeat each PropertySchema>
  ) throws -> JSON.DecodingResult<(repeat (each PropertySchema).Value)> {
    try state.decode(&self)
  }

}

struct ObjectPropertiesDecodingStateProvider<
  Key: CodingKey,
  each PropertySchema: ToolInput.Schema
>: Sendable {
  
  init(properties: repeat ObjectPropertySchema<Key, each PropertySchema>) {
    self.properties = (repeat each properties)
    
    var decoders: [Substring: PropertyDecoder] = [:]
    var offsetCursor = 0
    for property in repeat each properties {
      let key = Substring(property.key.stringValue)
      let alignment = property.decodingStateAligment
      let offset = (offsetCursor + alignment - 1) & ~(alignment - 1)
      offsetCursor = offset
      let decoder: PropertyDecoder = { stream, states in
        try withUnsafeMutableBytes(of: &states) { buffer in
          assert(offset < buffer.count)
          let pointer = (buffer.baseAddress! + offset)
            .assumingMemoryBound(to: property.decodingStateType)
          while true {
            switch pointer.pointee {
            case .missing:
              pointer.pointee = property.initialDecodingState
            case .decoding(var state):
              switch try property.schema.decodeValue(from: &stream, state: &state) {
              case .needsMoreData:
                pointer.pointee = .decoding(state)
                return .needsMoreData
              case .decoded(let value):
                pointer.pointee = .decoded(value)
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
  
  var initialDecodingState: ObjectPropertiesDecodingState<Key, repeat each PropertySchema> {
    ObjectPropertiesDecodingState(provider: self)
  }
  
  private typealias PropertyStates = (
    repeat ObjectPropertySchema<Key, (each PropertySchema)>.DecodingState
  )
  private typealias PropertyDecoder = @Sendable (
    inout JSON.DecodingStream,
    inout PropertyStates
  ) throws -> JSON.DecodingResult<Void>
  
  let properties: (repeat ObjectPropertySchema<Key, each PropertySchema>)
  private let decoders: [Substring: PropertyDecoder]

  
}

struct ObjectPropertiesDecodingState<
  Key: CodingKey,
  each PropertySchema: ToolInput.Schema
> {

  fileprivate init(provider: ObjectPropertiesDecodingStateProvider<Key, repeat each PropertySchema>) {
    self.provider = provider
    self.states = (repeat ObjectPropertySchema<Key, (each PropertySchema)>.DecodingState.missing)
  }
  
  fileprivate let provider: ObjectPropertiesDecodingStateProvider<Key, repeat each PropertySchema>

  fileprivate mutating func decode(
    _ stream: inout JSON.DecodingStream
  ) throws -> JSON.DecodingResult<(repeat (each PropertySchema).Value)> {
    decodeProperties: while true {
      switch try stream.decodeObjectComponent(&objectState) {
      case .needsMoreData:
        return .needsMoreData
      case .decoded(.end):
        break decodeProperties
      case .decoded(.propertyValueStart(let name)):
        switch try decoders[name]?(&stream, &states) {
        case .none:
          objectState.ignorePropertyValue()
        case .decoded:
          break
        case .needsMoreData:
          return .needsMoreData
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
        throw Error.missingPropertyValue(name)
      }
    }

    return .decoded(
      (repeat try getPropertyValue(
        name: (each provider.properties).key.stringValue,
        schema: (each provider.properties).schema,
        decodedValue: (each states).decodedValue
      ))
    )
  }

  private typealias PropertyStates = (
    repeat ObjectPropertySchema<Key, (each PropertySchema)>.DecodingState
  )
  private var objectState = JSON.ObjectDecodingState()
  private var states: PropertyStates
}

// MARK: - Implementation Details

extension ObjectPropertySchema {
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
  fileprivate var initialDecodingState: DecodingState {
    .decoding(schema.initialValueDecodingState)
  }
  fileprivate var decodingStateAligment: Int {
    MemoryLayout<DecodingState>.alignment
  }
  fileprivate var decodingStateType: DecodingState.Type {
    DecodingState.self
  }
}

private protocol OptionalSchemaProtocol<Value>: InternalSchema {

  var valueWhenOmitted: Value { get }

  func shouldOmit(_ value: Value) -> Bool

  func encodeWrappedSchemaDefinition(
    to encoder: Swift.Encoder,
    descriptionPrefix: String?,
    descriptionSuffix: String?
  ) throws

  func encodeWrappedSchemaDefinition(
    to stream: inout JSON.EncodingStream,
    descriptionPrefix: String?,
    descriptionSuffix: String?
  )

}

private struct OptionalSchema<WrappedSchema: ToolInput.Schema>: OptionalSchemaProtocol {

  let wrappedSchema: WrappedSchema

  typealias Value = WrappedSchema.Value?

  func encodeSchemaDefinition(to encoder: ToolInput.SchemaEncoder<Self>) throws {
    var container = encoder.wrapped.container(keyedBy: SchemaCodingKey.self)

    if let description = encoder.contextualDescription(nil) {
      try container.encode(description, forKey: .description)
    }

    if let leafType = (wrappedSchema as? any LeafSchema)?.type {
      try container.encode(["null", leafType], forKey: .type)
    } else {
      var container = container.nestedUnkeyedContainer(forKey: .oneOf)

      /// Encode `"null"`
      do {
        var container = container.nestedContainer(keyedBy: SchemaCodingKey.self)
        try container.encode("null", forKey: .type)
      }

      /// Encode wrapped schema
      do {
        if wrappedSchema.mayAcceptNullValue {
          /// If the wrapped schema may accept a null value, we use a non-nullable wrappper object to encode it.
          var container = container.nestedContainer(keyedBy: SchemaCodingKey.self)
          try container.encode("object", forKey: .type)
          var properties = container.nestedContainer(
            keyedBy: NonNullableWrapperCodingKey.self,
            forKey: .properties
          )
          try wrappedSchema.encodeSchemaDefinition(
            to: ToolInput.SchemaEncoder(
              wrapped: properties.superEncoder(forKey: .value)
            )
          )
        } else {
          /// If the wrapped schema does not accept a null value, we can encode it directly
          try wrappedSchema.encodeSchemaDefinition(
            to: ToolInput.SchemaEncoder(
              wrapped: container.superEncoder()
            )
          )
        }
      }
    }
  }

  func encodeSchemaDefinition(to encoder: inout ToolInput.NewSchemaEncoder<Self>) {
    let description = encoder.contextualDescription(nil)
    encoder.stream.encodeObject { encoder in
      if let description {
        encoder.encodeProperty(name: "description") { $0.encode(description) }
      }

      if let leafType = (wrappedSchema as? any LeafSchema)?.type {
        encoder.encodeProperty(name: "type") { encoder in
          encoder.encodeArray { encoder in
            encoder.encodeElement { $0.encode("null") }
            encoder.encodeElement { $0.encode(leafType) }
          }
        }
      } else {
        encoder.encodeProperty(name: "oneOf") { encoder in
          encoder.encodeArray { encoder in
            /// Encode `"null"`
            encoder.encodeElement { encoder in
              encoder.encodeObject { encoder in
                encoder.encodeProperty(name: "type") { $0.encode("null") }
              }
            }

            /// Encode wrapped schema
            encoder.encodeElement { stream in
              if wrappedSchema.mayAcceptNullValue {
                /// If the wrapped schema may accept a null value, we use a non-nullable wrappper object to encode it.
                stream.encodeObject { encoder in
                  /// This is implied by `properties`
                  // encoder.encodeProperty(name: "type") { $0.encode("object") }
                  encoder.encodeProperty(name: "properties") { encoder in
                    encoder.encodeObject { encoder in
                      encoder.encodeProperty(name: "value") { stream in
                        stream.encodeSchemaDefinition(wrappedSchema)
                      }
                    }
                  }
                }
              } else {
                /// If the wrapped schema does not accept null, we can encode it directly
                stream.encodeSchemaDefinition(wrappedSchema)
              }
            }
          }
        }
      }
    }

  }

  private enum SchemaCodingKey: Swift.CodingKey {
    case oneOf
    case description
    case type
    case properties
  }

  func encode(_ value: Value, to encoder: ToolInput.Encoder<Self>) throws {
    if wrappedSchema.mayAcceptNullValue {
      /// We use a non-nullable wrapper to encode the value
      var container = encoder.wrapped.container(keyedBy: NonNullableWrapperCodingKey.self)
      if let value {
        try wrappedSchema.encode(
          value,
          to: ToolInput.Encoder(
            wrapped: container.superEncoder(forKey: .value)
          )
        )
      } else {
        /// Omit the `value` property; `null` is not a valid value for the wrapper.
      }
    } else if let value {
      /// The value is encoded in place
      try wrappedSchema.encode(
        value,
        to: ToolInput.Encoder(
          wrapped: encoder.wrapped
        )
      )
    } else {
      var container = encoder.wrapped.singleValueContainer()
      try container.encodeNil()
    }
  }

  func decodeValue(from decoder: ToolInput.Decoder<Self>) throws -> Value {
    if wrappedSchema.mayAcceptNullValue {
      /// We expect the value to be encoded in a non-nullable wrapper
      let container = try decoder.wrapped.container(keyedBy: NonNullableWrapperCodingKey.self)
      if container.contains(.value) {
        return try wrappedSchema.decodeValue(
          from: ToolInput.Decoder(
            wrapped: container.superDecoder(forKey: .value)
          )
        )
      } else {
        return nil
      }
    } else {
      /// The value (or "null") is encoded in-place
      let container = try decoder.wrapped.singleValueContainer()
      if container.decodeNil() {
        return nil
      } else {
        return try wrappedSchema.decodeValue(
          from: ToolInput.Decoder(
            wrapped: decoder.wrapped
          )
        )
      }
    }
  }

  enum ValueDecodingState {
    case decodingNonNullableWrapperPrologue(JSON.ObjectDecodingState)
    case decodingValue(WrappedSchema.ValueDecodingState, JSON.ObjectDecodingState?)
    case decodingNonNullableWrapperEpilogue(Value, JSON.ObjectDecodingState)
  }
  var initialValueDecodingState: ValueDecodingState {
    if wrappedSchema.mayAcceptNullValue {
      /// We are using the non-nullable wrapper
      .decodingNonNullableWrapperPrologue(JSON.ObjectDecodingState())
    } else {
      .decodingValue(wrappedSchema.initialValueDecodingState, nil)
    }
  }

  func decodeValue(
    from stream: inout JSON.DecodingStream,
    state: inout ValueDecodingState
  ) throws -> JSON.DecodingResult<WrappedSchema.Value?> {
    while true {
      switch state {
      case .decodingNonNullableWrapperPrologue(var objectState):
        let header = try stream.decodeObjectPropertyHeader(&objectState)
        switch header {
        case .needsMoreData:
          state = .decodingNonNullableWrapperPrologue(objectState)
          return .needsMoreData
        case .decoded(let property?):
          if property.name == "value" {
            state = .decodingValue(wrappedSchema.initialValueDecodingState, objectState)
          } else {
            /// Ignore properties
            objectState.ignorePropertyValue()
            state = .decodingNonNullableWrapperPrologue(objectState)
          }
        case .decoded(.none):
          return .decoded(nil)
        }
      case .decodingValue(var valueState, let objectState):
        switch try wrappedSchema.decodeValue(from: &stream, state: &valueState) {
        case .needsMoreData:
          state = .decodingValue(valueState, objectState)
          return .needsMoreData
        case .decoded(let value):
          if let objectState {
            state = .decodingNonNullableWrapperEpilogue(value, objectState)
          } else {
            return .decoded(value)
          }
        }
      case .decodingNonNullableWrapperEpilogue(let value, var objectState):
        switch try stream.decodeObjectUntilComplete(&objectState) {
        case .needsMoreData:
          return .needsMoreData
        case .decoded(()):
          return .decoded(value)
        }
      }
    }
  }

  var valueWhenOmitted: Value { nil }

  func shouldOmit(_ value: Value) -> Bool {
    value == nil
  }

  func encodeWrappedSchemaDefinition(
    to encoder: Swift.Encoder,
    descriptionPrefix: String?,
    descriptionSuffix: String?
  ) throws {
    try wrappedSchema.encodeSchemaDefinition(
      to: ToolInput.SchemaEncoder<WrappedSchema>(
        wrapped: encoder,
        descriptionPrefix: descriptionPrefix,
        descriptionSuffix: descriptionSuffix
      )
    )
  }

  func encodeWrappedSchemaDefinition(
    to stream: inout JSON.EncodingStream,
    descriptionPrefix: String?,
    descriptionSuffix: String?
  ) {
    stream.encodeSchemaDefinition(
      wrappedSchema,
      descriptionPrefix: descriptionPrefix,
      descriptionSuffix: descriptionSuffix
    )
  }

  var mayAcceptNullValue: Bool {
    true
  }

  private enum NonNullableWrapperCodingKey: Swift.CodingKey {
    case value
  }

}

private enum Error: Swift.Error {
  case missingPropertyValue(String)
  case repeatedPropertyName(String)
  case multiplePropertiesWithSameName(String)
}

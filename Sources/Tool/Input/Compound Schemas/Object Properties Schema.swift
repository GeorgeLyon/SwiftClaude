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
    self.stateProvider = ObjectPropertiesDecodingStateProvider(
      properties: repeat each properties
    )
  }

  fileprivate let description: String?

  fileprivate typealias Properties = (repeat ObjectPropertySchema<PropertyKey, each PropertySchema>)
  fileprivate var properties: Properties {
    stateProvider.properties
  }
  fileprivate let stateProvider:
    ObjectPropertiesDecodingStateProvider<PropertyKey, repeat each PropertySchema>

  func encodeSchemaDefinition(to encoder: ToolInput.SchemaEncoder<Self>) throws {
    var container = encoder.wrapped.container(keyedBy: SchemaCodingKey.self)
    try container.encode("object", forKey: .type)

    if let description = encoder.contextualDescription(description) {
      try container.encodeIfPresent(description, forKey: .description)
    }

    /// Since properties can only be decoded if they are created ahead of time, additional properties are disallowed.
    try container.encode(false, forKey: .additionalProperties)

    try container.encodeSchemaDefinition(
      properties: repeat each properties,
      propertiesKey: .properties,
      requiredPropertiesKey: .required
    )
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
    var container = encoder.wrapped.container(keyedBy: PropertyKey.self)
    try container.encode(
      properties: repeat each properties,
      values: repeat each value
    )
  }

  func decodeValue(from decoder: ToolInput.Decoder<Self>) throws -> Value {
    let container = try decoder.wrapped.container(keyedBy: PropertyKey.self)
    return (try container.decodeProperties(repeat each properties))
  }

  typealias ValueDecodingState = ObjectPropertiesDecodingState<
    PropertyKey, repeat each PropertySchema
  >

  /// By making this a stored property, we cache the creation of the property decoder dictionary
  var initialValueDecodingState: ValueDecodingState {
    stateProvider.initialDecodingState
  }

  func decodeValue(
    from stream: inout JSON.DecodingStream,
    state: inout ValueDecodingState
  ) throws -> JSON.DecodingResult<(repeat (each PropertySchema).Value)> {
    try stream.decodeProperties(&state)
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

}

struct ObjectPropertySchema<PropertyKey: CodingKey, Schema: ToolInput.Schema> {
  let key: PropertyKey
  let description: String?
  let schema: Schema
}

private enum SchemaCodingKey: Swift.CodingKey {
  case type
  case description
  case properties
  case additionalProperties
  case required
}

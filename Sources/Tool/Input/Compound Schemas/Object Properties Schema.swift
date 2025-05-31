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
  }

  fileprivate let description: String?

  fileprivate typealias Properties = (repeat ObjectPropertySchema<PropertyKey, each PropertySchema>)
  fileprivate let properties: Properties

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
      encoder.encodeProperty(name: "type") { $0.encode("object") }

      if let description {
        encoder.encodeProperty(name: "description") { $0.encode(description) }
      }

      encoder.encodeProperty(name: "additionalProperties") { $0.encode(false) }

      encoder.encodeProperty(name: "properties") { stream in
        stream.encodeSchemaDefinition(properties: repeat each properties)
      }
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

extension ToolInput {

  public static func structSchema<
    Value,
    PropertyKey: CodingKey,
    each PropertySchema: Schema
  >(
    representing _: Value.Type,
    description: String?,
    keyedBy _: PropertyKey.Type,
    properties: (
      repeat (
        description: String?,
        keyPath: KeyPath<Value, (each PropertySchema).Value> & Sendable,
        key: PropertyKey,
        schema: (each PropertySchema)
      )
    ),
    initializer: @escaping @Sendable (
      StructSchemaDecoder<repeat (each PropertySchema).Value>
    ) -> Value
  ) -> some Schema<Value> {
    StructSchema(
      keyPaths: (repeat (each properties).keyPath),
      propertiesSchema: ObjectPropertiesSchema(
        description: description,
        properties: repeat ObjectPropertySchema(
          key: (each properties).key,
          description: (each properties).description,
          schema: (each properties).schema
        )
      ),
      initializer: initializer
    )
  }

  public struct StructSchemaDecoder<each PropertyValue> {
    public let propertyValues: (repeat each PropertyValue)

    fileprivate init(
      propertyValues: (repeat each PropertyValue)
    ) {
      self.propertyValues = propertyValues
    }
  }

}

// MARK: - Implementation Details

private struct StructSchema<
  Value,
  PropertyKey: CodingKey,
  each PropertySchema: ToolInput.Schema
>: ToolInput.Schema {

  let keyPaths: (repeat KeyPath<Value, (each PropertySchema).Value> & Sendable)

  typealias PropertiesSchema = ObjectPropertiesSchema<PropertyKey, repeat each PropertySchema>
  let propertiesSchema: PropertiesSchema

  let initializer:
    @Sendable (
      ToolInput.StructSchemaDecoder<repeat (each PropertySchema).Value>
    ) -> Value

  func encodeSchemaDefinition(to encoder: ToolInput.SchemaEncoder<Self>) throws {
    try propertiesSchema.encodeSchemaDefinition(to: encoder.map())
  }

  func encode(_ value: Value, to encoder: ToolInput.Encoder<Self>) throws {
    try propertiesSchema.encode(
      (repeat value[keyPath: each keyPaths]),
      to: ToolInput.Encoder(wrapped: encoder.wrapped)
    )
  }

  func decodeValue(from decoder: ToolInput.Decoder<Self>) throws -> Value {
    let properties =
      try propertiesSchema
      .decodeValue(from: ToolInput.Decoder(wrapped: decoder.wrapped))
    return initializer(
      ToolInput.StructSchemaDecoder(
        propertyValues: (repeat each properties)
      )
    )
  }

}

import JSONSupport

extension SchemaProvider {

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
        )),
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
  each PropertySchema: Schema
>: Schema {

  let keyPaths: (repeat KeyPath<Value, (each PropertySchema).Value> & Sendable)

  typealias PropertiesSchema = ObjectPropertiesSchema<PropertyKey, repeat each PropertySchema>
  let propertiesSchema: PropertiesSchema

  let initializer:
    @Sendable (
      SchemaProvider.StructSchemaDecoder<repeat (each PropertySchema).Value>
    ) -> Value

  func encodeSchemaDefinition(to encoder: inout SchemaEncoder) {
    propertiesSchema.encodeSchemaDefinition(to: &encoder)
  }

  typealias ValueDecodingState = PropertiesSchema.ValueDecodingState

  var initialValueDecodingState: ValueDecodingState {
    propertiesSchema.initialValueDecodingState
  }

  func decodeValue(
    from stream: inout JSON.DecodingStream,
    state: inout ValueDecodingState
  ) throws -> JSON.DecodingResult<Value> {
    try propertiesSchema
      .decodeValue(from: &stream, state: &state)
      .map { values in
        initializer(
          SchemaProvider.StructSchemaDecoder(
            propertyValues: (repeat each values)
          )
        )
      }
  }

  func encode(_ value: Value, to stream: inout JSON.EncodingStream) {
    propertiesSchema.encode(
      (repeat value[keyPath: each keyPaths]),
      to: &stream
    )
  }

}

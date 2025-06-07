import JSONSupport

extension SchemaCoding {

  public struct StructSchemaDecoder<each PropertyValue> {

    public let propertyValues: (repeat each PropertyValue)

    fileprivate init(
      propertyValues: (repeat each PropertyValue)
    ) {
      self.propertyValues = propertyValues
    }
  }

}

extension SchemaCoding.SchemaResolver {

  public static func structSchema<
    Value,
    each PropertySchema: SchemaCoding.Schema
  >(
    representing _: Value.Type,
    description: String?,
    properties: (
      repeat (
        description: String?,
        keyPath: KeyPath<Value, (each PropertySchema).Value> & Sendable,
        key: SchemaCoding.SchemaCodingKey,
        schema: (each PropertySchema)
      )
    ),
    initializer: @escaping @Sendable (
      SchemaCoding.StructSchemaDecoder<repeat (each PropertySchema).Value>
    ) -> Value
  ) -> some SchemaCoding.Schema<Value> {
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

}

// MARK: - Implementation Details

private struct StructSchema<
  Value,
  each PropertySchema: SchemaCoding.Schema
>: SchemaCoding.Schema {

  let keyPaths: (repeat KeyPath<Value, (each PropertySchema).Value> & Sendable)

  typealias PropertiesSchema = ObjectPropertiesSchema<repeat each PropertySchema>
  let propertiesSchema: PropertiesSchema

  let initializer:
    @Sendable (
      SchemaCoding.StructSchemaDecoder<repeat (each PropertySchema).Value>
    ) -> Value

  func encodeSchemaDefinition(to encoder: inout SchemaCoding.SchemaEncoder) {
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
          SchemaCoding.StructSchemaDecoder(
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

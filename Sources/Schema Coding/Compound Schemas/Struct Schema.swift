import JSONSupport

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
  ) -> some SchemaCoding.ExtendableSchema<Value> {
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

// MARK: - Implementation Details

private struct StructSchema<
  Value,
  each PropertySchema: SchemaCoding.Schema
>: SchemaCoding.ExtendableSchema {

  let keyPaths: (repeat KeyPath<Value, (each PropertySchema).Value> & Sendable)

  typealias PropertiesSchema = ObjectPropertiesSchema<repeat each PropertySchema>
  let propertiesSchema: PropertiesSchema

  let initializer:
    @Sendable (
      SchemaCoding.StructSchemaDecoder<repeat (each PropertySchema).Value>
    ) -> Value

  func encodeSchemaDefinition<each AdditionalPropertySchema>(
    to encoder: inout SchemaCoding.SchemaEncoder,
    additionalProperties: SchemaCoding.AdditionalPropertiesSchema<
      repeat each AdditionalPropertySchema
    >
  ) {
    propertiesSchema.encodeSchemaDefinition(
      to: &encoder,
      additionalProperties: additionalProperties
    )
  }

  func encode<each AdditionalPropertySchema>(
    _ value: Value,
    additionalProperties: SchemaCoding.AdditionalPropertiesSchema<
      repeat each AdditionalPropertySchema
    >,
    additionalPropertyValues: SchemaCoding.AdditionalPropertiesSchema<
      repeat each AdditionalPropertySchema
    >.Values,
    to encoder: inout SchemaCoding.SchemaValueEncoder
  ) {
    propertiesSchema.encode(
      (repeat value[keyPath: each keyPaths]),
      additionalProperties: additionalProperties,
      additionalPropertyValues: additionalPropertyValues,
      to: &encoder)
  }

  var initialValueDecodingState: PropertiesSchema.ValueDecodingState {
    propertiesSchema.initialValueDecodingState
  }

  func decodeValue<each AdditionalPropertySchema>(
    from decoder: inout SchemaCoding.SchemaValueDecoder,
    state: inout SchemaCoding.AdditionalPropertiesSchema<
      repeat each AdditionalPropertySchema
    >.ValueDecodingState<PropertiesSchema.ValueDecodingState>,
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
    let result =
      try propertiesSchema
      .decodeValue(
        from: &decoder,
        state: &state,
        additionalProperties: additionalProperties
      )
    switch result {
    case .needsMoreData:
      return .needsMoreData
    case .decoded(let pair):
      return .decoded(
        (
          initializer(
            SchemaCoding.StructSchemaDecoder(
              propertyValues: (repeat each pair.0)
            )
          ),
          (repeat each pair.1)
        )
      )
    }
  }

}

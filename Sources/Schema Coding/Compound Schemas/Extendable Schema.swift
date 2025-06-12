import JSONSupport

extension SchemaCoding {
  public typealias ExtendableSchema = SchemaCodingSupport.ExtendableSchema
}

extension SchemaCoding.SchemaCodingSupport {

  public protocol ExtendableSchema<Value>: SchemaCoding.Schema {

    func encodeSchemaDefinition<each AdditionalPropertySchema>(
      to encoder: inout SchemaCoding.SchemaEncoder,
      additionalProperties: AdditionalPropertiesSchema<
        repeat each AdditionalPropertySchema
      >
    )

    func decodeValue<each AdditionalPropertySchema>(
      from decoder: inout SchemaValueDecoder,
      state: inout AdditionalPropertiesSchema<
        repeat each AdditionalPropertySchema
      >.ValueDecodingState<ValueDecodingState>,
      additionalProperties: AdditionalPropertiesSchema<
        repeat each AdditionalPropertySchema
      >
    ) throws -> DecodingResult<(Value, (repeat (each AdditionalPropertySchema).Value))>

    func encode<each AdditionalPropertySchema>(
      _ value: Value,
      additionalProperties: AdditionalPropertiesSchema<
        repeat each AdditionalPropertySchema
      >,
      additionalPropertyValues: AdditionalPropertiesSchema<
        repeat each AdditionalPropertySchema
      >.Values,
      to encoder: inout SchemaValueEncoder
    )

  }

}

extension SchemaCoding.ExtendableSchema {

  public func encodeSchemaDefinition(to encoder: inout SchemaCoding.SchemaEncoder) {
    encodeSchemaDefinition(
      to: &encoder,
      additionalProperties: SchemaCoding.AdditionalPropertiesSchema()
    )
  }

  public func encode(
    _ value: Value,
    to encoder: inout SchemaCoding.SchemaValueEncoder
  ) {
    encode(
      value,
      additionalProperties: SchemaCoding.AdditionalPropertiesSchema(),
      additionalPropertyValues: SchemaCoding.AdditionalPropertiesSchema.Values(),
      to: &encoder
    )
  }

  public func decodeValue(
    from decoder: inout SchemaCoding.SchemaValueDecoder,
    state: inout ValueDecodingState
  ) throws -> SchemaCoding.DecodingResult<Value> {
    let additionalProperties = SchemaCoding.AdditionalPropertiesSchema()
    /// This gets re-created every time, but that is OK since we're not actually decoding any additional properties and thus do not need to maintain state for them.
    var additionalPropertyState =
      additionalProperties
      .initialValueDecodingState(
        base: state
      )
    defer { state = additionalPropertyState.baseState }
    let result = try decodeValue(
      from: &decoder,
      state: &additionalPropertyState,
      additionalProperties: additionalProperties
    )
    switch result {
    case .needsMoreData:
      return .needsMoreData
    case .decoded(let value):
      return .decoded(value.0)
    }
  }

}

// MARK: - Extended Schema

struct ExtendedSchema<
  BaseSchema: SchemaCoding.ExtendableSchema,
  each PropertySchema: SchemaCoding.Schema
>: SchemaCoding.Schema {

  typealias Value = (BaseSchema.Value, (repeat (each PropertySchema).Value))
  typealias AdditionalProperties = SchemaCoding.AdditionalPropertiesSchema<
    repeat each PropertySchema
  >

  let baseSchema: BaseSchema
  let additionalProperties: AdditionalProperties

  func encodeSchemaDefinition(to encoder: inout SchemaCoding.SchemaEncoder) {
    baseSchema.encodeSchemaDefinition(
      to: &encoder,
      additionalProperties: additionalProperties
    )
  }

  func encode(_ value: Value, to encoder: inout SchemaCoding.SchemaValueEncoder) {
    baseSchema.encode(
      value.0,
      additionalProperties: additionalProperties,
      additionalPropertyValues: .init(repeat each value.1),
      to: &encoder
    )
  }

  typealias ValueDecodingState =
    AdditionalProperties.ValueDecodingState<BaseSchema.ValueDecodingState>

  var initialValueDecodingState: ValueDecodingState {
    additionalProperties.initialValueDecodingState(
      base: baseSchema.initialValueDecodingState
    )
  }

  func decodeValue(
    from decoder: inout SchemaCoding.SchemaCodingSupport.SchemaValueDecoder,
    state: inout ValueDecodingState
  ) throws
    -> SchemaCoding.SchemaCodingSupport.DecodingResult<
      (BaseSchema.Value, (repeat (each PropertySchema).Value))
    >
  {
    try baseSchema.decodeValue(
      from: &decoder,
      state: &state,
      additionalProperties: additionalProperties
    )
  }

}

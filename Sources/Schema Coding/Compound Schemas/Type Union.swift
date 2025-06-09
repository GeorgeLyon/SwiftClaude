import JSONSupport

// MARK: - Case Encoding

extension SchemaCoding {

  public struct TypeUnionCaseEncoder {
    fileprivate let implementation: TypeUnionCaseEncoderImplementationProtocol
  }

  public struct TypeUnionUnhandledCaseSchema<Value>: SchemaCoding.Schema {
    public func encodeSchemaDefinition(to encoder: inout SchemaCoding.SchemaEncoder) {
      /// This should be unreachable, because it is not called
      fatalError()
    }
    public func encode(_ value: Value, to encoder: inout SchemaCoding.SchemaValueEncoder) {
      fatalError()
    }
    public func decodeValue(
      from stream: inout SchemaCoding.SchemaValueDecoder,
      state: inout ()
    ) throws -> SchemaCoding.SchemaDecodingResult<Value> {
      fatalError()
    }
  }

  fileprivate protocol TypeUnionCaseEncoderImplementationProtocol {
    func encode(to encoder: inout JSON.EncodingStream)
  }

  fileprivate struct TypeUnionCaseEncoderImplementation<
    Schema: SchemaCoding.Schema
  >: TypeUnionCaseEncoderImplementationProtocol {
    func encode(to stream: inout JSON.EncodingStream) {
      stream.encode(value, using: schema)
    }
    let schema: Schema
    let value: Schema.Value
  }

}

private struct TypeUnionSchema<
  Value,
  NullSchema: SchemaCoding.Schema,
  BoolSchema: SchemaCoding.Schema,
  NumberSchema: SchemaCoding.Schema,
  StringSchema: SchemaCoding.Schema,
  ArraySchema: SchemaCoding.Schema,
  ObjectSchema: SchemaCoding.Schema
>: SchemaCoding.Schema {

  let description: String?

  let nullCase: TypeUnionSchemaCase<Value, NullSchema>
  let boolCase: TypeUnionSchemaCase<Value, BoolSchema>
  let numberCase: TypeUnionSchemaCase<Value, NumberSchema>
  let stringCase: TypeUnionSchemaCase<Value, StringSchema>
  let arrayCase: TypeUnionSchemaCase<Value, ArraySchema>
  let objectCase: TypeUnionSchemaCase<Value, ObjectSchema>

  typealias CaseEncoder = @Sendable (
    Value,
    _ nullCase: (NullSchema.Value) -> SchemaCoding.TypeUnionCaseEncoder,
    _ boolCase: (BoolSchema.Value) -> SchemaCoding.TypeUnionCaseEncoder,
    _ numberCase: (NumberSchema.Value) -> SchemaCoding.TypeUnionCaseEncoder,
    _ stringCase: (StringSchema.Value) -> SchemaCoding.TypeUnionCaseEncoder,
    _ arrayCase: (ArraySchema.Value) -> SchemaCoding.TypeUnionCaseEncoder,
    _ objectCase: (ObjectSchema.Value) -> SchemaCoding.TypeUnionCaseEncoder
  ) -> SchemaCoding.TypeUnionCaseEncoder
  let caseEncoder: CaseEncoder

  func encodeSchemaDefinition(to encoder: inout SchemaCoding.SchemaEncoder) {
    let description = encoder.contextualDescription(description)
    encoder.stream.encodeObject { objectEncoder in
      if let description {
        objectEncoder.encodeProperty(name: "description") { propertyEncoder in
          propertyEncoder.encode(description)
        }
      }

      objectEncoder.encodeProperty(name: "oneOf") { propertyEncoder in
        propertyEncoder.encodeArray { arrayEncoder in
          arrayEncoder.encodeElement { stream in
            if !(nullCase.schema is SchemaCoding.TypeUnionUnhandledCaseSchema<Value>) {
              stream.encodeSchemaDefinition(nullCase.schema)
            }
            if !(boolCase.schema is SchemaCoding.TypeUnionUnhandledCaseSchema<Value>) {
              stream.encodeSchemaDefinition(boolCase.schema)
            }
            if !(numberCase.schema is SchemaCoding.TypeUnionUnhandledCaseSchema<Value>) {
              stream.encodeSchemaDefinition(numberCase.schema)
            }
            if !(stringCase.schema is SchemaCoding.TypeUnionUnhandledCaseSchema<Value>) {
              stream.encodeSchemaDefinition(stringCase.schema)
            }
            if !(arrayCase.schema is SchemaCoding.TypeUnionUnhandledCaseSchema<Value>) {
              stream.encodeSchemaDefinition(arrayCase.schema)
            }
            if !(objectCase.schema is SchemaCoding.TypeUnionUnhandledCaseSchema<Value>) {
              stream.encodeSchemaDefinition(objectCase.schema)
            }
          }
        }
      }
    }
  }

  func encode(_ value: Value, to encoder: inout SchemaCoding.SchemaValueEncoder) {
    let caseEncoder = self.caseEncoder(
      value,
      { value in
        SchemaCoding.TypeUnionCaseEncoder(
          implementation: SchemaCoding.TypeUnionCaseEncoderImplementation(
            schema: nullCase.schema,
            value: value
          )
        )
      },
      { value in
        SchemaCoding.TypeUnionCaseEncoder(
          implementation: SchemaCoding.TypeUnionCaseEncoderImplementation(
            schema: boolCase.schema,
            value: value
          )
        )
      },
      { value in
        SchemaCoding.TypeUnionCaseEncoder(
          implementation: SchemaCoding.TypeUnionCaseEncoderImplementation(
            schema: numberCase.schema,
            value: value
          )
        )
      },
      { value in
        SchemaCoding.TypeUnionCaseEncoder(
          implementation: SchemaCoding.TypeUnionCaseEncoderImplementation(
            schema: stringCase.schema,
            value: value
          )
        )
      },
      { value in
        SchemaCoding.TypeUnionCaseEncoder(
          implementation: SchemaCoding.TypeUnionCaseEncoderImplementation(
            schema: arrayCase.schema,
            value: value
          )
        )
      },
      { value in
        SchemaCoding.TypeUnionCaseEncoder(
          implementation: SchemaCoding.TypeUnionCaseEncoderImplementation(
            schema: objectCase.schema,
            value: value
          )
        )
      }
    )
    caseEncoder.implementation.encode(to: &encoder.stream)
  }

  struct ValueDecodingState {
    var kind: JSON.ValueKind?

    var nullState: NullSchema.ValueDecodingState
    var boolState: BoolSchema.ValueDecodingState
    var numberState: NumberSchema.ValueDecodingState
    var stringState: StringSchema.ValueDecodingState
    var arrayState: ArraySchema.ValueDecodingState
    var objectState: ObjectSchema.ValueDecodingState
  }

  var initialValueDecodingState: ValueDecodingState {
    ValueDecodingState(
      nullState: nullCase.schema.initialValueDecodingState,
      boolState: boolCase.schema.initialValueDecodingState,
      numberState: numberCase.schema.initialValueDecodingState,
      stringState: stringCase.schema.initialValueDecodingState,
      arrayState: arrayCase.schema.initialValueDecodingState,
      objectState: objectCase.schema.initialValueDecodingState
    )
  }

  func decodeValue(
    from decoder: inout SchemaCoding.SchemaValueDecoder,
    state: inout ValueDecodingState
  ) throws -> SchemaCoding.SchemaDecodingResult<Value> {
    let kind: JSON.ValueKind

    if let decodedKind = state.kind {
      kind = decodedKind
    } else {
      switch try decoder.stream.peekValueKind() {
      case .needsMoreData:
        return .needsMoreData
      case .decoded(let type):
        kind = type
        state.kind = type
      }
    }

    return switch kind {
    case .null:
      try decoder.stream
        .decodeValue(using: nullCase.schema, state: &state.nullState)
        .map { nullCase.initializer($0) }
    case .boolean:
      try decoder.stream
        .decodeValue(using: boolCase.schema, state: &state.boolState)
        .map { boolCase.initializer($0) }
    case .number:
      try decoder.stream
        .decodeValue(using: numberCase.schema, state: &state.numberState)
        .map { numberCase.initializer($0) }
    case .string:
      try decoder.stream
        .decodeValue(using: stringCase.schema, state: &state.stringState)
        .map { stringCase.initializer($0) }
    case .array:
      try decoder.stream
        .decodeValue(using: arrayCase.schema, state: &state.arrayState)
        .map { arrayCase.initializer($0) }
    case .object:
      try decoder.stream
        .decodeValue(using: objectCase.schema, state: &state.objectState)
        .map { objectCase.initializer($0) }
    }
  }

}

private struct TypeUnionSchemaCase<Value, Schema: SchemaCoding.Schema> {
  let schema: Schema
  let initializer: @Sendable (Schema.Value) -> Value
}

// MARK: - Implementation Details

extension SchemaCoding.SchemaDecodingResult {

  func map<T>(
    _ transform: (Value) -> T
  ) -> SchemaCoding.SchemaDecodingResult<T> {
    switch self {
    case .needsMoreData:
      return .needsMoreData
    case .decoded(let value):
      return .decoded(transform(value))
    }
  }

}

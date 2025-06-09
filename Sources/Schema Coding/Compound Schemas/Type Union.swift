import JSONSupport

// MARK: - API

extension SchemaCoding.SchemaResolver {

  public static func typedUnionSchema<
    Value,
    NullSchema,
    BooleanSchema,
    NumberSchema,
    StringSchema,
    ArraySchema,
    ObjectSchema
  >(
    representing value: Value.Type = Value.self,
    description: String? = nil,
    null: SchemaCoding.TypeUnionSchemaCase<Value, NullSchema>,
    boolean: SchemaCoding.TypeUnionSchemaCase<Value, BooleanSchema>,
    number: SchemaCoding.TypeUnionSchemaCase<Value, NumberSchema>,
    string: SchemaCoding.TypeUnionSchemaCase<Value, StringSchema>,
    array: SchemaCoding.TypeUnionSchemaCase<Value, ArraySchema>,
    object: SchemaCoding.TypeUnionSchemaCase<Value, ObjectSchema>,
    caseEncoder: @escaping @Sendable (
      Value,
      (NullSchema.Value) -> SchemaCoding.TypeUnionCaseEncoder,
      (BooleanSchema.Value) -> SchemaCoding.TypeUnionCaseEncoder,
      (NumberSchema.Value) -> SchemaCoding.TypeUnionCaseEncoder,
      (StringSchema.Value) -> SchemaCoding.TypeUnionCaseEncoder,
      (ArraySchema.Value) -> SchemaCoding.TypeUnionCaseEncoder,
      (ObjectSchema.Value) -> SchemaCoding.TypeUnionCaseEncoder
    ) -> SchemaCoding.TypeUnionCaseEncoder
  ) -> some SchemaCoding.Schema<Value> {
    TypeUnionSchema(
      description: description,
      nullCase: null,
      booleanCase: boolean,
      numberCase: number,
      stringCase: string,
      arrayCase: array,
      objectCase: object,
      caseEncoder: caseEncoder
    )
  }

}

// MARK: - Case

extension SchemaCoding.SchemaResolver {

  public static func typedUnionSchemaCase<Value, Schema: SchemaCoding.Schema>(
    schema: Schema,
    initializer: @escaping @Sendable (Schema.Value) -> Value
  ) -> SchemaCoding.TypeUnionSchemaCase<Value, some SchemaCoding.Schema> {
    SchemaCoding.TypeUnionSchemaCase(
      schema: schema,
      initializer: initializer
    )
  }

  public static func typedUnionSchemaUnhandledCase<Value>()
    -> SchemaCoding.TypeUnionSchemaCase<Value, some SchemaCoding.Schema<Never>>
  {
    SchemaCoding.TypeUnionSchemaCase(
      schema: UnhandledCaseSchema(),
      initializer: { $0 }
    )
  }

}

extension SchemaCoding {

  public struct TypeUnionSchemaCase<Value, Schema: SchemaCoding.Schema>: Sendable {
    fileprivate let schema: Schema
    fileprivate let initializer: @Sendable (Schema.Value) -> Value
  }

}

private struct UnhandledCaseSchema: SchemaCoding.Schema {
  func encodeSchemaDefinition(to encoder: inout SchemaCoding.SchemaEncoder) {
    /// This should be unreachable, because it is not called
    fatalError()
  }
  func encode(_ value: Never, to encoder: inout SchemaCoding.SchemaValueEncoder) {

  }
  func decodeValue(
    from stream: inout SchemaCoding.SchemaValueDecoder,
    state: inout ()
  ) throws -> SchemaCoding.SchemaDecodingResult<Never> {
    throw Error.unexpectedType
  }
}

// MARK: - Case Encoder

extension SchemaCoding {

  public struct TypeUnionCaseEncoder {
    fileprivate let implementation: TypeUnionCaseEncoderImplementationProtocol
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

// MARK: - Schema

private struct TypeUnionSchema<
  Value,
  NullSchema: SchemaCoding.Schema,
  BooleanSchema: SchemaCoding.Schema,
  NumberSchema: SchemaCoding.Schema,
  StringSchema: SchemaCoding.Schema,
  ArraySchema: SchemaCoding.Schema,
  ObjectSchema: SchemaCoding.Schema
>: SchemaCoding.Schema {

  let description: String?

  let nullCase: SchemaCoding.TypeUnionSchemaCase<Value, NullSchema>
  let booleanCase: SchemaCoding.TypeUnionSchemaCase<Value, BooleanSchema>
  let numberCase: SchemaCoding.TypeUnionSchemaCase<Value, NumberSchema>
  let stringCase: SchemaCoding.TypeUnionSchemaCase<Value, StringSchema>
  let arrayCase: SchemaCoding.TypeUnionSchemaCase<Value, ArraySchema>
  let objectCase: SchemaCoding.TypeUnionSchemaCase<Value, ObjectSchema>

  typealias CaseEncoder = @Sendable (
    Value,
    _ nullCase: (NullSchema.Value) -> SchemaCoding.TypeUnionCaseEncoder,
    _ booleanCase: (BooleanSchema.Value) -> SchemaCoding.TypeUnionCaseEncoder,
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
            if !(nullCase.schema is UnhandledCaseSchema) {
              stream.encodeSchemaDefinition(nullCase.schema)
            }
            if !(booleanCase.schema is UnhandledCaseSchema) {
              stream.encodeSchemaDefinition(booleanCase.schema)
            }
            if !(numberCase.schema is UnhandledCaseSchema) {
              stream.encodeSchemaDefinition(numberCase.schema)
            }
            if !(stringCase.schema is UnhandledCaseSchema) {
              stream.encodeSchemaDefinition(stringCase.schema)
            }
            if !(arrayCase.schema is UnhandledCaseSchema) {
              stream.encodeSchemaDefinition(arrayCase.schema)
            }
            if !(objectCase.schema is UnhandledCaseSchema) {
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
            schema: booleanCase.schema,
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
    var booleanState: BooleanSchema.ValueDecodingState
    var numberState: NumberSchema.ValueDecodingState
    var stringState: StringSchema.ValueDecodingState
    var arrayState: ArraySchema.ValueDecodingState
    var objectState: ObjectSchema.ValueDecodingState
  }

  var initialValueDecodingState: ValueDecodingState {
    ValueDecodingState(
      nullState: nullCase.schema.initialValueDecodingState,
      booleanState: booleanCase.schema.initialValueDecodingState,
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
        .decodeValue(using: booleanCase.schema, state: &state.booleanState)
        .map { booleanCase.initializer($0) }
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

private enum Error: Swift.Error {
  case unexpectedType
}

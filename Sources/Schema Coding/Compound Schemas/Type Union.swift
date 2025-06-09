import JSONSupport

// MARK: - API

extension SchemaCoding.SchemaResolver {

  public static func typedUnionSchema<
    Value,
    NullSchema: SchemaCoding.Schema,
    BoolSchema: SchemaCoding.Schema,
    NumberSchema: SchemaCoding.Schema,
    StringSchema: SchemaCoding.Schema,
    ArraySchema: SchemaCoding.Schema,
    ObjectSchema: SchemaCoding.Schema
  >(
    representing value: Value.Type = Value.self,
    description: String? = nil,
    null: (
      schema: NullSchema,
      initializer: @Sendable (NullSchema.Value) -> Value
    ) = (
      SchemaCoding.TypeUnionUnhandledCaseSchema(),
      { _ in }
    ),
    boolean: (
      schema: BoolSchema,
      initializer: @Sendable (BoolSchema.Value) -> Value
    ) = (
      SchemaCoding.TypeUnionUnhandledCaseSchema(),
      { _ in }
    ),
    number: (
      schema: NumberSchema,
      initializer: @Sendable (NumberSchema.Value) -> Value
    ) = (
      SchemaCoding.TypeUnionUnhandledCaseSchema(),
      { _ in }
    ),
    string: (
      schema: StringSchema,
      initializer: @Sendable (StringSchema.Value) -> Value
    ) = (
      SchemaCoding.TypeUnionUnhandledCaseSchema(),
      { _ in }
    ),
    array: (
      schema: ArraySchema,
      initializer: @Sendable (ArraySchema.Value) -> Value
    ) = (
      SchemaCoding.TypeUnionUnhandledCaseSchema(),
      { _ in }
    ),
    object: (
      schema: ObjectSchema,
      initializer: @Sendable (ObjectSchema.Value) -> Value
    ) = (
      SchemaCoding.TypeUnionUnhandledCaseSchema(),
      { _ in }
    ),
    caseEncoder: @escaping @Sendable (
      Value,
      (NullSchema.Value) -> SchemaCoding.TypeUnionCaseEncoder,
      (BoolSchema.Value) -> SchemaCoding.TypeUnionCaseEncoder,
      (NumberSchema.Value) -> SchemaCoding.TypeUnionCaseEncoder,
      (StringSchema.Value) -> SchemaCoding.TypeUnionCaseEncoder,
      (ArraySchema.Value) -> SchemaCoding.TypeUnionCaseEncoder,
      (ObjectSchema.Value) -> SchemaCoding.TypeUnionCaseEncoder
    ) -> SchemaCoding.TypeUnionCaseEncoder
  ) -> some SchemaCoding.Schema<Value> {
    TypeUnionSchema(
      description: description,
      nullCase: TypeUnionSchemaCase(
        schema: null.schema,
        initializer: null.initializer
      ),
      booleanCase: TypeUnionSchemaCase(
        schema: boolean.schema,
        initializer: boolean.initializer
      ),
      numberCase: TypeUnionSchemaCase(
        schema: number.schema,
        initializer: number.initializer
      ),
      stringCase: TypeUnionSchemaCase(
        schema: string.schema,
        initializer: string.initializer
      ),
      arrayCase: TypeUnionSchemaCase(
        schema: array.schema,
        initializer: array.initializer
      ),
      objectCase: TypeUnionSchemaCase(
        schema: object.schema,
        initializer: object.initializer
      ),
      caseEncoder: caseEncoder
    )
  }

}

// MARK: - Case Encoding

extension SchemaCoding {

  public struct TypeUnionCaseEncoder {
    fileprivate let implementation: TypeUnionCaseEncoderImplementationProtocol
  }

  public struct TypeUnionUnhandledCaseSchema: SchemaCoding.Schema {
    public init() {

    }
    public func encodeSchemaDefinition(to encoder: inout SchemaCoding.SchemaEncoder) {
      /// This should be unreachable, because it is not called
      fatalError()
    }
    public func encode(_ value: Never, to encoder: inout SchemaCoding.SchemaValueEncoder) {

    }
    public func decodeValue(
      from stream: inout SchemaCoding.SchemaValueDecoder,
      state: inout ()
    ) throws -> SchemaCoding.SchemaDecodingResult<Never> {
      throw Error.unexpectedType
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

  let nullCase: TypeUnionSchemaCase<Value, NullSchema>
  let booleanCase: TypeUnionSchemaCase<Value, BooleanSchema>
  let numberCase: TypeUnionSchemaCase<Value, NumberSchema>
  let stringCase: TypeUnionSchemaCase<Value, StringSchema>
  let arrayCase: TypeUnionSchemaCase<Value, ArraySchema>
  let objectCase: TypeUnionSchemaCase<Value, ObjectSchema>

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
            if !(nullCase.schema is SchemaCoding.TypeUnionUnhandledCaseSchema) {
              stream.encodeSchemaDefinition(nullCase.schema)
            }
            if !(booleanCase.schema is SchemaCoding.TypeUnionUnhandledCaseSchema) {
              stream.encodeSchemaDefinition(booleanCase.schema)
            }
            if !(numberCase.schema is SchemaCoding.TypeUnionUnhandledCaseSchema) {
              stream.encodeSchemaDefinition(numberCase.schema)
            }
            if !(stringCase.schema is SchemaCoding.TypeUnionUnhandledCaseSchema) {
              stream.encodeSchemaDefinition(stringCase.schema)
            }
            if !(arrayCase.schema is SchemaCoding.TypeUnionUnhandledCaseSchema) {
              stream.encodeSchemaDefinition(arrayCase.schema)
            }
            if !(objectCase.schema is SchemaCoding.TypeUnionUnhandledCaseSchema) {
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

private enum Error: Swift.Error {
  case unexpectedType
}

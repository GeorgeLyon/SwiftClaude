import JSONSupport

extension ToolInput {

  public static func internallyTaggedEnumSchema<
    Value,
    CaseKey: CodingKey,
    each AssociatedValuesSchema: ToolInput.Schema
  >(
    representing _: Value.Type,
    description: String?,
    discriminatorPropertyName: String,
    keyedBy _: CaseKey.Type,
    cases: (
      repeat (
        key: CaseKey,
        description: String?,
        schema: InternallyTaggedEnumCaseSchema<each AssociatedValuesSchema>,
        initializer: @Sendable ((each AssociatedValuesSchema).Value) -> Value
      )
    ),
    caseEncoder: @escaping @Sendable (
      Value,
      repeat ((each AssociatedValuesSchema).Value) -> InternallyTaggedEnumCaseEncoder
    ) -> InternallyTaggedEnumCaseEncoder
  ) -> some Schema<Value> {
    InternallyTaggedEnumSchema(
      description: description,
      discriminatorPropertyName: discriminatorPropertyName,
      cases: (repeat InternallyTaggedEnumSchemaCase(
        key: (each cases).key,
        description: (each cases).description,
        schema: (each cases).schema,
        initializer: (each cases).initializer
      )),
      caseEncoder: caseEncoder
    )
  }

  /// Special overload to work around single-element-tuple weirdness
  public static func internallyTaggedEnumCaseSchema<
    Key: CodingKey,
    ValueSchema: Schema
  >(
    values: (
      key: Key,
      schema: ValueSchema
    ),
    keyedBy: Key.Type
  ) -> InternallyTaggedEnumCaseSchema<some Schema<ValueSchema.Value>> {
    InternallyTaggedEnumCaseSchema(
      schema: ObjectPropertiesSchema(
        description: nil,
        properties: ObjectPropertySchema(
          key: values.key,
          description: nil,
          schema: values.schema
        )
      )
    )
  }

  public static func internallyTaggedEnumCaseSchema<
    Key: CodingKey,
    each ValueSchema: Schema
  >(
    values: (
      repeat (
        key: Key,
        schema: each ValueSchema
      )
    ),
    keyedBy: Key.Type
  ) -> InternallyTaggedEnumCaseSchema<some Schema<(repeat (each ValueSchema).Value)>> {
    InternallyTaggedEnumCaseSchema(
      schema: ObjectPropertiesSchema(
        description: nil,
        properties: repeat ObjectPropertySchema(
          key: (each values).key,
          description: nil,
          schema: (each values).schema
        )
      )
    )
  }

  public struct InternallyTaggedEnumCaseSchema<AssociatedValuesSchema: ToolInput.Schema>: Sendable {
    init(schema: AssociatedValuesSchema)
    where AssociatedValuesSchema: ObjectPropertiesSchemaProtocol {
      self.schema = schema
      self.objectPropertiesSchema = schema
    }
    fileprivate let schema: AssociatedValuesSchema
    fileprivate let objectPropertiesSchema:
      any ObjectPropertiesSchemaProtocol<
        AssociatedValuesSchema.Value,
        AssociatedValuesSchema.ValueDecodingState
      >
  }

}

private struct InternallyTaggedEnumSchema<
  Value,
  CaseKey: CodingKey,
  each AssociatedValuesSchema: ToolInput.Schema
>: InternalSchema {
  func encodeSchemaDefinition(to encoder: ToolInput.SchemaEncoder<Self>) throws {
    fatalError()
  }

  func encode(
    _ value: Value,
    to encoder: ToolInput.Encoder<Self>
  ) throws {
    fatalError()
  }

  func decodeValue(
    from decoder: ToolInput.Decoder<Self>
  ) throws -> Value {
    fatalError()
  }

  typealias Cases = (
    repeat InternallyTaggedEnumSchemaCase<Value, CaseKey, each AssociatedValuesSchema>
  )

  typealias CaseEncoder = @Sendable (
    Value,
    repeat @escaping ((each AssociatedValuesSchema).Value) ->
      ToolInput.InternallyTaggedEnumCaseEncoder
  ) -> ToolInput.InternallyTaggedEnumCaseEncoder

  init(
    description: String?,
    discriminatorPropertyName: String,
    cases: Cases,
    caseEncoder: @escaping CaseEncoder
  ) {
    self.description = description
    self.discriminatorPropertyName = discriminatorPropertyName
    self.cases = cases
    self.caseEncoder = caseEncoder
    self.decoderProvider = EnumCaseDecoderProvider(
      discriminatorPropertyName: discriminatorPropertyName,
      cases: repeat each cases
    )
  }

  private let description: String?
  private let discriminatorPropertyName: String
  private let cases: Cases
  private let decoderProvider: EnumCaseDecoderProvider
  private let caseEncoder: CaseEncoder

}

private struct InternallyTaggedEnumSchemaCase<
  Value,
  CaseKey: CodingKey,
  Schema: ToolInput.Schema
> {
  let key: CaseKey
  let description: String?
  let schema: ToolInput.InternallyTaggedEnumCaseSchema<Schema>
  let initializer: @Sendable (Schema.Value) -> Value
}

// MARK: - Schema Definition

extension InternallyTaggedEnumSchema {

  func encodeSchemaDefinition(
    to encoder: inout ToolInput.NewSchemaEncoder
  ) {
    let description = encoder.contextualDescription(description)
    encoder.stream.encodeObject { encoder in
      if let description {
        encoder.encodeProperty(name: "description") { $0.encode(description) }
      }

      encoder.encodeProperty(name: "oneOf") { stream in
        stream.encodeArray { encoder in
          for enumCase in repeat each cases {
            encoder.encodeElement { stream in
              var encoder = ToolInput.NewSchemaEncoder(
                stream: stream,
                descriptionPrefix: enumCase.description
              )
              enumCase.schema.objectPropertiesSchema.encodeSchemaDefinition(
                to: &encoder,
                discriminator: (
                  name: discriminatorPropertyName,
                  value: enumCase.key.stringValue
                )
              )
              stream = encoder.stream
            }
          }
        }
      }
    }
  }

}

// MARK: - Value Encoding

extension ToolInput {

  public struct InternallyTaggedEnumCaseEncoder {
    fileprivate let implementation: InternallyTaggedEnumCaseEncoderImplementationProtocol
  }

  fileprivate protocol InternallyTaggedEnumCaseEncoderImplementationProtocol {
    func encode(
      to stream: inout JSON.EncodingStream,
      discriminatorPropertyName: String
    )
  }

  fileprivate struct InternallyTaggedEnumCaseEncoderImplementation<
    Schema: ToolInput.Schema
  >: InternallyTaggedEnumCaseEncoderImplementationProtocol {
    func encode(
      to stream: inout JSON.EncodingStream,
      discriminatorPropertyName: String
    ) {
      objectPropertiesSchema.encode(
        value,
        discriminator: (
          name: discriminatorPropertyName,
          value: key
        ),
        to: &stream
      )
    }
    let key: String
    let schema: Schema
    let objectPropertiesSchema:
      any ObjectPropertiesSchemaProtocol<Schema.Value, Schema.ValueDecodingState>
    let value: Schema.Value
  }

}

extension InternallyTaggedEnumSchema {

  func encode(_ value: Value, to stream: inout JSONSupport.JSON.EncodingStream) {
    let encoder = caseEncoder(
      value,
      repeat { value in
        ToolInput.InternallyTaggedEnumCaseEncoder(
          implementation: ToolInput.InternallyTaggedEnumCaseEncoderImplementation(
            key: (each cases).key.stringValue,
            schema: (each cases).schema.schema,
            objectPropertiesSchema: (each cases).schema.objectPropertiesSchema,
            value: value
          )
        )
      }
    )
    encoder.implementation.encode(
      to: &stream,
      discriminatorPropertyName: discriminatorPropertyName
    )
  }

}

// MARK: - Value Decoding

extension InternallyTaggedEnumSchema {

  typealias AssociatedValueDecodingStates = (
    repeat (each AssociatedValuesSchema).ValueDecodingState
  )

  typealias EnumCaseDecoder = @Sendable (
    inout JSON.DecodingStream,
    inout AssociatedValueDecodingStates
  ) throws -> JSON.DecodingResult<Value>

  struct EnumCaseDecoderProvider {
    init(
      discriminatorPropertyName: String,
      cases: repeat InternallyTaggedEnumSchemaCase<Value, CaseKey, each AssociatedValuesSchema>
    ) {
      var decoders: [Substring: EnumCaseDecoder] = [:]
      var tupleArchetype = VariadicTupleArchetype<AssociatedValueDecodingStates>()
      for enumCase in repeat each cases {
        let accessor = tupleArchetype.nextElementAccessor(
          of: type(of: enumCase.schema.schema.initialValueDecodingState)
        )
        let key = Substring(enumCase.key.stringValue)
        let decoder: EnumCaseDecoder = { stream, states in
          try accessor.mutate(&states) { state in
            let result = try enumCase.schema
              .objectPropertiesSchema
              .decodeValue(
                from: &stream,
                state: &state,
                discriminator: (
                  name: discriminatorPropertyName,
                  value: enumCase.key.stringValue
                )
              )
            switch result {
            case .needsMoreData:
              return .needsMoreData
            case .decoded(let value):
              return .decoded(enumCase.initializer(value))
            }
          }
        }

        if decoders.updateValue(decoder, forKey: key) != nil {
          assertionFailure()
          decoders[key] = { _, _ in
            throw Error.multipleEnumCasesWithSameName(enumCase.key.stringValue)
          }
        }
      }
      self.decoders = decoders
    }

    func decoder(for caseName: Substring) throws -> EnumCaseDecoder {
      guard let decoder: EnumCaseDecoder = decoders[caseName] else {
        throw Error.unknownEnumCase(allKeys: [String(caseName)])
      }
      return decoder
    }

    private let decoders: [Substring: EnumCaseDecoder]
  }

  struct ValueDecodingState {
    /// We can't have enums with parameter packs, so we just splat the associated values

    var associatedValueStates: AssociatedValueDecodingStates
    var decoder: EnumCaseDecoder?
  }

  var initialValueDecodingState: ValueDecodingState {
    ValueDecodingState(
      associatedValueStates: (repeat (each cases).schema.schema.initialValueDecodingState)
    )
  }

  func decodeValue(
    from stream: inout JSON.DecodingStream,
    state: inout ValueDecodingState
  ) throws -> JSON.DecodingResult<Value> {
    while true {
      if let decoder = state.decoder {
        return try decoder(&stream, &state.associatedValueStates)
      } else {
        let result = try stream.peekObjectProperty(discriminatorPropertyName) { stream in
          try stream.decodeString()
        }
        switch result {
        case .needsMoreData:
          return .needsMoreData
        case .decoded(let discriminatorValue?):
          state.decoder = try decoderProvider.decoder(for: discriminatorValue)
        case .decoded(.none):
          throw Error.discriminatorNotFound
        }
      }
    }
  }

}

// MARK: - Errors

private enum Error: Swift.Error {
  case additionalPropertyFound(String)
  case multipleEnumCasesWithSameName(String)
  case discriminatorNotFound
  case unknownEnumCase(allKeys: [String])
}

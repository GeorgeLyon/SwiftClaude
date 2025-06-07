import JSONSupport

extension SchemaCoding.SchemaResolver {

  public static func internallyTaggedEnumSchema<
    Value,
    each AssociatedValuesSchema: SchemaCoding.Schema
  >(
    representing _: Value.Type,
    description: String?,
    discriminatorPropertyName: String,
    cases: (
      repeat (
        key: SchemaCoding.SchemaCodingKey,
        description: String?,
        schema: SchemaCoding.InternallyTaggedEnumCaseSchema<each AssociatedValuesSchema>,
        initializer: @Sendable ((each AssociatedValuesSchema).Value) -> Value
      )
    ),
    caseEncoder: @escaping @Sendable (
      Value,
      repeat ((each AssociatedValuesSchema).Value) -> SchemaCoding.InternallyTaggedEnumCaseEncoder
    ) -> SchemaCoding.InternallyTaggedEnumCaseEncoder
  ) -> some SchemaCoding.Schema<Value> {
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
    ValueSchema: SchemaCoding.Schema
  >(
    values: (
      key: SchemaCoding.SchemaCodingKey,
      schema: ValueSchema
    )
  ) -> SchemaCoding.InternallyTaggedEnumCaseSchema<some SchemaCoding.Schema<ValueSchema.Value>> {
    SchemaCoding.InternallyTaggedEnumCaseSchema(
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
    each ValueSchema: SchemaCoding.Schema
  >(
    values: (
      repeat (
        key: SchemaCoding.SchemaCodingKey,
        schema: each ValueSchema
      )
    )
  ) -> SchemaCoding.InternallyTaggedEnumCaseSchema<some SchemaCoding.Schema<(repeat (each ValueSchema).Value)>> {
    SchemaCoding.InternallyTaggedEnumCaseSchema(
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

}

extension SchemaCoding {
  public struct InternallyTaggedEnumCaseSchema<AssociatedValuesSchema: SchemaCoding.Schema>: Sendable {
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
  each AssociatedValuesSchema: SchemaCoding.Schema
>: InternalSchema {
  typealias Cases = (
    repeat InternallyTaggedEnumSchemaCase<Value, each AssociatedValuesSchema>
  )

  typealias CaseEncoder = @Sendable (
    Value,
    repeat @escaping ((each AssociatedValuesSchema).Value) ->
      SchemaCoding.InternallyTaggedEnumCaseEncoder
  ) -> SchemaCoding.InternallyTaggedEnumCaseEncoder

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
  Schema: SchemaCoding.Schema
> {
  let key: SchemaCoding.SchemaCodingKey
  let description: String?
  let schema: SchemaCoding.InternallyTaggedEnumCaseSchema<Schema>
  let initializer: @Sendable (Schema.Value) -> Value
}

// MARK: - Schema Definition

extension InternallyTaggedEnumSchema {

  func encodeSchemaDefinition(
    to encoder: inout SchemaCoding.SchemaEncoder
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
              var encoder = SchemaCoding.SchemaEncoder(
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

extension SchemaCoding {

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
    Schema: SchemaCoding.Schema
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
        SchemaCoding.InternallyTaggedEnumCaseEncoder(
          implementation: SchemaCoding.InternallyTaggedEnumCaseEncoderImplementation(
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
      cases: repeat InternallyTaggedEnumSchemaCase<Value, each AssociatedValuesSchema>
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

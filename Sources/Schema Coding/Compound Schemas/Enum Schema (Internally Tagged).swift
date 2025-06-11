import JSONSupport

extension SchemaCoding.SchemaCodingSupport {

  public static func internallyTaggedEnumSchema<
    Value,
    each AssociatedValuesSchema: SchemaCoding.ExtendableSchema
  >(
    representing _: Value.Type,
    description: String?,
    discriminatorPropertyName: StaticString,
    cases: (
      repeat (
        key: SchemaCoding.SchemaCodingSupport.CodingKey,
        description: String?,
        schema: each AssociatedValuesSchema,
        initializer: @Sendable ((each AssociatedValuesSchema).Value) -> Value
      )
    ),
    caseEncoder: @escaping @Sendable (
      Value,
      repeat ((each AssociatedValuesSchema).Value) ->
        SchemaCoding.InternallyTaggedEnumCaseEncoder
    ) -> SchemaCoding.InternallyTaggedEnumCaseEncoder
  ) -> some SchemaCoding.Schema<Value> {
    InternallyTaggedEnumSchema(
      description: description,
      discriminatorSchema: SchemaCoding.AdditionalPropertiesSchema(
        properties: ObjectPropertySchema(
          key: SchemaCoding.CodingKey(discriminatorPropertyName),
          description: nil,
          schema: StringSchema()
        )
      ),
      cases: (repeat InternallyTaggedEnumSchemaCase(
        key: (each cases).key,
        description: (each cases).description,
        schema: (each cases).schema,
        initializer: (each cases).initializer
      )),
      caseEncoder: caseEncoder
    )
  }

}

private struct InternallyTaggedEnumSchema<
  Value,
  each AssociatedValuesSchema: SchemaCoding.ExtendableSchema
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
    discriminatorSchema: SchemaCoding.AdditionalPropertiesSchema<StringSchema>,
    cases: Cases,
    caseEncoder: @escaping CaseEncoder
  ) {
    self.description = description
    self.discriminatorSchema = discriminatorSchema
    self.cases = cases
    self.caseEncoder = caseEncoder
    self.decoderProvider = EnumCaseDecoderProvider(
      discriminatorSchema: discriminatorSchema,
      cases: repeat each cases
    )
  }

  private let description: String?
  private let discriminatorSchema: SchemaCoding.AdditionalPropertiesSchema<StringSchema>
  private let cases: Cases
  private let decoderProvider: EnumCaseDecoderProvider
  private let caseEncoder: CaseEncoder

}

private struct InternallyTaggedEnumSchemaCase<
  Value,
  Schema: SchemaCoding.ExtendableSchema
> {
  let key: SchemaCoding.CodingKey
  let description: String?
  let schema: Schema
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
              enumCase.schema.encodeSchemaDefinition(
                to: &encoder,

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
  public typealias InternallyTaggedEnumCaseEncoder = SchemaCodingSupport
    .InternallyTaggedEnumCaseEncoder
  fileprivate typealias InternallyTaggedEnumCaseEncoderImplementationProtocol =
    SchemaCodingSupport.InternallyTaggedEnumCaseEncoderImplementationProtocol
  fileprivate typealias InternallyTaggedEnumCaseEncoderImplementation =
    SchemaCodingSupport.InternallyTaggedEnumCaseEncoderImplementation
}

extension SchemaCoding.SchemaCodingSupport {

  public struct InternallyTaggedEnumCaseEncoder {
    fileprivate let implementation: InternallyTaggedEnumCaseEncoderImplementationProtocol
  }

  fileprivate protocol InternallyTaggedEnumCaseEncoderImplementationProtocol {
    func encode(
      to stream: inout SchemaCoding.SchemaValueEncoder,
      discriminatorSchema: AdditionalPropertiesSchema<StringSchema>
    )
  }

  fileprivate struct InternallyTaggedEnumCaseEncoderImplementation<
    Schema: SchemaCoding.ExtendableSchema
  >: InternallyTaggedEnumCaseEncoderImplementationProtocol {
    func encode(
      to stream: inout SchemaCoding.SchemaValueEncoder,
      discriminatorSchema: AdditionalPropertiesSchema<StringSchema>
    ) {
      schema.encode(
        value,
        additionalProperties: discriminatorSchema,
        additionalPropertyValues: .init(key),
        to: &stream
      )
    }
    let key: String
    let schema: Schema
    let value: Schema.Value
  }

}

extension InternallyTaggedEnumSchema {

  func encode(_ value: Value, to encoder: inout SchemaCoding.SchemaValueEncoder) {
    let enumCaseEncoder = caseEncoder(
      value,
      repeat { value in
        SchemaCoding.InternallyTaggedEnumCaseEncoder(
          implementation: SchemaCoding.InternallyTaggedEnumCaseEncoderImplementation(
            key: (each cases).key.stringValue,
            schema: (each cases).schema,
            value: value
          )
        )
      }
    )
    enumCaseEncoder.implementation.encode(
      to: &encoder,
      discriminatorSchema: discriminatorSchema
    )
  }

}

// MARK: - Value Decoding

extension InternallyTaggedEnumSchema {

  typealias AssociatedValueDecodingStates = (
    repeat SchemaCoding.SchemaCodingSupport.AdditionalPropertiesSchema<
      StringSchema
    >.ValueDecodingState<(each AssociatedValuesSchema).ValueDecodingState>
  )

  typealias EnumCaseDecoder = @Sendable (
    inout SchemaCoding.SchemaValueDecoder,
    inout AssociatedValueDecodingStates
  ) throws -> SchemaCoding.DecodingResult<Value>

  struct EnumCaseDecoderProvider {
    init(
      discriminatorSchema: SchemaCoding.SchemaCodingSupport.AdditionalPropertiesSchema<
        StringSchema
      >,
      cases: repeat InternallyTaggedEnumSchemaCase<Value, each AssociatedValuesSchema>
    ) {
      var decoders: [Substring: EnumCaseDecoder] = [:]
      var tupleArchetype = VariadicTupleArchetype<AssociatedValueDecodingStates>()
      for enumCase in repeat each cases {
        let accessor = tupleArchetype.nextElementAccessor(
          of: type(
            of: discriminatorSchema.initialValueDecodingState(
              base: enumCase.schema.initialValueDecodingState
            )
          )
        )
        let key = Substring(enumCase.key.stringValue)
        let decoder: EnumCaseDecoder = { decoder, states in
          try accessor.mutate(&states) { state in
            let result = try enumCase.schema
              .decodeValue(
                from: &decoder,
                state: &state,
                additionalProperties: discriminatorSchema
              )
            switch result {
            case .needsMoreData:
              return .needsMoreData
            case .decoded(let value):
              return .decoded(enumCase.initializer(value.0))
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
      associatedValueStates: (repeat discriminatorSchema.initialValueDecodingState(
        base: (each cases).schema.initialValueDecodingState
      ))
    )
  }

  func decodeValue(
    from decoder: inout SchemaCoding.SchemaValueDecoder,
    state: inout ValueDecodingState
  ) throws -> SchemaCoding.DecodingResult<Value> {
    while true {
      if let caseDecoder = state.decoder {
        return try caseDecoder(&decoder, &state.associatedValueStates)
      } else {
        let result = try decoder.stream.peekObjectProperty(
          discriminatorSchema.properties.key.stringValue
        ) {
          stream in
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

import JSONSupport

extension SchemaCoding.SchemaCodingSupport {

  public static func enumSchema<
    Value,
    each AssociatedValuesSchema: SchemaCoding.ExtendableSchema
  >(
    representing _: Value.Type,
    description: String?,
    discriminatorPropertyName: SchemaCoding.CodingKey,
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
        InternallyTaggedEnumCaseEncoder
    ) -> InternallyTaggedEnumCaseEncoder
  ) -> some SchemaCoding.Schema<Value> {
    InternallyTaggedEnumSchema(
      description: description,
      discriminatorPropertyName: discriminatorPropertyName.stringValue,
      cases: (repeat InternallyTaggedEnumSchemaCase(
        discriminatorPropertyName: discriminatorPropertyName,
        key: (each cases).key,
        description: (each cases).description,
        schema: (each cases).schema,
        initializer: (each cases).initializer
      )),
      caseEncoder: caseEncoder
    )
  }

}

// MARK: - Schema

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
      SchemaCoding.SchemaCodingSupport.InternallyTaggedEnumCaseEncoder
  ) -> SchemaCoding.SchemaCodingSupport.InternallyTaggedEnumCaseEncoder

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
  Schema: SchemaCoding.ExtendableSchema
> {
  init(
    discriminatorPropertyName: SchemaCoding.CodingKey,
    key: SchemaCoding.CodingKey,
    description: String? = nil,
    schema: Schema,
    initializer: @Sendable @escaping (Schema.Value) -> Value
  ) {
    self.key = key
    self.description = description
    self.schema = ExtendedSchema(
      baseSchema: schema,
      additionalProperties: SchemaCoding.AdditionalPropertiesSchema(
        properties: ObjectPropertySchema(
          key: discriminatorPropertyName,
          description: nil,
          schema: ConstSchema(value: key.stringValue)
        )
      )
    )
    self.initializer = initializer
  }

  let key: SchemaCoding.CodingKey
  let description: String?
  let schema: ExtendedSchema<Schema, ConstSchema>
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
                to: &encoder
              )
              stream = encoder.stream
            }
          }
        }
      }
    }
  }

}

private struct ConstSchema: SchemaCoding.Schema {

  let value: String

  func encodeSchemaDefinition(to encoder: inout SchemaCoding.SchemaCodingSupport.SchemaEncoder) {
    encoder.stream.encodeObject { stream in
      stream.encodeProperty(name: "const") { $0.encode(value) }
    }
  }

  func encode(
    _: Void,
    to encoder: inout SchemaCoding.SchemaCodingSupport.SchemaValueEncoder
  ) {
    encoder.stream.encode(value)
  }

  func decodeValue(
    from decoder: inout SchemaCoding.SchemaCodingSupport.SchemaValueDecoder,
    state: inout ()
  ) throws -> SchemaCoding.DecodingResult<Void> {
    let result = try decoder.stream.decodeString()
    switch result {
    case .needsMoreData:
      return .needsMoreData
    case .decoded(let decodedValue):
      guard decodedValue == value else {
        throw Error.invalidDiscriminatValue(
          observed: String(decodedValue),
          expected: value
        )
      }
      return .decoded(())
    }
  }

}

// MARK: - Value Encoding

extension SchemaCoding {
  public typealias InternallyTaggedEnumCaseEncoder = SchemaCodingSupport
    .InternallyTaggedEnumCaseEncoder
  fileprivate typealias InternallyTaggedEnumCaseEncoderImplementationProtocol = SchemaCodingSupport
    .InternallyTaggedEnumCaseEncoderImplementationProtocol
  fileprivate typealias InternallyTaggedEnumCaseEncoderImplementation = SchemaCodingSupport
    .InternallyTaggedEnumCaseEncoderImplementation
}

extension SchemaCoding.SchemaCodingSupport {

  public struct InternallyTaggedEnumCaseEncoder {
    fileprivate let implementation: InternallyTaggedEnumCaseEncoderImplementationProtocol
  }

  fileprivate protocol InternallyTaggedEnumCaseEncoderImplementationProtocol {
    func encode(
      to stream: inout SchemaCoding.SchemaValueEncoder
    )
  }

  fileprivate struct InternallyTaggedEnumCaseEncoderImplementation<
    Schema: SchemaCoding.Schema
  >: InternallyTaggedEnumCaseEncoderImplementationProtocol {
    func encode(
      to stream: inout SchemaCoding.SchemaValueEncoder
    ) {
      schema.encode(
        value,
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
        SchemaCoding.SchemaCodingSupport.InternallyTaggedEnumCaseEncoder(
          implementation: SchemaCoding.SchemaCodingSupport
            .InternallyTaggedEnumCaseEncoderImplementation(
              key: (each cases).key.stringValue,
              schema: (each cases).schema,
              value: (value, ())
            )
        )
      }
    )
    enumCaseEncoder.implementation.encode(
      to: &encoder
    )
  }

}

// MARK: - Value Decoding

extension InternallyTaggedEnumSchema {

  typealias AssociatedValueDecodingStates = (
    repeat ExtendedSchema<(each AssociatedValuesSchema), ConstSchema>.ValueDecodingState
  )

  typealias EnumCaseDecoder = @Sendable (
    inout SchemaCoding.SchemaValueDecoder,
    inout AssociatedValueDecodingStates
  ) throws -> SchemaCoding.DecodingResult<Value>

  struct EnumCaseDecoderProvider {
    init(
      cases: repeat InternallyTaggedEnumSchemaCase<Value, each AssociatedValuesSchema>
    ) {
      var decoders: [Substring: EnumCaseDecoder] = [:]
      var tupleArchetype = VariadicTupleArchetype<AssociatedValueDecodingStates>()
      for enumCase in repeat each cases {
        let accessor = tupleArchetype.nextElementAccessor(
          of: type(of: enumCase.schema.initialValueDecodingState)
        )
        let key = Substring(enumCase.key.stringValue)
        let decoder: EnumCaseDecoder = { decoder, states in
          try accessor.mutate(&states) { state in
            let result = try enumCase.schema
              .decodeValue(
                from: &decoder,
                state: &state
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
      associatedValueStates: (repeat (each cases).schema.initialValueDecodingState)
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
          discriminatorPropertyName
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
  case invalidDiscriminatValue(observed: String, expected: String)
  case discriminatorNotFound
  case unknownEnumCase(allKeys: [String])
}

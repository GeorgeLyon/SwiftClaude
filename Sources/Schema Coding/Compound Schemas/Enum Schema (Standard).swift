import JSONSupport

// MARK: - Defining Schemas

/// This extension defines a family of `enumSchema` methods.
/// These are intended to be added to enums via a macro and so are structured to be very regular.
extension SchemaCoding.SchemaCodingSupport {

  @_disfavoredOverload
  public static func enumSchema<
    Value,
    each AssociatedValuesSchema: SchemaCoding.Schema
  >(
    representing _: Value.Type,
    description: String?,
    cases: (
      repeat (
        key: CodingKey,
        description: String?,
        schema: each AssociatedValuesSchema,
        initializer: @Sendable ((each AssociatedValuesSchema).Value) -> Value
      )
    ),
    caseEncoder: @escaping @Sendable (
      Value,
      repeat ((each AssociatedValuesSchema).Value) -> SchemaCoding.EnumCaseEncoder
    ) -> SchemaCoding.EnumCaseEncoder
  ) -> some SchemaCoding.Schema<Value> {
    StandardEnumSchema(
      description: description,
      cases: (repeat StandardEnumSchemaCase(
        key: (each cases).key,
        description: (each cases).description,
        schema: (each cases).schema,
        initializer: (each cases).initializer
      )),
      caseEncoder: caseEncoder
    )
  }

}

// MARK: - Encoding Enums

extension SchemaCoding {

  public struct EnumCaseEncoder {
    fileprivate let key: String
    fileprivate let implementation: EnumCaseEncoderImplementationProtocol
  }

  fileprivate protocol EnumCaseEncoderImplementationProtocol {
    func encode(to encoder: inout JSON.EncodingStream)
  }

  fileprivate struct EnumCaseEncoderImplementation<
    Schema: SchemaCoding.Schema
  >: EnumCaseEncoderImplementationProtocol {
    func encode(to stream: inout JSON.EncodingStream) {
      stream.encode(value, using: schema)
    }
    let schema: Schema
    let value: Schema.Value
  }

}

// MARK: - Associated Values

extension SchemaCoding.SchemaCodingSupport {

  public static func enumCaseAssociatedValuesSchema(
    values: ()
  ) -> some SchemaCoding.Schema<Void> {
    NullSchema()
  }

  public static func enumCaseAssociatedValuesSchema<
    ValueSchema: SchemaCoding.Schema
  >(
    values: (
      key: SchemaCoding.CodingKey?,
      schema: ValueSchema
    )
  ) -> some SchemaCoding.Schema<ValueSchema.Value> {
    values.schema
  }

  public static func enumCaseAssociatedValuesSchema<
    ValueSchema: SchemaCoding.ExtendableSchema
  >(
    values: (
      key: SchemaCoding.CodingKey?,
      schema: ValueSchema
    )
  ) -> some SchemaCoding.ExtendableSchema<ValueSchema.Value> {
    values.schema
  }

  // public static func enumCaseAssociatedValuesSchema<
  //   ValueSchema: SchemaCoding.Schema
  // >(
  //   values: (
  //     key: SchemaCoding.CodingKey,
  //     schema: ValueSchema
  //   )
  // ) -> some SchemaCoding.ExtendableSchema<ValueSchema.Value> {
  //   fatalError()
  // }

  @_disfavoredOverload
  public static func enumCaseAssociatedValuesSchema<
    each ValueSchema: SchemaCoding.Schema
  >(
    values: (
      repeat (
        key: SchemaCoding.CodingKey,
        schema: each ValueSchema
      )
    )
  ) -> some SchemaCoding.ExtendableSchema<(repeat (each ValueSchema).Value)> {
    /// Associated values which all have names are represented as an object
    ObjectPropertiesSchema(
      description: nil,
      properties: repeat ObjectPropertySchema(
        key: (each values).key,
        description: nil,
        schema: (each values).schema
      )
    )
  }

  @_disfavoredOverload
  public static func enumCaseAssociatedValuesSchema<
    each ValueSchema: SchemaCoding.Schema
  >(
    values: (
      repeat (
        key: SchemaCoding.CodingKey?,
        schema: each ValueSchema
      )
    )
  ) -> some SchemaCoding.Schema<(repeat (each ValueSchema).Value)> {
    TupleSchema(
      elements: (repeat (
        name: (each values).key?.stringValue,
        schema: (each values).schema
      ))
    )
  }

}

// MARK: - Schema

private struct StandardEnumSchema<
  Value,
  each AssociatedValuesSchema: SchemaCoding.Schema
>: InternalSchema {

  typealias Cases = (repeat StandardEnumSchemaCase<Value, each AssociatedValuesSchema>)

  typealias CaseEncoder = @Sendable (
    Value,
    repeat @escaping ((each AssociatedValuesSchema).Value) -> SchemaCoding.EnumCaseEncoder
  ) -> SchemaCoding.EnumCaseEncoder

  init(
    description: String?,
    cases: Cases,
    caseEncoder: @escaping CaseEncoder
  ) {
    self.description = description
    self.cases = cases
    self.caseEncoder = caseEncoder
    self.decoderProvider = EnumCaseDecoderProvider(cases: repeat each cases)

    /// Resolve style
    do {
      var caseCount = 0
      var allCaseAssociatedValuesAreVoid = true
      for `case` in repeat each cases {
        caseCount += 1
        if !(`case`.schema is any SchemaCoding.Schema<Void>) {
          allCaseAssociatedValuesAreVoid = false
        }
      }
      if caseCount == 1 {
        self.style = .singleCase
      } else if allCaseAssociatedValuesAreVoid {
        self.style = .noAssociatedValues
      } else {
        self.style = .objectProperties
      }
    }
  }

  private let description: String?
  private let cases: Cases
  private let decoderProvider: EnumCaseDecoderProvider
  private let caseEncoder: CaseEncoder
  private let style: EnumStyle

  func encodeSchemaDefinition(to encoder: inout SchemaCoding.SchemaEncoder) {
    switch style {
    case .singleCase:
      encodeSingleCaseSchemaDefinition(to: &encoder)
    case .noAssociatedValues:
      encodeNoAssociatedValuesSchemaDefinition(to: &encoder)
    case .objectProperties:
      encodeObjectPropertiesSchemaDefinition(to: &encoder)
    }
  }

  private func encodeSingleCaseSchemaDefinition(
    to encoder: inout SchemaCoding.SchemaEncoder
  ) {
    /// There should only be a single case
    let contextualDescription = encoder.contextualDescription(description)
    for `case` in repeat each cases {
      encoder.stream.encodeSchemaDefinition(
        `case`.schema,
        descriptionPrefix: combineDescriptions(
          contextualDescription,
          `case`.description
        )
      )
    }
  }

  private func encodeNoAssociatedValuesSchemaDefinition(
    to encoder: inout SchemaCoding.SchemaEncoder
  ) {
    let description = encoder.contextualDescription(description)
    encoder.stream.encodeObject { stream in
      var possibleValues: [String] = []
      var valueDescriptions: [String] = []
      for `case` in repeat each cases {
        possibleValues.append(`case`.key.stringValue)

        if let caseDescription = `case`.description {
          valueDescriptions.append(" - \(`case`.key): \(caseDescription)")
        }
      }

      let combinedDescription: String?
      switch (description, valueDescriptions.isEmpty) {
      case (nil, true):
        combinedDescription = nil
      case (nil, false):
        combinedDescription = valueDescriptions.joined(separator: "\n")
      case (let description?, true):
        combinedDescription = description
      case (let description?, false):
        combinedDescription = [[description], valueDescriptions]
          .flatMap(\.self)
          .joined(separator: "\n")
      }

      if let combinedDescription {
        stream.encodeProperty(name: "description") { $0.encode(combinedDescription) }
      }

      stream.encodeProperty(name: "enum") { stream in
        stream.encodeArray { array in
          for value in possibleValues {
            array.encodeElement { $0.encode(value) }
          }
        }
      }
    }
  }

  private func encodeObjectPropertiesSchemaDefinition(
    to encoder: inout SchemaCoding.SchemaEncoder
  ) {
    let description = encoder.contextualDescription(description)
    encoder.stream.encodeObject { stream in
      if let description {
        stream.encodeProperty(name: "description") { $0.encode(description) }
      }

      /// This is implied by `properties`, and we're being economic with tokens.
      // stream.encodeProperty(name: "type") { $0.encode("object") }

      stream.encodeProperty(name: "properties") { stream in
        stream.encodeObject { stream in
          for `case` in repeat each cases {
            stream.encodeProperty(name: `case`.key.stringValue) { stream in
              stream.encodeSchemaDefinition(
                `case`.schema,
                descriptionPrefix: `case`.description
              )
            }
          }
        }
      }

      stream.encodeProperty(name: "minProperties") { $0.encode(1) }
      stream.encodeProperty(name: "maxProperties") { $0.encode(1) }

      /// We can add this if Claude begins hallucinating additional properties
      // stream.encodeProperty(name: "additionalProperties") { $0.encode(false) }
    }
  }

  func encode(_ value: Value, to encoder: inout SchemaCoding.SchemaValueEncoder) {
    let enumCaseEncoder = caseEncoder(
      value,
      repeat { value in
        SchemaCoding.EnumCaseEncoder(
          key: (each cases).key.stringValue,
          implementation: SchemaCoding.EnumCaseEncoderImplementation(
            schema: (each cases).schema,
            value: value
          )
        )
      }
    )
    switch style {
    case .singleCase:
      enumCaseEncoder.implementation.encode(to: &encoder.stream)
    case .noAssociatedValues:
      encoder.stream.encode(enumCaseEncoder.key)
    case .objectProperties:
      encoder.stream.encodeObject { objectEncoder in
        objectEncoder.encodeProperty(name: enumCaseEncoder.key) { stream in
          enumCaseEncoder.implementation.encode(to: &stream)
        }
      }
    }
  }

}

// MARK: - JSON Stream Decoding

extension StandardEnumSchema {

  typealias AssociatedValueDecodingStates = (
    repeat (each AssociatedValuesSchema).ValueDecodingState
  )

  typealias EnumCaseDecoder = @Sendable (
    inout SchemaCoding.SchemaValueDecoder,
    inout AssociatedValueDecodingStates
  ) throws -> SchemaCoding.DecodingResult<Value>

  struct EnumCaseDecoderProvider {
    init(cases: repeat StandardEnumSchemaCase<Value, each AssociatedValuesSchema>) {
      var decoders: [Substring: EnumCaseDecoder] = [:]
      var tupleArchetype = VariadicTupleArchetype<AssociatedValueDecodingStates>()
      for enumCase in repeat each cases {
        let accessor = tupleArchetype.nextElementAccessor(
          of: type(of: enumCase.schema.initialValueDecodingState)
        )
        let key = Substring(enumCase.key.stringValue)
        let decoder: EnumCaseDecoder = { decoder, states in
          try accessor.mutate(&states) { state in
            switch try enumCase.schema.decodeValue(from: &decoder, state: &state) {
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
      guard let decoder = decoders[caseName] else {
        throw Error.unknownEnumCase(allKeys: [String(caseName)])
      }
      return decoder
    }

    var singleCaseDecoder: EnumCaseDecoder {
      get throws {
        guard
          let decoder = decoders.values.first,
          decoders.count == 1
        else {
          assertionFailure()
          throw Error.invalidState
        }
        return decoder
      }
    }

    private let decoders: [Substring: EnumCaseDecoder]
  }

  struct ValueDecodingState {
    /// We can't have enums with parameter packs, so we just splat the associated values

    var associatedValueStates: AssociatedValueDecodingStates
    var objectState = JSON.ObjectDecodingState()
    var decoder: EnumCaseDecoder?
    var value: Value?
    var phase: EnumObjectDecodingPhase = .decodingPrologue
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
    switch style {
    case .singleCase:
      return try decoderProvider.singleCaseDecoder(&decoder, &state.associatedValueStates)
    case .noAssociatedValues:
      switch try decoder.stream.decodeString() {
      case .needsMoreData:
        return .needsMoreData
      case .decoded(let name):
        for `case` in repeat each cases {
          if name == `case`.key.stringValue {
            return try .decoded(`case`.initializeVoidSchemaValue())
          }
        }
        throw Error.unknownEnumCase(allKeys: [String(name)])
      }
    case .objectProperties:
      while true {
        if let caseDecoder = state.decoder {
          /// We are decoding the value
          switch try caseDecoder(&decoder, &state.associatedValueStates) {
          case .needsMoreData:
            return .needsMoreData
          case .decoded(let value):
            state.decoder = nil
            state.value = value
          }
        } else if let value = state.value {
          /// We are decoding the epilogue
          switch try decoder.stream.decodeObjectComponent(&state.objectState) {
          case .needsMoreData:
            return .needsMoreData
          case .decoded(.propertyValueStart(let name)):
            throw Error.additionalPropertyFound(String(name))
          case .decoded(.end):
            return .decoded(value)
          }
        } else {
          /// We are decoding the prologue
          switch try decoder.stream.decodeObjectComponent(&state.objectState) {
          case .needsMoreData:
            return .needsMoreData
          case .decoded(.propertyValueStart(let name)):
            state.decoder = try decoderProvider.decoder(for: name)
          case .decoded(.end):
            throw Error.unknownEnumCase(allKeys: [])
          }
        }
      }
    }
  }

}

// MARK: - Implementation Details

private enum EnumObjectDecodingPhase {
  case decodingPrologue
  case decodingEpilogue
}

private enum EnumStyle {
  case singleCase
  case noAssociatedValues
  case objectProperties
}

private struct StandardEnumSchemaCase<
  Value,
  AssociatedValuesSchema: SchemaCoding.Schema
> {
  let key: SchemaCoding.CodingKey
  let description: String?
  let schema: AssociatedValuesSchema
  let initializer: @Sendable (AssociatedValuesSchema.Value) -> Value

  func initializeVoidSchemaValue() throws -> Value {
    guard let value = () as? AssociatedValuesSchema.Value else {
      throw Error.expectedVoidSchema
    }
    return initializer(value)
  }
}

private enum Error: Swift.Error {
  case invalidState
  case additionalPropertyFound(String)
  case multipleEnumCasesWithSameName(String)
  case expectedNull
  case expectedVoidSchema
  case unknownEnumCase(allKeys: [String])
}

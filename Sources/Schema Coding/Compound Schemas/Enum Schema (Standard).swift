import JSONSupport

// MARK: - Defining Schemas

/// This extension defines a family of `enumSchema` methods.
/// These are intended to be added to enums via a macro and so are structured to be very regular.
extension SchemaProvider {

  @_disfavoredOverload
  public static func enumSchema<
    Value,
    CaseKey: CodingKey,
    each AssociatedValuesSchema: Schema
  >(
    representing _: Value.Type,
    description: String?,
    keyedBy _: CaseKey.Type,
    cases: (
      repeat (
        key: CaseKey,
        description: String?,
        associatedValuesSchema: each AssociatedValuesSchema,
        initializer: @Sendable ((each AssociatedValuesSchema).Value) -> Value
      )
    ),
    caseEncoder: @escaping @Sendable (
      Value,
      repeat ((each AssociatedValuesSchema).Value) -> EnumCaseEncoder
    ) -> EnumCaseEncoder
  ) -> some Schema<Value> {
    StandardEnumSchema(
      description: description,
      cases: (repeat StandardEnumSchemaCase(
        key: (each cases).key,
        description: (each cases).description,
        schema: (each cases).associatedValuesSchema,
        initializer: (each cases).initializer
      )),
      caseEncoder: caseEncoder
    )
  }

}

// MARK: - Encoding Enums

extension SchemaProvider {

  public struct EnumCaseEncoder {
    fileprivate let key: String
    fileprivate let implementation: EnumCaseEncoderImplementationProtocol
  }

  fileprivate protocol EnumCaseEncoderImplementationProtocol {
    func encode(to stream: inout JSON.EncodingStream)
  }

  fileprivate struct EnumCaseEncoderImplementation<
    Schema: SchemaCoding.Schema
  >: EnumCaseEncoderImplementationProtocol {
    func encode(to stream: inout JSON.EncodingStream) {
      schema.encode(value, to: &stream)
    }
    let schema: Schema
    let value: Schema.Value
  }

}

// MARK: - Defining Associated Values

extension SchemaProvider {

  public static func enumCaseAssociatedValuesSchema<Key: CodingKey>(
    values: (),
    keyedBy: Key.Type
  ) -> some Schema<Void> {
    EnumCaseVoidAssociatedValueSchema()
  }

  public static func enumCaseAssociatedValuesSchema<
    Key: CodingKey,
    ValueSchema: Schema
  >(
    values: (
      key: Key?,
      schema: ValueSchema
    ),
    keyedBy: Key.Type
  ) -> some Schema<ValueSchema.Value> {
    values.schema
  }

  public static func enumCaseAssociatedValuesSchema<
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
  ) -> some Schema<(repeat (each ValueSchema).Value)> {
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

  public static func enumCaseAssociatedValuesSchema<
    Key: CodingKey,
    each ValueSchema: Schema
  >(
    values: (
      repeat (
        key: Key?,
        schema: each ValueSchema
      )
    ),
    keyedBy: Key.Type
  ) -> some Schema<(repeat (each ValueSchema).Value)> {
    TupleSchema(
      elements: (repeat (
        name: (each values).key?.stringValue,
        schema: (each values).schema
      ))
    )
  }

}

extension SchemaProvider {

  /// In the full enum schema, cases without associated values are represented using a `null` value.
  /// For example `{"myEnumCase":null}`
  private struct EnumCaseVoidAssociatedValueSchema: LeafSchema {

    typealias Value = Void

    let type: String = "null"

    func decodeValue(
      from stream: inout JSON.DecodingStream,
      state: inout ()
    ) throws -> JSON.DecodingResult<Void> {
      try stream.decodeNull()
    }

    func encode(_ value: Void, to stream: inout JSON.EncodingStream) {
      stream.encodeNull()
    }

  }

}

// MARK: - Schemas

// MARK: Case Iterable

// MARK: Standard Enum

private struct StandardEnumSchema<
  Value,
  CaseKey: CodingKey,
  each AssociatedValuesSchema: Schema
>: InternalSchema {

  typealias Cases = (repeat StandardEnumSchemaCase<Value, CaseKey, each AssociatedValuesSchema>)

  typealias CaseEncoder = @Sendable (
    Value,
    repeat @escaping ((each AssociatedValuesSchema).Value) -> SchemaProvider.EnumCaseEncoder
  ) -> SchemaProvider.EnumCaseEncoder

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
        if !(`case`.schema is any Schema<Void>) {
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

  func encodeSchemaDefinition(to encoder: inout SchemaEncoder) {
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
    to encoder: inout SchemaEncoder
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
    to encoder: inout SchemaEncoder
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
    to encoder: inout SchemaEncoder
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

  func encode(_ value: Value, to stream: inout JSON.EncodingStream) {
    let encoder = caseEncoder(
      value,
      repeat { value in
        SchemaProvider.EnumCaseEncoder(
          key: (each cases).key.stringValue,
          implementation: SchemaProvider.EnumCaseEncoderImplementation(
            schema: (each cases).schema,
            value: value
          )
        )
      }
    )
    switch style {
    case .singleCase:
      encoder.implementation.encode(to: &stream)
    case .noAssociatedValues:
      stream.encode(encoder.key)
    case .objectProperties:
      stream.encodeObject { objectEncoder in
        objectEncoder.encodeProperty(name: encoder.key) { stream in
          encoder.implementation.encode(to: &stream)
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
    inout JSON.DecodingStream,
    inout AssociatedValueDecodingStates
  ) throws -> JSON.DecodingResult<Value>

  struct EnumCaseDecoderProvider {
    init(cases: repeat StandardEnumSchemaCase<Value, CaseKey, each AssociatedValuesSchema>) {
      var decoders: [Substring: EnumCaseDecoder] = [:]
      var tupleArchetype = VariadicTupleArchetype<AssociatedValueDecodingStates>()
      for enumCase in repeat each cases {
        let accessor = tupleArchetype.nextElementAccessor(
          of: type(of: enumCase.schema.initialValueDecodingState)
        )
        let key = Substring(enumCase.key.stringValue)
        let decoder: EnumCaseDecoder = { stream, states in
          try accessor.mutate(&states) { state in
            switch try enumCase.schema.decodeValue(from: &stream, state: &state) {
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
    from stream: inout JSON.DecodingStream,
    state: inout ValueDecodingState
  ) throws -> JSON.DecodingResult<Value> {
    switch style {
    case .singleCase:
      return try decoderProvider.singleCaseDecoder(&stream, &state.associatedValueStates)
    case .noAssociatedValues:
      switch try stream.decodeString() {
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
        if let decoder = state.decoder {
          /// We are decoding the value
          switch try decoder(&stream, &state.associatedValueStates) {
          case .needsMoreData:
            return .needsMoreData
          case .decoded(let value):
            state.decoder = nil
            state.value = value
          }
        } else if let value = state.value {
          /// We are decoding the epilogue
          switch try stream.decodeObjectComponent(&state.objectState) {
          case .needsMoreData:
            return .needsMoreData
          case .decoded(.propertyValueStart(let name)):
            throw Error.additionalPropertyFound(String(name))
          case .decoded(.end):
            return .decoded(value)
          }
        } else {
          /// We are decoding the prologue
          switch try stream.decodeObjectComponent(&state.objectState) {
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
  CaseKey: CodingKey,
  AssociatedValuesSchema: Schema
> {
  let key: CaseKey
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

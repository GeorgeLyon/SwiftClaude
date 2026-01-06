private import SchemaCodingSupport

// MARK: - Cases

extension SchemaCoding.Support {

  public static func enumSchemaCase<Value, each Property>(
    name: SchemaCodingKey,
    description: String? = nil,
    @ParameterClauseSchemaBuilder
    associatedValues: () -> ParameterClauseObject<
      repeat each Property
    >,
    finishDecoding: @escaping (EnumCaseDecoder<repeat (each Property).Value>) -> Value
  ) -> EnumSchemaCase<
    Value,
    some ObjectSchema<(repeat (each Property).Value)>
  > {
    let associatedValues = associatedValues()
    let associatedValuesSchema = ConcreteObjectSchema(
      description: description,
      properties: TupleObjectSchemaProperties(
        repeat (each associatedValues.properties).objectProperty
      )
    )
    return EnumSchemaCase(
      name: name,
      associatedValuesSchema: associatedValuesSchema,
      finishDecoding: { associatedValues in
        finishDecoding(EnumCaseDecoder(repeat each associatedValues))
      }
    )
  }

  public static func enumSchemaCase<Value, Property>(
    name: SchemaCodingKey,
    description: String? = nil,
    @ParameterClauseSchemaBuilder
    associatedValues: () -> ParameterClauseObject<Property>,
    finishDecoding: @escaping (EnumSingleAssociatedValueCaseDecoder<Property.Value>) -> Value
  ) -> EnumSchemaCase<
    Value,
    some ObjectSchema<Property.Value>
  > {
    let associatedValues = associatedValues()
    let associatedValuesSchema = ConcreteObjectSchema(
      description: description,
      properties: associatedValues.properties.objectProperty
    )
    return EnumSchemaCase(
      name: name,
      associatedValuesSchema: associatedValuesSchema,
      finishDecoding: { associatedValues in
        finishDecoding(EnumSingleAssociatedValueCaseDecoder(associatedValues))
      }
    )
  }

  public static func enumSchemaCase<Value, each ElementSchema>(
    name: SchemaCodingKey,
    description: String? = nil,
    @ParameterClauseSchemaBuilder
    associatedValues: () -> ParameterClauseTuple<repeat each ElementSchema>,
    finishDecoding: @escaping (EnumCaseDecoder<repeat (each ElementSchema).Value>) -> Value
  ) -> EnumSchemaCase<
    Value,
    some Schema<(repeat (each ElementSchema).Value)>
  > {
    let associatedValues = associatedValues()
    let associatedValuesSchema = TupleSchema(
      description: description,
      elements: repeat each associatedValues.elements
    )
    return EnumSchemaCase(
      name: name,
      associatedValuesSchema: associatedValuesSchema,
      finishDecoding: { associatedValues in
        finishDecoding(EnumCaseDecoder(repeat each associatedValues))
      }
    )
  }

  public static func enumSchemaCase<Value, AssociatedValuesSchema>(
    name: SchemaCodingKey,
    @ParameterClauseSchemaBuilder
    associatedValues: () -> ParameterClauseTuple<AssociatedValuesSchema>,
    finishDecoding:
      @escaping (EnumSingleAssociatedValueCaseDecoder<AssociatedValuesSchema.Value>) -> Value
  ) -> EnumSchemaCase<
    Value,
    AssociatedValuesSchema
  > {
    let associatedValues = associatedValues()
    return EnumSchemaCase(
      name: name,
      associatedValuesSchema: associatedValues.elements.schema,
      finishDecoding: { associatedValues in
        finishDecoding(EnumSingleAssociatedValueCaseDecoder(associatedValues))
      }
    )
  }

  public struct EnumSchemaCase<
    Value,
    AssociatedValuesSchema: Schema
  > {

    let name: SchemaCodingKey
    let associatedValuesSchema: AssociatedValuesSchema
    let finishDecoding: (AssociatedValuesSchema.Value) -> Value

  }

  public struct EnumCaseDecoder<each AssociatedValue> {
    public let associatedValues: (repeat each AssociatedValue)
    init(_ associatedValues: repeat each AssociatedValue) {
      self.associatedValues = (repeat each associatedValues)
    }
  }

  public struct EnumSingleAssociatedValueCaseDecoder<AssociatedValue> {
    public let associatedValues: (AssociatedValue, ())
    init(_ associatedValue: AssociatedValue) {
      self.associatedValues = (associatedValue, ())
    }
  }

}

extension SchemaCoding.Support {

  @resultBuilder
  public enum EnumSchemaCasesBuilder<Value> {

    public static func buildBlock() -> EnumSchemaCases<Value> {
      EnumSchemaCases()
    }

    public static func buildPartialBlock<Schema>(
      first: EnumSchemaCase<Value, Schema>
    ) -> EnumSchemaCases<Value, Schema> {
      EnumSchemaCases(first)
    }

    public static func buildPartialBlock<each Schema, NextSchema>(
      accumulated: EnumSchemaCases<Value, repeat each Schema>,
      next: EnumSchemaCase<Value, NextSchema>
    ) -> EnumSchemaCases<Value, repeat each Schema, NextSchema> {
      EnumSchemaCases(repeat each accumulated.cases, next)
    }

  }

  public struct EnumSchemaCases<
    Value,
    each AssociatedValueSchema: SchemaCoding.Schema
  > {
    let cases: (repeat EnumSchemaCase<Value, each AssociatedValueSchema>)

    fileprivate init(
      _ cases: repeat EnumSchemaCase<Value, each AssociatedValueSchema>
    ) {
      self.cases = (repeat each cases)
    }

  }

}

// MARK: - Decoding

extension SchemaCoding {

  public typealias EnumCaseDecoder = Support.EnumCaseDecoder
  public typealias EnumSingleAssociatedValueCaseDecoder = Support
    .EnumSingleAssociatedValueCaseDecoder

}

extension SchemaCoding.Support {

  protocol EnumSchemaCaseProtocol<Value> {
    associatedtype Value
    associatedtype Decoder: EnumSchemaCaseDecoderProtocol where Decoder.Value == Value
    func beginDecoding(from decoder: borrowing SchemaCoding.Support.Decoder) -> Decoder
  }

  protocol EnumSchemaCaseDecoderProtocol<Value> {
    associatedtype Value
    func decode(from decoder: inout Decoder) throws -> DecodingResult<Void>
    func finishDecoding(from decoder: borrowing Decoder) throws -> Value
  }

  struct EnumSchemaCaseDecoder<
    Value,
    AssociatedValueSchema: Schema
  >: EnumSchemaCaseDecoderProtocol {

    init(
      `case`: EnumSchemaCase<Value, AssociatedValueSchema>,
      decoder: borrowing Decoder,
    ) {
      self.schema = `case`.associatedValuesSchema
      self.finishDecoding = `case`.finishDecoding
      self.reference = decoder.arena.push(.decoding(schema.beginDecodingValue(from: decoder)))
    }

    func decode(from decoder: inout Decoder) throws -> DecodingResult<Void> {
      try decoder.arena.withValue(reference) { state in
        switch state {
        case .decoded:
          throw Error.alreadyDecoded
        case .decoding(var decodingState):
          switch try schema.decodeValue(from: &decoder, state: &decodingState).kind {
          case .incomplete:
            state = .decoding(decodingState)
            return .incomplete
          case .decoded(let value):
            state = .decoded(value)
            return .decoded
          }
        }
      }
    }

    func finishDecoding(from decoder: borrowing Decoder) throws -> Value {
      switch decoder.arena[reference] {
      case .decoded(let value):
        return finishDecoding(value)
      case .decoding:
        throw Error.partiallyDecoded
      }
    }

    private enum State {
      case decoding(AssociatedValueSchema.ValueDecodingState)
      case decoded(AssociatedValueSchema.Value)
    }
    private let reference: Arena.Reference<State>

    private let schema: AssociatedValueSchema
    private let finishDecoding: (AssociatedValueSchema.Value) -> Value

  }

}

extension SchemaCoding.Support.EnumSchemaCase: SchemaCoding.Support.EnumSchemaCaseProtocol {
  func beginDecoding(
    from decoder: borrowing SchemaCoding.Support.Decoder
  ) -> SchemaCoding.Support.EnumSchemaCaseDecoder<Value, AssociatedValuesSchema> {
    SchemaCoding.Support.EnumSchemaCaseDecoder(case: self, decoder: decoder)
  }
}

// MARK: - Errors

private enum Error: Swift.Error {
  case alreadyDecoded
  case partiallyDecoded
}

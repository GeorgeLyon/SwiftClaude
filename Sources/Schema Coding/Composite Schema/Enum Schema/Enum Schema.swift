private import JSONSupport
private import SchemaCodingSupport

// MARK: - Public API

extension SchemaCoding.Support {

  @_disfavoredOverload
  public static func enumSchema<
    Value,
    each AssociatedValuesSchema
  >(
    representing: Value.Type = Value.self,
    description: String? = nil,
    style: EnumSchemaStyleStandard = .standard,
    @EnumSchemaCasesBuilder<Value>
    cases: () -> EnumSchemaCases<Value, repeat each AssociatedValuesSchema>,
    encodeValue:
      @escaping (
        Value,
        inout EnumSchemaEncoder<repeat each AssociatedValuesSchema>,
      ) -> Void
  ) -> some Schema<Value> {
    EnumSchema(
      description: description,
      cases: repeat each cases().cases,
      encodeValue: encodeValue
    )
  }

  /// Single-case enums hit a compiler bug which ends up crashing the compiler.
  public static func enumSchema<
    Value,
    AssociatedValuesSchema
  >(
    representing: Value.Type = Value.self,
    description: String? = nil,
    style: EnumSchemaStyleStandard = .standard,
    @EnumSchemaCasesBuilder<Value>
    cases: () -> EnumSchemaCases<Value, AssociatedValuesSchema>,
    encodeValue:
      @escaping (
        Value,
        inout EnumSchemaSingleCaseEncoder<AssociatedValuesSchema>,
      ) -> Void
  ) -> some Schema<Value> {
    EnumSchema(
      description: description,
      cases: cases().cases,
      encodeValue: { value, encoder in
        var singleCaseEncoder = EnumSchemaSingleCaseEncoder(wrapped: encoder)
        encodeValue(value, &singleCaseEncoder)
        encoder = singleCaseEncoder.wrapped
      }
    )
  }

}

// MARK: - Schema

extension SchemaCoding.Support {

  struct EnumSchema<
    Value,
    each AssociatedValuesSchema: Schema
  >: Schema {

    func encode(_ value: Value, to encoder: inout SchemaCoding.Support.Encoder) {
      var enumEncoder = EnumSchemaEncoder(
        encodings: (repeat EnumSchemaCaseEncoding(
          name: (each cases).name.stringValue,
          schema: (each cases).associatedValuesSchema
        )),
        valueEncoder: encoder
      )
      encodeValue(value, &enumEncoder)
      assert(enumEncoder.isEncoded)
      encoder = enumEncoder.valueEncoder
    }

    struct ValueDecodingState {
      fileprivate var objectState = JSON.ObjectDecodingState()
      fileprivate var caseDecoder: (any EnumSchemaCaseDecoderProtocol<Value>)?
    }

    func beginDecodingValue(from decoder: borrowing Decoder) -> ValueDecodingState {
      ValueDecodingState()
    }

    func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value> {
      while true {
        if let caseDecoder = state.caseDecoder {
          switch try caseDecoder.decode(from: &decoder).kind {
          case .incomplete:
            return .incomplete
          case .decoded:
            break
          }
        }

        switch try decoder.stream.decodeObjectComponent(state: &state.objectState) {
        case .incomplete:
          return .incomplete
        case .decoded(.propertyValueStart(let name)):
          guard state.caseDecoder == nil else {
            throw Error.multipleCasesPresent
          }
          guard let `case` = casesByName[name] else {
            throw Error.unknownCase(String(name))
          }
          state.caseDecoder = `case`.beginDecoding(from: decoder)
        case .decoded(.end):
          guard let caseDecoder = state.caseDecoder else {
            throw Error.noCaseFound
          }
          return .decoded(try `caseDecoder`.finishDecoding(from: decoder))
        }
      }
    }

    typealias MetaSchema = WrapperSchema<
      Self,
      ConcreteObjectSchema<
        TupleObjectSchemaProperties<
          OptionalObjectProperty<StringSchema>,
          RequiredObjectProperty<
            ConcreteObjectSchema<
              TupleObjectSchemaProperties<
                repeat RequiredObjectProperty<(each AssociatedValuesSchema).MetaSchema>
              >
            >
          >
        >
      >
    >
    var metaSchema: MetaSchema {
      let objectSchema = ConcreteObjectSchema {
        OptionalObjectProperty(
          name: .description,
          schema: StringSchema()
        )
        RequiredObjectProperty(
          name: .properties,
          schema: ConcreteObjectSchema(
            properties: repeat RequiredObjectProperty(
              name: (each cases).name,
              schema: (each cases).associatedValuesSchema.metaSchema
            )
          )
        )
      }
      return objectSchema.wrap { (description, schemas) -> Self in
        Self(
          description: description,
          cases: repeat EnumSchemaCase(
            name: (each cases).name,
            associatedValuesSchema: each schemas,
            finishDecoding: (each cases).finishDecoding
          ),
          encodeValue: encodeValue
        )
      } unwrap: { schema in
        (schema.description, (repeat (each schema.cases).associatedValuesSchema))
      }
    }

    init(
      description: String? = nil,
      cases: repeat EnumSchemaCase<Value, each AssociatedValuesSchema>,
      encodeValue:
        @escaping (
          Value,
          inout EnumSchemaEncoder<repeat each AssociatedValuesSchema>
        ) -> Void
    ) {
      self.metadata = SchemaMetadata(description: description)
      self.cases = (repeat each cases)

      var casesByName: [Substring: any EnumSchemaCaseProtocol<Value>] = [:]
      for `case` in repeat each cases {
        let oldCase = casesByName.updateValue(
          `case`,
          forKey: Substring(`case`.name.stringValue))
        assert(oldCase == nil)
      }
      self.casesByName = casesByName

      self.encodeValue = encodeValue
    }

    var metadata: SchemaMetadata

    fileprivate let cases: (repeat EnumSchemaCase<Value, each AssociatedValuesSchema>)
    fileprivate let casesByName: [Substring: any EnumSchemaCaseProtocol<Value>]
    fileprivate let encodeValue:
      (
        Value,
        inout EnumSchemaEncoder<repeat each AssociatedValuesSchema>
      ) -> Void

  }

}

// MARK: - Style

extension SchemaCoding.Support {

  public struct EnumSchemaStyleStandard: Style {
    fileprivate init() {}
  }

}

extension SchemaCoding.Support.Style
where Self == SchemaCoding.Support.EnumSchemaStyleStandard {
  public static var standard: Self {
    Self()
  }
}

// MARK: - Encoding

extension SchemaCoding.Support {

  public struct EnumSchemaCaseEncoding<Schema: SchemaCoding.Schema> {
    fileprivate let name: String
    fileprivate let schema: Schema
  }
  public struct EnumSchemaEncoder<each AssociatedValueSchema: Schema>: ~Copyable {

    public let encodings: (repeat EnumSchemaCaseEncoding<each AssociatedValueSchema>)

    public mutating func encode<Schema: SchemaCoding.Schema>(
      _ value: Schema.Value,
      using encoding: EnumSchemaCaseEncoding<Schema>,
    ) {
      guard !isEncoded else {
        assertionFailure()
        return
      }
      isEncoded = true

      valueEncoder.stream.encodeObject { objectEncoder in
        objectEncoder.encodeProperty(name: encoding.name) { stream in
          stream.encode(value, using: encoding.schema)
        }
      }
    }

    fileprivate var isEncoded = false
    fileprivate var valueEncoder: Encoder

  }
  public struct EnumSchemaSingleCaseEncoder<AssociatedValueSchema: Schema>: ~Copyable {

    /// Allows using `.0` even with a single enum case
    public var encodings: (EnumSchemaCaseEncoding<AssociatedValueSchema>, Void) {
      (wrapped.encodings, ())
    }

    public mutating func encode<Schema: SchemaCoding.Schema>(
      _ value: Schema.Value,
      using encoding: EnumSchemaCaseEncoding<Schema>,
    ) {
      wrapped.encode(value, using: encoding)
    }

    fileprivate var wrapped: EnumSchemaEncoder<AssociatedValueSchema>

  }

}

// MARK: - Errors

private enum Error: Swift.Error {
  case multipleCasesPresent
  case unknownCase(String)
  case noCaseFound
}

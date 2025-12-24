private import JSONSupport

// MARK: - Public API

extension SchemaCoding.Support {

  @_disfavoredOverload
  public static func enumSchema<
    Value,
    each AssociatedValuesSchema: ObjectSchema
  >(
    representing: Value.Type = Value.self,
    description: String? = nil,
    style: EnumSchemaStyleInternallyTagged,
    @EnumSchemaCasesBuilder<Value>
    cases: () -> EnumSchemaCases<Value, repeat each AssociatedValuesSchema>,
    encodeValue:
      @escaping (
        Value,
        inout InternallyTaggedEnumSchemaEncoder<repeat each AssociatedValuesSchema>,
      ) -> Void
  ) -> some Schema<Value> {
    InternallyTaggedEnumSchema(
      description: description,
      discriminatorPropertyName: style.discriminatorPropertyName,
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
    style: EnumSchemaStyleInternallyTagged,
    @EnumSchemaCasesBuilder<Value>
    cases: () -> EnumSchemaCases<Value, AssociatedValuesSchema>,
    encodeValue:
      @escaping (
        Value,
        inout InternallyTaggedEnumSchemaSingleCaseEncoder<AssociatedValuesSchema>,
      ) -> Void
  ) -> some Schema<Value> {
    InternallyTaggedEnumSchema(
      description: description,
      discriminatorPropertyName: style.discriminatorPropertyName,
      cases: cases().cases,
      encodeValue: { value, encoder in
        var singleCaseEncoder = InternallyTaggedEnumSchemaSingleCaseEncoder(wrapped: encoder)
        encodeValue(value, &singleCaseEncoder)
        encoder = singleCaseEncoder.wrapped
      }
    )
  }

}

// MARK: - Schema

extension SchemaCoding.Support {

  struct InternallyTaggedEnumSchema<
    Value,
    each AssociatedValuesSchema: ObjectSchema
  >: Schema {

    func encode(_ value: Value, to encoder: inout SchemaCoding.Support.Encoder) {
      var enumEncoder = InternallyTaggedEnumSchemaEncoder(
        encodings: (repeat InternallyTaggedEnumSchemaCaseEncoding<each AssociatedValuesSchema>(
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
      var caseDecoder: (any EnumSchemaCaseDecoderProtocol<Value>)?
    }

    func beginDecodingValue(from decoder: borrowing Decoder) -> ValueDecodingState {
      ValueDecodingState()
    }

    func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value> {
      let caseDecoder: any EnumSchemaCaseDecoderProtocol<Value>
      if let activeDecoder = state.caseDecoder {
        caseDecoder = activeDecoder
      } else {
        let peekResult = try decoder.stream.peekObjectProperty(
          discriminatorPropertyName.stringValue
        ) {
          stream in
          try stream.decodeString()
        }
        switch peekResult {
        case .incomplete:
          return .incomplete
        case .decoded(.none):
          throw Error.discriminatorNotFound
        case .decoded(let discriminator?):
          guard let `case` = casesByName[discriminator] else {
            throw Error.unknownCase(String(discriminator))
          }
          caseDecoder = `case`.beginDecoding(from: decoder)
          state.caseDecoder = caseDecoder
        }
      }

      switch try caseDecoder.decode(from: &decoder).kind {
      case .incomplete:
        return .incomplete
      case .decoded:
        return .decoded(try caseDecoder.finishDecoding(from: decoder))
      }
    }

    typealias MetaSchema = WrapperSchema<
      Self,
      ConcreteObjectSchema<
        TupleObjectSchemaProperties<
          OptionalObjectProperty<StringSchema>,
          RequiredObjectProperty<
            TupleSchema<repeat InternallyTaggedSchema<each AssociatedValuesSchema>.MetaSchema>
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
          name: .oneOf,
          schema: TupleSchema(
            elementSchemas: repeat (each cases).associatedValuesSchema.metaSchema
          )
        )
      }
      return objectSchema.wrap { (description, associatedValueSchemas) in
        Self(
          description: description,
          discriminatorPropertyName: discriminatorPropertyName,
          cases: repeat EnumSchemaCase(
            name: (each cases).name,
            associatedValuesSchema: (each associatedValueSchemas),
            finishDecoding: (each cases).finishDecoding
          ),
          encodeValue: encodeValue
        )
      } unwrap: { schema in
        (description, (repeat (each schema.cases).associatedValuesSchema))
      }
    }

    init(
      description: String? = nil,
      discriminatorPropertyName: SchemaCodingKey,
      cases: repeat EnumSchemaCase<Value, each AssociatedValuesSchema>,
      encodeValue:
        @escaping (
          Value,
          inout InternallyTaggedEnumSchemaEncoder<repeat each AssociatedValuesSchema>
        ) -> Void
    ) {
      self.init(
        description: description,
        discriminatorPropertyName: discriminatorPropertyName,
        cases: repeat (each cases).internallyTagged(
          discriminatorPropertyName: discriminatorPropertyName),
        encodeValue: encodeValue
      )
    }

    var metadata: SchemaMetadata

    init(
      description: String? = nil,
      discriminatorPropertyName: SchemaCodingKey,
      cases: repeat EnumSchemaCase<Value, InternallyTaggedSchema<each AssociatedValuesSchema>>,
      encodeValue:
        @escaping (
          Value,
          inout InternallyTaggedEnumSchemaEncoder<repeat each AssociatedValuesSchema>
        ) -> Void
    ) {
      self.metadata = SchemaMetadata(description: description)
      self.discriminatorPropertyName = discriminatorPropertyName
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
    private let discriminatorPropertyName: SchemaCodingKey
    private let cases:
      (
        repeat EnumSchemaCase<
          Value,
          InternallyTaggedSchema<each AssociatedValuesSchema>
        >
      )
    private let casesByName: [Substring: any EnumSchemaCaseProtocol<Value>]
    private let encodeValue:
      (
        Value,
        inout InternallyTaggedEnumSchemaEncoder<repeat each AssociatedValuesSchema>
      ) -> Void
  }

}

// MARK: - Style

extension SchemaCoding.Support {

  public struct EnumSchemaStyleInternallyTagged: Style {
    fileprivate let discriminatorPropertyName: SchemaCodingKey
  }

}

extension SchemaCoding.Support.Style
where Self == SchemaCoding.Support.EnumSchemaStyleInternallyTagged {
  public static func internallyTagged(
    discriminatorPropertyName: SchemaCoding.Support.SchemaCodingKey
  ) -> Self {
    Self(discriminatorPropertyName: discriminatorPropertyName)
  }
}

// MARK: - Cases

extension SchemaCoding.Support.EnumSchemaCase
where AssociatedValuesSchema: SchemaCoding.ObjectSchema {

  func internallyTagged(
    discriminatorPropertyName: SchemaCoding.Support.SchemaCodingKey
  )
    -> SchemaCoding.Support.EnumSchemaCase<
      Value,
      SchemaCoding.Support.InternallyTaggedSchema<AssociatedValuesSchema>
    >
  {
    let schema = SchemaCoding.Support.ConcreteObjectSchema(
      description: associatedValuesSchema.description,
      properties: SchemaCoding.Support.CompositeObjectSchemaProperties(
        SchemaCoding.Support.TupleObjectSchemaProperties(
          SchemaCoding.Support.RequiredObjectProperty(
            name: discriminatorPropertyName,
            schema: SchemaCoding.Support.ConstantSchema(
              wrappedSchema: SchemaCoding.Support.StringSchema(),
              constantValue: name.stringValue
            )
          )
        ),
        associatedValuesSchema.properties
      )
    )
    return SchemaCoding.Support.EnumSchemaCase<Value, _>(
      name: name,
      associatedValuesSchema: schema,
      finishDecoding: { (_, value) in
        finishDecoding(value)
      }
    )
  }

}

// MARK: - Internally Tagged Schema

extension SchemaCoding.Support {

  typealias InternallyTaggedSchema<
    WrappedSchema: ObjectSchema
  > = ConcreteObjectSchema<
    CompositeObjectSchemaProperties<
      TupleObjectSchemaProperties<
        RequiredObjectProperty<
          ConstantSchema<
            StringSchema
          >
        >
      >,
      WrappedSchema.Properties
    >
  >

}

// MARK: - Encoding

extension SchemaCoding.Support {

  public struct InternallyTaggedEnumSchemaCaseEncoding<
    Schema: SchemaCoding.ObjectSchema
  > {
    fileprivate let name: String
    fileprivate let schema: InternallyTaggedSchema<Schema>
  }
  public struct InternallyTaggedEnumSchemaEncoder<
    each AssociatedValueSchema: ObjectSchema
  >: ~Copyable {

    public let encodings:
      (
        repeat InternallyTaggedEnumSchemaCaseEncoding<
          each AssociatedValueSchema
        >
      )

    public mutating func encode<Schema: SchemaCoding.Schema>(
      _ value: Schema.Value,
      using encoding: InternallyTaggedEnumSchemaCaseEncoding<Schema>,
    ) {
      guard !isEncoded else {
        assertionFailure()
        return
      }
      isEncoded = true

      valueEncoder.stream.encode(((), value), using: encoding.schema)
    }

    fileprivate var isEncoded = false
    fileprivate var valueEncoder: Encoder

  }
  public struct InternallyTaggedEnumSchemaSingleCaseEncoder<
    AssociatedValueSchema: ObjectSchema
  >: ~Copyable {

    /// Allows using `.0` even with a single enum case
    public var encodings: (InternallyTaggedEnumSchemaCaseEncoding<AssociatedValueSchema>, Void) {
      (wrapped.encodings, ())
    }

    public mutating func encode<Schema: SchemaCoding.Schema>(
      _ value: Schema.Value,
      using encoding: InternallyTaggedEnumSchemaCaseEncoding<Schema>,
    ) {
      wrapped.encode(value, using: encoding)
    }

    fileprivate var wrapped: InternallyTaggedEnumSchemaEncoder<AssociatedValueSchema>

  }

}

// MARK: - Errors

private enum Error: Swift.Error {
  case discriminatorNotFound
  case unknownCase(String)
}

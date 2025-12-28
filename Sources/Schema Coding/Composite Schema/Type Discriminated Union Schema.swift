private import JSONSupport

extension SchemaCoding.Support {

  public static func typeDiscriminatedUnionSchema<
    Value,
    NullSchema: Schema,
    BooleanSchema: Schema,
    NumberSchema: Schema,
    StringSchema: Schema,
    ArraySchema: Schema,
    ObjectSchema: Schema
  >(
    representing: Value.Type = Value.self,
    null: TypeDiscriminatedUnionSchemaCase<Value, NullSchema>,
    boolean: TypeDiscriminatedUnionSchemaCase<Value, BooleanSchema>,
    number: TypeDiscriminatedUnionSchemaCase<Value, NumberSchema>,
    string: TypeDiscriminatedUnionSchemaCase<Value, StringSchema>,
    array: TypeDiscriminatedUnionSchemaCase<Value, ArraySchema>,
    object: TypeDiscriminatedUnionSchemaCase<Value, ObjectSchema>,
    encodeValue:
      @escaping (
        Value,
        inout TypeDiscriminatedUnionSchemaCaseEncoder<
          NullSchema,
          BooleanSchema,
          NumberSchema,
          StringSchema,
          ArraySchema,
          ObjectSchema
        >
      ) -> Void
  ) -> some Schema<Value> {
    TypeDiscriminatedUnionSchema(
      metadata: SchemaMetadata(description: nil),
      null: null,
      boolean: boolean,
      number: number,
      string: string,
      array: array,
      object: object,
      encodeValue: encodeValue
    )
  }

  public struct TypeDiscriminatedUnionSchemaCase<Value, Schema: SchemaCoding.Schema> {
    public init(
      schema: Schema,
      finishDecoding: @escaping (Schema.Value) -> Value
    ) {
      self.isInhabited = true
      self.schema = schema
      self.finishDecoding = finishDecoding
    }

    static func never(_ value: Value.Type = Value.self) -> Self
    where Schema == NeverSchema {
      Self(
        isInhabited: false,
        schema: NeverSchema(),
        finishDecoding: { (_: Never) -> Value in }
      )
    }

    private init(
      isInhabited: Bool,
      schema: Schema,
      finishDecoding: @escaping (Schema.Value) -> Value
    ) {
      self.isInhabited = isInhabited
      self.schema = schema
      self.finishDecoding = finishDecoding
    }
    fileprivate let isInhabited: Bool
    fileprivate let schema: Schema
    fileprivate let finishDecoding: (Schema.Value) -> Value
  }

}

extension SchemaCoding.Support {

  struct TypeDiscriminatedUnionSchema<
    Value,
    NullSchema: Schema,
    BooleanSchema: Schema,
    NumberSchema: Schema,
    StringSchema: Schema,
    ArraySchema: Schema,
    ObjectSchema: Schema
  >: Schema {

    func encode(_ value: Value, to encoder: inout Encoder) {
      var caseEncoder = CaseEncoder(
        nullEncoding: .init(schema: null.schema),
        booleanEncoding: .init(schema: boolean.schema),
        numberEncoding: .init(schema: number.schema),
        stringEncoding: .init(schema: string.schema),
        arrayEncoding: .init(schema: array.schema),
        objectEncoding: .init(schema: object.schema),
        wrapped: encoder
      )
      encodeValue(value, &caseEncoder)
      assert(caseEncoder.isEncoded)
      encoder = caseEncoder.wrapped
    }

    struct ValueDecodingState {
      enum Phase {
        case determiningKind
        case decodingValue(MemberState)
      }
      enum MemberState {
        case null(NullSchema.ValueDecodingState)
        case boolean(BooleanSchema.ValueDecodingState)
        case number(NumberSchema.ValueDecodingState)
        case string(StringSchema.ValueDecodingState)
        case array(ArraySchema.ValueDecodingState)
        case object(ObjectSchema.ValueDecodingState)
      }
      var phase: Phase = .determiningKind
    }

    func beginDecodingValue(from decoder: borrowing Decoder) -> ValueDecodingState {
      ValueDecodingState()
    }

    func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value> {
      var memberState: ValueDecodingState.MemberState
      switch state.phase {
      case .determiningKind:
        switch try decoder.stream.peekValueKind() {
        case .incomplete:
          return .incomplete
        case .decoded(let kind):
          switch kind {
          case .null:
            memberState = .null(null.schema.beginDecodingValue(from: decoder))
          case .boolean:
            memberState = .boolean(boolean.schema.beginDecodingValue(from: decoder))
          case .number:
            memberState = .number(number.schema.beginDecodingValue(from: decoder))
          case .string:
            memberState = .string(string.schema.beginDecodingValue(from: decoder))
          case .array:
            memberState = .array(array.schema.beginDecodingValue(from: decoder))
          case .object:
            memberState = .object(object.schema.beginDecodingValue(from: decoder))
          }
        }
      case .decodingValue(let state):
        memberState = state
      }

      switch memberState {
      case .null(var nullState):
        switch try null.schema.decodeValue(from: &decoder, state: &nullState).kind {
        case .incomplete:
          state.phase = .decodingValue(.null(nullState))
          return .incomplete
        case .decoded(let value):
          return .decoded(null.finishDecoding(value))
        }
      case .boolean(var booleanState):
        switch try boolean.schema.decodeValue(from: &decoder, state: &booleanState).kind {
        case .incomplete:
          state.phase = .decodingValue(.boolean(booleanState))
          return .incomplete
        case .decoded(let value):
          return .decoded(boolean.finishDecoding(value))
        }
      case .number(var numberState):
        switch try number.schema.decodeValue(from: &decoder, state: &numberState).kind {
        case .incomplete:
          state.phase = .decodingValue(.number(numberState))
          return .incomplete
        case .decoded(let value):
          return .decoded(number.finishDecoding(value))
        }
      case .string(var stringState):
        switch try string.schema.decodeValue(from: &decoder, state: &stringState).kind {
        case .incomplete:
          state.phase = .decodingValue(.string(stringState))
          return .incomplete
        case .decoded(let value):
          return .decoded(string.finishDecoding(value))
        }
      case .array(var arrayState):
        switch try array.schema.decodeValue(from: &decoder, state: &arrayState).kind {
        case .incomplete:
          state.phase = .decodingValue(.array(arrayState))
          return .incomplete
        case .decoded(let value):
          return .decoded(array.finishDecoding(value))
        }
      case .object(var objectState):
        switch try object.schema.decodeValue(from: &decoder, state: &objectState).kind {
        case .incomplete:
          state.phase = .decodingValue(.object(objectState))
          return .incomplete
        case .decoded(let value):
          return .decoded(object.finishDecoding(value))
        }
      }

    }

    typealias MetaSchema = WrapperSchema<
      Self,
      ConcreteObjectSchema<
        TupleObjectSchemaProperties<
          OptionalObjectProperty<SchemaCoding.Support.StringSchema>,
          DirectObjectProperty<
            TupleSchema<
              NullSchema.MetaSchema,
              BooleanSchema.MetaSchema,
              NumberSchema.MetaSchema,
              StringSchema.MetaSchema,
              ArraySchema.MetaSchema,
              ObjectSchema.MetaSchema
            >
          >
        >
      >
    >
    var metaSchema: MetaSchema {
      let objectSchema = ConcreteObjectSchema {
        OptionalObjectProperty(
          name: .description,
          schema: OptionalSchema(wrappedSchema: SchemaCoding.Support.StringSchema())
        )
        DirectObjectProperty(
          name: .oneOf,
          schema: TupleSchema(
            elements:
              TupleSchemaElement(
                schema: null.schema.metaSchema,
                kind: null.isInhabited ? .required : .omitted(constantValue: null.schema)
              ),
            TupleSchemaElement(
              schema: boolean.schema.metaSchema,
              kind: boolean.isInhabited ? .required : .omitted(constantValue: boolean.schema)
            ),
            TupleSchemaElement(
              schema: number.schema.metaSchema,
              kind: number.isInhabited ? .required : .omitted(constantValue: number.schema)
            ),
            TupleSchemaElement(
              schema: string.schema.metaSchema,
              kind: string.isInhabited ? .required : .omitted(constantValue: string.schema)
            ),
            TupleSchemaElement(
              schema: array.schema.metaSchema,
              kind: array.isInhabited ? .required : .omitted(constantValue: array.schema)
            ),
            TupleSchemaElement(
              schema: object.schema.metaSchema,
              kind: object.isInhabited ? .required : .omitted(constantValue: object.schema)
            )
          )
        )
      }
      return objectSchema.wrap { (description, schemas) in
        let (null, boolean, number, string, array, object) = schemas
        return Self(
          metadata: SchemaMetadata(description: description),
          null: TypeDiscriminatedUnionSchemaCase(
            schema: null,
            finishDecoding: self.null.finishDecoding
          ),
          boolean: TypeDiscriminatedUnionSchemaCase(
            schema: boolean,
            finishDecoding: self.boolean.finishDecoding
          ),
          number: TypeDiscriminatedUnionSchemaCase(
            schema: number,
            finishDecoding: self.number.finishDecoding
          ),
          string: TypeDiscriminatedUnionSchemaCase(
            schema: string,
            finishDecoding: self.string.finishDecoding
          ),
          array: TypeDiscriminatedUnionSchemaCase(
            schema: array,
            finishDecoding: self.array.finishDecoding
          ),
          object: TypeDiscriminatedUnionSchemaCase(
            schema: object,
            finishDecoding: self.object.finishDecoding
          ),
          encodeValue: self.encodeValue
        )
      } unwrap: { schema in
        (
          schema.metadata.description,
          (
            schema.null.schema,
            schema.boolean.schema,
            schema.number.schema,
            schema.string.schema,
            schema.array.schema,
            schema.object.schema
          )
        )
      }
    }

    var metadata: SchemaMetadata

    let null: TypeDiscriminatedUnionSchemaCase<Value, NullSchema>
    let boolean: TypeDiscriminatedUnionSchemaCase<Value, BooleanSchema>
    let number: TypeDiscriminatedUnionSchemaCase<Value, NumberSchema>
    let string: TypeDiscriminatedUnionSchemaCase<Value, StringSchema>
    let array: TypeDiscriminatedUnionSchemaCase<Value, ArraySchema>
    let object: TypeDiscriminatedUnionSchemaCase<Value, ObjectSchema>
    typealias CaseEncoder = TypeDiscriminatedUnionSchemaCaseEncoder<
      NullSchema,
      BooleanSchema,
      NumberSchema,
      StringSchema,
      ArraySchema,
      ObjectSchema
    >
    let encodeValue: (Value, inout CaseEncoder) -> Void
  }

}

// MARK: - Encoding

extension SchemaCoding.Support {

  public struct TypeDiscriminatedUnionSchemaCaseEncoding<
    Schema: SchemaCoding.Schema
  > {
    let schema: Schema
  }

  public struct TypeDiscriminatedUnionSchemaCaseEncoder<
    NullSchema: Schema,
    BooleanSchema: Schema,
    NumberSchema: Schema,
    StringSchema: Schema,
    ArraySchema: Schema,
    ObjectSchema: Schema
  >: ~Copyable {
    public let nullEncoding: TypeDiscriminatedUnionSchemaCaseEncoding<NullSchema>
    public let booleanEncoding: TypeDiscriminatedUnionSchemaCaseEncoding<BooleanSchema>
    public let numberEncoding: TypeDiscriminatedUnionSchemaCaseEncoding<NumberSchema>
    public let stringEncoding: TypeDiscriminatedUnionSchemaCaseEncoding<StringSchema>
    public let arrayEncoding: TypeDiscriminatedUnionSchemaCaseEncoding<ArraySchema>
    public let objectEncoding: TypeDiscriminatedUnionSchemaCaseEncoding<ObjectSchema>

    public mutating func encode<Schema>(
      _ value: Schema.Value,
      using encoding: TypeDiscriminatedUnionSchemaCaseEncoding<Schema>
    ) {
      guard !isEncoded else {
        assertionFailure()
        return
      }
      isEncoded = true

      wrapped.stream.encode(value, using: encoding.schema)
    }

    fileprivate var wrapped: Encoder
    fileprivate var isEncoded = false
  }

}

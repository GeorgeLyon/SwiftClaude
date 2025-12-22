import JSONSupport

#if canImport(Foundation)
  public import struct Foundation.Decimal
#endif

extension SchemaCoding.Support {

  public static func schema(
    representing: Double.Type = Double.self,
    description: String? = nil
  ) -> some Schema<Double> {
    DoubleSchema(description: description)
  }

  public static func schema(
    representing: Float.Type = Float.self,
    description: String? = nil
  ) -> some Schema<Float> {
    FloatSchema(description: description)
  }

  public static func schema(
    representing: Float16.Type = Float16.self,
    description: String? = nil
  ) -> some Schema<Float16> {
    Float16Schema(description: description)
  }

  #if canImport(Foundation)
    public static func schema(
      representing: Decimal.Type = Decimal.self,
      description: String? = nil
    ) -> some Schema<Decimal> {
      DecimalSchema(description: description)
    }
  #endif

}

extension Double: SchemaCoding.SchemaCodable {

  public static var schema: some SchemaCoding.Schema<Self> {
    SchemaCoding.Support.DoubleSchema(description: nil)
  }

}

extension Float: SchemaCoding.SchemaCodable {

  public static var schema: some SchemaCoding.Schema<Self> {
    SchemaCoding.Support.FloatSchema(description: nil)
  }

}

extension Float16: SchemaCoding.SchemaCodable {

  public static var schema: some SchemaCoding.Schema<Self> {
    SchemaCoding.Support.Float16Schema(description: nil)
  }

}

#if canImport(Foundation)
  extension Decimal: SchemaCoding.SchemaCodable {

    public static var schema: some SchemaCoding.Schema<Self> {
      SchemaCoding.Support.DecimalSchema(description: nil)
    }

  }
#endif

extension SchemaCoding.Support {

  struct DoubleSchema: Schema {

    typealias Value = Double

    func encode(_ value: Value, to encoder: inout Encoder) {
      encoder.stream.encode(value)
    }

    typealias ValueDecodingState = Void

    func beginDecodingValue(
      from decoder: borrowing Decoder
    ) -> ValueDecodingState {
      ()
    }

    func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value> {
      try decoder.stream.decodeNumber()
        .map { try $0.decode(as: Value.self) }
        .schemaDecodingResult
    }

    typealias MetaSchema = WrapperSchema<
      Self,
      ConcreteObjectSchema<
        TupleObjectSchemaProperties<
          OptionalObjectProperty<String.Schema>,
          RequiredObjectProperty<ConstantSchema<String.Schema>>
        >
      >
    >
    func metaSchema(in context: SchemaContext) -> MetaSchema {
      let objectSchema = ConcreteObjectSchema {
        OptionalObjectProperty(
          name: .description,
          schema: String.schema
        )
        RequiredObjectProperty(
          name: .type,
          schema: ConstantSchema(
            wrappedSchema: String.schema,
            constantValue: type
          )
        )
      }
      return objectSchema.wrap { (description, _) in
        Self(description: description)
      } unwrap: { schema in
        (schema.description, ())
      }
    }

    let description: String?
    let type = "number"

  }

  struct FloatSchema: Schema {

    typealias Value = Float

    func encode(_ value: Value, to encoder: inout Encoder) {
      encoder.stream.encode(value)
    }

    typealias ValueDecodingState = Void

    func beginDecodingValue(
      from decoder: borrowing Decoder
    ) -> ValueDecodingState {
      ()
    }

    func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value> {
      try decoder.stream.decodeNumber()
        .map { try $0.decode(as: Value.self) }
        .schemaDecodingResult
    }

    typealias MetaSchema = WrapperSchema<
      Self,
      ConcreteObjectSchema<
        TupleObjectSchemaProperties<
          OptionalObjectProperty<String.Schema>,
          RequiredObjectProperty<ConstantSchema<String.Schema>>
        >
      >
    >
    func metaSchema(in context: SchemaContext) -> MetaSchema {
      let objectSchema = ConcreteObjectSchema {
        OptionalObjectProperty(
          name: .description,
          schema: String.schema
        )
        RequiredObjectProperty(
          name: .type,
          schema: ConstantSchema(
            wrappedSchema: String.schema,
            constantValue: type
          )
        )
      }
      return objectSchema.wrap { (description, _) in
        Self(description: description)
      } unwrap: { schema in
        (schema.description, ())
      }
    }

    let description: String?
    let type = "number"

  }

  struct Float16Schema: Schema {

    typealias Value = Float16

    func encode(_ value: Value, to encoder: inout Encoder) {
      encoder.stream.encode(value)
    }

    typealias ValueDecodingState = Void

    func beginDecodingValue(
      from decoder: borrowing Decoder
    ) -> ValueDecodingState {
      ()
    }

    func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value> {
      try decoder.stream.decodeNumber()
        .map { try $0.decode(as: Value.self) }
        .schemaDecodingResult
    }

    typealias MetaSchema = WrapperSchema<
      Self,
      ConcreteObjectSchema<
        TupleObjectSchemaProperties<
          OptionalObjectProperty<String.Schema>,
          RequiredObjectProperty<ConstantSchema<String.Schema>>
        >
      >
    >
    func metaSchema(in context: SchemaContext) -> MetaSchema {
      let objectSchema = ConcreteObjectSchema {
        OptionalObjectProperty(
          name: .description,
          schema: String.schema
        )
        RequiredObjectProperty(
          name: .type,
          schema: ConstantSchema(
            wrappedSchema: String.schema,
            constantValue: type
          )
        )
      }
      return objectSchema.wrap { (description, _) in
        Self(description: description)
      } unwrap: { schema in
        (schema.description, ())
      }
    }

    let description: String?
    let type = "number"

  }

  #if canImport(Foundation)
    struct DecimalSchema: Schema {

      typealias Value = Decimal

      func encode(_ value: Value, to encoder: inout Encoder) {
        encoder.stream.encode(value)
      }

      typealias ValueDecodingState = Void

      func beginDecodingValue(
        from decoder: borrowing Decoder
      ) -> ValueDecodingState {
        ()
      }

      func decodeValue(
        from decoder: inout Decoder,
        state: inout ValueDecodingState
      ) throws -> DecodingResult<Value> {
        try decoder.stream.decodeNumber()
          .map { try $0.decode(as: Value.self) }
          .schemaDecodingResult
      }

      typealias MetaSchema = WrapperSchema<
        Self,
        ConcreteObjectSchema<
          TupleObjectSchemaProperties<
            OptionalObjectProperty<String.Schema>,
            RequiredObjectProperty<ConstantSchema<String.Schema>>
          >
        >
      >
      func metaSchema(in context: SchemaContext) -> MetaSchema {
        let objectSchema = ConcreteObjectSchema {
          OptionalObjectProperty(
            name: .description,
            schema: String.schema
          )
          RequiredObjectProperty(
            name: .type,
            schema: ConstantSchema(
              wrappedSchema: String.schema,
              constantValue: type
            )
          )
        }
        return objectSchema.wrap { (description, _) in
          Self(description: description)
        } unwrap: { schema in
          (schema.description, ())
        }
      }

      let description: String?
      let type = "number"

    }
  #endif

}

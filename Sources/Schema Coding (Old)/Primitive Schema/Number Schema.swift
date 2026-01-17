import JSONSupport

#if canImport(Foundation)
  public import struct Foundation.Decimal
#endif

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
          OptionalObjectProperty<StringSchema>,
          DirectObjectProperty<ConstantSchema<StringSchema>>
        >
      >
    >
    var metaSchema: MetaSchema {
      let objectSchema = ConcreteObjectSchema {
        OptionalObjectProperty(
          name: .description,
          schema: OptionalSchema(wrappedSchema: StringSchema())
        )
        DirectObjectProperty(
          name: .type,
          schema: ConstantSchema(
            wrappedSchema: StringSchema(),
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

    init(description: String? = nil) {
      self.metadata = SchemaMetadata(description: description)
    }
    var metadata: SchemaMetadata

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
          OptionalObjectProperty<StringSchema>,
          DirectObjectProperty<ConstantSchema<StringSchema>>
        >
      >
    >
    var metaSchema: MetaSchema {
      let objectSchema = ConcreteObjectSchema {
        OptionalObjectProperty(
          name: .description,
          schema: OptionalSchema(wrappedSchema: StringSchema())
        )
        DirectObjectProperty(
          name: .type,
          schema: ConstantSchema(
            wrappedSchema: StringSchema(),
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

    init(description: String? = nil) {
      self.metadata = SchemaMetadata(description: description)
    }
    var metadata: SchemaMetadata

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
          OptionalObjectProperty<StringSchema>,
          DirectObjectProperty<ConstantSchema<StringSchema>>
        >
      >
    >
    var metaSchema: MetaSchema {
      let objectSchema = ConcreteObjectSchema {
        OptionalObjectProperty(
          name: .description,
          schema: OptionalSchema(wrappedSchema: StringSchema())
        )
        DirectObjectProperty(
          name: .type,
          schema: ConstantSchema(
            wrappedSchema: StringSchema(),
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

    init(description: String? = nil) {
      self.metadata = SchemaMetadata(description: description)
    }
    var metadata: SchemaMetadata

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
            OptionalObjectProperty<StringSchema>,
            DirectObjectProperty<ConstantSchema<StringSchema>>
          >
        >
      >
      var metaSchema: MetaSchema {
        let objectSchema = ConcreteObjectSchema {
          OptionalObjectProperty(
            name: .description,
            schema: OptionalSchema(wrappedSchema: StringSchema())
          )
          DirectObjectProperty(
            name: .type,
            schema: ConstantSchema(
              wrappedSchema: StringSchema(),
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

      init(description: String? = nil) {
        self.metadata = SchemaMetadata(description: description)
      }
      var metadata: SchemaMetadata

    }
  #endif

}

private let type = "number"

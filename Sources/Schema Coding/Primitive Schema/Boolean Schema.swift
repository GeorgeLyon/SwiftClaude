import JSONSupport

extension Bool: SchemaCoding.SchemaCodable {

  public static var schema: some SchemaCoding.Schema<Bool> {
    SchemaCoding.Support.BooleanSchema(description: nil)
  }

}

extension SchemaCoding.Support {

  struct BooleanSchema: Schema {

    typealias Value = Bool

    func encode(_ value: Bool, to encoder: inout Encoder) {
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
    ) throws -> DecodingResult<Bool> {
      try decoder.stream.decodeBoolean()
        .schemaDecodingResult
    }

    typealias MetaSchema = WrapperSchema<
      Self,
      ConcreteObjectSchema<
        TupleObjectSchemaProperties<
          OptionalObjectProperty<StringSchema>,
          RequiredObjectProperty<ConstantSchema<StringSchema>>
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
          name: .type,
          schema: ConstantSchema(
            wrappedSchema: StringSchema(),
            constantValue: "boolean"
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

}

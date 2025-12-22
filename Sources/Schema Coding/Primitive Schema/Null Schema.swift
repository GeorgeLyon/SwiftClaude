import JSONSupport

extension SchemaCoding.Support {

  public static let nullSchema: some Schema<Void> = NullSchema(description: nil)

}

extension SchemaCoding.Support {

  struct NullSchema: Schema {

    typealias Value = Void

    func encode(_ value: Void, to encoder: inout Encoder) {
      encoder.stream.encodeNull()
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
    ) throws -> DecodingResult<Void> {
      try decoder.stream.decodeNull().schemaDecodingResult
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
    func metaSchema(in context: SchemaContext) -> MetaSchema {
      let objectSchema = ConcreteObjectSchema {
        OptionalObjectProperty(
          name: .description,
          schema: StringSchema()
        )
        RequiredObjectProperty(
          name: .type,
          schema: ConstantSchema(
            wrappedSchema: StringSchema(),
            constantValue: "null"
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

  }

}

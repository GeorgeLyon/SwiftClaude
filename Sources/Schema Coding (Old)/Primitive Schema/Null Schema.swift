import JSONSupport

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

    init(description: String? = nil) {
      self.metadata = SchemaMetadata(description: description)
    }
    var metadata: SchemaMetadata

  }

}

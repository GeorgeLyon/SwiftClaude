import JSONSupport

extension SchemaCoding.Support {

  public static func schema(
    representing: String.Type = String.self,
    description: String? = nil
  ) -> some Schema<String> {
    StringSchema(description: description)
  }

}

extension String: SchemaCoding.SchemaCodable {

  public static var schema: some SchemaCoding.Schema<String> {
    SchemaCoding.Support.StringSchema(description: nil)
  }

}

extension SchemaCoding.Support {

  struct StringSchema: Schema {

    typealias Value = String

    func encode(_ value: String, to encoder: inout Encoder) {
      encoder.stream.encode(value)
    }

    struct ValueDecodingState: Sendable {
      var stringState = JSON.StringDecodingState()
    }

    func beginDecodingValue(
      from decoder: borrowing Decoder
    ) -> ValueDecodingState {
      ValueDecodingState()
    }

    func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<String> {
      try decoder.stream.decodeString(state: &state.stringState)
        .map(String.init)
        .schemaDecodingResult
    }

    typealias MetaSchema = WrapperSchema<
      Self,
      ConcreteObjectSchema<
        TupleObjectSchemaProperties<
          OptionalObjectProperty<String.Schema>,
          RequiredObjectProperty<
            ConstantSchema<String.Schema>
          >
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
            constantValue: "string"
          )
        )
      }
      let wrapperSchema =
        objectSchema
        .wrap { (description, _) in
          Self(description: description)
        } unwrap: { schema in
          (schema.description, ())
        }
      return wrapperSchema
    }

    let description: String?

  }

}

import JSONSupport

extension SchemaCoding.Support {

  struct NeverSchema: Schema {

    typealias Value = Never

    func encode(_ value: Never, to encoder: inout Encoder) {

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
    ) throws -> DecodingResult<Never> {
      throw Error.neverSchemaCannotDecode
    }

    typealias MetaSchema = WrapperSchema<
      Self,
      ConcreteObjectSchema<
        TupleObjectSchemaProperties<
          OptionalObjectProperty<StringSchema>,
          DirectObjectProperty<ConcreteObjectSchema<TupleObjectSchemaProperties<>>>
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
          name: .not,
          schema: ConcreteObjectSchema {}
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

private enum Error: Swift.Error {
  case neverSchemaCannotDecode
}

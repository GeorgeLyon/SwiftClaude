import JSONSupport

extension SchemaCoding.Support {

  struct NeverSchema: Schema {

    public typealias Value = Never

    public func encode(_ value: Never, to encoder: inout Encoder) {

    }

    public typealias ValueDecodingState = Void

    public func beginDecodingValue(
      from decoder: borrowing Decoder
    ) -> ValueDecodingState {
      ()
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Never> {
      throw Error.neverSchemaCannotDecode
    }

    public var metaSchema: some Schema<Self> {
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
    public var metadata: SchemaMetadata

  }

}

private enum Error: Swift.Error {
  case neverSchemaCannotDecode
}

import JSONSupport

extension SchemaCoding.Support {

  public static func schema(
    representing: Bool.Type = Bool.self,
    description: String? = nil
  ) -> some Schema<Bool> {
    BooleanSchema(description: description)
  }

}

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

    func metaSchema(in context: SchemaContext) -> some Schema<Self> {
      let objectSchema = objectSchema(
        description: nil,
        properties: {
          objectProperty(
            name: .description,
            schema: String?.schema
          )
          objectProperty(
            name: .type,
            schema: schema(constantValue: type)
          )
        }
      )
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
    let type = "boolean"

  }

}

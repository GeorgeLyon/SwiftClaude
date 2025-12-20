import JSONSupport

extension SchemaCoding.Support {

  public static let nullSchema: some Schema<Void> = NullSchema(description: nil)

}

extension SchemaCoding.Support {

  fileprivate struct NullSchema: Schema {

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

    func metaSchema(in context: SchemaContext) -> some Schema<Self> {
      let objectSchema = objectSchema(
        description: nil,
        propertyName: SchemaPropertyName.self,
        properties: {
          objectProperty(
            name: SchemaPropertyName.description,
            schema: String?.schema
          )
          objectProperty(
            name: SchemaPropertyName.type,
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
    let type = "null"

  }

}

private enum SchemaPropertyName: CodingKey {
  case description, type
}

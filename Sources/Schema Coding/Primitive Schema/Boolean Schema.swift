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

  public static var schema: some SchemaCoding.Schema<Self> {
    SchemaCoding.Support.schema(
      representing: Bool.self
    )
  }

}

extension SchemaCoding.Support {

  private struct BooleanSchema: PrimitiveSchema {

    typealias Value = Bool

    func encode(_ value: Bool, to encoder: inout Encoder) {
      encoder.stream.encode(value)
    }

    func decodeValue(
      from decoder: inout Decoder,
      state: inout Void
    ) throws -> DecodingResult<Bool> {
      try decoder.stream.decodeBoolean()
        .schemaDecodingResult
    }

    let description: String?
    let type = "boolean"

  }

}

private enum SchemaPropertyName: CodingKey {
  case description, type
}

import JSONSupport

extension SchemaCoding.SchemaResolver {

  public static func nullSchema() -> some SchemaCoding.Schema<Void> {
    NullSchema()
  }

}

// MARK: - Implementation Details

struct NullSchema: LeafSchema {

  typealias Value = Void

  let type = "null"

  func decodeValue(
    from decoder: inout SchemaCoding.SchemaValueDecoder,
    state: inout ValueDecodingState
  ) throws -> SchemaCoding.SchemaDecodingResult<Value> {
    try decoder.stream.decodeNull().schemaDecodingResult
  }

  func encode(
    _ value: Void,
    to encoder: inout SchemaCoding.SchemaValueEncoder
  ) {
    encoder.stream.encodeNull()
  }

}

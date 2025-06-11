import JSONSupport

extension SchemaCoding.SchemaCodingSupport {

  public static func schema(
    representing _: Bool.Type = Bool.self
  ) -> some SchemaCoding.Schema<Bool> {
    BoolSchema()
  }

}

extension Bool: SchemaCoding.SchemaCodable {

  public static var schema: some SchemaCoding.Schema<Self> {
    SchemaCoding.SchemaCodingSupport.schema(representing: Bool.self)
  }

}
// MARK: - Implementation Details

private struct BoolSchema: LeafSchema {

  typealias Value = Bool

  let type = "boolean"

  func decodeValue(
    from decoder: inout SchemaCoding.SchemaValueDecoder,
    state: inout ValueDecodingState
  ) throws -> SchemaCoding.DecodingResult<Value> {
    try decoder.stream.decodeBoolean().schemaDecodingResult
  }

  func encode(
    _ value: Bool,
    to encoder: inout SchemaCoding.SchemaValueEncoder
  ) {
    encoder.stream.encode(value)
  }

}

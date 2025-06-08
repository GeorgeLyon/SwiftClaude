import JSONSupport

extension SchemaCoding.SchemaResolver {

  public static func schema(
    representing _: Bool.Type = Bool.self
  ) -> some SchemaCoding.Schema<Bool> {
    BoolSchema()
  }

}

extension Bool: SchemaCodable {

  public static var schema: some SchemaCoding.Schema<Self> {
    SchemaCoding.SchemaResolver.schema(representing: Bool.self)
  }

}
// MARK: - Implementation Details

private struct BoolSchema: LeafSchema {

  typealias Value = Bool

  let type = "boolean"

  func decodeValue(
    from decoder: inout SchemaCoding.SchemaValueDecoder,
    state: inout ValueDecodingState
  ) throws -> JSON.DecodingResult<Value> {
    try decoder.stream.decodeBoolean()
  }

  func encode(
    _ value: Bool,
    to encoder: inout SchemaCoding.SchemaValueEncoder
  ) {
    encoder.stream.encode(value)
  }

}

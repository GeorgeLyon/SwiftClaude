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
    from stream: inout JSON.DecodingStream,
    state: inout ()
  ) throws -> JSON.DecodingResult<Bool> {
    try stream.decodeBoolean()
  }

  func encode(_ value: Bool, to stream: inout JSON.EncodingStream) {
    stream.encode(value)
  }

}

import JSONSupport

extension SchemaCoding.SchemaCodingSupport {

  public static func schema<T: SchemaCodable & FixedWidthInteger & Codable & Sendable>(
    representing _: T.Type = T.self
  ) -> some SchemaCoding.Schema<T> {
    IntegerSchema()
  }

}

extension Int: SchemaCoding.SchemaCodable {}
extension Int8: SchemaCoding.SchemaCodable {}
extension Int16: SchemaCoding.SchemaCodable {}
extension Int32: SchemaCoding.SchemaCodable {}
extension Int64: SchemaCoding.SchemaCodable {}

extension UInt: SchemaCoding.SchemaCodable {}
extension UInt8: SchemaCoding.SchemaCodable {}
extension UInt16: SchemaCoding.SchemaCodable {}
extension UInt32: SchemaCoding.SchemaCodable {}
extension UInt64: SchemaCoding.SchemaCodable {}

// MARK: - Implementation Details

extension SchemaCoding.SchemaCodable where Self: FixedWidthInteger & Codable & Sendable {

  public static var schema: some SchemaCoding.Schema<Self> {
    SchemaCoding.SchemaCodingSupport.schema(representing: Self.self)
  }

}

private struct IntegerSchema<Value: FixedWidthInteger & Codable & Sendable>: LeafSchema {

  let type = "integer"

  func decodeValue(
    from decoder: inout SchemaCoding.SchemaValueDecoder,
    state: inout ()
  ) throws -> SchemaCoding.DecodingResult<Value> {
    try decoder.stream.decodeNumber().map { try $0.decode() }.schemaDecodingResult
  }

  func encode(_ value: Value, to encoder: inout SchemaCoding.SchemaValueEncoder) {
    encoder.stream.encode(value)
  }

}

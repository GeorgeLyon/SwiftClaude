import JSONSupport

extension SchemaSupport {

  public static func schema<T: SchemaCodable & FixedWidthInteger & Codable & Sendable>(
    representing _: T.Type = T.self
  ) -> some Schema<T> {
    IntegerSchema()
  }

}

extension Int: SchemaCodable {}
extension Int8: SchemaCodable {}
extension Int16: SchemaCodable {}
extension Int32: SchemaCodable {}
extension Int64: SchemaCodable {}

extension UInt: SchemaCodable {}
extension UInt8: SchemaCodable {}
extension UInt16: SchemaCodable {}
extension UInt32: SchemaCodable {}
extension UInt64: SchemaCodable {}

// MARK: - Implementation Details

extension SchemaCodable where Self: FixedWidthInteger & Codable & Sendable {

  public static var schema: some SchemaCoding.Schema<Self> {
    SchemaSupport.schema()
  }

}

private struct IntegerSchema<Value: FixedWidthInteger & Codable & Sendable>: LeafSchema {

  let type = "integer"

  func decodeValue(
    from stream: inout JSON.DecodingStream,
    state: inout ()
  ) throws -> JSON.DecodingResult<Value> {
    try stream.decodeNumber().map { try $0.decode() }
  }

  func encode(_ value: Value, to stream: inout JSON.EncodingStream) {
    stream.encode(value)
  }

}

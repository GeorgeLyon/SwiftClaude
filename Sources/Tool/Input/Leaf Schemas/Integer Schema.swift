import JSONSupport

extension ToolInput {

  public static func schema<T: ToolInput.SchemaCodable & FixedWidthInteger & Codable & Sendable>(
    representing _: T.Type = T.self
  ) -> some Schema<T> {
    IntegerSchema()
  }

}

extension Int: ToolInput.SchemaCodable {}
extension Int8: ToolInput.SchemaCodable {}
extension Int16: ToolInput.SchemaCodable {}
extension Int32: ToolInput.SchemaCodable {}
extension Int64: ToolInput.SchemaCodable {}

extension UInt: ToolInput.SchemaCodable {}
extension UInt8: ToolInput.SchemaCodable {}
extension UInt16: ToolInput.SchemaCodable {}
extension UInt32: ToolInput.SchemaCodable {}
extension UInt64: ToolInput.SchemaCodable {}

// MARK: - Implementation Details

extension ToolInput.SchemaCodable where Self: FixedWidthInteger & Codable & Sendable {

  public static var toolInputSchema: some ToolInput.Schema<Self> {
    ToolInput.schema()
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

  func encodeValue(_ value: Value, to stream: inout JSON.EncodingStream) {
    stream.encode(value)
  }

}

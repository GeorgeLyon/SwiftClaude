import JSONSupport

extension ToolInput {

  public static func schema<
    T: ToolInput.SchemaCodable & BinaryFloatingPoint & LosslessStringConvertible & Codable
      & Sendable
  >(
    representing _: T.Type = T.self
  ) -> some Schema<T> {
    NumberSchema()
  }

}

extension Float: ToolInput.SchemaCodable {}
extension Float16: ToolInput.SchemaCodable {}
extension Double: ToolInput.SchemaCodable {}

// MARK: - Implementation Details

extension ToolInput.SchemaCodable
where Self: BinaryFloatingPoint & LosslessStringConvertible & Codable & Sendable {

  public static var toolInputSchema: some ToolInput.Schema<Self> {
    ToolInput.schema()
  }

}

private struct NumberSchema<
  Value: BinaryFloatingPoint & LosslessStringConvertible & Codable & Sendable
>: LeafSchema {

  let type = "number"

  func decodeValue(
    from stream: inout JSON.DecodingStream,
    state: inout ()
  ) throws -> JSON.DecodingResult<Value> {
    try stream.decodeNumber().map { try $0.decode() }
  }

  func encode(_ value: Value, to stream: inout JSON.EncodingStream) {
    if let float16 = value as? Float16 {
      stream.encode(float16)
    } else if let float32 = value as? Float32 {
      stream.encode(float32)
    } else if let double = value as? Double {
      stream.encode(double)
    } else {
      // Fallback for other floating point types
      stream.encode(String(value))
    }
  }

}

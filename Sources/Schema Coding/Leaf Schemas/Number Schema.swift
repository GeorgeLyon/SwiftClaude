import JSONSupport

extension SchemaCoding.SchemaResolver {

  public static func schema<
    T: SchemaCodable & BinaryFloatingPoint & LosslessStringConvertible & Codable
      & Sendable
  >(
    representing _: T.Type = T.self
  ) -> some SchemaCoding.Schema<T> {
    NumberSchema()
  }

}

extension Float: SchemaCodable {}
extension Float16: SchemaCodable {}
extension Double: SchemaCodable {}

// MARK: - Implementation Details

extension SchemaCodable
where Self: BinaryFloatingPoint & LosslessStringConvertible & Codable & Sendable {

  public static var schema: some SchemaCoding.Schema<Self> {
    SchemaCoding.SchemaResolver.schema(representing: Self.self)
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

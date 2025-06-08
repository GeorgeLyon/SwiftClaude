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
    from decoder: inout SchemaCoding.SchemaValueDecoder,
    state: inout ()
  ) throws -> SchemaCoding.SchemaDecodingResult<Value> {
    try decoder.stream.decodeNumber().map { try $0.decode() }.schemaDecodingResult
  }

  func encode(_ value: Value, to encoder: inout SchemaCoding.SchemaValueEncoder) {
    if let float16 = value as? Float16 {
      encoder.stream.encode(float16)
    } else if let float32 = value as? Float32 {
      encoder.stream.encode(float32)
    } else if let double = value as? Double {
      encoder.stream.encode(double)
    } else {
      // Fallback for other floating point types
      encoder.stream.encode(String(value))
    }
  }

}

import JSONSupport

extension SchemaCoding.SchemaCodingSupport {

  public static func schema<
    T: SchemaCodable & BinaryFloatingPoint & LosslessStringConvertible & Codable
      & Sendable
  >(
    representing _: T.Type = T.self
  ) -> some SchemaCoding.Schema<T> {
    NumberSchema()
  }

}

extension Float: SchemaCoding.SchemaCodable {}
extension Float16: SchemaCoding.SchemaCodable {}
extension Double: SchemaCoding.SchemaCodable {}

// MARK: - Implementation Details

extension SchemaCoding.SchemaCodable
where Self: BinaryFloatingPoint & LosslessStringConvertible & Codable & Sendable {

  public static var schema: some SchemaCoding.Schema<Self> {
    SchemaCoding.SchemaCodingSupport.schema(representing: Self.self)
  }

}

private struct NumberSchema<
  Value: BinaryFloatingPoint & LosslessStringConvertible & Codable & Sendable
>: LeafSchema {

  let type = "number"

  func decodeValue(
    from decoder: inout SchemaCoding.SchemaValueDecoder,
    state: inout ()
  ) throws -> SchemaCoding.DecodingResult<Value> {
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

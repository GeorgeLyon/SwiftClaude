import JSONSupport

extension Int: SchemaCoding.SchemaCodable {}
extension Int8: SchemaCoding.SchemaCodable {}
extension Int16: SchemaCoding.SchemaCodable {}
extension Int32: SchemaCoding.SchemaCodable {}
extension Int64: SchemaCoding.SchemaCodable {}
extension Int128: SchemaCoding.SchemaCodable {}
extension UInt: SchemaCoding.SchemaCodable {}
extension UInt8: SchemaCoding.SchemaCodable {}
extension UInt16: SchemaCoding.SchemaCodable {}
extension UInt32: SchemaCoding.SchemaCodable {}
extension UInt64: SchemaCoding.SchemaCodable {}
extension UInt128: SchemaCoding.SchemaCodable {}

extension SchemaCoding.Support {

  public static func schema<T: FixedWidthInteger & Sendable>(
    representing: T.Type = T.self,
    description: String? = nil
  ) -> some Schema<T> {
    IntegerNumberSchema(description: description)
  }

}

extension FixedWidthInteger where Self: Sendable {

  public static var schema: some SchemaCoding.Schema<Self> {
    SchemaCoding.Support.schema(
      representing: Self.self
    )
  }

}

extension SchemaCoding.Support {

  private struct IntegerNumberSchema<T>: PrimitiveSchema where T: FixedWidthInteger & Sendable {

    typealias Value = T

    func encode(_ value: T, to encoder: inout Encoder) {
      encoder.stream.encode(value)
    }

    func decodeValue(
      from decoder: inout Decoder,
      state: inout Void
    ) throws -> DecodingResult<T> {
      try decoder.stream.decodeNumber()
        .map { try $0.decode(as: T.self) }
        .schemaDecodingResult
    }

    let description: String?
    let type = "integer"

  }

}

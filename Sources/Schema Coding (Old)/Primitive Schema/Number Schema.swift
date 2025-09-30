import JSONSupport

#if canImport(Foundation)
  public import struct Foundation.Decimal
#endif

extension SchemaCoding.Support {

  public static func schema(
    representing: Double.Type = Double.self,
    description: String? = nil
  ) -> some Schema<Double> {
    DoubleNumberSchema(description: description)
  }

  public static func schema(
    representing: Float.Type = Float.self,
    description: String? = nil
  ) -> some Schema<Float> {
    FloatNumberSchema(description: description)
  }

  public static func schema(
    representing: Float16.Type = Float16.self,
    description: String? = nil
  ) -> some Schema<Float16> {
    Float16NumberSchema(description: description)
  }

  public static func schema(
    representing: Decimal.Type = Decimal.self,
    description: String? = nil
  ) -> some Schema<Decimal> {
    DecimalNumberSchema(description: description)
  }

}

extension Double: SchemaCoding.SchemaCodable {

  public static var schema: some SchemaCoding.Schema<Self> {
    SchemaCoding.Support.schema(
      representing: Double.self
    )
  }

}

extension Float: SchemaCoding.SchemaCodable {

  public static var schema: some SchemaCoding.Schema<Self> {
    SchemaCoding.Support.schema(
      representing: Float.self
    )
  }

}

extension SchemaCoding.Support {

  private struct DoubleNumberSchema: PrimitiveSchema {

    typealias Value = Double

    func encode(_ value: Value, to encoder: inout Encoder) {
      encoder.stream.encode(value)
    }

    func decodeValue(
      from decoder: inout Decoder,
      state: inout Void
    ) throws -> DecodingResult<Value> {
      try decoder.stream.decodeNumber()
        .map { try $0.decode(as: Value.self) }
        .schemaDecodingResult
    }

    let description: String?
    let type = "number"

  }

  private struct FloatNumberSchema: PrimitiveSchema {

    typealias Value = Float

    func encode(_ value: Value, to encoder: inout Encoder) {
      encoder.stream.encode(value)
    }

    func decodeValue(
      from decoder: inout Decoder,
      state: inout Void
    ) throws -> DecodingResult<Value> {
      try decoder.stream.decodeNumber()
        .map { try $0.decode(as: Value.self) }
        .schemaDecodingResult
    }

    let description: String?
    let type = "number"

  }

  private struct Float16NumberSchema: PrimitiveSchema {

    typealias Value = Float16

    func encode(_ value: Value, to encoder: inout Encoder) {
      encoder.stream.encode(value)
    }

    func decodeValue(
      from decoder: inout Decoder,
      state: inout Void
    ) throws -> DecodingResult<Value> {
      try decoder.stream.decodeNumber()
        .map { try $0.decode(as: Value.self) }
        .schemaDecodingResult
    }

    let description: String?
    let type = "number"

  }

  #if canImport(Foundation)
    private struct DecimalNumberSchema: PrimitiveSchema {

      typealias Value = Decimal

      func encode(_ value: Value, to encoder: inout Encoder) {
        encoder.stream.encode(value)
      }

      func decodeValue(
        from decoder: inout Decoder,
        state: inout Void
      ) throws -> DecodingResult<Value> {
        try decoder.stream.decodeNumber()
          .map { try $0.decode(as: Value.self) }
          .schemaDecodingResult
      }

      let description: String?
      let type = "number"

    }
  #endif

}

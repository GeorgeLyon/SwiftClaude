extension SchemaCoding.Support {

  public static let nullSchema: some Schema<Void> = NullSchema(description: nil)

}

// MARK: - Schema

extension SchemaCoding.Support {

  private struct NullSchema: PrimitiveSchema {

    public typealias Value = Void

    public func encode(_ value: Void, to encoder: inout Encoder) {
      encoder.stream.encodeNull()
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout Void
    ) throws -> DecodingResult<Void> {
      try decoder.stream.decodeNull().schemaDecodingResult
    }

    public let description: String?
    public let type = "null"

  }

}

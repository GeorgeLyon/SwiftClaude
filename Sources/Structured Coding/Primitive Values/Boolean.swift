private import JavaScriptObjectNotation

// MARK: - Schema

extension Bool {

  public static var schema: some StructuredCodingSchema {
    MetaSchema.boolean(description: nil)
  }

}

// MARK: - Encoding

extension Bool: StructuredEncodable {

  public func encode(to encoder: inout StructuredEncoder) throws {
    encoder.stream.encode(self)
  }

}

// MARK: - Decoding

extension Bool: StructuredDecodable {

  public static func initialValueForDecoding(isMutable: Bool) -> sending Self? {
    nil
  }

  public static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    let value = try await decoder.stream.decodeBoolean()
    try await accessor.initializeValue(to: value)
  }

}

private import JavaScriptObjectNotation

// MARK: - Schema

extension Bool {

  @StructuredCodable
  public struct Schema: StructuredCodable {
    fileprivate init(description: String?) {
      self.description = description
    }
    private let description: String?
    private let type = "boolean"
  }
  public static func schema(description: String?) -> Schema {
    Schema(description: description)
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

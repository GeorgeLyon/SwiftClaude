private import JavaScriptObjectNotation

// MARK: - Schema

extension String {

  public static func schema(description: String?) -> some StructuredCodable {
    MetaSchema.string(description: description)
  }

}

// MARK: - Encoding

extension String: StructuredEncodable {

  public func encode(to encoder: inout StructuredEncoder) throws {
    encoder.stream.encode(self)
  }

}

// MARK: - Decoding

extension String: StructuredDecodable {

  public static func initialValueForDecoding(isMutable: Bool) -> sending String? {
    isMutable ? "" : nil
  }

  public static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    if accessor.isMutable {
      try await decoder.stream.decodeCharacterRuns { fragment in
        try await accessor.mutateValue(applying: fragment) { $0.append(contentsOf: $1) }
      }
    } else {
      try await accessor.initializeValue(to: try await decoder.stream.decodeString())
    }
  }

}

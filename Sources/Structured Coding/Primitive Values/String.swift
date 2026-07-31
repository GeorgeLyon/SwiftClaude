private import JavaScriptObjectNotation

// MARK: - Schema

extension String {

  public static var schema: some StructuredCodingSchema {
    MetaSchema.string(description: nil)
  }

}

// MARK: - Encoding

extension String: StructuredEncodable {

  public func encode(to stream: inout StructuredEncodingStream) throws {
    stream.json.encode(self)
  }

}

// MARK: - Decoding

extension String: StructuredDecodable {

  public static func initialValueForDecoding(isMutable: Bool) -> sending String? {
    isMutable ? "" : nil
  }

  public static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from stream: inout StructuredDecodingStream,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    if accessor.isMutable {
      try await stream.json.decodeCharacterRuns { fragment in
        try await accessor.mutateValue(applying: fragment) { $0.append(contentsOf: $1) }
      }
    } else {
      try await accessor.initializeValue(to: try await stream.json.decodeString())
    }
  }

}

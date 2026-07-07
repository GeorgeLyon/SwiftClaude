public import JavaScriptObjectNotation

// MARK: - Initializer

extension OpaqueValue {

  init<Value: StructuredEncodable>(
    _ value: Value
  ) throws {
    try self.init { stream in
      var encoder = StructuredEncoder(stream: stream)
      do {
        try value.encode(to: &encoder)
        stream = encoder.stream
      } catch {
        stream = encoder.stream
        throw error
      }
    }

  }

}

// MARK: - Schema

extension OpaqueValue {

  public static func schema(description: String?) -> some StructuredCodable {
    MetaSchema.any(description: description)
  }

}

// MARK: - Encoding

extension OpaqueValue: StructuredEncodable {

  public func encode(to encoder: inout StructuredEncoder) throws {
    encoder.stream.encode(self)
  }

}

// MARK: - Decoding

extension OpaqueValue: StructuredDecodable {

  public static func initialValueForDecoding(isMutable: Bool) -> sending OpaqueValue? {
    nil
  }

  public static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    try await accessor.initializeValue(to: try await decoder.stream.decodeOpaqueValue())
  }

}

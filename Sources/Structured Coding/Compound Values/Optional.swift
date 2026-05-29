private import JavaScriptObjectNotation

// MARK: - Encoding

extension Optional: StructuredEncodable where Wrapped: StructuredEncodable {

  public func encode(to encoder: inout StructuredEncoder) throws {
    try encoder.stream.encodeObject { objectEncoder in
      guard let wrapped = self else {
        /// `nil` encodes as the empty object.
        return
      }
      try objectEncoder.encodeProperty(
        encodeName: { stream in
          stream.encode(StructuredCodingKey.value.staticStringValue)
        },
        encodeValue: { stream in
          try stream.withEncoder { encoder in
            try wrapped.encode(to: &encoder)
          }
        }
      )
    }
  }

}

// MARK: - Decoding

extension Optional: StructuredDecodable where Wrapped: StructuredDecodable {

  public static func initialValueForDecoding(isMutable: Bool) -> sending Wrapped?? {
    isMutable ? .some(.none) : .none
  }

  public static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Wrapped? {
    try await decoder.stream.decodeObject { objectDecoder in
      if objectDecoder.isAtEnd {
        /// The accessor's value already started as `nil`; there is nothing to write.
        return
      }
      try await objectDecoder.decodeProperty(
        decodeName: { stream in
          try await stream.decodeString(StructuredCodingKey.value.staticStringValue)
        },
        decodeValue: { _, stream in
          try await stream.withDecoder { decoder in
            if let initialValue = Wrapped.initialValueForDecoding(isMutable: accessor.isMutable) {
              try await accessor.initializeValue(to: initialValue)
            }
            try await accessor.withSomeAccessor { accessor in
              try await Wrapped.decode(from: &decoder, in: context, using: accessor)
            }
          }
        }
      )
      guard objectDecoder.isAtEnd else {
        throw OptionalDecodingError.unexpectedAdditionalProperty
      }
    }
  }

}

// MARK: - Errors

private enum OptionalDecodingError: Error {
  case unexpectedAdditionalProperty
}

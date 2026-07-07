private import JavaScriptObjectNotation

// MARK: - Definition

public struct StructuredTuple<each Element: StructuredDecodable> {

  public let values: (repeat each Element)

  public init(_ values: repeat each Element) {
    self.values = (repeat each values)
  }

}

// MARK: - Conformances

extension StructuredTuple: Sendable where repeat each Element: Sendable {}

extension StructuredTuple: Equatable where repeat each Element: Equatable {

  public static func == (lhs: Self, rhs: Self) -> Bool {
    for (lhs, rhs) in repeat (each lhs.values, each rhs.values) {
      guard lhs == rhs else { return false }
    }
    return true
  }

}

// MARK: - Schema

extension StructuredTuple {

  public static func schema(description: String?) -> some StructuredCodable {
    MetaSchema.tuple(
      description: description,
      prefixItems: repeat (each Element).schema()
    )
  }

}

// MARK: - Encoding

extension StructuredTuple: StructuredEncodable where repeat each Element: StructuredEncodable {

  public func encode(to encoder: inout StructuredEncoder) throws {
    try encoder.stream.encodeArray { arrayEncoder in
      for element in repeat each values {
        try arrayEncoder.encodeElement { stream in
          try stream.withEncoder { encoder in
            try element.encode(to: &encoder)
          }
        }
      }
    }
  }

}

// MARK: - Decoding

extension StructuredTuple: StructuredDecodable {

  /// Tuples are not streamable: there is no way to address an individual element
  /// mid-stream, so no value is observable until every element has been decoded.
  public static func initialValueForDecoding(isMutable: Bool) -> sending Self? {
    nil
  }

  public static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    try await context.withArena { arena in
      let stateRefs =
        (repeat arena.push(TupleElementDecodingState<each Element>.pending).unsafePointer)

      try await decoder.stream.decodeArray { arrayDecoder in
        for stateRef in repeat each stateRefs {
          guard !arrayDecoder.isAtEnd else {
            throw TupleDecodingError.tooFewElements
          }
          try await arrayDecoder.decodeElement { stream in
            try await stream.withDecoder { decoder in
              try await stateRef.pointee.decode(from: &decoder, in: context)
            }
          }
        }
        guard arrayDecoder.isAtEnd else {
          throw TupleDecodingError.tooManyElements
        }
      }

      try await accessor.initializeValue(
        to: StructuredTuple(repeat try (each stateRefs).pointee.takeDecodedValue())
      )
    }
  }

}

// MARK: - Element Decoding State

private enum TupleElementDecodingState<Element: StructuredDecodable>: ~Copyable {

  /// The element has not been decoded yet.
  case pending

  /// The element has been fully decoded.
  case decoded(Sending<Element>)

  mutating func decode(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext
  ) async throws {
    let value = try await Element.decode(from: &decoder, in: context)
    self = .decoded(Sending(value))
  }

  /// Moves the decoded element out, leaving the state `pending`.
  mutating func takeDecodedValue() throws -> sending Element {
    switch consume self {
    case .pending:
      self = .pending
      throw TupleDecodingError.elementNotDecoded
    case .decoded(let value):
      self = .pending
      return value.send()
    }
  }

}

// MARK: - Errors

private enum TupleDecodingError: Error {
  case tooFewElements
  case tooManyElements
  case elementNotDecoded
}


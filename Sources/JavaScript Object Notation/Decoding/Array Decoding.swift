extension DecodingStream {

  public struct ArrayDecoder: ~Copyable, ~Escapable {

    public mutating func decodeElement<T>(
      _ decodeElement: (inout DecodingStream) async throws -> sending T
    ) async throws -> sending T {
      guard !isAtEnd else {
        throw DecodingError.encountered(.decodingElementPastArrayEnd, at: stream.currentPosition)
      }
      let element = try await decodeElement(&stream)
      try await stream.readWhitespace()

      switch try await stream.read(ArrayComponent.self) {
      case .element:
        isAtEnd = false
      case .end:
        isAtEnd = true
      }
      return element
    }

    private enum ArrayComponent: Byte, ByteRepresentable {
      case end = "]"
      case element = ","
    }

    @_lifetime(&stream)
    fileprivate init(stream: inout DecodingStream) async throws(DecodingError) {
      try await stream.readWhitespace()
      try await stream.read("[")
      try await stream.readWhitespace()
      isAtEnd = try await stream.readByteIfPresent(in: "]")
      self.stream = stream.mutate()
    }

    public private(set) var isAtEnd: Bool
    private var stream: DecodingStream

  }

  public mutating func decodeArrayElements<Element>(
    decodeElement: (inout DecodingStream) async throws -> sending Element
  ) async throws -> [Element] {
    var elements: [Element] = []
    try await decodeArray { decoder in
      while !decoder.isAtEnd {
        elements.append(try await decoder.decodeElement(decodeElement))
      }
    }
    return elements
  }

  public mutating func decodeArray<T>(
    _ decodeArray: (inout ArrayDecoder) async throws -> sending T
  ) async throws -> sending T {
    var decoder = try await ArrayDecoder(stream: &self)
    return try await decodeArray(&decoder)
  }

}

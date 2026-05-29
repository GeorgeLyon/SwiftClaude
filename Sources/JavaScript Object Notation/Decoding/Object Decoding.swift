extension DecodingStream {

  public struct ObjectDecoder: ~Copyable, ~Escapable {

    public mutating func startDecodingProperty() async throws -> String {
      try await startDecodingProperty { try await $0.decodeString() }
    }

    /// Decodes the next property name, leaving the stream ready to decode the subsequent value.
    /// The caller is responsible for calling `finishDecodingProperty` once the value is decoded
    public mutating func startDecodingProperty<T>(
      decodeName: (inout DecodingStream) async throws -> T
    ) async throws -> T {
      guard !isAtEnd else {
        throw DecodingError.encountered(.decodingPropertyPastObjectEnd, at: stream.currentPosition)
      }
      let name = try await decodeName(&stream)
      try await stream.readWhitespace()
      try await stream.read(":")
      return name
    }

    public mutating func finishDecodingProperty() async throws {
      try await stream.readWhitespace()
      switch try await stream.read(PrivateComponent.self) {
      case .property:
        assert(!isAtEnd)
      case .end:
        isAtEnd = true
      }
    }

    public mutating func decodeProperty<T>(
      decodeValue: (String, inout DecodingStream) async throws -> sending T
    ) async throws -> sending T {
      try await decodeProperty(
        decodeName: { stream in
          try await stream.decodeString()
        },
        decodeValue: decodeValue
      )
    }

    public mutating func decodeProperty<PropertyName: ~Copyable & ~Escapable, T>(
      decodeName: (inout DecodingStream) async throws -> PropertyName,
      decodeValue: (consuming PropertyName, inout DecodingStream) async throws -> sending T
    ) async throws -> sending T {
      guard !isAtEnd else {
        throw DecodingError.encountered(.decodingPropertyPastObjectEnd, at: stream.currentPosition)
      }
      let name = try await decodeName(&stream)
      try await stream.readWhitespace()
      try await stream.read(":")
      let result = try await decodeValue(name, &stream)
      try await finishDecodingProperty()
      return result
    }

    public mutating func peekObjectProperty<T>(
      named name: String,
      peekPropertyValue: (inout DecodingStream) async throws -> sending T
    ) async throws -> sending T? {
      try await peekObjectProperty(
        matchPropertyName: { nameStream in
          try await nameStream.decodeString() == name
        },
        peekPropertyValue: peekPropertyValue
      )
    }

    public mutating func peekObjectProperty<T>(
      matchPropertyName: (inout DecodingStream) async throws -> Bool,
      peekPropertyValue: (inout DecodingStream) async throws -> sending T
    ) async throws -> sending T? {
      let start = stream.currentPosition
      let wasAtEnd = isAtEnd
      defer {
        isAtEnd = wasAtEnd
        stream.restore(start)
      }
      while !isAtEnd {
        let result = try await decodeProperty(
          decodeName: { stream in
            try await matchPropertyName(&stream)
          },
          decodeValue: { (isPeekedProperty, stream) -> T? in
            if isPeekedProperty {
              return try await peekPropertyValue(&stream)
            } else {
              try await stream.decodeValue()
              return nil
            }
          }
        )
        if let result {
          return result
        }
      }
      return nil
    }

    @_lifetime(&stream)
    fileprivate init(stream: inout DecodingStream) async throws(DecodingError) {
      try await stream.readWhitespace()
      try await stream.read("{")
      try await stream.readWhitespace()
      isAtEnd = try await stream.readByteIfPresent(in: "}")
      self.stream = stream.mutate()
    }

    @_lifetime(&other)
    private init(
      other: inout Self
    ) {
      isAtEnd = other.isAtEnd
      stream = other.stream.mutate()
    }

    public private(set) var isAtEnd: Bool
    public var stream: DecodingStream

    private enum PrivateComponent: Byte, ByteRepresentable {
      case end = "}"
      case property = ","
    }

  }

  public mutating func decodeObject<T>(
    _ decodeObject: (inout ObjectDecoder) async throws -> sending T
  ) async throws -> sending T {
    var decoder = try await ObjectDecoder(stream: &self)
    return try await decodeObject(&decoder)
  }

}

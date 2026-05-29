extension EncodingStream {

  public struct ObjectEncoder: ~Copyable {

    public mutating func encodeProperty(
      _ name: String,
      encodeValue: (inout EncodingStream) throws -> Void
    ) rethrows {
      try encodeProperty(
        encodeName: { stream in
          stream.encode(name)
        },
        encodeValue: encodeValue
      )
    }

    public mutating func encodeProperty(
      encodeName: (inout EncodingStream) -> Void,
      encodeValue: (inout EncodingStream) throws -> Void
    ) rethrows {
      if isFirstProperty {
        isFirstProperty = false
      } else {
        stream.write(",")
        stream.writeNewline()
      }

      stream.writeIndentation()
      encodeName(&stream)
      stream.write(":")
      stream.writeIfPretty(" ")
      try encodeValue(&stream)
    }

    fileprivate init(stream: consuming EncodingStream) {
      stream.write("{")
      self.stream = stream
      self.stream.increaseNesting()
    }

    fileprivate consuming func finish() -> EncodingStream {
      stream.decreaseNesting()
      stream.writeIndentation()
      stream.write("}")
      return stream
    }

    private var isFirstProperty = true
    private var stream: EncodingStream

  }

  public mutating func encodeObject(
    _ encode: (inout ObjectEncoder) throws -> Void
  ) rethrows {
    var encoder = ObjectEncoder(stream: self)
    do {
      try encode(&encoder)
      self = encoder.finish()
    } catch {
      self = encoder.finish()
      throw error
    }
  }

}

extension EncodingStream {

  public struct ArrayEncoder: ~Copyable {

    public mutating func encodeElement(
      _ encodeValue: (inout EncodingStream) throws -> Void
    ) rethrows {
      if isFirstElement {
        isFirstElement = false
      } else {
        stream.write(",")
        stream.writeNewline()
      }
      stream.writeIndentation()
      try encodeValue(&stream)
    }

    fileprivate init(stream: consuming EncodingStream) {
      stream.write("[")
      self.stream = stream
      self.stream.increaseNesting()
    }

    fileprivate consuming func finish() -> EncodingStream {
      stream.decreaseNesting()
      stream.writeIndentation()
      stream.write("]")
      return stream
    }

    private var isFirstElement = true
    private var stream: EncodingStream

  }

  public mutating func encodeArray(
    _ encode: (inout ArrayEncoder) throws -> Void
  ) rethrows {
    var encoder = ArrayEncoder(stream: self)
    do {
      try encode(&encoder)
      self = encoder.finish()
    } catch {
      self = encoder.finish()
      throw error
    }
  }

}

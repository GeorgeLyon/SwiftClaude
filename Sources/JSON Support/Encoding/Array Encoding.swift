extension JSON {

  public struct ArrayEncoder: Sendable, ~Copyable {

    public mutating func encodeElement(
      _ encodeValue: (inout EncodingStream) -> Void
    ) {
      if isFirstElement {
        isFirstElement = false
      } else {
        stream.write(",")
      }
      encodeValue(&stream)
    }

    fileprivate init(stream: consuming EncodingStream) {
      self.stream = stream
    }

    fileprivate consuming func finish() -> EncodingStream {
      stream.write("]")
      return stream
    }

    private var isFirstElement = true
    private var stream: EncodingStream

  }

}

extension JSON.EncodingStream {

  public mutating func encodeArray(
    _ encode: (inout JSON.ArrayEncoder) -> Void
  ) {
    write("[")
    var encoder = JSON.ArrayEncoder(stream: self)
    encode(&encoder)
    self = encoder.finish()
  }

}

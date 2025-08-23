extension JSON {

  public struct ObjectEncoder: Sendable, ~Copyable {

    public mutating func encodeProperty(
      name: String,
      encodeValue: (inout EncodingStream) -> Void
    ) {
      if isFirstProperty {
        isFirstProperty = false
      } else {
        stream.write(",")
        stream.writeLineBreak()
      }

      stream.writeIndentation()
      stream.encode(name)
      stream.write(":")
      stream.writeIfPretty(" ")
      encodeValue(&stream)
    }

    fileprivate init(stream: consuming EncodingStream) {
      self.stream = stream
      self.stream.writeLineBreak(depthChange: 1)
    }

    fileprivate consuming func finish() -> EncodingStream {
      stream.writeLineBreak(depthChange: -1)
      stream.writeIndentation()
      stream.write("}")
      return stream
    }

    private var isFirstProperty = true
    private var stream: EncodingStream

  }

}

extension JSON.EncodingStream {

  public mutating func encodeObject(
    _ encode: (inout JSON.ObjectEncoder) -> Void
  ) {
    write("{")
    var encoder = JSON.ObjectEncoder(stream: self)
    encode(&encoder)
    self = encoder.finish()
  }

}

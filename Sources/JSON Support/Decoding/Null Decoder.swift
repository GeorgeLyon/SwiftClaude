extension JSON {

  public struct NullDecoder: PrimitiveDecoder, ~Copyable {

    public init() {
      self.init(stream: JSON.DecodingStream())
    }

    public mutating func decodeNull() throws -> JSON.DecodingResult<Void> {
      try state.decodeValue()
    }

    static func decodeValueStatelessly(_ stream: inout JSON.DecodingStream) throws
      -> JSON.DecodingResult<Void>
    {
      try stream.read("null").decodingResult()
    }

    init(state: consuming State) {
      self.state = state
    }

    consuming func finish() -> FinishDecodingResult<Self> {
      state.finish()
    }

    var state: State

  }

}

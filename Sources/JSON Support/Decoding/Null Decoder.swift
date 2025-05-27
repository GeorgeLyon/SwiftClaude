extension JSON {

  public struct NullDecoder: PrimitiveDecoder, ~Copyable {

    public init() {
      self.init(stream: JSON.DecodingStream())
    }

    public mutating func decodeNull() throws -> JSON.DecodingResult<Void> {
      try state.decodeValue()
    }

    public var isComplete: Bool {
      get throws {
        try state.isComplete
      }
    }

    static func decodeValueStatelessly(_ stream: inout JSON.DecodingStream) throws
      -> JSON.DecodingResult<Void>
    {
      stream.readWhitespace()
      return try stream.read("null").decodingResult()
    }

    init(state: consuming State) {
      self.state = state
    }

    consuming func finish() -> FinishDecodingResult<Self> {
      state.finish()
    }

    consuming func destroy() -> JSON.DecodingStream {
      state.destroy()
    }

    var state: State

  }

}

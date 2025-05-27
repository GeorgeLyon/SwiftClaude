extension JSON {

  public struct NullDecoder: PrimitiveDecoder, ~Copyable {

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

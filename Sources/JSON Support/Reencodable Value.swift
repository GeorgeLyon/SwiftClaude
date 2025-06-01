extension JSON {

  public struct ReencodableValueDecodingState {

    public init() {}

    fileprivate var start: JSON.DecodingStream.Checkpoint?
    fileprivate var valueState = JSON.ValueDecodingState()
  }

  public struct ReencodableValue: Sendable {
    fileprivate let validatedJSONString: Substring
  }

}

// MARK: - Decoding

extension JSON.DecodingStream {

  public mutating func decodeReencodableValue(state: inout JSON.ReencodableValueDecodingState)
    throws
    -> JSON.DecodingResult<JSON.ReencodableValue>
  {
    readWhitespace()

    let checkpoint: JSON.DecodingStream.Checkpoint
    if let start = state.start {
      checkpoint = start
    } else {
      checkpoint = createCheckpoint()
      state.start = checkpoint
    }

    return try decodeValue(&state.valueState)
      .map { _ in
        JSON.ReencodableValue(
          validatedJSONString: substringRead(since: checkpoint)
        )
      }

  }
}

// MARK: - Encoding

extension JSON.EncodingStream {

  public mutating func encode(_ value: JSON.ReencodableValue) {
    write(value.validatedJSONString)
  }

}

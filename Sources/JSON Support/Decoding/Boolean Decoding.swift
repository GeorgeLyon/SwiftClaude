extension JSON {

  struct BooleanDecoder: PrimitiveDecoder, ~Copyable {
    typealias Value = Bool

    init(state: consuming State) {
      self.state = state
    }

    var state: PrimitiveDecoderState<Self>

    static func decodeValueStatelessly(
      _ stream: inout JSON.DecodingStream
    ) throws -> JSON.DecodingResult<Bool> {
      try stream.readBoolean()
    }

    consuming func finish() -> FinishDecodingResult<Self> {
      state.finish()
    }
  }

}

extension JSON.DecodingStream {

  mutating func readBoolean() throws -> JSON.DecodingResult<Bool> {
    readWhitespace()

    let expectedValue = try peekCharacter { character in
      switch character {
      case "t":
        return true
      case "f":
        return false
      default:
        return nil
      }
    }.decodingResult()

    switch expectedValue {
    case .needsMoreData:
      return .needsMoreData
    case .decoded(let value):
      if value {
        return try read("true").decodingResult().map { _ in true }
      } else {
        return try read("false").decodingResult().map { _ in false }
      }
    }
  }

}

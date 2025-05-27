extension JSON {

  public struct BooleanDecoder: PrimitiveDecoder, ~Copyable {

    public init() {
      self.init(stream: JSON.DecodingStream())
    }

    public mutating func decodeBoolean() throws -> JSON.DecodingResult<Bool> {
      try state.decodeValue()
    }

    public var isComplete: Bool {
      get throws {
        try state.isComplete
      }
    }

    init(state: consuming State) {
      self.state = state
    }

    var state: PrimitiveDecoderState<Self>

    static func decodeValueStatelessly(
      _ stream: inout JSON.DecodingStream
    ) throws -> JSON.DecodingResult<Bool> {
      stream.readWhitespace()
      return try stream.readBoolean()
    }

    consuming func finish() -> FinishDecodingResult<Self> {
      state.finish()
    }

    consuming func destroy() -> JSON.DecodingStream {
      state.destroy()
    }
  }

}

extension JSON.DecodingStream {

  mutating func readBoolean() throws -> JSON.DecodingResult<Bool> {
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

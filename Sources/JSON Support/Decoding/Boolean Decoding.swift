extension JSON.DecodingStream {

  public mutating func decodeBoolean() throws -> JSON.DecodingResult<Bool> {
    try readBoolean().decodingResult()
  }

  mutating func readBoolean() -> ReadResult<Bool> {
    readWhitespace()

    let expectedValue = peekCharacter { character in
      switch character {
      case "t":
        return true
      case "f":
        return false
      default:
        return nil
      }
    }

    switch expectedValue {
    case .needsMoreData:
      return .needsMoreData
    case .notMatched(let error):
      return .notMatched(error)
    case .matched(let value):
      /// Read cursor is only updated if the read is successful
      switch read(value ? "true" : "false") {
      case .needsMoreData:
        return .needsMoreData
      case .notMatched(let error):
        return .notMatched(error)
      case .matched:
        return .matched(value)
      }
    }
  }

}

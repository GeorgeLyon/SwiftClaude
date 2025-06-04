extension JSON.DecodingStream {

  public mutating func decodeNull() throws -> JSON.DecodingResult<Void> {
    try readNull().decodingResult()
  }

  /// Returns: - `.decoded(true)` if we decoded a null
  public mutating func decodeNullIfPresent() throws -> JSON.DecodingResult<Bool> {
    readWhitespace()

    let peekNull = peekCharacter { character in
      switch character {
      case "n":
        return true
      default:
        return false
      }
    }

    switch peekNull {
    case .needsMoreData:
      return .needsMoreData
    case .matched(true):
      return try decodeNull()
        .map { _ in true }
    case .matched(false):
      return .decoded(false)
    case .notMatched(let error):
      throw error
    }
  }

  mutating func readNull() -> ReadResult<Void> {
    readWhitespace()
    return read("null")
  }

}

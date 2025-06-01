extension JSON.DecodingStream {

  public mutating func decodeNull() throws -> JSON.DecodingResult<Void> {
    readWhitespace()
    return try read("null").decodingResult()
  }

  /// Returns: - `.decoded(true)` if we expect to decode a null value next
  public mutating func peekNull() throws -> JSON.DecodingResult<Bool> {
    readWhitespace()
    return try peekCharacter { character in
      switch character {
      case "n":
        return true
      default:
        return false
      }
    }.decodingResult()
  }

}

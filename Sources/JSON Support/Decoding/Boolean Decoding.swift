extension JSON.DecodingStream {

  public mutating func decodeBoolean() throws -> JSON.DecodingResult<Bool> {
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
      /// Read cursor is only updated if the read is successful
      let result = read(value ? "true" : "false")
      return try result.decodingResult().map { _ in value }
    }
  }

}

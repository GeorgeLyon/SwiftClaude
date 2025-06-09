extension JSON.DecodingStream {

  public mutating func decodeNull() throws -> JSON.DecodingResult<Void> {
    try readNull().decodingResult()
  }

  mutating func readNull() -> ReadResult<Void> {
    readWhitespace()
    return read("null")
  }

}

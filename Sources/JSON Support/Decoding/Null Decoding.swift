extension JSON.DecodingStream {

  public mutating func decodeNull() throws -> JSON.DecodingResult<Void> {
    readWhitespace()
    return try read("null").decodingResult()
  }

}

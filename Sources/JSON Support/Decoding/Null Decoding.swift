extension JSON.DecodingStream {

  fileprivate mutating func readNull() throws -> JSON.DecodingResult<Void> {
    readWhitespace()
    return try read("null").decodingResult()
  }

}

extension DecodingStream {

  public mutating func decodeNull() async throws(DecodingError) {
    try await readWhitespace()
    return try await read("null")
  }

}

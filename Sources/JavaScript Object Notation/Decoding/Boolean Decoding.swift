extension DecodingStream {

  public mutating func decodeBoolean() async throws(DecodingError) -> Bool {
    try await readWhitespace()

    enum FirstLetter: Byte, ByteRepresentable {
      case t = "t"
      case f = "f"
    }
    switch try await read(FirstLetter.self) {
    case .t:
      try await read("rue")
      return true
    case .f:
      try await read("alse")
      return false
    }
  }

}

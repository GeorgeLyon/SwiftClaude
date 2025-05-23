extension JSON {

  public struct Number {
    let significand: Substring
    let exponent: Substring?
  }

}

extension JSON.DecodingStream {

  public mutating func decodeNumber<T>(
    onSuccess: (JSON.Number) throws -> T
  ) throws -> T? {
    readWhitespace()

    let start = createCheckpoint()

    guard try !read(whileCharactersIn: "-", maxCount: 1).isContinuable else {
      restore(start)
      return nil
    }
    guard try !read(whileCharactersIn: "0"..."9", minCount: 1).isContinuable else {
      restore(start)
      return nil
    }

    fatalError()
  }

}

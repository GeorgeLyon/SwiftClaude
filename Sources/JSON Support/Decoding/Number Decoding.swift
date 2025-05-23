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
    fatalError()
  }

  private mutating func readSignificand() throws -> Bool {
    guard
      try !read(whileCharactersIn: "-", maxCount: 1).isContinuable
    else {
      return false
    }

    switch read("0") {
    case .continuableMatch:
      return false
    case .matched:
      switch read(".") {
      case .continuableMatch:
        return false
      case .matched:
        guard try !read(whileCharactersIn: "0"..."9", minCount: 1).isContinuable else {
          return false
        }
      case .notMatched:
        /// This number can only be `0` because JSON disallows leading zeroes
        break
      }
    case .notMatched:
      guard try !read(whileCharactersIn: "1"..."9", minCount: 1).isContinuable else {
        return false
      }
      break
    }
    fatalError()
  }

}

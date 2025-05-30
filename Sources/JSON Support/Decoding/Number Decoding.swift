extension JSON {

  public struct Number {
    let stringValue: Substring
    let significand: Substring
    let integerPart: Substring
    let fractionalPart: Substring?
    let exponent: Substring?
  }

}

extension JSON.DecodingStream {

  public mutating func decodeNumber() throws -> JSON.DecodingResult<JSON.Number> {
    let significand: Substring
    let integerPart: Substring
    let fractionalPart: Substring?
    let exponentPart: Substring?

    readWhitespace()

    let start = createCheckpoint()

    /// Read integer part
    do {
      guard try !read(whileCharactersIn: "-", maxCount: 1).needsMoreData else {
        restore(start)
        return .needsMoreData
      }

      guard
        try !read(
          whileCharactersIn: "0"..."9",
          minCount: 1,
          process: { substring, _ in
            guard substring.prefix(while: { $0 == "0" }).count < 2 else {
              throw Error.numberWithLeadingZeroes
            }
          }
        ).needsMoreData
      else {
        restore(start)
        return .needsMoreData
      }
      integerPart = substringDecoded(since: start)
    }

    /// Read fractional part
    switch read(".") {
    case .needsMoreData:
      restore(start)
      return .needsMoreData

    case .matched:
      let fractionStart = createCheckpoint()

      guard try !read(whileCharactersIn: "0"..."9", minCount: 1).needsMoreData else {
        restore(start)
        return .needsMoreData
      }

      fractionalPart = substringDecoded(since: fractionStart)

    case .notMatched:
      fractionalPart = nil
      break
    }

    significand = substringDecoded(since: start)

    /// Read exponent
    switch read(whileCharactersIn: "E", "e", minCount: 1, maxCount: 1) {
    case .needsMoreData:
      restore(start)
      return .needsMoreData

    case .matched:
      let exponentStart = createCheckpoint()

      guard
        try !read(whileCharactersIn: "+", "-", maxCount: 1).needsMoreData,
        try !read(whileCharactersIn: "0"..."9", minCount: 1).needsMoreData
      else {
        restore(start)
        return .needsMoreData
      }

      exponentPart = substringDecoded(since: exponentStart)

    case .notMatched:
      exponentPart = nil
      break
    }

    return .decoded(
      JSON.Number(
        stringValue: substringDecoded(since: start),
        significand: significand,
        integerPart: integerPart,
        fractionalPart: fractionalPart,
        exponent: exponentPart
      )
    )
  }

}

private enum Error: Swift.Error {
  case numberWithLeadingZeroes
}

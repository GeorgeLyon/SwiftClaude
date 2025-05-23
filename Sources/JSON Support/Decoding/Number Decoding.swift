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

  public mutating func decodeNumber<T>(
    process: (JSON.Number) throws -> T
  ) throws -> T? {
    let significand: Substring
    let integerPart: Substring
    let fractionalPart: Substring?
    let exponentPart: Substring?

    readWhitespace()

    let start = createCheckpoint()

    /// Read integer part
    do {
      guard try !read(whileCharactersIn: "-", maxCount: 1).isContinuable else {
        restore(start)
        return nil
      }
      let result = try read(
        whileCharactersIn: "0"..."9",
        minCount: 1,
        process: { substring in
          guard substring.prefix(while: { $0 == "0" }).count < 2 else {
            throw JSON.Number.Error.leadingZeroes
          }
        }
      )
      switch result {
      case .continuableMatch:
        restore(start)
        return nil
      case .matched:
        break
      case .notMatched(let error):
        throw error
      }
      integerPart = substringRead(since: start)
    }

    /// Read fractional part
    switch read(".") {
    case .continuableMatch:
      restore(start)
      return nil

    case .matched:
      let fractionStart = createCheckpoint()

      guard try !read(whileCharactersIn: "0"..."9", minCount: 1).isContinuable else {
        restore(start)
        return nil
      }

      fractionalPart = substringRead(since: fractionStart)

    case .notMatched:
      fractionalPart = nil
      break
    }

    significand = substringRead(since: start)

    /// Read exponent
    switch read(whileCharactersIn: "E", "e", minCount: 1, maxCount: 1) {
    case .continuableMatch:
      restore(start)
      return nil

    case .matched:
      let exponentStart = createCheckpoint()

      guard
        try !read(whileCharactersIn: "+", "-", maxCount: 1).isContinuable,
        try !read(whileCharactersIn: "0"..."9", minCount: 1).isContinuable
      else {
        restore(start)
        return nil
      }

      exponentPart = substringRead(since: exponentStart)

    case .notMatched:
      exponentPart = nil
      break
    }

    let number = JSON.Number(
      stringValue: substringRead(since: start),
      significand: significand,
      integerPart: integerPart,
      fractionalPart: fractionalPart,
      exponent: exponentPart
    )

    return try process(number)
  }

}

extension JSON.Number {

  enum Error: Swift.Error {
    case leadingZeroes
  }

}

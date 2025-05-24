extension JSON {

  public struct Number {
    let stringValue: Substring
    let significand: Substring
    let integerPart: Substring
    let fractionalPart: Substring?
    let exponent: Substring?
  }

}

extension JSON.Value {

  public mutating func decodeAsNumber<T>(
    process: (JSON.Number) throws -> T
  ) throws -> T? {
    let significand: Substring
    let integerPart: Substring
    let fractionalPart: Substring?
    let exponentPart: Substring?

    stream.readWhitespace()

    let start = stream.createCheckpoint()

    /// Read integer part
    do {
      guard try !stream.read(whileCharactersIn: "-", maxCount: 1).isContinuable else {
        stream.restore(start)
        return nil
      }
      let result = try stream.read(
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
        stream.restore(start)
        return nil
      case .matched:
        break
      case .notMatched(let error):
        throw error
      }
      integerPart = stream.substringRead(since: start)
    }

    /// Read fractional part
    switch stream.read(".") {
    case .continuableMatch:
      stream.restore(start)
      return nil

    case .matched:
      let fractionStart = stream.createCheckpoint()

      guard try !stream.read(whileCharactersIn: "0"..."9", minCount: 1).isContinuable else {
        stream.restore(start)
        return nil
      }

      fractionalPart = stream.substringRead(since: fractionStart)

    case .notMatched:
      fractionalPart = nil
      break
    }

    significand = stream.substringRead(since: start)

    /// Read exponent
    switch stream.read(whileCharactersIn: "E", "e", minCount: 1, maxCount: 1) {
    case .continuableMatch:
      stream.restore(start)
      return nil

    case .matched:
      let exponentStart = stream.createCheckpoint()

      guard
        try !stream.read(whileCharactersIn: "+", "-", maxCount: 1).isContinuable,
        try !stream.read(whileCharactersIn: "0"..."9", minCount: 1).isContinuable
      else {
        stream.restore(start)
        return nil
      }

      exponentPart = stream.substringRead(since: exponentStart)

    case .notMatched:
      exponentPart = nil
      break
    }

    let number = JSON.Number(
      stringValue: stream.substringRead(since: start),
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

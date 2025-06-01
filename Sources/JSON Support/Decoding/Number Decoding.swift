public import Foundation

extension JSON {

  public struct Number {

    public let stringValue: Substring

    let significand: Substring
    let integerPart: Substring
    let fractionalPart: Substring?
    let exponent: Substring?
  }

}

extension JSON.Number {

  public func decode<T: FixedWidthInteger>(as _: T.Type = T.self) throws -> T {
    guard let value = T(integerPart) else {
      throw Error.notRepresentable
    }
    guard fractionalPart == nil, exponent == nil else {
      throw Error.notRepresentable
    }
    return value
  }

  public func decode<
    T: BinaryFloatingPoint & LosslessStringConvertible
  >(
    as _: T.Type = T.self
  ) throws -> T {
    guard let value = T(String(significand)) else {
      throw Error.notRepresentable
    }
    guard exponent == nil else {
      throw Error.notRepresentable
    }
    return value
  }

  public func decode(
    as _: Float.Type = Float.self
  ) throws -> Float {
    guard var value = Float(significand) else {
      throw Error.notRepresentable
    }
    if let exponent {
      guard let exponentValue = Float(exponent) else {
        throw Error.notRepresentable
      }
      value = value * pow(10.0, exponentValue)
    }
    return value
  }

  public func decode(
    as _: Double.Type = Double.self
  ) throws -> Double {
    guard var value = Double(significand) else {
      throw Error.notRepresentable
    }
    if let exponent {
      guard let exponentValue = Double(exponent) else {
        throw Error.notRepresentable
      }
      value = value * pow(10.0, exponentValue)
    }
    return value
  }

  public func decode(
    as _: Decimal.Type = Decimal.self
  ) throws -> Decimal {
    guard var value = Decimal(string: String(significand)) else {
      throw Error.notRepresentable
    }
    if let exponent {
      guard let exponentValue = Int(exponent) else {
        throw Error.notRepresentable
      }
      value = value * pow(Decimal(10), exponentValue)
    }
    return value
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
      integerPart = substringRead(since: start)
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

      fractionalPart = substringRead(since: fractionStart)

    case .notMatched:
      fractionalPart = nil
      break
    }

    significand = substringRead(since: start)

    /// Read exponent
    switch read(whileCharactersIn: ["E", "e"], minCount: 1, maxCount: 1) {
    case .needsMoreData:
      restore(start)
      return .needsMoreData

    case .matched:
      let exponentStart = createCheckpoint()

      guard
        try !read(whileCharactersIn: ["+", "-"], maxCount: 1).needsMoreData,
        try !read(whileCharactersIn: "0"..."9", minCount: 1).needsMoreData
      else {
        restore(start)
        return .needsMoreData
      }

      exponentPart = substringRead(since: exponentStart)

    case .notMatched:
      exponentPart = nil
      break
    }

    return .decoded(
      JSON.Number(
        stringValue: substringRead(since: start),
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
  case notRepresentable
}

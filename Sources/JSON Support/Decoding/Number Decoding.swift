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
    let effectiveInteger: Substring
    if let exponent {
      // You can do 1.25e2 (125) or 100e-1 (10) 🫠
      guard let exponentValue = Int(exponent) else {
        throw Error.notRepresentable
      }
      if exponentValue < 0 {
        guard integerPart.suffix(-exponentValue) == String(repeating: "0", count: -exponentValue)
        else {
          throw Error.notRepresentable
        }
        effectiveInteger = integerPart.dropLast(-exponentValue)
      } else {
        let fractionalPart = fractionalPart ?? ""
        guard fractionalPart.count <= exponentValue else {
          throw Error.notRepresentable
        }
        effectiveInteger =
          integerPart + fractionalPart
          + String(repeating: "0", count: exponentValue - fractionalPart.count)
      }
    } else {
      effectiveInteger = integerPart
      guard fractionalPart == nil else {
        throw Error.notRepresentable
      }
    }
    guard let value = T(String(effectiveInteger)) else {
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
    try readNumber().decodingResult()
  }

  mutating func readNumber() -> ReadResult<JSON.Number> {
    let significand: Substring
    let integerPart: Substring
    let fractionalPart: Substring?
    let exponentPart: Substring?

    readWhitespace()

    let start = createCheckpoint()

    /// Read integer part
    do {
      switch read(whileCharactersIn: "-", maxCount: 1) {
      case .matched:
        break
      case .incomplete:
        restore(start)
        return .incomplete
      case .notMatched(let error):
        return .notMatched(error)
      }

      let result = read(
        whileCharactersIn: "0"..."9",
        minCount: 1,
        process: { substring, _ in
          guard substring.prefix(while: { $0 == "0" }).count < 2 else {
            throw Error.numberWithLeadingZeroes
          }
        }
      )
      switch result {
      case .matched:
        break
      case .incomplete:
        restore(start)
        return .incomplete
      case .notMatched(let error):
        return .notMatched(error)
      }
      integerPart = substringRead(since: start)
    }

    /// Read fractional part
    switch read(".") {
    case .incomplete:
      restore(start)
      return .incomplete

    case .matched:
      let fractionStart = createCheckpoint()

      switch read(whileCharactersIn: "0"..."9", minCount: 1) {
      case .matched:
        break
      case .incomplete:
        restore(start)
        return .incomplete
      case .notMatched(let error):
        return .notMatched(error)
      }

      fractionalPart = substringRead(since: fractionStart)

    case .notMatched:
      fractionalPart = nil
      break
    }

    significand = substringRead(since: start)

    /// Read exponent
    switch read(whileCharactersIn: ["E", "e"], minCount: 1, maxCount: 1) {
    case .incomplete:
      restore(start)
      return .incomplete

    case .matched:
      let exponentStart = createCheckpoint()

      switch read(whileCharactersIn: ["+", "-"], maxCount: 1) {
      case .matched:
        break
      case .incomplete:
        restore(start)
        return .incomplete
      case .notMatched(let error):
        return .notMatched(error)
      }

      switch read(whileCharactersIn: "0"..."9", minCount: 1) {
      case .matched:
        break
      case .incomplete:
        restore(start)
        return .incomplete
      case .notMatched(let error):
        return .notMatched(error)
      }

      exponentPart = substringRead(since: exponentStart)

    case .notMatched:
      exponentPart = nil
      break
    }

    return .matched(
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

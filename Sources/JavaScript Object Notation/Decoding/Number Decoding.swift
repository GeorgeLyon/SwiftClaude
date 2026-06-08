public import Foundation

extension DecodingStream {

  public struct Number: ~Copyable, ~Escapable {

    public func decode<T: FixedWidthInteger & Sendable>(as _: T.Type = T.self) throws(DecodingError)
      -> sending T
    {
      let fractionalPart = fractionalPart ?? .empty
      if let exponent {
        if fractionalPart.isAllZeroes, integerPart.isZero {
          /// 0 is 0 regardless of exponent
          return 0
        }
        guard let exponentValue = Int(exponent.stringValue) else {
          throw .encountered(.numberNotRepresentable, at: position)
        }
        if exponentValue < 0 {
          guard
            /// `Int(exactly:)` rejects `Int.min`, whose magnitude overflows `Int`.
            let negatedExponent = Int(exactly: exponentValue.magnitude),
            negatedExponent < integerPart.count,
            integerPart.suffix(negatedExponent).isAllZeroes,
            fractionalPart.isAllZeroes,
            let value = T(integerPart.dropLast(negatedExponent).stringValue)
          else {
            throw .encountered(.numberNotRepresentable, at: position)
          }
          return value
        } else {
          guard
            fractionalPart.dropFirst(exponentValue).isAllZeroes,
            let value = T(
              integerPart.stringValue + fractionalPart.prefix(exponentValue).stringValue
            )
          else {
            throw .encountered(.numberNotRepresentable, at: position)
          }
          if fractionalPart.count < exponentValue {
            guard
              let value = value.multipliedByTen(
                toThePowerOf: exponentValue - fractionalPart.count
              )
            else {
              throw .encountered(.numberNotRepresentable, at: position)
            }
            return value
          } else {
            return value
          }
        }
      } else {
        guard
          fractionalPart.isAllZeroes,
          let value = T(integerPart.stringValue)
        else {
          throw .encountered(.numberNotRepresentable, at: position)
        }
        return value
      }
    }

    public func decode<
      T: BinaryFloatingPoint & LosslessStringConvertible & Sendable
    >(
      as _: T.Type = T.self
    ) throws(DecodingError) -> sending T {
      guard let value = T(number.stringValue) else {
        throw .encountered(.numberNotRepresentable, at: position)
      }
      guard value.isFinite else {
        throw .encountered(.numberIsInfinite, at: position)
      }
      return value
    }

    public func decode(as _: Decimal.Type = Decimal.self) throws(DecodingError) -> sending Decimal {
      guard let value = Decimal(string: number.stringValue) else {
        throw .encountered(.numberNotRepresentable, at: position)
      }
      guard !value.isNaN else {
        throw .encountered(.numberNotRepresentable, at: position)
      }
      return value
    }

    public var opaqueValue: OpaqueValue {
      OpaqueValue(bytes: number.array)
    }

    private let position: DecodingStream.Position
    private let number: Bytes.SubSequence
    private let significand: Bytes.SubSequence
    private let integerPart: Bytes.SubSequence
    private let fractionalPart: Bytes.SubSequence?
    private let exponent: Bytes.SubSequence?

    @_lifetime(borrow stream)
    fileprivate init(
      stream: borrowing DecodingStream,
      position: consuming DecodingStream.Position,
      number: Bytes.SubSequence,
      significand: Bytes.SubSequence,
      integerPart: Bytes.SubSequence,
      fractionalPart: Bytes.SubSequence?,
      exponent: Bytes.SubSequence?
    ) {
      self.position = position
      self.number = number
      self.significand = significand
      self.integerPart = integerPart
      self.fractionalPart = fractionalPart
      self.exponent = exponent
    }

  }

}

extension DecodingStream {

  @_lifetime(&self)
  public mutating func decodeNumber() async throws(DecodingError) -> Number {
    let significand: Bytes.SubSequence
    let integerPart: Bytes.SubSequence
    let fractionalPart: Bytes.SubSequence?
    let exponent: Bytes.SubSequence?

    try await readWhitespace()

    let numberStart = currentPosition

    /// Read integer part
    let significandStart = currentPosition
    do {
      try await readByteIfPresent(in: "-")
      let digits = try await readBytes(
        whileIn: "0"..."9",
        minCount: 1
      )
      guard digits.count == 1 || digits.prefix(whileIn: "0").isEmpty else {
        throw .encountered(.numberWithLeadingZeroes, at: numberStart)
      }
      integerPart = bytesRead(since: significandStart)
    }

    /// Read fractional part
    do {
      if try await readByteIfPresent(in: ".") {
        let fractionStart = currentPosition
        try await readBytes(whileIn: "0"..."9", minCount: 1)
        fractionalPart = bytesRead(since: fractionStart)
      } else {
        fractionalPart = nil
      }
    }

    significand = bytesRead(since: significandStart)

    /// Read exponent
    do {
      if try await readByteIfPresent(in: ["E", "e"]) {
        let exponentStart = currentPosition
        try await readByteIfPresent(in: ["+", "-"])
        try await readBytes(whileIn: "0"..."9", minCount: 1)
        exponent = bytesRead(since: exponentStart)
      } else {
        exponent = nil
      }
    }

    let number = bytesRead(since: numberStart)
    return Number(
      stream: self,
      position: numberStart,
      number: number,
      significand: significand,
      integerPart: integerPart,
      fractionalPart: fractionalPart,
      exponent: exponent
    )
  }

}

extension Bytes.SubSequence {

  fileprivate var isAllZeroes: Bool {
    for index in indices {
      guard self[index] == Byte.asciiZero.value else {
        return false
      }
    }
    return true
  }

  fileprivate var isZero: Bool {
    [
      [Byte.asciiZero.value],
      [Byte.asciiMinus.value, Byte.asciiZero.value],
    ].contains(array)
  }

}

extension Byte {
  fileprivate static let asciiMinus: Byte = "-"
  fileprivate static let asciiZero: Byte = "0"
}

extension FixedWidthInteger {

  func multipliedByTen(toThePowerOf n: Int) -> Self? {
    /// Short-circuit pathological cases to avoid DoS
    guard self != 0 else { return self }
    guard n < Self.bitWidth else { return nil }

    var value = self
    for _ in 0..<n {
      let (nextValue, overflow) = value.multipliedReportingOverflow(by: 10)
      guard !overflow else {
        return nil
      }
      value = nextValue
    }
    return value
  }

}

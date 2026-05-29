public import Foundation

// MARK: - Integer

extension EncodingStream {

  public mutating func encode(_ value: Int) { encodeBinaryInteger(value) }
  public mutating func encode(_ value: Int8) { encodeBinaryInteger(value) }
  public mutating func encode(_ value: Int16) { encodeBinaryInteger(value) }
  public mutating func encode(_ value: Int32) { encodeBinaryInteger(value) }
  public mutating func encode(_ value: Int64) { encodeBinaryInteger(value) }
  public mutating func encode(_ value: UInt8) { encodeBinaryInteger(value) }
  public mutating func encode(_ value: UInt16) { encodeBinaryInteger(value) }
  public mutating func encode(_ value: UInt32) { encodeBinaryInteger(value) }
  public mutating func encode(_ value: UInt64) { encodeBinaryInteger(value) }
  public mutating func encode(_ value: UInt) { encodeBinaryInteger(value) }
  public mutating func encode<T: BinaryInteger>(_ value: T) { encodeBinaryInteger(value) }

  /// Encodes a binary integer without depending on Unicode
  private mutating func encodeBinaryInteger<T: BinaryInteger>(_ value: T) {
    /// Upper bound on decimal digit count: ⌈bitWidth × log₁₀(2)⌉ + 1
    /// Always-sufficient integer approximation: 1/3 ≈ 0.333 > 0.30103 = log₁₀(2)
    let maxDigits = (value.magnitude.bitWidth + 2) / 3 + 1

    withUnsafeTemporaryAllocation(
      of: UInt8.self,
      /// Additional byte for possible sign
      capacity: maxDigits + 1
    ) { buffer in
      var remainingMagnitude = value.magnitude
      /// We write from the end backwards
      var currentIndex = buffer.indices.last!

      /// Write digits
      while true {
        let (quotient, remainder) =
          remainingMagnitude
          .quotientAndRemainder(dividingBy: 10)
        assert(UInt8(remainder) < 10)
        buffer[currentIndex] = ("0" as Byte).value + UInt8(remainder)
        guard quotient != 0 else {
          break
        }
        remainingMagnitude = quotient
        currentIndex -= 1
      }

      if value.signum() == -1 {
        /// Write sign
        let signIndex = currentIndex - 1
        buffer[signIndex] = ("-" as Byte).value
        write(buffer[signIndex...])
      } else {
        write(buffer[currentIndex...])
      }
    }
  }

}

// MARK: - Floating Point

extension EncodingStream {
  public mutating func encode(_ value: Float16) throws(EncodingError) {
    try encodeFloatingPoint(value)
  }
  public mutating func encode(_ value: Float32) throws(EncodingError) {
    try encodeFloatingPoint(value)
  }
  public mutating func encode(_ value: Double) throws(EncodingError) {
    try encodeFloatingPoint(value)
  }

  private mutating func encodeFloatingPoint<T: BinaryFloatingPoint & LosslessStringConvertible>(
    _ value: T
  ) throws(EncodingError) {
    guard !value.isNaN else {
      throw .numberIsNaN
    }
    guard value.isFinite else {
      throw .numberIsInfinite
    }
    write(String(value))
  }

}

// MARK: - Decimal

extension EncodingStream {

  public mutating func encode(_ value: Decimal) throws(EncodingError) {
    guard !value.isNaN else {
      throw .numberIsNaN
    }
    write("\(value)")
  }

}

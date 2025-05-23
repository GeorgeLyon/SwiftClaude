extension JSON {

  public struct Number {
    let integerPart: Substring
    let fractionalPart: Substring?
    let significand: Substring
    let exponent: Substring?
  }

}

extension JSON.DecodingStream {

  public mutating func decodeNumber<T>(
    onSuccess: (JSON.Number) throws -> T
  ) throws -> T? {
    let start = createCheckpoint()

    fatalError()
  }

}

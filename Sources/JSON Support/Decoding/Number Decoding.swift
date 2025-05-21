extension JSON {

  public struct NumberDecoder: ~Copyable {

    public var stream: DecodingStream

    fileprivate struct Exponent {
      let isNegative: Bool
      let value: Substring
    }

    fileprivate enum Result {
      case invalid(Substring)
      case value(
        integerPart: Substring,
        fractionalPart: Substring,
        exponent: Exponent?
      )
    }

  }

}

extension JSON.DecodingStream {

  public consuming func decodeNumber() -> JSON.NumberDecoder {
    fatalError()
  }

}

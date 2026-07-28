public enum DecodingError: Error {
  case concurrentDecoding
  case taskCancelled
  case streamIncomplete
  case decodingIncomplete
  case removingBytesDuringActiveRead

  /// The byte stream was completed, but the decode operation still produced
  /// no result. A decoding operation may only suspend awaiting more bytes;
  /// this error means it suspended on something the decoder's pump cannot
  /// run — most commonly because the operation is actor-isolated (beware
  /// that a closure literal formed in an actor-isolated context infers that
  /// isolation; pass a nonisolated function instead), or because it awaited
  /// some other external dependency.
  case decodingStalled

  public enum Condition: Sendable, CustomStringConvertible {
    case byte(UInt8)
    case byteRange(ClosedRange<UInt8>)

    public var description: String {
      switch self {
      case .byte(let byte):
        return String(decoding: [byte], as: UTF8.self)
      case .byteRange(let range):
        let lowerBound = String(decoding: [range.lowerBound], as: UTF8.self)
        let upperBound = String(decoding: [range.upperBound], as: UTF8.self)
        return "\(lowerBound)...\(upperBound)"
      }
    }
  }
  public enum Issue: Sendable {
    case expected(StaticString)
    case expectedOneOf([Condition])
    case numberWithLeadingZeroes
    case numberNotRepresentable
    case numberIsInfinite
    case orphanedHighSurrogate
    case orphanedLowSurrogate
    case unescapedControlCharacter
    case unexpectedTrailingByte
    case decodingElementPastArrayEnd
    case decodingPropertyPastObjectEnd

    static func expectedOneOf(_ conditions: Condition...) -> Self {
      .expectedOneOf(conditions)
    }
  }
  case encountered(Issue, index: Int)

}

extension JSON {

  public struct StringBuffer {

    public init() {

    }

    public var stringValue: Substring {
      if isComplete {
        return possiblyIncompleteString[possiblyIncompleteString.startIndex...]
      } else {
        /// The last grapheme cluster in a string can be modified by subsequent unicode scalars.
        /// If we have the string `fac` we can't know whether the string being streamed is `facts` or `façade`.
        /// Emojis can also be modified by a `ZWJ`.
        /// To avoid characters changing mid-stream, we drop the last character while streaming.
        return possiblyIncompleteString.dropLast()
      }
    }

    public fileprivate(set) var isComplete: Bool = false

    public mutating func reset() {
      possiblyIncompleteString.unicodeScalars.removeAll(keepingCapacity: true)
    }

    fileprivate var possiblyIncompleteString: String = ""

  }

}

extension JSON.ByteBuffer {

  mutating func readStringFragment(
    into outputBuffer: inout JSON.StringBuffer,
  ) throws {
    let isComplete = try readStringFragment(
      into: &outputBuffer.possiblyIncompleteString.unicodeScalars
    )
    outputBuffer.isComplete = isComplete
  }

  /// Reads a string fragment into the buffer
  /// - Returns: `true` if the string is complete
  private mutating func readStringFragment(
    into outputBuffer: inout some RangeReplaceableCollection<UnicodeScalar>,
  ) throws -> Bool {
    while true {
      let controlCharacter: ControlCharacter?
      do {
        let readBytes: Bytes.SubSequence
        (readBytes, controlCharacter) = self.readBytes(
          until: { byte -> ControlCharacter? in
            switch UnicodeScalar(byte) {
            case "\"":
              return .end
            case "\\":
              return .escape
            default:
              return nil
            }
          }
        )
        outputBuffer.append(contentsOf: readBytes.map(UnicodeScalar.init))
      }

      switch controlCharacter {
      case .none:
        /// We've reached the end of the buffer
        return false
      case .end:
        return true
      case .escape:
        guard let nextScalar = readByte().map(UnicodeScalar.init) else {
          return false
        }

        switch nextScalar {
        /// Unsupported characters
        case "b", "r", "f":
          throw Error.unsupportedEscapeCharacter(nextScalar)
        /// Verbatim characters
        case "\"", "\\", "/":
          outputBuffer.append(nextScalar)
        /// Escaped characters
        case "n":
          outputBuffer.append("\n")
        case "t":
          outputBuffer.append("\t")
        case "u":
          guard
            let escapeSequence = readBytes(count: 4)
              .map({ String(String.UnicodeScalarView($0.map(UnicodeScalar.init))) })
          else {
            return false
          }

          guard
            let intValue = Int(escapeSequence, radix: 16)
          else {
            throw Error.invalidUnicodeEscapeSequence(escapeSequence)
          }

          switch intValue {

          /// Handle UTF-16 surrogate pairs
          /// Details in Section 2 of https://www.ietf.org/rfc/rfc2781.txt
          case 0xDC00...0xDFFF:
            /// Low surrogate value without corresponding high surrogate value
            throw Error.invalidUnicodeEscapeSequence(escapeSequence)
          case 0xD800...0xDBFF:
            // This is a high surrogate pair any must be immediately followed by a low surrogate pair
            guard
              let remainingBytes = readBytes(count: 6)
                .map({ String(String.UnicodeScalarView($0.map(UnicodeScalar.init))) })
            else {
              return false
            }

            guard remainingBytes.prefix(2) == "\\u" else {
              throw Error.invalidUnicodeEscapeSequence(escapeSequence + remainingBytes)
            }

            guard
              let lowIntValue = Int(remainingBytes.dropFirst(2)),
              (0xDC00...0xDFFF).contains(lowIntValue),
              let scalar = UnicodeScalar(
                [
                  0x10000,
                  ((intValue - 0xD800) << 10),
                  lowIntValue - 0xDC00,
                ].reduce(0, +)
              )
            else {
              throw Error.invalidUnicodeEscapeSequence(escapeSequence + remainingBytes)
            }

            outputBuffer.append(scalar)

          default:
            guard let scalar = UnicodeScalar(intValue) else {
              throw Error.invalidUnicodeScalar(intValue)
            }

            outputBuffer.append(scalar)
          }

        default:
          throw Error.invalidEscapeCharacter(nextScalar)

        }
      }
    }
  }

}

// MARK: - Implementation Details

private enum ControlCharacter {
  case end
  case escape
}

private enum Error: Swift.Error {
  case unsupportedEscapeCharacter(UnicodeScalar)
  case invalidEscapeCharacter(UnicodeScalar)
  case invalidUnicodeEscapeSequence(String)
  case invalidUnicodeScalar(Int)
}

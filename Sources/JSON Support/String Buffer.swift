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

  /// Reads a string fragment into the buffer
  /// - Returns: `true` if the string is complete
  mutating func readStringFragment(
    into outputBuffer: inout JSON.StringBuffer,
  ) throws {
    assert(!outputBuffer.isComplete)
    while true {
      do {
        /// Read bytes until we reach a control character or the end of the string
        let readBytes = self.readBytes(
          until: { byte in
            switch UnicodeScalar(byte) {
            case "\"", "\\":
              return true
            default:
              return false
            }
          }
        )
        let string = String(decoding: readBytes, as: UTF8.self)
        outputBuffer.possiblyIncompleteString.append(string)
      }

      let checkpoint = createCheckpoint()

      switch readByte().map(UnicodeScalar.init) {
      case .none:
        /// We've reached the end of the buffer
        discard(checkpoint)
        return
      case "\"":
        /// We've reached the end of the string
        discard(checkpoint)
        outputBuffer.isComplete = true
        return
      case "\\":
        /// This is an escape sequence
        guard let nextScalar = readByte().map(UnicodeScalar.init) else {
          restore(to: checkpoint)
          return
        }

        switch nextScalar {
        /// Unsupported characters
        case "b", "r", "f":
          restore(to: checkpoint)
          throw Error.unsupportedEscapeCharacter(nextScalar)
        /// Verbatim characters
        case "\"", "\\", "/":
          discard(checkpoint)
          outputBuffer.possiblyIncompleteString.unicodeScalars.append(nextScalar)
        /// Escaped characters
        case "n":
          discard(checkpoint)
          outputBuffer.append("\n")
        case "t":
          discard(checkpoint)
          outputBuffer.append("\t")
        case "u":
          guard
            let escapeSequence = readBytes(count: 4)
              .map({ String(String.UnicodeScalarView($0.map(UnicodeScalar.init))) })
          else {
            restore(to: checkpoint)
            return false
          }

          guard
            let intValue = Int(escapeSequence, radix: 16)
          else {
            restore(to: checkpoint)
            throw Error.invalidUnicodeEscapeSequence(escapeSequence)
          }

          switch intValue {

          /// Handle UTF-16 surrogate pairs
          /// Details in Section 2 of https://www.ietf.org/rfc/rfc2781.txt
          case 0xDC00...0xDFFF:
            /// Low surrogate value without corresponding high surrogate value
            restore(to: checkpoint)
            throw Error.invalidUnicodeEscapeSequence(escapeSequence)
          case 0xD800...0xDBFF:
            // This is a high surrogate pair any must be immediately followed by a low surrogate pair
            guard
              let remainingBytes = readBytes(count: 6)
                .map({ String(String.UnicodeScalarView($0.map(UnicodeScalar.init))) })
            else {
              restore(to: checkpoint)
              return false
            }

            guard remainingBytes.prefix(2) == "\\u" else {
              restore(to: checkpoint)
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
              restore(to: checkpoint)
              throw Error.invalidUnicodeEscapeSequence(escapeSequence + remainingBytes)
            }

            discard(checkpoint)
            outputBuffer.append(scalar)

          default:
            guard let scalar = UnicodeScalar(intValue) else {
              restore(to: checkpoint)
              throw Error.invalidUnicodeScalar(intValue)
            }

            discard(checkpoint)
            outputBuffer.append(scalar)
          }

        default:
          restore(to: checkpoint)
          throw Error.invalidEscapeCharacter(nextScalar)

        }
      default:
        /// This shouldn't be possible, since this character should have been consumed by `readBytes(until:)`
        assertionFailure()
        restore(to: checkpoint)
        throw Error.internalError
      }
    }
  }

}

// MARK: - Implementation Details

private enum Error: Swift.Error {
  case unsupportedEscapeCharacter(UnicodeScalar)
  case invalidEscapeCharacter(UnicodeScalar)
  case invalidUnicodeEscapeSequence(String)
  case invalidUnicodeScalar(Int)
  case internalError
}

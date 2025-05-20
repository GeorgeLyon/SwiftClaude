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
      isComplete = false
    }

    fileprivate var possiblyIncompleteString: String = ""

  }

}

extension JSON.UnicodeScalarBuffer {

  /// Reads a string fragment into the buffer
  /// - Returns: `true` if the string is complete
  mutating func readStringFragment(
    into outputBuffer: inout JSON.StringBuffer,
  ) throws {
    assert(!outputBuffer.isComplete)
    while true {
      /// Read scalars until we reach a control character or the end of the string
      readingScalars(
        until: { byte in
          switch UnicodeScalar(byte) {
          case "\"", "\\":
            return true
          default:
            return false
          }
        }
      ) { scalars in
        outputBuffer.possiblyIncompleteString.unicodeScalars.append(contentsOf: scalars)
      }

      let checkpoint = createCheckpoint()

      switch readScalar() {
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
        guard let nextScalar = readScalar() else {
          restore(to: checkpoint)
          return
        }

        switch nextScalar {
        /// Unsupported characters
        case "b", "r", "f":
          discard(checkpoint)
          outputBuffer.possiblyIncompleteString.append("�")
        /// Verbatim characters
        case "\"", "\\", "/":
          discard(checkpoint)
          outputBuffer.possiblyIncompleteString.unicodeScalars.append(nextScalar)
        /// Escaped characters
        case "n":
          discard(checkpoint)
          outputBuffer.possiblyIncompleteString.append("\n")
        case "t":
          discard(checkpoint)
          outputBuffer.possiblyIncompleteString.append("\t")
        case "u":
          guard let escapeSequence = readUnicodeEscapeSequence() else {
            restore(to: checkpoint)
            return
          }

          switch escapeSequence {
          case .scalar(let scalar):
            discard(checkpoint)
            outputBuffer.possiblyIncompleteString.unicodeScalars.append(scalar)
          case .invalid, .lowSurrogate:
            discard(checkpoint)
            outputBuffer.possiblyIncompleteString.append("�")
          case .highSurrogate(let highSurrogateValue):
            guard let lowSurrogateEscapeSequence = readUnicodeEscapeSequence() else {
              restore(to: checkpoint)
              return
            }

            discard(checkpoint)

            switch lowSurrogateEscapeSequence {
            case .scalar(let scalar):
              outputBuffer.possiblyIncompleteString.append("�")
              outputBuffer.possiblyIncompleteString.unicodeScalars.append(scalar)
            case .invalid, .highSurrogate:
              outputBuffer.possiblyIncompleteString.append("��")
            case .lowSurrogate(let lowSurrogateValue):
              guard
                let scalar = UnicodeScalar(
                  highSurrogateValue + lowSurrogateValue
                )
              else {
                outputBuffer.possiblyIncompleteString.append("�")
                return
              }
              outputBuffer.possiblyIncompleteString.unicodeScalars.append(scalar)

            }
          }
        default:
          /// This is an invalid escape sequence
          discard(checkpoint)
          outputBuffer.possiblyIncompleteString.append("�")
        }
      case let scalar?:
        /// This shouldn't be possible, since this character should have been consumed by `readBytes(until:)`
        assertionFailure()
        discard(checkpoint)
        outputBuffer.possiblyIncompleteString.unicodeScalars.append(scalar)
      }
    }
  }

  private enum UnicodeEscapeSequence {
    case scalar(UnicodeScalar)

    /// Details in Section 2 of https://www.ietf.org/rfc/rfc2781.txt
    case highSurrogate(Int)
    case lowSurrogate(Int)

    case invalid
  }
  private mutating func readUnicodeEscapeSequence() -> UnicodeEscapeSequence? {
    readingScalars(
      while: { scalar in
        switch scalar {
        case "0"..."9", "a"..."f", "A"..."F":
          return true
        default:
          return false
        }
      },
      maxCount: 4
    ) { scalars in
      guard scalars.count == 4 else {
        return .invalid
      }
      guard let intValue = Int(String(String.UnicodeScalarView(scalars)), radix: 16) else {
        return .invalid
      }
      switch intValue {
      case 0xDC00...0xDFFF:
        return .lowSurrogate(intValue - 0xDC00)
      case 0xD800...0xDBFF:
        return .highSurrogate(0x10000 + ((intValue - 0xD800) << 10))
      default:
        guard let scalar = UnicodeScalar(intValue) else {
          return .invalid
        }
        return .scalar(scalar)
      }
    }
  }

}

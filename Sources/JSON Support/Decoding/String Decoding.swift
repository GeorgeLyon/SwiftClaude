extension JSON {

  public struct StringBuffer {

    public init() {

    }

    public mutating func reset() {
      isComplete = false
      lastCharacterMayBeModified = true
      possiblyIncompleteString.unicodeScalars.removeAll(keepingCapacity: true)
    }

    /// The portion of the string that will not change
    public var validSubstring: Substring {
      /**
         If the string is incomplete, the last character may be changed by subsequent unicode scalars.
         For example, the incomplete string `fac` may become `facts` or `façade` depending on future unicode scalars; also, emojis can be modified by a `ZWJ`.
         This can change the meaning of the string, and make `endIndex` invalid.
         To solve this, we do not consider the last character readable until the stream is complete.
         - note: We need to handle this _both_ when parsing the incoming JSON stream _and_ when returning the string value because the issue can manifest at either level. For strings, a `c` can be followed by `\u0327`, for example.
         */
      if !isComplete, lastCharacterMayBeModified {
        return possiblyIncompleteString.dropLast()
      } else {
        return Substring(possiblyIncompleteString)
      }
    }

    public fileprivate(set) var isComplete: Bool = false
    fileprivate var possiblyIncompleteString: String = ""
    fileprivate var lastCharacterMayBeModified: Bool = true

  }

}

extension JSON.DecodingStream {

  /// Reads a string fragment into the buffer
  /// - Returns: `true` if the string is complete
  mutating func readStringFragment(
    into outputBuffer: inout JSON.StringBuffer,
    in context: inout JSON.DecodingContext
  ) throws {
    assert(!outputBuffer.isComplete)
    let fragment = context.efficientlyCollectStringFragments { fragments in
      readingStream: while true {
        /// Read scalars until we reach a control character or the end of the string
        read(
          until: { character in
            switch character {
            case "\"", "\\":
              return true
            default:
              return false
            }
          }
        ) { substring, conditionMet in
          fragments.append(substring)
          /// Always commit the read
          return true
        }

        let checkpoint = createCheckpoint()

        switch readCharacter() {
        case .none:
          /// We've reached the end of the buffer
          discard(checkpoint)
          break readingStream
        case "\"":
          /// We've reached the end of the string
          discard(checkpoint)
          outputBuffer.isComplete = true
          break readingStream
        case "\\":
          /// This is an escape sequence
          guard let escapedCharacter = readCharacter() else {
            restore(to: checkpoint)
            break readingStream
          }

          switch escapedCharacter {
          /// Unsupported characters
          case "b", "f":
            discard(checkpoint)
            fragments.append("�")
          /// Verbatim characters
          case "\"":
            discard(checkpoint)
            fragments.append("\"")
          case "\\":
            discard(checkpoint)
            fragments.append("\\")
          case "/":
            discard(checkpoint)
            fragments.append("/")
          /// Escaped characters
          case "n":
            discard(checkpoint)
            fragments.append("\n")
          case "t":
            discard(checkpoint)
            fragments.append("\t")
          case "r":
            discard(checkpoint)
            fragments.append("\r")
          case "u":
            guard let escapeSequence = readUnicodeEscapeSequence() else {
              restore(to: checkpoint)
              break readingStream
            }

            switch escapeSequence {
            case .encoded(let fragment):
              discard(checkpoint)
              fragments.append(fragment)
            case .invalid, .lowSurrogate:
              discard(checkpoint)
              fragments.append("�")
            case .highSurrogate(let highSurrogateValue):
              guard let result = read("\\u") else {
                restore(to: checkpoint)
                break readingStream
              }

              guard result else {
                discard(checkpoint)
                fragments.append("�")
                continue readingStream
              }

              guard let lowSurrogateEscapeSequence = readUnicodeEscapeSequence() else {
                restore(to: checkpoint)
                break readingStream
              }

              discard(checkpoint)

              switch lowSurrogateEscapeSequence {
              case .encoded(let fragment):
                fragments.append("�")
                fragments.append(fragment)
              case .invalid, .highSurrogate:
                fragments.append("��")
              case .lowSurrogate(let lowSurrogateValue):
                guard
                  let scalar = UnicodeScalar(
                    highSurrogateValue + lowSurrogateValue
                  )
                else {
                  /// This shouldn't be possible, because all values that are created by a valid surrogate pair should result in a valid scalar.
                  assertionFailure()
                  fragments.append("�")
                  continue readingStream
                }
                fragments.append(Substring(String(String.UnicodeScalarView([scalar]))))
              }
            }
          default:
            /// This is an invalid escape sequence
            discard(checkpoint)
            fragments.append("�")
          }
        case let character?:
          /// This shouldn't be possible, since this character should have been consumed by `readBytes(until:)`
          assertionFailure()
          discard(checkpoint)
          fragments.append(Substring(String(character)))
        }
      }
    }

    /**
     The last character can only be modified if the next grapheme cluster is `\`, which may be the start of an escape sequence representing a modifier or a `ZWJ`.
     `Stream` already handles buffering the last character in case it is modified by a subsequent non-escaped scalar in the stream.
     */
    outputBuffer.lastCharacterMayBeModified = possiblyIncompleteIncomingGraphemeCluster == "\\"

    outputBuffer.possiblyIncompleteString.append(fragment)
  }

  private enum UnicodeEscapeSequence {
    case encoded(Substring)

    /// Details in Section 2 of https://www.ietf.org/rfc/rfc2781.txt
    case highSurrogate(Int)
    case lowSurrogate(Int)

    case invalid
  }
  private mutating func readUnicodeEscapeSequence() -> UnicodeEscapeSequence? {
    read(
      until: { scalar in
        switch scalar {
        case "0"..."9", "a"..."f", "A"..."F":
          return false
        default:
          return true
        }
      },
      maxCount: 4
    ) { substring, encounteredNonHexCharacter in
      guard substring.count == 4 else {
        return encounteredNonHexCharacter ? .invalid : nil
      }
      guard let intValue = Int(substring, radix: 16) else {
        /// This shouldn't be possible because we only read hex characters
        assertionFailure()
        return .invalid
      }
      switch intValue {
      case 0xDC00...0xDFFF:
        return .lowSurrogate(intValue - 0xDC00)
      case 0xD800...0xDBFF:
        return .highSurrogate(0x10000 + ((intValue - 0xD800) << 10))
      default:
        guard let scalar = UnicodeScalar(intValue) else {
          /// This shouldn't be possible, because other than surrogate pairs all values in the range 0x0000...0xFFFF are valid.
          assertionFailure()
          return .invalid
        }
        return .encoded(Substring(String(String.UnicodeScalarView([scalar]))))
      }
    }
  }

}

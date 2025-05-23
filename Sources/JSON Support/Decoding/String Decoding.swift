extension JSON.DecodingStream {

  consuming func decodeString() -> JSON.StringDecoder {
    JSON.StringDecoder(stream: self)
  }

}

extension JSON {

  public struct StringDecoder: ~Copyable {

    public mutating func decodeFragments(
      _ processFragment: (Substring) throws -> Void
    ) throws {
      let fragments = try readFragments()
      if isComplete, trailingCharacter == nil, fragments.count == 1 {
        /// Fast path for simple strings
        try processFragment(fragments[0])
      } else {
        var fragment = Substring(
          [
            trailingCharacter.map { [Substring(String($0))] } ?? [],
            fragments,
          ]
          .joined()
          .joined()
        )

        if !isComplete, stream.possiblyIncompleteIncomingGraphemeCluster == "\\" {
          /// The last character may be modified by a unicode escape sequence
          trailingCharacter = fragment.popLast()
        } else {
          trailingCharacter = nil
        }

        try processFragment(fragment)
      }
    }

    public private(set) var isComplete = false

    public consuming func finish() throws -> JSON.DecodingStream {
      /// Read any remaining fragments
      _ = try readFragments()

      guard isComplete else {
        throw Error.incompleteString
      }

      return stream
    }

    public var stream: JSON.DecodingStream

    private var trailingCharacter: Character?
    private var readOpenQuote = false

  }

}

/// MARK: - Implementation Details

extension JSON.StringDecoder {

  fileprivate mutating func readFragments() throws -> [Substring] {
    guard !isComplete else {
      return []
    }

    if !readOpenQuote {
      stream.readWhitespace()
      guard try !stream.read("\"").isContinuable else {
        return []
      }
      readOpenQuote = true
    }

    var fragments: [Substring] = []
    readingStream: while true {
      /// Read scalars until we reach a control character or the end of the string
      _ = stream.read(
        untilCharacterIn: "\"", "\\"
      ) { substring in
        fragments.append(substring)
      }

      let checkpoint = stream.createCheckpoint()

      switch stream.readCharacter() {
      case .none:
        /// We've reached the end of the buffer
        break readingStream
      case "\"":
        /// We've reached the end of the string
        isComplete = true
        break readingStream
      case "\\":
        /// This is an escape sequence
        guard let escapedCharacter = stream.readCharacter() else {
          stream.restore(checkpoint)
          break readingStream
        }

        switch escapedCharacter {
        /// Unsupported characters
        case "b", "f":
          fragments.append("�")
        /// Verbatim characters
        case "\"":
          fragments.append("\"")
        case "\\":
          fragments.append("\\")
        case "/":
          fragments.append("/")
        /// Escaped characters
        case "n":
          fragments.append("\n")
        case "t":
          fragments.append("\t")
        case "r":
          fragments.append("\r")
        case "u":
          guard let escapeSequence = stream.readUnicodeEscapeSequence() else {
            stream.restore(checkpoint)
            break readingStream
          }

          switch escapeSequence {
          case .encoded(let fragment):
            fragments.append(fragment)
          case .invalid, .lowSurrogate:
            fragments.append("�")
          case .highSurrogate(let highSurrogateValue):
            switch stream.read("\\u") {
            case .matched:
              break
            case .continuableMatch:
              stream.restore(checkpoint)
              break readingStream
            case .notMatched:
              /// The high surrogate was not followed by a unicode escape sequence
              fragments.append("�")
              continue readingStream
            }

            guard let lowSurrogateEscapeSequence = stream.readUnicodeEscapeSequence() else {
              stream.restore(checkpoint)
              break readingStream
            }

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
          fragments.append("�")
        }
      case let character?:
        /// This shouldn't be possible, since this character should have been consumed by `readBytes(until:)`
        assertionFailure()
        fragments.append(Substring(String(character)))
      }
    }
    return fragments
  }

  fileprivate init(
    stream: consuming JSON.DecodingStream,
  ) {
    self.stream = stream
  }

}

extension JSON.DecodingStream {

  fileprivate enum UnicodeEscapeSequence {
    case encoded(Substring)

    /// Details in Section 2 of https://www.ietf.org/rfc/rfc2781.txt
    case highSurrogate(Int)
    case lowSurrogate(Int)

    case invalid
  }
  fileprivate mutating func readUnicodeEscapeSequence() -> UnicodeEscapeSequence? {
    let result = read(
      whileCharactersIn: "0"..."9", "a"..."f", "A"..."F",
      minCount: 4,
      maxCount: 4
    ) { substring -> UnicodeEscapeSequence in
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
    return switch result {
    case .continuableMatch:
      nil
    case .matched(let sequence):
      sequence
    case .notMatched:
      .invalid
    }
  }

}

extension JSON.StringDecoder {

  enum Error: Swift.Error {
    case incompleteString
  }

}

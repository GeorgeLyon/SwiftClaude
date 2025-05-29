extension JSON {

  public struct StringDecodingState: ~Copyable {
    fileprivate var isComplete = false
    fileprivate var trailingCharacter: Character?
  }

}

extension JSON.DecodingStream {

  public mutating func decodeStringStart() throws -> JSON.DecodingResult<JSON.StringDecodingState> {
    readWhitespace()

    switch read("\"") {
    case .needsMoreData:
      return .needsMoreData
    case .matched:
      return .decoded(JSON.StringDecodingState())
    case .notMatched(let error):
      throw error
    }
  }

  public mutating func decodeStringFragments(
    state: inout JSON.StringDecodingState,
    onFragment: (_ fragment: Substring) -> Void
  ) throws {
    guard !state.isComplete else {
      assertionFailure()
      return
    }

    var nextFragment: Substring?
    if let trailingCharacter = state.trailingCharacter {
      nextFragment = Substring(String(trailingCharacter))
    }
    state.isComplete = try readRawStringFragments { fragment in
      assert(!fragment.isEmpty)
      if let nextFragment {
        onFragment(nextFragment)
      }
      nextFragment = fragment
    }
    if var lastFragment = nextFragment {

      if !state.isComplete, possiblyIncompleteIncomingGraphemeCluster == "\\" {
        /// `DecodingStream` handles the possibility of a combining diacritic or a `ZWJ` being streamed as unicode, but we also need to handle modifications caused by escaped unicode sequences such as `\u0327`.
        state.trailingCharacter = lastFragment.popLast()
        assert(state.trailingCharacter != nil)
      } else {
        state.trailingCharacter = nil
      }

      onFragment(lastFragment)
    }
  }

  /// - Returns: `true` if the end of the string was read
  private mutating func readRawStringFragments(
    onFragment: (_ fragment: Substring) -> Void
  ) throws -> Bool {
    readingStream: while true {
      /// Read scalars until we reach a control character or the end of the string
      _ = read(
        untilCharacterIn: "\"", "\\",
        processPartialMatchAtEndOfBuffer: true,
        process: { substring, terminatingCharacter in
          guard !substring.isEmpty else {
            /// Empty fragments that are not lastcould mess with our last-character-may-be-modified-by-subsequent-characters mitigation efforts
            return
          }
          onFragment(substring)
        }
      )

      let readStart = createCheckpoint()

      let nextCharacter: Character
      switch readCharacter() {
      case .needsMoreData:
        /// We've reached the end of the buffer
        return false
      case .matched(let character):
        nextCharacter = character
      case .notMatched(let error):
        throw error
      }

      switch nextCharacter {
      case "\"":
        /// We've reached the end of the string
        return true
      case "\\":
        /// This is an escape sequence
        let escapedCharacter: Character
        switch readCharacter() {
        case .needsMoreData:
          restore(readStart)
          return false
        case .matched(let character):
          escapedCharacter = character
        case .notMatched(let error):
          throw error
        }

        switch escapedCharacter {
        /// Unsupported characters
        case "b", "f":
          onFragment("�")
        /// Verbatim characters
        case "\"":
          onFragment("\"")
        case "\\":
          onFragment("\\")
        case "/":
          onFragment("/")
        /// Escaped characters
        case "n":
          onFragment("\n")
        case "t":
          onFragment("\t")
        case "r":
          onFragment("\r")
        case "u":
          guard let escapeSequence = readUnicodeEscapeSequence() else {
            restore(readStart)
            return false
          }

          switch escapeSequence {
          case .encoded(let fragment):
            onFragment(fragment)
          case .invalid, .lowSurrogate:
            onFragment("�")
          case .highSurrogate(let highSurrogateValue):
            switch read("\\u") {
            case .matched:
              break
            case .needsMoreData:
              restore(readStart)
              return false
            case .notMatched:
              /// The high surrogate was not followed by a unicode escape sequence
              onFragment("�")
              continue readingStream
            }

            guard let lowSurrogateEscapeSequence = readUnicodeEscapeSequence() else {
              restore(readStart)
              return false
            }

            switch lowSurrogateEscapeSequence {
            case .encoded(let fragment):
              onFragment("�")
              onFragment(fragment)
            case .invalid, .highSurrogate:
              onFragment("��")
            case .lowSurrogate(let lowSurrogateValue):
              guard
                let scalar = UnicodeScalar(
                  highSurrogateValue + lowSurrogateValue
                )
              else {
                /// This shouldn't be possible, because all values that are created by a valid surrogate pair should result in a valid scalar.
                assertionFailure()
                onFragment("�")
                continue readingStream
              }
              onFragment(Substring(String(String.UnicodeScalarView([scalar]))))
            }
          }
        default:
          /// This is an invalid escape sequence
          onFragment("�")
        }
      case let character:
        /// This shouldn't be possible, since this character should have been consumed by `readBytes(until:)`
        assertionFailure()
        onFragment(Substring(String(character)))
      }
    }
    return false
  }

  private enum UnicodeEscapeSequence {
    case encoded(Substring)

    /// Details in Section 2 of https://www.ietf.org/rfc/rfc2781.txt
    case highSurrogate(Int)
    case lowSurrogate(Int)

    case invalid
  }
  private mutating func readUnicodeEscapeSequence() -> UnicodeEscapeSequence? {
    let result = read(
      whileCharactersIn: "0"..."9", "a"..."f", "A"..."F",
      minCount: 4,
      maxCount: 4
    ) { substring, _ -> UnicodeEscapeSequence in
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
    case .needsMoreData:
      nil
    case .matched(let sequence):
      sequence
    case .notMatched:
      .invalid
    }
  }

}

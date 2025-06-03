extension JSON {

  public struct StringDecodingState {
    
    public init() {
      
    }
    
    fileprivate enum Phase {
      case readingStart
      case readingFragments(trailingCharacter: Character?)
      case readingComplete
    }
    fileprivate var phase: Phase = .readingStart
  }
  
  public enum StringComponent {
    case end
  }

}

extension JSON.DecodingStream {

  public mutating func decodeStringFragments(
    state: inout JSON.StringDecodingState,
    onFragment: (_ fragment: Substring) -> Void
  ) throws -> JSON.DecodingResult<JSON.StringComponent> {
    try readStringFragments(state: &state, onFragment: onFragment)
      .decodingResult()
  }
  
  mutating func readStringFragments(
    state: inout JSON.StringDecodingState,
    onFragment: (_ fragment: Substring) -> Void
  ) -> ReadResult<JSON.StringComponent> {
    let trailingCharacter: Character?
    
    switch state.phase {
    case .readingStart:
      switch readStringStart() {
      case .needsMoreData:
        return .needsMoreData
      case .notMatched(let error):
        return .notMatched(error)
      case .matched(()):
        trailingCharacter = nil
      }
    case .readingFragments(let character):
      trailingCharacter = character
    case .readingComplete:
      assertionFailure()
      return .matched(.end)
    }
    
    var nextFragment: Substring?
    if let trailingCharacter {
      nextFragment = Substring(String(trailingCharacter))
    }
    let result = readRawStringFragments { fragment in
      assert(!fragment.isEmpty)
      if let nextFragment {
        onFragment(nextFragment)
      }
      nextFragment = fragment
    }
    let isComplete = if case .matched = result {
      true
    } else {
      false
    }
    if var lastFragment = nextFragment {
      if !isComplete, possiblyIncompleteIncomingGraphemeCluster == "\\" {
        /// `DecodingStream` handles the possibility of a combining diacritic or a `ZWJ` being streamed as unicode, but we also need to handle modifications caused by escaped unicode sequences such as `\u0327`.
        let trailingCharacter = lastFragment.popLast()
        
        /// Empty fragments can break the logic which ensures character boundaries don't change on append.
        assert(trailingCharacter != nil)
        
        state.phase = .readingFragments(trailingCharacter: trailingCharacter)
      } else {
        state.phase = .readingFragments(trailingCharacter: nil)
      }

      onFragment(lastFragment)
    } else {
      state.phase = .readingFragments(trailingCharacter: trailingCharacter)
    }
    if isComplete {
      state.phase = .readingComplete
    }
    return result
    
  }

  mutating func readStringStart() -> ReadResult<Void> {
    readWhitespace()

    switch read("\"") {
    case .needsMoreData:
      return .needsMoreData
    case .matched:
      return .matched(())
    case .notMatched(let error):
      return .notMatched(error)
    }
  }

  /// Unlike other `read` methods, this method advances the read cursor even if `needsMoreData` is returned.
  /// - Returns: `true` if the end of the string was read
  mutating func readRawStringFragments(
    onFragment: (_ fragment: Substring) -> Void
  ) -> ReadResult<JSON.StringComponent> {
    readingStream: while true {
      do {
        /// Read scalars until we reach a control character or the end of the string
        let result = read(
          processCharacter: { character in
            guard let first = character.unicodeScalars.first else {
              return .fail
            }
            switch first {
            case "\"", "\\":
              guard character.unicodeScalars.count == 1 else {
                return .fail
              }
              return .reject
            case "\u{0000}"..."\u{001F}":
              /// Unescaped control characters are not allowed in strings
              return .fail
            default:
              return .accept
            }
          },
          processPartialMatchAtEndOfBuffer: true,
          process: { substring, terminatingCharacter in
            guard !substring.isEmpty else {
              /// Empty fragments that are not lastcould mess with our last-character-may-be-modified-by-subsequent-characters mitigation efforts
              return
            }
            onFragment(substring)
          }
        )
        switch result {
        case .matched:
          break
        case .needsMoreData:
          /// This shouldn't be possible since the above condition can match an empty fragment
          assertionFailure()
          return .needsMoreData
        case .notMatched(let error):
          return .notMatched(error)
        }
      }

      let readStart = createCheckpoint()

      let nextCharacter: Character
      switch readCharacter() {
      case .needsMoreData:
        return .needsMoreData
      case .matched(let character):
        nextCharacter = character
      case .notMatched(let error):
        return .notMatched(error)
      }

      switch nextCharacter {
      case "\"":
        /// We've reached the end of the string
        return .matched(.end)
      case "\\":
        /// This is an escape sequence
        let escapedCharacter: Character
        switch readCharacter() {
        case .needsMoreData:
          restore(readStart)
          return .needsMoreData
        case .matched(let character):
          escapedCharacter = character
        case .notMatched(let error):
          return .notMatched(error)
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
          switch readUnicodeEscapeSequence() {
          case .needsMoreData:
            restore(readStart)
            return .needsMoreData
          case .notMatched:
            onFragment("�")
          case .matched(let escapeSequence):
            switch escapeSequence {
            case .encoded(let fragment):
              onFragment(fragment)
            case .invalid, .lowSurrogate:
              onFragment("�")
            case .highSurrogate(let highSurrogateValue):
              let highSurrogateStart = createCheckpoint()

              switch read("\\u") {
              case .matched:
                break
              case .needsMoreData:
                restore(readStart)
                return .needsMoreData
              case .notMatched:
                /// The high surrogate was not followed by a unicode escape sequence
                onFragment("�")
                continue readingStream
              }

              switch readUnicodeEscapeSequence() {
              case .needsMoreData:
                restore(readStart)
                return .needsMoreData
              case .notMatched:
                onFragment("�")
              case .matched(.encoded(let fragment)):
                onFragment("�")
                onFragment(fragment)
              case .matched(.highSurrogate):
                onFragment("�")

                /// Read a new surrogate pair starting from this high surrogate
                restore(highSurrogateStart)
              case .matched(.invalid):
                onFragment("��")
              case .matched(.lowSurrogate(let lowSurrogateValue)):
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
  }

  private enum UnicodeEscapeSequence {
    case encoded(Substring)

    /// Details in Section 2 of https://www.ietf.org/rfc/rfc2781.txt
    case highSurrogate(Int)
    case lowSurrogate(Int)

    case invalid
  }

  private mutating func readUnicodeEscapeSequence() -> ReadResult<UnicodeEscapeSequence> {
    read(
      whileCharactersIn: ["0"..."9", "a"..."f", "A"..."F"],
      minCount: 4,
      maxCount: 4,
      process: { substring, _ -> UnicodeEscapeSequence in
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
    )
  }

}

// MARK: - Implementation Details

extension Character {

  var isControl: Bool {
    guard let scalar = unicodeScalars.first, unicodeScalars.count == 1 else {
      return false
    }
    return scalar.properties.generalCategory == .control
  }

}

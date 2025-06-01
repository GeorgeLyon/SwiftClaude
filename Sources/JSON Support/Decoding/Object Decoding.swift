extension JSON {

  public struct ObjectDecodingState {
    public init() {

    }

    fileprivate enum Phase {
      case decodingObjectStart
      case decodingProperties
    }
    fileprivate var phase: Phase = .decodingObjectStart
  }

  public struct ObjectProperty {
    public let name: Substring

    fileprivate init(name: Substring) {
      self.name = name
    }
  }

}

extension JSON.DecodingStream {

  public mutating func decodeObjectProperty(
    _ state: inout JSON.ObjectDecodingState
  ) throws -> JSON.DecodingResult<JSON.ObjectProperty?> {
    switch state.phase {
    case .decodingObjectStart:
      state.phase = .decodingProperties
      return try decodeObjectUpToFirstPropertyValue()

    case .decodingProperties:
      return try decodeObjectUpToNextPropertyValue()
    }
  }

  mutating func decodeObjectUpToFirstPropertyValue() throws
    -> JSON.DecodingResult<JSON.ObjectProperty?>
  {
    readWhitespace()

    let start = createCheckpoint()

    switch try read("{").decodingResult() {
    case .needsMoreData:
      return .needsMoreData
    case .decoded:
      readWhitespace()

      let isEmpty = readCharacter { character in
        switch character {
        case "}":
          return ()
        default:
          return nil
        }
      }

      switch isEmpty {
      case .matched:
        return .decoded(nil)
      case .notMatched:
        switch readNextPropertyName() {
        case .matched(let name):
          return .decoded(JSON.ObjectProperty(name: name))
        case .notMatched(let error):
          throw error
        case .needsMoreData:
          restore(start)
          return .needsMoreData
        }
      case .needsMoreData:
        restore(start)
        return .needsMoreData
      }
    }
  }

  mutating func decodeObjectUpToNextPropertyValue() throws
    -> JSON.DecodingResult<JSON.ObjectProperty?>
  {
    readWhitespace()

    let start = createCheckpoint()

    let isComplete = try readCharacter { character in
      switch character {
      case "}":
        return true
      case ",":
        return false
      default:
        return nil
      }
    }.decodingResult()

    switch isComplete {
    case .needsMoreData:
      restore(start)
      return .needsMoreData
    case .decoded(let isComplete):
      if isComplete {
        return .decoded(nil)
      } else {
        switch readNextPropertyName() {
        case .matched(let name):
          return .decoded(JSON.ObjectProperty(name: name))
        case .notMatched(let error):
          throw error
        case .needsMoreData:
          restore(start)
          return .needsMoreData
        }
      }
    }
  }

  /// Does not restore the read cursor when it `needsMoreData`.
  /// Also reads the ":" character.
  /// - Returns: The property name
  private mutating func readNextPropertyName() -> ReadResult<Substring> {
    readWhitespace()

    let propertyFragments: [Substring]
    do {
      var state: JSON.StringDecodingState
      switch readStringStart() {
      case .matched(let s):
        state = s
      case .needsMoreData:
        return .needsMoreData
      case .notMatched(let error):
        return .notMatched(error)
      }

      var fragments: [Substring] = []
      let result = readStringFragments(state: &state) { fragment in
        fragments.append(fragment)
      }
      switch result {
      case .needsMoreData:
        return .needsMoreData
      case .notMatched(let error):
        return .notMatched(error)
      case .matched:
        guard state.isComplete else {
          /// `state` should be complete if we matched
          assertionFailure()
          return .notMatched(Error.invalidState)
        }
        propertyFragments = fragments
      }
    }

    readWhitespace()

    switch read(":") {
    case .needsMoreData:
      return .needsMoreData
    case .matched:
      if propertyFragments.count == 1 {
        /// Fast path for a single fragment
        return .matched(propertyFragments[0])
      } else {
        /// Join all fragments
        return .matched(Substring(propertyFragments.joined()))
      }
    case .notMatched(let error):
      return .notMatched(error)
    }
  }

}

private enum Error: Swift.Error {
  case invalidState
}

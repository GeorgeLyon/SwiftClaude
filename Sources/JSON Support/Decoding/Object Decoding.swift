extension JSON {

  public enum ObjectDecodingState {
    case needsMoreData

    /// The read cursor has been advanced to the start of the property value
    case decodingPropertyValue(name: Substring)

    /// The object is complete
    case complete
  }

}

extension JSON.DecodingStream {

  public mutating func decodeObjectStart() throws -> JSON.ObjectDecodingState {
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
        return .complete
      case .notMatched:
        switch readNextPropertyName() {
        case .matched(let name):
          return .decodingPropertyValue(name: name)
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

  public mutating func decodeNextObjectProperty() throws -> JSON.ObjectDecodingState {
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
        return .complete
      } else {
        switch readNextPropertyName() {
        case .matched(let name):
          return .decodingPropertyValue(name: name)
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

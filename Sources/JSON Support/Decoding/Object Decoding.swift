extension JSON {

  public struct ObjectDecodingState {
    public init() {

    }

    /// This method can be used so that the next call to `decodeObjectPropertyHeader` will decode up to the **next** header without explicitly decoding the property value.
    public mutating func ignorePropertyValue() {
      assert(ignoredPropertyState == nil)
      assert(phase == .readingProperties)
      ignoredPropertyState = JSON.ValueDecodingState()
    }

    fileprivate enum Phase {
      case readingObjectStart
      case readingProperties
      case readingComplete
    }
    fileprivate var phase: Phase = .readingObjectStart

    fileprivate var ignoredPropertyState: JSON.ValueDecodingState?
  }

  public struct ObjectPropertyHeader {
    public let name: Substring

    fileprivate init(name: Substring) {
      self.name = name
    }
  }

}

extension JSON.DecodingStream {

  public mutating func decodeObjectPropertyHeader(
    _ state: inout JSON.ObjectDecodingState
  ) throws -> JSON.DecodingResult<JSON.ObjectPropertyHeader?> {
    try readObjectPropertyHeader(&state).decodingResult()
  }

  public mutating func decodeObjectUntilComplete(
    _ state: inout JSON.ObjectDecodingState
  ) throws -> JSON.DecodingResult<Void> {
    while true {
      switch readObjectPropertyHeader(&state) {
      case .needsMoreData:
        return .needsMoreData
      case .notMatched(let error):
        throw error
      case .matched(.some):
        state.ignorePropertyValue()
      case .matched(.none):
        return .decoded(())
      }
    }
  }

  mutating func readObjectPropertyHeader(
    _ state: inout JSON.ObjectDecodingState
  ) -> ReadResult<JSON.ObjectPropertyHeader?> {
    switch state.phase {
    case .readingObjectStart:
      let result = readObjectUpToFirstPropertyValue()
      if case .matched = result {
        state.phase = .readingProperties
      }
      return result

    case .readingProperties:

      if var propertyState = state.ignoredPropertyState {
        /// We are ignoring this property, so just read it as an arbitrary value
        switch readValue(&propertyState) {
        case .needsMoreData:
          return .needsMoreData
        case .matched:
          state.ignoredPropertyState = nil
        case .notMatched(let error):
          state.ignoredPropertyState = propertyState
          return .notMatched(error)
        }
      }

      return readObjectUpToNextPropertyValue()

    case .readingComplete:
      assertionFailure()
      return .matched(nil)
    }
  }

  mutating func readObjectUpToFirstPropertyValue()
    -> ReadResult<JSON.ObjectPropertyHeader?>
  {
    readWhitespace()

    let start = createCheckpoint()

    switch read("{") {
    case .needsMoreData:
      return .needsMoreData
    case .notMatched(let error):
      return .notMatched(error)
    case .matched:
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
        return .matched(nil)
      case .notMatched:
        switch readNextPropertyName() {
        case .matched(let name):
          return .matched(JSON.ObjectPropertyHeader(name: name))
        case .notMatched(let error):
          return .notMatched(error)
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

  mutating func readObjectUpToNextPropertyValue()
    -> ReadResult<JSON.ObjectPropertyHeader?>
  {
    readWhitespace()

    let start = createCheckpoint()

    let isComplete = readCharacter { character in
      switch character {
      case "}":
        return true
      case ",":
        return false
      default:
        return nil
      }
    }

    switch isComplete {
    case .needsMoreData:
      restore(start)
      return .needsMoreData
    case .notMatched(let error):
      return .notMatched(error)
    case .matched(let isComplete):
      if isComplete {
        return .matched(nil)
      } else {
        switch readNextPropertyName() {
        case .matched(let name):
          return .matched(JSON.ObjectPropertyHeader(name: name))
        case .notMatched(let error):
          return .notMatched(error)
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

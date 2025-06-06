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

  public enum ObjectComponent {
    case propertyValueStart(name: Substring)
    case end
  }

}

extension JSON.DecodingStream {

  public mutating func decodeObjectComponent(
    _ state: inout JSON.ObjectDecodingState
  ) throws -> JSON.DecodingResult<JSON.ObjectComponent> {
    try readObjectComponent(&state).decodingResult()
  }

  public mutating func decodeObjectUntilComplete(
    _ state: inout JSON.ObjectDecodingState
  ) throws -> JSON.DecodingResult<Void> {
    while true {
      switch readObjectComponent(&state) {
      case .needsMoreData:
        return .needsMoreData
      case .notMatched(let error):
        throw error
      case .matched(.propertyValueStart):
        state.ignorePropertyValue()
      case .matched(.end):
        return .decoded(())
      }
    }
  }

  public mutating func peekObjectProperty<T>(
    _ name: String,
    peek: (inout JSON.DecodingStream) throws -> JSON.DecodingResult<T>
  ) throws -> JSON.DecodingResult<T?> {
    let checkpoint = createCheckpoint()

    /// Because we restore the state on all non-error code paths, it is safe to discard
    var state = JSON.ObjectDecodingState()

    while true {
      switch readObjectComponent(&state) {
      case .needsMoreData:
        restore(checkpoint)
        return .needsMoreData
      case .notMatched(let error):
        throw error
      case .matched(.propertyValueStart(let propertyName)):
        if propertyName == name {
          let result = try peek(&self)
          restore(checkpoint)
          switch result {
          case .needsMoreData:
            return .needsMoreData
          case .decoded(let result):
            return .decoded(result)
          }
        }
        state.ignorePropertyValue()
      case .matched(.end):
        restore(checkpoint)
        return .decoded(nil)
      }
    }
  }

  mutating func readObjectComponent(
    _ state: inout JSON.ObjectDecodingState
  ) -> ReadResult<JSON.ObjectComponent> {
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
      return .matched(.end)
    }
  }

  mutating func readObjectUpToFirstPropertyValue()
    -> ReadResult<JSON.ObjectComponent>
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
        return .matched(.end)
      case .notMatched:
        switch readNextPropertyName() {
        case .matched(let name):
          return .matched(.propertyValueStart(name: name))
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
    -> ReadResult<JSON.ObjectComponent>
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
        return .matched(.end)
      } else {
        switch readNextPropertyName() {
        case .matched(let name):
          return .matched(.propertyValueStart(name: name))
        case .notMatched(let error):
          return .notMatched(error)
        case .needsMoreData:
          restore(start)
          return .needsMoreData
        }
      }
    }
  }

  /// This relies on the method calling it to restore the state of the stream on failure.
  /// Also reads the ":" character.
  /// - Returns: The property name
  private mutating func readNextPropertyName() -> ReadResult<Substring> {
    readWhitespace()

    let name: Substring
    switch readString() {
    case .matched(let string):
      name = string
    case .notMatched(let error):
      return .notMatched(error)
    case .needsMoreData:
      return .needsMoreData
    }

    readWhitespace()

    switch read(":") {
    case .needsMoreData:
      return .needsMoreData
    case .matched:
      return .matched(name)
    case .notMatched(let error):
      return .notMatched(error)
    }
  }

}

private enum Error: Swift.Error {
  case invalidState
}

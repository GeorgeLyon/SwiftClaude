extension JSON {

  public struct ArrayDecodingState: Sendable {
    public init() {

    }

    fileprivate enum Phase {
      case readingArrayStart
      case readingElements
      case readingComplete
    }
    fileprivate var phase: Phase = .readingArrayStart
  }

  public enum ArrayComponent {
    case elementStart
    case end
  }

}

extension JSON.DecodingStream {

  public mutating func decodeArrayComponent(
    state: inout JSON.ArrayDecodingState
  ) throws -> JSON.DecodingResult<JSON.ArrayComponent> {
    try readArrayComponent(&state).decodingResult()
  }

  mutating func readArrayComponent(
    _ state: inout JSON.ArrayDecodingState
  ) throws -> ReadResult<JSON.ArrayComponent> {
    switch state.phase {
    case .readingArrayStart:
      let result = readArrayUpToFirstElement()
      if case .matched = result {
        state.phase = .readingElements
      }
      return result

    case .readingElements:
      return readArrayUpToNextElement()

    case .readingComplete:
      assertionFailure()
      return .matched(.end)
    }
  }

  mutating func readArrayUpToFirstElement()
    -> ReadResult<JSON.ArrayComponent>
  {
    readWhitespace()

    let start = createCheckpoint()

    switch read("[") {
    case .incomplete:
      return .incomplete
    case .notMatched(let error):
      return .notMatched(error)
    case .matched:
      readWhitespace()
      let isEmpty = readCharacter { character in
        switch character {
        case "]":
          return ()
        default:
          return nil
        }
      }
      switch isEmpty {
      case .matched:
        return .matched(.end)
      case .notMatched:
        return .matched(.elementStart)
      case .incomplete:
        /// Restore to start so we don't need to keep track of the fact that we've read "["
        restore(start)
        return .incomplete
      }
    }
  }

  mutating func readArrayUpToNextElement()
    -> ReadResult<JSON.ArrayComponent>
  {
    readWhitespace()

    let isComplete = readCharacter { character in
      switch character {
      case "]":
        return true
      case ",":
        return false
      default:
        return nil
      }
    }

    switch isComplete {
    case .incomplete:
      return .incomplete
    case .matched(let isComplete):
      return .matched(isComplete ? .end : .elementStart)
    case .notMatched(let error):
      return .notMatched(error)
    }
  }

}

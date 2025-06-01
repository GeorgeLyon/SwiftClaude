extension JSON {

  public struct ArrayDecodingState {
    public init() {

    }

    fileprivate enum Phase {
      case decodingArrayStart
      case decodingElements
    }
    fileprivate var phase: Phase = .decodingArrayStart
  }

}

extension JSON.DecodingStream {

  public mutating func decodeArrayElement(
    _ state: inout JSON.ArrayDecodingState
  ) throws -> JSON.DecodingResult<Bool> {
    switch state.phase {
    case .decodingArrayStart:
      state.phase = .decodingElements
      return try decodeArrayUpToFirstElement()

    case .decodingElements:
      return try decodeArrayUpToNextElement()
    }
  }

  mutating func decodeArrayUpToFirstElement() throws
    -> JSON.DecodingResult<Bool>
  {
    readWhitespace()

    let start = createCheckpoint()

    switch try read("[").decodingResult() {
    case .needsMoreData:
      return .needsMoreData
    case .decoded:
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
        return .decoded(false)
      case .notMatched:
        return .decoded(true)
      case .needsMoreData:
        /// Restore to start so we don't need to keep track of the fact that we've read "["
        restore(start)
        return .needsMoreData
      }
    }
  }

  mutating func decodeArrayUpToNextElement() throws
    -> JSON.DecodingResult<Bool>
  {
    readWhitespace()

    let isComplete = try readCharacter { character in
      switch character {
      case "]":
        return true
      case ",":
        return false
      default:
        return nil
      }
    }.decodingResult()

    switch isComplete {
    case .needsMoreData:
      return .needsMoreData
    case .decoded(let isComplete):
      return .decoded(!isComplete)
    }
  }

}

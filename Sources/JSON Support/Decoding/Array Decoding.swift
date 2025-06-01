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

  public enum ArrayElementHeader {
    case elementHeader
  }

}

extension JSON.DecodingStream {

  public mutating func decodeArrayElementHeader(
    _ state: inout JSON.ArrayDecodingState
  ) throws -> JSON.DecodingResult<JSON.ArrayElementHeader?> {
    switch state.phase {
    case .decodingArrayStart:
      let result = try decodeArrayUpToFirstElement()
      if case .decoded = result {
        state.phase = .decodingElements
      }
      return result

    case .decodingElements:
      return try decodeArrayUpToNextElement()
    }
  }

  mutating func decodeArrayUpToFirstElement() throws
    -> JSON.DecodingResult<JSON.ArrayElementHeader?>
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
        return .decoded(.none)
      case .notMatched:
        return .decoded(.elementHeader)
      case .needsMoreData:
        /// Restore to start so we don't need to keep track of the fact that we've read "["
        restore(start)
        return .needsMoreData
      }
    }
  }

  mutating func decodeArrayUpToNextElement() throws
    -> JSON.DecodingResult<JSON.ArrayElementHeader?>
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
      return .decoded(isComplete ? .none : .elementHeader)
    }
  }

}

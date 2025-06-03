extension JSON {

  public struct ArrayDecodingState {
    public init() {

    }

    fileprivate enum Phase {
      case readingArrayStart
      case readingElements
      case readingComplete
    }
    fileprivate var phase: Phase = .readingArrayStart
  }

  public enum ArrayElementHeader {
    case elementHeader
  }

}

extension JSON.DecodingStream {

  public mutating func decodeArrayElementHeader(
    _ state: inout JSON.ArrayDecodingState
  ) throws -> JSON.DecodingResult<JSON.ArrayElementHeader?> {
    try readArrayElementHeader(&state).decodingResult()
  }

  mutating func readArrayElementHeader(
    _ state: inout JSON.ArrayDecodingState
  ) throws -> ReadResult<JSON.ArrayElementHeader?> {
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
      return .matched(nil)
    }
  }

  mutating func readArrayUpToFirstElement()
    -> ReadResult<JSON.ArrayElementHeader?>
  {
    readWhitespace()

    let start = createCheckpoint()

    switch read("[") {
    case .needsMoreData:
      return .needsMoreData
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
        return .matched(.none)
      case .notMatched:
        return .matched(.elementHeader)
      case .needsMoreData:
        /// Restore to start so we don't need to keep track of the fact that we've read "["
        restore(start)
        return .needsMoreData
      }
    }
  }

  mutating func readArrayUpToNextElement()
    -> ReadResult<JSON.ArrayElementHeader?>
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
    case .needsMoreData:
      return .needsMoreData
    case .matched(let isComplete):
      return .matched(isComplete ? .none : .elementHeader)
    case .notMatched(let error):
      return .notMatched(error)
    }
  }

}

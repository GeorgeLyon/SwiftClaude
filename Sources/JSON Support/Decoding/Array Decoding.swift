extension JSON {

  public enum ArrayDecodingResult {
    case needsMoreData

    /// The read cursor has been advanced to the start of the next element in the array
    case decodingElement

    /// The array is complete
    case complete
  }

}

extension JSON.DecodingStream {

  public mutating func decodeArrayStart() throws -> JSON.ArrayDecodingResult {
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
        return .complete
      case .notMatched:
        return .decodingElement
      case .needsMoreData:
        /// Restore to start so we don't need to keep track of the fact that we've read "["
        restore(start)
        return .needsMoreData
      }
    }
  }

  public mutating func decodeNextArrayElement() throws -> JSON.ArrayDecodingResult {
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
      return isComplete ? .complete : .decodingElement
    }
  }

}

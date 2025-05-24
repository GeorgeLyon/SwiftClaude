extension JSON.Value {

  consuming func decodeArray() -> JSON.ArrayDecoder {
    JSON.ArrayDecoder(stream: stream)
  }

}

extension JSON {

  public struct ArrayDecoder: ~Copyable {

    public mutating func decodeNextElement<T>(
      _ decode: (inout JSON.DecodingStream) throws -> T?
    ) throws -> T? {
      guard !isComplete else {
        return nil
      }

      if !readOpenBracket {
        stream.readWhitespace()
        guard try !stream.read("[").isContinuable else {
          return nil
        }
        readOpenBracket = true
      }

      stream.readWhitespace()

      /// Check for empty array or end of array
      if !hasReadFirstElement {
        switch stream.read("]") {
        case .matched:
          isComplete = true
          return nil
        case .continuableMatch:
          return nil
        case .notMatched:
          break
        }
        hasReadFirstElement = true
      } else {
        /// Read comma separator between elements
        switch stream.read(",") {
        case .matched:
          break
        case .continuableMatch:
          return nil
        case .notMatched:
          /// Check if we've reached the end of the array
          switch stream.read("]") {
          case .matched:
            isComplete = true
            return nil
          case .continuableMatch:
            return nil
          case .notMatched(let error):
            throw error
          }
        }
      }

      stream.readWhitespace()

      /// Decode the element
      guard let element = try decode(&stream) else {
        return nil
      }

      stream.readWhitespace()

      /// Peek ahead to see if the array is complete
      let checkpoint = stream.createCheckpoint()
      switch stream.read("]") {
      case .matched:
        isComplete = true
      case .continuableMatch, .notMatched:
        stream.restore(checkpoint)
      }

      return element
    }

    public private(set) var isComplete = false

    public consuming func finish() throws -> JSON.DecodingStream {
      /// Read any remaining elements
      while !isComplete {
        guard try decodeNextElement({ _ in () }) != nil else {
          break
        }
      }

      guard isComplete else {
        throw Error.incompleteArray
      }

      return stream
    }

    public var stream: JSON.DecodingStream

    private var readOpenBracket = false
    private var hasReadFirstElement = false

  }

}

/// MARK: - Implementation Details

extension JSON.ArrayDecoder {

  fileprivate init(
    stream: consuming JSON.DecodingStream
  ) {
    self.stream = stream
  }

}

extension JSON.ArrayDecoder {

  enum Error: Swift.Error {
    case incompleteArray
  }

}

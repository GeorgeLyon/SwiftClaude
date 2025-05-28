extension JSON {

  public struct ArrayDecoder: ~Copyable {

  }

}

// MARK: - Implementation Details

private enum ArrayDecoderState: ~Copyable {

  case readingOpenBracket(JSON.DecodingStream)
  case decodingElement(JSON.ValueDecoder)
  case decodingElementOrCloseBracket(JSON.DecodingStream)
  case complete(JSON.DecodingStream)

  struct Failed: ~Copyable {
    let error: Swift.Error
    var stream: JSON.DecodingStream
  }
  case failed(Failed)
  case partiallyConsumed

  var stream: JSON.DecodingStream {
    _read {
      switch self {
      case .readingOpenBracket(let stream):
        yield stream
      case .decodingElement(let decoder):
        yield decoder.stream
      case .decodingElementOrCloseBracket(let stream):
        yield stream
      case .complete(let stream):
        yield stream
      case .failed(let failed):
        yield failed.stream
      case .partiallyConsumed:
        assertionFailure()
        yield JSON.DecodingStream()
      }
    }
    _modify {
      let value = consume self
      self = .partiallyConsumed
      switch value {
      case .readingOpenBracket(var stream):
        yield &stream
        self = .readingOpenBracket(stream)
      case .decodingElement(var decoder):
        yield &decoder.stream
        self = .decodingElement(decoder)
      case .decodingElementOrCloseBracket(var stream):
        yield &stream
        self = .decodingElementOrCloseBracket(stream)
      case .complete(var stream):
        yield &stream
        self = .complete(stream)
      case .failed(var failed):
        yield &failed.stream
        self = .failed(failed)
      case .partiallyConsumed:
        assertionFailure()
        var stream = JSON.DecodingStream()
        yield &stream
      }
    }
  }

  var currentElementDecoder: JSON.ValueDecoder? {
    mutating _read {
      let value = consume self
      self = .partiallyConsumed
      switch consume value {
      case .decodingElement(let decoder):
        /// We have to do a little dance to yield this as an optional
        let optionalDecoder: JSON.ValueDecoder? = decoder
        yield optionalDecoder
        guard let decoder = optionalDecoder else {
          assertionFailure()
          self = .failed(
            .init(
              error: Error.valueDecoderOptionalityChanged,
              stream: JSON.DecodingStream())
          )
          return
        }
        self = .decodingElement(decoder)
      case .readingOpenBracket(let stream):
        yield nil
        self = .readingOpenBracket(stream)
      case .decodingElementOrCloseBracket(let stream):
        yield nil
        self = .decodingElementOrCloseBracket(stream)
      case .complete(let stream):
        yield nil
        self = .complete(stream)

      case .failed(let failed):
        yield nil
        self = .failed(failed)
      case .partiallyConsumed:
        assertionFailure()
        yield nil
        self = .partiallyConsumed
      }
    }
    _modify {
      let value = consume self
      self = .partiallyConsumed
      switch consume value {
      case .decodingElement(let decoder):
        var optionalDecoder: JSON.ValueDecoder? = decoder
        yield &optionalDecoder
        guard let decoder = optionalDecoder else {
          assertionFailure()
          self = .failed(
            .init(error: Error.valueDecoderOptionalityChanged, stream: JSON.DecodingStream()))
          return
        }
        self = .decodingElement(decoder)
      case .readingOpenBracket(let stream):
        var optionalDecoder: JSON.ValueDecoder? = nil
        yield &optionalDecoder
        guard optionalDecoder == nil else {
          self = .failed(
            .init(
              error: Error.valueDecoderOptionalityChanged,
              stream: stream
            )
          )
          return
        }
        self = .readingOpenBracket(stream)
      case .decodingElementOrCloseBracket(let stream):
        var optionalDecoder: JSON.ValueDecoder? = nil
        yield &optionalDecoder
        guard optionalDecoder == nil else {
          self = .failed(
            .init(
              error: Error.valueDecoderOptionalityChanged,
              stream: stream
            )
          )
          return
        }
        self = .decodingElementOrCloseBracket(stream)
      case .complete(let stream):
        var optionalDecoder: JSON.ValueDecoder? = nil
        yield &optionalDecoder
        guard optionalDecoder == nil else {
          self = .failed(
            .init(
              error: Error.valueDecoderOptionalityChanged,
              stream: stream
            )
          )
          return
        }
        self = .complete(stream)
      case .failed(let failed):
        var optionalDecoder: JSON.ValueDecoder? = nil
        yield &optionalDecoder
        guard optionalDecoder == nil else {
          self = .failed(
            .init(
              error: Error.valueDecoderOptionalityChanged,
              stream: failed.stream
            )
          )
          return
        }
        self = .failed(failed)
      case .partiallyConsumed:
        assertionFailure()
        var optionalDecoder: JSON.ValueDecoder? = nil
        yield &optionalDecoder
        guard optionalDecoder == nil else {
          self = .failed(
            .init(
              error: Error.valueDecoderOptionalityChanged,
              stream: JSON.DecodingStream()
            )
          )
          return
        }
        self = .partiallyConsumed
      }
    }
  }

  /// If the array has not started decoding, makes `currentElementDecoder` refer to the first element.
  /// If the array is already decoding, makes `currentElementDecoder` refer to the next element if one exists.
  /// - Returns:
  ///     `.decoded(true)` if there is a next element to decode
  ///     `.decoded(false)` if the array is complete
  ///     `.needsMoreData` if we are not ready to decode the next element yet
  @discardableResult
  mutating func decodeNextElement() throws -> JSON.DecodingResult<Bool> {
    while true {
      switch consume self {
      case .readingOpenBracket(var stream):
        stream.readWhitespace()
        switch stream.read("[") {
        case .matched:
          self = .decodingElementOrCloseBracket(stream)
          continue
        case .notMatched(let error):
          self = .failed(.init(error: error, stream: stream))
          throw error
        case .needsMoreData:
          self = .readingOpenBracket(stream)
          return .needsMoreData
        }
      case .decodingElement(let decoder):
        switch decoder.finish() {
        case .needsMoreData(let decoder):
          self = .decodingElement(decoder)
          return .needsMoreData
        case .decodingComplete(let stream):
          self = .decodingElementOrCloseBracket(stream)
          continue
        case .decodingFailed(let error, let stream):
          self = .failed(.init(error: error, stream: stream))
          throw error
        }
      case .decodingElementOrCloseBracket(var stream):
        stream.readWhitespace()
        let isComplete = stream.readCharacter { character in

        }

      case .complete(let stream):
        self = .complete(stream)
        return .decoded(false)
      case .failed(let failure):
        let error = failure.error
        self = .failed(failure)
        throw error
      case .partiallyConsumed:
        assertionFailure()
        self = .partiallyConsumed
        throw Error.invalidState
      }
    }
  }

}

private enum Error: Swift.Error {
  case invalidState
  case valueDecoderOptionalityChanged
}

extension JSON {

  public struct ValueDecoder: ~Copyable {

    public init() {
      state = .unknown(JSON.DecodingStream())
    }

    public init(stream: consuming JSON.DecodingStream) {
      state = .unknown(stream)
    }

    public init(error: Swift.Error, stream: consuming JSON.DecodingStream) {
      state = .failure(.init(error: error, remainder: stream))
    }

    public var stream: JSON.DecodingStream {
      _read {
        yield state.stream
      }
      _modify {
        yield &state.stream
      }
    }

    public var stringDecoder: StringDecoder {
      consuming _read {
        yield state.stringDecoder
      }
      _modify {
        yield &state.stringDecoder
      }
    }

    public var numberDecoder: NumberDecoder {
      consuming _read {
        yield state.numberDecoder
      }
      _modify {
        yield &state.numberDecoder
      }
    }

    public var nullDecoder: NullDecoder {
      consuming _read {
        yield state.nullDecoder
      }
      _modify {
        yield &state.nullDecoder
      }
    }

    public var booleanDecoder: BooleanDecoder {
      consuming _read {
        yield state.booleanDecoder
      }
      _modify {
        yield &state.booleanDecoder
      }
    }

    consuming func finish() -> FinishDecodingResult<Self> {
      state.finish().map(ValueDecoder.init)
    }

    private init(state: consuming ValueDecoderState) {
      self.state = state
    }

    private var state: ValueDecoderState

    private enum Error: Swift.Error {
      case unexpectedType
      case partiallyConsumed
    }

  }

}

// MARK: - Implementation Details

private enum ValueDecoderState: ~Copyable {

  case unknown(JSON.DecodingStream)
  case string(JSON.StringDecoder)
  case number(JSON.NumberDecoder)
  case null(JSON.NullDecoder)
  case boolean(JSON.BooleanDecoder)

  /// Making this a separate struct to avoid a compiler bug where `stream` is copied even though its non-copyable.
  /// This seems to be related to a non-copyable type being used as one of several associated values in an enum case.
  struct Failure: ~Copyable {
    let error: Swift.Error
    var remainder: JSON.DecodingStream
  }
  case failure(Failure)

  /// `Value` cannot be partially consumed when yielding a stream in the `_modify` accessor, so we need an explicit state to represent this.
  case partiallyConsumed

  var stream: JSON.DecodingStream {
    _read {
      switch self {
      case .unknown(let stream):
        yield stream

      case .null(let decoder):
        yield decoder.stream
      case .boolean(let decoder):
        yield decoder.stream
      case .number(let decoder):
        yield decoder.stream
      case .string(let decoder):
        yield decoder.stream

      case .partiallyConsumed:
        assertionFailure()
        yield JSON.DecodingStream()
      case .failure(let failure):
        yield failure.remainder
      }
    }
    _modify {
      let value = consume self
      self = .partiallyConsumed
      switch value {
      case .unknown(var stream):
        yield &stream
        self = .unknown(stream)

      case .null(var decoder):
        yield &decoder.stream
        self = .null(decoder)
      case .boolean(var decoder):
        yield &decoder.stream
        self = .boolean(decoder)
      case .number(var decoder):
        yield &decoder.stream
        self = .number(decoder)
      case .string(var decoder):
        yield &decoder.stream
        self = .string(decoder)

      case .partiallyConsumed:
        assertionFailure()
        var stream = JSON.DecodingStream()
        yield &stream
      case .failure(var failure):
        assertionFailure()
        yield &failure.remainder
        self = .failure(failure)
      }
    }
  }

  var stringDecoder: JSON.StringDecoder {
    consuming _read {
      let decoder: JSON.StringDecoder
      switch consume self {
      case .partiallyConsumed:
        assertionFailure()
        decoder = JSON.StringDecoder(error: Error.partiallyConsumed, stream: JSON.DecodingStream())
      case .failure(let failure):
        decoder = JSON.StringDecoder(error: failure.error, stream: failure.remainder)
      case .unknown(let stream):
        decoder = JSON.StringDecoder(stream: stream)
      case .string(let existingDecoder):
        decoder = existingDecoder
      case .number(let existingDecoder):
        decoder = JSON.StringDecoder(error: Error.unexpectedType, stream: existingDecoder.destroy())
      case .null(let existingDecoder):
        decoder = JSON.StringDecoder(error: Error.unexpectedType, stream: existingDecoder.destroy())
      case .boolean(let existingDecoder):
        decoder = JSON.StringDecoder(error: Error.unexpectedType, stream: existingDecoder.destroy())
      }
      yield decoder
    }
    _modify {
      var decoder: JSON.StringDecoder
      switch consume self {
      case .partiallyConsumed:
        assertionFailure()
        decoder = JSON.StringDecoder(error: Error.partiallyConsumed, stream: JSON.DecodingStream())
      case .failure(let failure):
        decoder = JSON.StringDecoder(error: failure.error, stream: failure.remainder)
      case .unknown(let stream):
        decoder = JSON.StringDecoder(stream: stream)
      case .string(let existingDecoder):
        decoder = existingDecoder
      case .number(let existingDecoder):
        decoder = JSON.StringDecoder(error: Error.unexpectedType, stream: existingDecoder.destroy())
      case .null(let existingDecoder):
        decoder = JSON.StringDecoder(error: Error.unexpectedType, stream: existingDecoder.destroy())
      case .boolean(let existingDecoder):
        decoder = JSON.StringDecoder(error: Error.unexpectedType, stream: existingDecoder.destroy())
      }
      self = .partiallyConsumed
      yield &decoder
      self = .string(decoder)
    }
  }

  var numberDecoder: JSON.NumberDecoder {
    consuming _read {
      let decoder: JSON.NumberDecoder
      switch consume self {
      case .partiallyConsumed:
        assertionFailure()
        decoder = JSON.NumberDecoder(error: Error.partiallyConsumed, stream: JSON.DecodingStream())
      case .failure(let failure):
        decoder = JSON.NumberDecoder(error: failure.error, stream: failure.remainder)
      case .unknown(let stream):
        decoder = JSON.NumberDecoder(stream: stream)
      case .number(let existingDecoder):
        decoder = existingDecoder
      case .string(let existingDecoder):
        decoder = JSON.NumberDecoder(error: Error.unexpectedType, stream: existingDecoder.destroy())
      case .null(let existingDecoder):
        decoder = JSON.NumberDecoder(error: Error.unexpectedType, stream: existingDecoder.destroy())
      case .boolean(let existingDecoder):
        decoder = JSON.NumberDecoder(error: Error.unexpectedType, stream: existingDecoder.destroy())
      }
      yield decoder
    }
    _modify {
      var decoder: JSON.NumberDecoder
      switch consume self {
      case .partiallyConsumed:
        assertionFailure()
        decoder = JSON.NumberDecoder(error: Error.partiallyConsumed, stream: JSON.DecodingStream())
      case .failure(let failure):
        decoder = JSON.NumberDecoder(error: failure.error, stream: failure.remainder)
      case .unknown(let stream):
        decoder = JSON.NumberDecoder(stream: stream)
      case .number(let existingDecoder):
        decoder = existingDecoder
      case .string(let existingDecoder):
        decoder = JSON.NumberDecoder(error: Error.unexpectedType, stream: existingDecoder.destroy())
      case .null(let existingDecoder):
        decoder = JSON.NumberDecoder(error: Error.unexpectedType, stream: existingDecoder.destroy())
      case .boolean(let existingDecoder):
        decoder = JSON.NumberDecoder(error: Error.unexpectedType, stream: existingDecoder.destroy())
      }
      self = .partiallyConsumed
      yield &decoder
      self = .number(decoder)
    }
  }

  var booleanDecoder: JSON.BooleanDecoder {
    consuming _read {
      let decoder: JSON.BooleanDecoder
      switch consume self {
      case .partiallyConsumed:
        assertionFailure()
        decoder = JSON.BooleanDecoder(error: Error.partiallyConsumed, stream: JSON.DecodingStream())
      case .failure(let failure):
        decoder = JSON.BooleanDecoder(error: failure.error, stream: failure.remainder)
      case .unknown(let stream):
        decoder = JSON.BooleanDecoder(stream: stream)
      case .boolean(let existingDecoder):
        decoder = existingDecoder
      case .string(let existingDecoder):
        decoder = JSON.BooleanDecoder(
          error: Error.unexpectedType, stream: existingDecoder.destroy())
      case .number(let existingDecoder):
        decoder = JSON.BooleanDecoder(
          error: Error.unexpectedType, stream: existingDecoder.destroy())
      case .null(let existingDecoder):
        decoder = JSON.BooleanDecoder(
          error: Error.unexpectedType, stream: existingDecoder.destroy())
      }
      yield decoder
    }
    _modify {
      var decoder: JSON.BooleanDecoder
      switch consume self {
      case .partiallyConsumed:
        assertionFailure()
        decoder = JSON.BooleanDecoder(error: Error.partiallyConsumed, stream: JSON.DecodingStream())
      case .failure(let failure):
        decoder = JSON.BooleanDecoder(error: failure.error, stream: failure.remainder)
      case .unknown(let stream):
        decoder = JSON.BooleanDecoder(stream: stream)
      case .boolean(let existingDecoder):
        decoder = existingDecoder
      case .string(let existingDecoder):
        decoder = JSON.BooleanDecoder(
          error: Error.unexpectedType, stream: existingDecoder.destroy())
      case .number(let existingDecoder):
        decoder = JSON.BooleanDecoder(
          error: Error.unexpectedType, stream: existingDecoder.destroy())
      case .null(let existingDecoder):
        decoder = JSON.BooleanDecoder(
          error: Error.unexpectedType, stream: existingDecoder.destroy())
      }
      self = .partiallyConsumed
      yield &decoder
      self = .boolean(decoder)
    }
  }

  var nullDecoder: JSON.NullDecoder {
    consuming _read {
      let decoder: JSON.NullDecoder
      switch consume self {
      case .partiallyConsumed:
        assertionFailure()
        decoder = JSON.NullDecoder(error: Error.partiallyConsumed, stream: JSON.DecodingStream())
      case .failure(let failure):
        decoder = JSON.NullDecoder(error: failure.error, stream: failure.remainder)
      case .unknown(let stream):
        decoder = JSON.NullDecoder(stream: stream)
      case .null(let existingDecoder):
        decoder = existingDecoder
      case .string(let existingDecoder):
        decoder = JSON.NullDecoder(error: Error.unexpectedType, stream: existingDecoder.destroy())
      case .number(let existingDecoder):
        decoder = JSON.NullDecoder(error: Error.unexpectedType, stream: existingDecoder.destroy())
      case .boolean(let existingDecoder):
        decoder = JSON.NullDecoder(error: Error.unexpectedType, stream: existingDecoder.destroy())
      }
      yield decoder
    }
    _modify {
      var decoder: JSON.NullDecoder
      switch consume self {
      case .partiallyConsumed:
        assertionFailure()
        decoder = JSON.NullDecoder(error: Error.partiallyConsumed, stream: JSON.DecodingStream())
      case .failure(let failure):
        decoder = JSON.NullDecoder(error: failure.error, stream: failure.remainder)
      case .unknown(let stream):
        decoder = JSON.NullDecoder(stream: stream)
      case .null(let existingDecoder):
        decoder = existingDecoder
      case .string(let existingDecoder):
        decoder = JSON.NullDecoder(error: Error.unexpectedType, stream: existingDecoder.destroy())
      case .number(let existingDecoder):
        decoder = JSON.NullDecoder(error: Error.unexpectedType, stream: existingDecoder.destroy())
      case .boolean(let existingDecoder):
        decoder = JSON.NullDecoder(error: Error.unexpectedType, stream: existingDecoder.destroy())
      }
      self = .partiallyConsumed
      yield &decoder
      self = .null(decoder)
    }
  }

  consuming func finish() -> FinishDecodingResult<Self> {
    switch consume self {
    case .partiallyConsumed:
      assertionFailure()
      return .decodingFailed(Error.partiallyConsumed, remainder: JSON.DecodingStream())
    case .failure(let failure):
      return .decodingFailed(failure.error, remainder: failure.remainder)
    case .string(let decoder):
      return decoder.finish().map { .string($0) }
    case .number(let decoder):
      return decoder.finish().map { .number($0) }
    case .null(let decoder):
      return decoder.finish().map { .null($0) }
    case .boolean(let decoder):
      return decoder.finish().map { .boolean($0) }

    case .unknown(var stream):
      stream.readWhitespace()

      enum Kind {
        case null
        case string
        case number
        case boolean
        case object
        case array
      }

      let result = stream.peekCharacter { character -> Kind? in
        switch character {
        case "n":
          return .null
        case "\"":
          return .string
        case "0"..."9", "-":
          return .number
        case "t", "f":
          return .boolean
        case "{":
          return .object
        case "[":
          return .array
        default:
          return nil
        }
      }

      switch result {
      case .needsMoreData:
        return .needsMoreData(.unknown(stream))
      case .notMatched(let error):
        return .decodingFailed(error, remainder: stream)
      case .matched(let kind):
        switch kind {
        case .string:
          let decoder = JSON.StringDecoder(stream: stream)
          return decoder.finish().map { .string($0) }
        case .number:
          let decoder = JSON.NumberDecoder(stream: stream)
          return decoder.finish().map { .number($0) }
        case .null:
          let decoder = JSON.NullDecoder(stream: stream)
          return decoder.finish().map { .null($0) }
        case .boolean:
          let decoder = JSON.BooleanDecoder(stream: stream)
          return decoder.finish().map { .boolean($0) }
        default:
          #warning("fix")
          fatalError()
        }
      }
    }
  }

}

extension FinishDecodingResult where Decoder: ~Copyable {

  fileprivate consuming func map<T: ~Copyable>(_ transform: (consuming Decoder) -> T)
    -> FinishDecodingResult<T>
  {
    switch consume self {
    case .needsMoreData(let decoder):
      return .needsMoreData(transform(decoder))
    case .decodingComplete(let remainder):
      return .decodingComplete(remainder: remainder)
    case let .decodingFailed(error, remainder):
      return .decodingFailed(error, remainder: remainder)
    }
  }

}

private enum Error: Swift.Error {
  case unexpectedType
  case partiallyConsumed
}

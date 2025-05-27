extension JSON {

  public struct ValueDecoder: ~Copyable {

    public init() {
      value = .unknown(JSON.DecodingStream())
    }

    public var stream: JSON.DecodingStream {
      _read {
        switch value {
        case .partiallyConsumed:
          assertionFailure()
          let stream = JSON.DecodingStream()
          yield stream
        case .unknown(let stream):
          yield stream
        case .string(let decoder):
          yield decoder.stream
        case .number(let decoder):
          yield decoder.stream
        case .null(let decoder):
          yield decoder.stream
        case .boolean(let decoder):
          yield decoder.stream
        }
      }
      _modify {
        switch consume value {
        case .partiallyConsumed:
          assertionFailure()
          self = ValueDecoder(value: .partiallyConsumed)
          var stream = JSON.DecodingStream()
          yield &stream
        case .unknown(var stream):
          self = ValueDecoder(value: .partiallyConsumed)
          yield &stream
          self = ValueDecoder(value: .unknown(stream))
        case .string(var decoder):
          self = ValueDecoder(value: .partiallyConsumed)
          yield &decoder.stream
          self = ValueDecoder(value: .string(decoder))
        case .number(var decoder):
          self = ValueDecoder(value: .partiallyConsumed)
          yield &decoder.stream
          self = ValueDecoder(value: .number(decoder))
        case .null(var decoder):
          self = ValueDecoder(value: .partiallyConsumed)
          yield &decoder.stream
          self = ValueDecoder(value: .null(decoder))
        case .boolean(var decoder):
          self = ValueDecoder(value: .partiallyConsumed)
          yield &decoder.stream
          self = ValueDecoder(value: .boolean(decoder))
        }
      }
    }

    public mutating func decodeAsString<T>(
      _ body: (inout StringDecoder) -> T
    ) throws -> T {
      switch consume value {
      case .partiallyConsumed:
        assertionFailure()
        self = ValueDecoder(value: .partiallyConsumed)
        throw Error.partiallyConsumed
      case .unknown(let stream):
        var decoder = JSON.StringDecoder(stream: stream)
        let result = body(&decoder)
        self = ValueDecoder(value: .string(decoder))
        return result
      case .string(var decoder):
        let result = body(&decoder)
        self = ValueDecoder(value: .string(decoder))
        return result
      case let value:
        self = ValueDecoder(value: value)
        throw Error.unexpectedType
      }
    }

    consuming func finish() -> FinishDecodingResult<Self> {
      switch consume value {
      case .partiallyConsumed:
        assertionFailure()
        return .decodingFailed(Error.partiallyConsumed, remainder: JSON.DecodingStream())
      case .string(let decoder):
        return decoder.finish().map { ValueDecoder(value: .string($0)) }
      case .number(let decoder):
        return decoder.finish().map { ValueDecoder(value: .number($0)) }
      case .null(let decoder):
        return decoder.finish().map { ValueDecoder(value: .null($0)) }
      case .boolean(let decoder):
        return decoder.finish().map { ValueDecoder(value: .boolean($0)) }

      case .unknown(let stream):

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
          return .needsMoreData(ValueDecoder(value: .unknown(stream)))
        case .notMatched(let error):
          return .decodingFailed(error, remainder: stream)
        case .matched(let kind):
          switch kind {
          case .string:
            let decoder = StringDecoder(stream: stream)
            return decoder.finish().map { ValueDecoder(value: .string($0)) }
          case .number:
            let decoder = NumberDecoder(stream: stream)
            return decoder.finish().map { ValueDecoder(value: .number($0)) }
          case .null:
            let decoder = NullDecoder(stream: stream)
            return decoder.finish().map { ValueDecoder(value: .null($0)) }
          case .boolean:
            let decoder = BooleanDecoder(stream: stream)
            return decoder.finish().map { ValueDecoder(value: .boolean($0)) }
          default:
            #warning("fix")
            fatalError()
          }
        }
      }
    }

    private init(value: consuming Value) {
      self.value = value
    }

    private enum Value: ~Copyable {
      /// `Value` cannot be partially consumed when yielding a stream in the `_modify` accessor, so we need an explicit state to represent this.
      case partiallyConsumed

      case unknown(DecodingStream)
      case string(StringDecoder)
      case number(NumberDecoder)
      case null(NullDecoder)
      case boolean(BooleanDecoder)
    }
    private var value: Value

    private enum Error: Swift.Error {
      case unexpectedType
      case partiallyConsumed
    }

  }

}

// MARK: - Implementation Details

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

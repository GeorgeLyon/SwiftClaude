extension JSON {

  public struct ValueDecoder: ~Copyable {

    consuming func finish() -> FinishDecodingResult<Self> {
      switch consume value {
      case .string(let decoder):
        return decoder.finish().map { ValueDecoder(value: .string($0)) }
      case .number(let decoder):
        return decoder.finish().map { ValueDecoder(value: .number($0)) }
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
            return decoder.finish().map { ValueDecoder(value:) }
          default:
            #warning("fix")
            fatalError()
          }
        }
      }
    }

    private enum Value: ~Copyable {
      case unknown(DecodingStream)
      case string(StringDecoder)
      case number(NumberDecoder)
      case null(NullDecoder)
    }
    private var value: Value
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

extension PrimitiveDecoder {

}

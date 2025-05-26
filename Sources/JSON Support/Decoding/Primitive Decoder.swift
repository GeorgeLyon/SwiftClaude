protocol PrimitiveDecoder: ~Copyable {

  associatedtype Value

  init(state: consuming PrimitiveDecoderState<Self>)

  static func decodeValueStatelessly(
    _ stream: inout JSON.DecodingStream
  ) throws -> JSON.DecodingResult<Value>

  var state: PrimitiveDecoderState<Self> { get set }

}

struct PrimitiveDecoderState<Decoder: PrimitiveDecoder & ~Copyable>: ~Copyable {

  init(stream: consuming JSON.DecodingStream) {
    self.stream = stream
  }

  consuming func finish() -> FinishDecodingResult<Decoder> {
    if case .incomplete = state {
      _ = try? decodeValue()
    }

    switch state {
    case .complete:
      return .decodingComplete(remainder: stream)
    case .failed(let error):
      return .decodingFailed(error, remainder: stream)
    case .incomplete:
      return .needsMoreData(Decoder(state: self))
    }
  }

  fileprivate mutating func decodeValue() throws -> JSON.DecodingResult<Decoder.Value> {
    switch state {
    case .incomplete:
      do {
        switch try Decoder.decodeValueStatelessly(&stream) {
        case .decoded(let number):
          state = .complete(number)
          return .decoded(number)
        case .needsMoreData:
          return .needsMoreData
        }
      } catch {
        state = .failed(error)
        throw error
      }
    case .complete(let number):
      return .decoded(number)
    case .failed(let error):
      throw error
    }
  }

  fileprivate enum State {
    case incomplete
    case complete(Decoder.Value)
    case failed(Swift.Error)
  }
  fileprivate var state: State = .incomplete

  fileprivate var stream: JSON.DecodingStream

}

extension PrimitiveDecoder where Self: ~Copyable {

  typealias State = PrimitiveDecoderState<Self>

  mutating func decodeValue() throws -> JSON.DecodingResult<Value> {
    try state.decodeValue()
  }

}

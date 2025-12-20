import JSONSupport
import SchemaCodingSupport

// MARK: - Decoder

extension SchemaCoding.Support {

  public struct Decoder: ~Copyable {
    public init() {
      self.arena = Arena()
      self.stream = JSON.DecodingStream()
    }
    let arena: Arena
    var stream: JSON.DecodingStream
  }

}

// MARK: - Decoding Result

extension SchemaCoding.Support {

  public struct DecodingResult<Value> {

    static func decoded(_ value: Value) -> Self {
      .init(kind: .decoded(value))
    }

    static var incomplete: Self {
      .init(kind: .incomplete)
    }

    enum Kind {
      case incomplete
      case decoded(Value)
    }
    var kind: Kind

    private init(kind: Kind) {
      self.kind = kind
    }

    func map<NewValue>(
      _ transform: (Value) throws -> NewValue
    ) rethrows -> DecodingResult<NewValue> {
      switch kind {
      case .incomplete:
        return .incomplete
      case .decoded(let value):
        let transformed = try transform(value)
        return DecodingResult<NewValue>(kind: .decoded(transformed))
      }
    }

  }

}

extension SchemaCoding.Support.DecodingResult where Value == () {

  static var decoded: Self {
    .decoded(())
  }

}

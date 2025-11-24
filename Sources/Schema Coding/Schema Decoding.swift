import JSONSupport
import SchemaCodingSupport

// MARK: - Decoder

extension SchemaCoding.Support {

  public struct Decoder: ~Copyable {
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

  }

}

extension SchemaCoding.Support.DecodingResult where Value == () {

  static var decoded: Self {
    .decoded(())
  }

}

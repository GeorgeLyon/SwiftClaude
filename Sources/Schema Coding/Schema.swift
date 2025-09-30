// MARK: - Namespaces

public enum SchemaCoding {

  public enum Support {

  }

}

// MARK: - Schema

extension SchemaCoding.Support {

  public protocol Schema<Value>: Sendable {

    associatedtype Value: Sendable

    associatedtype ValueDecodingState: Sendable

    func beginDecodingValue(
      from decoder: inout Decoder
    ) -> ValueDecodingState

    func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> Value

  }

}

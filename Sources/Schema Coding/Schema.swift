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

    func beginDecoding(
      in context: inout Decoder.Context
    ) -> ValueDecodingState

    func decodeInitialValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) -> DecodingResult<Value>

    func decodeStreamingValue<Root>(
      from decoder: inout Decoder,
      root: Root,
      keyPath: WritableKeyPath<Root, Value>,
      state: inout ValueDecodingState
    ) async throws

    func finishDecoding(
      in context: inout Decoder.Context,
      state: ValueDecodingState
    )

  }

}

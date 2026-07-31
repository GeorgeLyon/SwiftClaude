// MARK: - Storage

@StructuredCodable
private struct OptionalStorage<Wrapped: StructuredCodable> {
  var value: Wrapped?
}

// MARK: - Encoding

extension Optional: StructuredEncodable where Wrapped: StructuredCodable {

  public static var schema: some StructuredCodingSchema {
    MetaSchema.object(
      description: nil,
      properties: ("value" as StructuredCodingKey, Wrapped.schema, false)
    )
  }

  public func encode(to stream: inout StructuredEncodingStream) throws {
    try OptionalStorage(value: self).encode(to: &stream)
  }

}

// MARK: - Decoding

extension Optional: StructuredDecodable where Wrapped: StructuredCodable {

  public static func initialValueForDecoding(isMutable: Bool) -> sending Wrapped?? {
    isMutable ? .some(.none) : .none
  }

  public static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from stream: inout StructuredDecodingStream,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Wrapped? {
    try await OptionalStorage<Wrapped>.decode(
      from: &stream,
      in: context,
      using: KeyPathAccessor(base: accessor, keyPath: .writable(\.storage))
    )
  }

}

extension Optional where Wrapped: StructuredCodable {

  fileprivate var storage: OptionalStorage<Wrapped> {
    get { OptionalStorage(value: self) }
    set { self = newValue.value }
  }

}

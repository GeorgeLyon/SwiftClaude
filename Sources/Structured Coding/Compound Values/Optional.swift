// MARK: - Schema

@StructuredCodable
public struct StructuredOptionalSchema<
  WrappedSchema: StructuredCodingSchema
>: StructuredCodingSchema {
  public init(description: String?) {
    self.description = description
    self.properties = Properties(value: WrappedSchema())
  }
  private let description: String?

  @StructuredCodable
  public struct Properties {
    let value: WrappedSchema
  }
  private let properties: Properties
}

// MARK: - Storage

@StructuredCodable
private struct OptionalStorage<Wrapped: StructuredCodable> {
  var value: Wrapped?
}

// MARK: - Encoding

extension Optional: StructuredEncodable where Wrapped: StructuredCodable {

  public typealias Schema = StructuredOptionalSchema<Wrapped.Schema>

  public func encode(to encoder: inout StructuredEncoder) throws {
    try OptionalStorage(value: self).encode(to: &encoder)
  }

}

// MARK: - Decoding

extension Optional: StructuredDecodable where Wrapped: StructuredCodable {

  public static func initialValueForDecoding(isMutable: Bool) -> sending Wrapped?? {
    isMutable ? .some(.none) : .none
  }

  public static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Wrapped? {
    try await OptionalStorage<Wrapped>.decode(
      from: &decoder,
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

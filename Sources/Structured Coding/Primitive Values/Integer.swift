private import JavaScriptObjectNotation

extension Int: StructuredCodable {}
extension Int8: StructuredCodable {}
extension Int16: StructuredCodable {}
extension Int32: StructuredCodable {}
extension Int64: StructuredCodable {}
extension Int128: StructuredCodable {}
extension UInt: StructuredCodable {}
extension UInt8: StructuredCodable {}
extension UInt16: StructuredCodable {}
extension UInt32: StructuredCodable {}
extension UInt64: StructuredCodable {}
extension UInt128: StructuredCodable {}

// MARK: - Encoding

extension FixedWidthInteger where Self: StructuredEncodable {

  public func encode(to encoder: inout StructuredEncoder) {
    encoder.stream.encode(self)
  }

}

// MARK: - Decoding

extension FixedWidthInteger where Self: StructuredDecodable & Sendable {

  public static func initialValueForDecoding(isMutable: Bool) -> sending Self? {
    nil
  }

  public static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    let number = try await decoder.stream.decodeNumber()
    let value = try number.decode(as: Self.self)
    try await accessor.initializeValue(to: value)
  }

}

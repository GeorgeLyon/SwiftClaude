private import JavaScriptObjectNotation

public import struct Foundation.Decimal

// MARK: - Concrete Conformances

extension Double: StructuredCodable {}
extension Float: StructuredCodable {}
extension Float16: StructuredCodable {}

// MARK: - Schema

@StructuredCodable
public struct StructuredNumberSchema: StructuredCodingSchema {
  public init(description: String?) {
    self.description = description
  }
  private let description: String?
  private let type = "number"
}

extension BinaryFloatingPoint
where Self: StructuredCodable & Sendable & LosslessStringConvertible {

  public typealias Schema = StructuredNumberSchema

}

extension Decimal {

  public typealias Schema = StructuredNumberSchema

}

// MARK: - Encoding

extension Double {

  public func encode(to encoder: inout StructuredEncoder) throws {
    try encoder.stream.encode(self)
  }

}

extension Float {

  public func encode(to encoder: inout StructuredEncoder) throws {
    try encoder.stream.encode(self)
  }

}

extension Float16 {

  public func encode(to encoder: inout StructuredEncoder) throws {
    try encoder.stream.encode(self)
  }

}

extension Decimal: StructuredEncodable {

  public func encode(to encoder: inout StructuredEncoder) throws {
    try encoder.stream.encode(self)
  }

}

// MARK: - Decoding

extension BinaryFloatingPoint
where Self: StructuredDecodable & Sendable & LosslessStringConvertible {

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

extension Decimal: StructuredDecodable {

  public static func initialValueForDecoding(isMutable: Bool) -> sending Self? {
    nil
  }

  public static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    let number = try await decoder.stream.decodeNumber()
    let value = try number.decode(as: Decimal.self)
    try await accessor.initializeValue(to: value)
  }

}

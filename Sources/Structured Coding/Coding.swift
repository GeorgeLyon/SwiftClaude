public import JavaScriptObjectNotation

// MARK: - Codable

public typealias StructuredCodable = StructuredDecodable & StructuredEncodable

// MARK: - Schema

/// A schema value, as returned by a `schema` witness.
public protocol StructuredCodingSchema: StructuredCodable {

  var metadata: StructuredCodingSchemaMetadata { get set }

}

public struct StructuredCodingSchemaMetadata: Sendable {

  public init() {
    description = nil
  }

  init(description: String?) {
    self.description = description
  }

  var description: String?

}

extension StructuredCodingSchema {

  /// Convenience for `metadata.description`.
  var description: String? {
    get { metadata.description }
    set { metadata.description = newValue }
  }

  /// Returns the schema with `description` placed before any description the
  /// schema already carries. Prepending `nil` returns the schema unchanged.
  consuming func prependDescription(_ description: String?) -> Self {
    metadata.description = combineDescriptions(description, metadata.description)
    return self
  }

}

// MARK: - Encoding

public protocol StructuredEncodable: SendableMetatype {

  associatedtype Schema: StructuredCodingSchema
  static var schema: Schema { get }

  func encode(to encoder: inout StructuredEncoder) throws

}

public struct StructuredEncoder: ~Copyable {

  public init(options: EncodingStream.Options = []) {
    self.stream = EncodingStream()
    self.stream.options = options
  }

  public var stringValue: String {
    stream.stringValue
  }

  init(stream: consuming EncodingStream) {
    self.stream = stream
  }

  var stream: EncodingStream

}

extension EncodingStream {

  mutating func withEncoder<T>(
    _ body: (inout StructuredEncoder) throws -> T
  ) rethrows -> T {
    var encoder = StructuredEncoder(stream: self)
    do {
      let result = try body(&encoder)
      self = encoder.stream
      return result
    } catch {
      self = encoder.stream
      throw error
    }
  }

}

// MARK: - Decoding

public protocol StructuredDecodable: SendableMetatype {

  associatedtype Schema: StructuredCodingSchema
  static var schema: Schema { get }

  /// If non-`nil`, `decode` expects `accessor` is already initialized with the returned value.
  static func initialValueForDecoding(
    isMutable: Bool
  ) -> sending Self?

  static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self

}

extension StructuredDecodable {

  static func decode(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext
  ) async throws -> sending Self {
    try await withSendingAccessor(in: context) { accessor in
      if let initialValue = initialValueForDecoding(isMutable: accessor.isMutable) {
        try await accessor.initializeValue(to: initialValue)
      }
      try await decode(from: &decoder, in: context, using: accessor)
    }
  }

}

public struct StructuredDecoder: ~Copyable, ~Escapable {
  var stream: DecodingStream
}

public struct StructuredDecodingContext: ~Copyable, ~Escapable {

  @_lifetime(immortal)
  public init() {
    arena = Arena()
  }

  func withArena<T: ~Copyable>(
    _ body: (borrowing Arena) async throws -> sending T
  ) async rethrows -> sending T {
    try await withArena(sending: ()) {
      arena, _
      in try await body(arena)
    }
  }

  func withArena<T: ~Copyable, U: ~Copyable>(
    sending value: consuming sending T,
    _ body: (borrowing Arena, consuming sending T) async throws -> sending U
  ) async rethrows -> sending U {
    try await arena.withScope(sending: value) { value in
      try await body(arena, value)
    }
  }

  private let arena: Arena

}

enum DecodingError: Swift.Error {
  case noValueDecoded
}

// MARK: - Coding Key

public struct StructuredCodingKey: ExpressibleByStringLiteral, Sendable {

  public init(stringLiteral value: StaticString) {
    staticStringValue = value
  }
  let staticStringValue: StaticString

  var stringValue: String {
    "\(staticStringValue)"
  }

}

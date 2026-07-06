public import JavaScriptObjectNotation

// MARK: - Codable

public typealias StructuredCodable = StructuredDecodable & StructuredEncodable

// MARK: - Encoding

public protocol StructuredEncodable: SendableMetatype {

  associatedtype Schema: StructuredCodable
  static func schema(description: String?) -> Schema

  func encode(to encoder: inout StructuredEncoder) throws

}

extension StructuredEncodable {

  public static func schema() -> Schema {
    schema(description: nil)
  }

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

  associatedtype Schema: StructuredCodable
  static func schema(description: String?) -> Schema

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

  public static func schema() -> Schema {
    schema(description: nil)
  }

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

// MARK: - Schema

@StructuredCodable
public struct StructuredAnySchema: StructuredCodable {
  public init(description: String?) {
    self.description = description
  }
  private let description: String?
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

  static let description: Self = "description"
  static let properties: Self = "properties"

}

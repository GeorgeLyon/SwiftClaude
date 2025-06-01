import JSONSupport

public enum ToolInput {

  public protocol SchemaCodable {

    associatedtype ToolInputSchema: Schema<Self>

    static var toolInputSchema: ToolInputSchema { get }

  }

  public static func schema<Value: SchemaCodable>(
    representing: Value.Type
  ) -> some Schema<Value> {
    Value.toolInputSchema
  }

  /// A Schema describing the shape of a tool input
  public protocol Schema<Value>: Sendable {

    associatedtype Value

    func encodeSchemaDefinition(to encoder: SchemaEncoder<Self>) throws

    func encode(_ value: Value, to encoder: Encoder<Self>) throws

    func decodeValue(from decoder: Decoder<Self>) throws -> Value

    func encodeSchemaDefinition(to encoder: inout NewSchemaEncoder<Self>)

    func decodeValue(from decoder: inout NewDecoder) async throws -> Value

  }

}

extension ToolInput {

  public struct NewSchemaEncoder<Schema>: ~Copyable {

    init(
      stream: consuming JSON.EncodingStream,
      descriptionPrefix: String? = nil,
      descriptionSuffix: String? = nil
    ) {
      self.stream = stream
      self.descriptionPrefix = descriptionPrefix
      self.descriptionSuffix = descriptionSuffix
    }

    func contextualDescription(_ description: String?) -> String? {
      combineDescriptions(descriptionPrefix, description, descriptionSuffix)
    }

    mutating func withMapped<T>(
      _ body: (inout NewSchemaEncoder<T>) -> Void
    ) {
      var encoder = NewSchemaEncoder<T>(
        stream: stream,
        descriptionPrefix: descriptionPrefix,
        descriptionSuffix: descriptionSuffix
      )
      body(&encoder)
      self = NewSchemaEncoder(
        stream: encoder.stream,
        descriptionPrefix: descriptionPrefix,
        descriptionSuffix: descriptionSuffix
      )
    }

    var stream: JSON.EncodingStream

    private let descriptionPrefix: String?
    private let descriptionSuffix: String?

  }

  public struct SchemaEncoder<Value> {

    init(
      wrapped: Swift.Encoder,
      descriptionPrefix: String? = nil,
      descriptionSuffix: String? = nil
    ) {
      self.wrapped = wrapped
      self.descriptionPrefix = descriptionPrefix
      self.descriptionSuffix = descriptionSuffix
    }

    func contextualDescription(_ description: String?) -> String? {
      combineDescriptions(descriptionPrefix, description, descriptionSuffix)
    }

    func map<T>(_ type: T.Type = T.self) -> SchemaEncoder<T> {
      SchemaEncoder<T>(
        wrapped: wrapped,
        descriptionPrefix: descriptionPrefix,
        descriptionSuffix: descriptionSuffix
      )
    }

    let wrapped: Swift.Encoder

    private let descriptionPrefix: String?
    private let descriptionSuffix: String?

  }

  public struct Encoder<Schema> {
    let wrapped: Swift.Encoder

    func map<T>(_ type: T.Type = T.self) -> Encoder<T> {
      Encoder<T>(wrapped: wrapped)
    }
  }

  public struct Decoder<Schema> {
    let wrapped: Swift.Decoder

    func map<T>(_ type: T.Type = T.self) -> Decoder<T> {
      Decoder<T>(wrapped: wrapped)
    }
  }

  public struct NewDecoder: ~Copyable {

    mutating func decode<T>(
      _ body: (inout JSON.DecodingStream) throws -> JSON.DecodingResult<T>
    ) async throws -> T {
      fatalError()
    }

  }

}

// MARK: - Internal API

extension ToolInput.Schema {

  var mayAcceptNullValue: Bool {
    /// Schemas must explicitly opt out of accepting null values by conforming to `InternalSchema`
    (self as? any InternalSchema)?.mayAcceptNullValue ?? true
  }

}

protocol InternalSchema: ToolInput.Schema {

  var mayAcceptNullValue: Bool { get }

}

extension InternalSchema {

  /// By default, internal schemas should not accept `null` as a default value
  var mayAcceptNullValue: Bool { false }

}

/// Currently, we require that leaf schemas have no additional fields beyond `description` and `type`
protocol LeafSchema: InternalSchema {

  var type: String { get }

}

/// We don't expect internal leaf schemas to have any additional properties, but they should still encode a contextual description if necessary.
extension LeafSchema {

  public func encodeSchemaDefinition(to encoder: ToolInput.SchemaEncoder<Self>) throws {
    var container = encoder.wrapped.container(keyedBy: SchemaCodingKey.self)
    try container.encode(type, forKey: .type)

    if let description = encoder.contextualDescription(nil) {
      try container.encode(description, forKey: .description)
    }
  }

  public func encodeSchemaDefinition(to encoder: inout ToolInput.NewSchemaEncoder<Self>) {
    let description = encoder.contextualDescription(nil)
    encoder.stream.encodeObject { encoder in
      if let description {
        encoder.encodeProperty(name: "description") { $0.encode(description) }
      }
      encoder.encodeProperty(name: "type") { $0.encode(type) }
    }
  }

}

extension LeafSchema where Value: Codable {

  func encode(_ value: Value, to encoder: ToolInput.Encoder<Self>) throws {
    var container = encoder.wrapped.singleValueContainer()
    try container.encode(value)
  }

  func decodeValue(from decoder: ToolInput.Decoder<Self>) throws -> Value {
    try decoder.wrapped.singleValueContainer().decode(Value.self)
  }

}

// MARK: - Convenience

extension JSON.EncodingStream {

  /// Convenience method to encode a schema definition
  mutating func encodeSchemaDefinition<Schema: ToolInput.Schema>(
    _ schema: Schema,
    descriptionPrefix: String? = nil,
    descriptionSuffix: String? = nil
  ) {
    var encoder = ToolInput.NewSchemaEncoder<Schema>(
      stream: self,
      descriptionPrefix: descriptionPrefix,
      descriptionSuffix: descriptionSuffix
    )
    schema.encodeSchemaDefinition(to: &encoder)
    self = encoder.stream
  }

}

extension ToolInput.NewDecoder {

  mutating func decodeObjectPropertyHeader(
    _ state: inout JSON.ObjectDecodingState
  ) async throws -> JSON.ObjectPropertyHeader? {
    try await decode { stream in
      try stream.decodeObjectPropertyHeader(&state)
    }
  }

  mutating func decodeArrayElementHeader(
    _ state: inout JSON.ArrayDecodingState
  ) async throws -> JSON.ArrayElementHeader? {
    try await decode { stream in
      try stream.decodeArrayElementHeader(&state)
    }
  }

  mutating func peekNull() async throws -> Bool {
    try await decode { stream in
      try stream.peekNull()
    }
  }

  mutating func decodeNull() async throws {
    try await decode { stream in
      try stream.decodeNull()
    }
  }

}

// MARK: - Implementation Details

private enum SchemaCodingKey: CodingKey {
  case type, description
}

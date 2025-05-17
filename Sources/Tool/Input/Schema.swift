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

  }

}

extension ToolInput {

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

// MARK: - Implementation Details

private enum SchemaCodingKey: CodingKey {
  case type, description
}

import JSONSupport

public typealias SchemaCodable = SchemaCoding.SchemaCodable

/// Most public types are nested in `SchemaCoding` since most don't need to be referenced directly.
public enum SchemaCoding {

  public protocol SchemaCodable {

    associatedtype Schema: SchemaCoding.Schema<Self>

    static var schema: Schema { get }

  }

  /// A Schema describing the shape of a tool input
  public protocol Schema<Value>: Sendable {

    associatedtype Value

    func encodeSchemaDefinition(to encoder: inout SchemaEncoder)

    associatedtype ValueDecodingState = ()

    var initialValueDecodingState: ValueDecodingState { get }

    func decodeValue(
      from stream: inout SchemaValueDecoder,
      state: inout ValueDecodingState
    ) throws -> SchemaDecodingResult<Value>

    func encode(_ value: Value, to encoder: inout SchemaValueEncoder)

  }

  public enum SchemaResolver {

    public static func schema<Value: SchemaCodable>(
      representing: Value.Type
    ) -> some Schema<Value> {
      Value.schema
    }

    public static func schema<Value: SchemaCodable>(
      representing: Value.Type
    ) -> some ExtendableSchema<Value> where Value.Schema: ExtendableSchema {
      Value.schema
    }

  }

  public struct SchemaCodingKey: Sendable, Hashable, ExpressibleByStringLiteral {

    public init(_ value: StaticString) {
      self.stringValue = String(describing: value)
    }

    public init(stringLiteral value: StaticString) {
      self.init(value)
    }

    internal let stringValue: String

  }

  public struct SchemaEncoder: ~Copyable {

    public init() {
      self.init(
        stream: JSON.EncodingStream(),
        descriptionPrefix: nil,
        descriptionSuffix: nil
      )
    }

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

    var stream: JSON.EncodingStream

    private let descriptionPrefix: String?
    private let descriptionSuffix: String?

  }

  public struct SchemaValueEncoder: ~Copyable {
    public init() {
      stream = JSON.EncodingStream()
    }
    var stream: JSON.EncodingStream

    fileprivate init(stream: consuming JSON.EncodingStream) {
      self.stream = stream
    }
  }

  public struct SchemaValueDecoder: ~Copyable {
    public init() {
      stream = JSON.DecodingStream()
    }
    var stream: JSON.DecodingStream

    fileprivate init(stream: consuming JSON.DecodingStream) {
      self.stream = stream
    }
  }

  public enum SchemaDecodingResult<Value> {
    case needsMoreData
    case decoded(Value)
  }

  /// We've made `convertToSnakeCase` the default while this is only used in SwiftClaude
  public enum CodingKeyConversionStrategy {
    case convertToSnakeCase
    case none
  }

}

extension SchemaCoding.Schema where ValueDecodingState == Void {

  public var initialValueDecodingState: Void { () }

}

// MARK: - Macros

@attached(
  extension,
  conformances: SchemaCodable,
  names: named(schema), named(init)
)
public macro SchemaCodable(
  codingKeyConversionStrategy: SchemaCoding.CodingKeyConversionStrategy = .convertToSnakeCase
) =
  #externalMacro(
    module: "Macros",
    type: "SchemaCodableMacro"
  )

@attached(
  extension,
  conformances: SchemaCodable,
  names: named(schema), named(init)
)
public macro SchemaCodable(
  discriminatorPropertyName: String,
  codingKeyConversionStrategy: SchemaCoding.CodingKeyConversionStrategy = .convertToSnakeCase
) =
  #externalMacro(
    module: "Macros",
    type: "InternallyTaggedEnumSchemaCodableMacro"
  )

// MARK: - Internal API

extension SchemaCoding.Schema {

  var mayAcceptNullValue: Bool {
    /// Schemas must explicitly opt out of accepting null values by conforming to `InternalSchema`
    (self as? any InternalSchema)?.mayAcceptNullValue ?? true
  }

}

protocol InternalSchema: SchemaCoding.Schema {

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

  public func encodeSchemaDefinition(to encoder: inout SchemaCoding.SchemaEncoder) {
    let description = encoder.contextualDescription(nil)
    encoder.stream.encodeObject { encoder in
      if let description {
        encoder.encodeProperty(name: "description") { $0.encode(description) }
      }
      encoder.encodeProperty(name: "type") { $0.encode(type) }
    }
  }

}

// MARK: - Convenience

extension JSON.EncodingStream {

  /// Convenience method to encode a schema definition
  mutating func encodeSchemaDefinition<Schema: SchemaCoding.Schema>(
    _ schema: Schema,
    descriptionPrefix: String? = nil,
    descriptionSuffix: String? = nil
  ) {
    var encoder = SchemaCoding.SchemaEncoder(
      stream: self,
      descriptionPrefix: descriptionPrefix,
      descriptionSuffix: descriptionSuffix
    )
    schema.encodeSchemaDefinition(to: &encoder)
    self = encoder.stream
  }

  mutating func encode<Schema: SchemaCoding.Schema>(_ value: Schema.Value, using schema: Schema) {
    var encoder = SchemaCoding.SchemaValueEncoder(stream: self)
    schema.encode(value, to: &encoder)
    self = encoder.stream
  }

}

extension JSON.DecodingStream {

  /// Convenience method to decode a schema definition
  mutating func decodeValue<Schema: SchemaCoding.Schema>(
    using schema: Schema,
    state: inout Schema.ValueDecodingState
  ) throws -> SchemaCoding.SchemaDecodingResult<Schema.Value> {
    var decoder = SchemaCoding.SchemaValueDecoder(stream: self)
    do {
      let result = try schema.decodeValue(from: &decoder, state: &state)
      self = decoder.stream
      return result
    } catch {
      self = decoder.stream
      throw error
    }
  }

}

extension JSON.DecodingResult {
  var schemaDecodingResult: SchemaCoding.SchemaDecodingResult<Value> {
    switch self {
    case .needsMoreData:
      return .needsMoreData
    case .decoded(let value):
      return .decoded(value)
    }
  }
}

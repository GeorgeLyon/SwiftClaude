public import JSONSupport

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
      from stream: inout JSON.DecodingStream,
      state: inout ValueDecodingState
    ) throws -> JSON.DecodingResult<Value>

    func encode(_ value: Value, to stream: inout JSON.EncodingStream)

  }

  public enum SchemaResolver {

    public static func schema<Value: SchemaCodable>(
      representing: Value.Type
    ) -> some Schema<Value> {
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

}

extension SchemaCoding.Schema where ValueDecodingState == Void {

  var initialValueDecodingState: Void { () }

}

// MARK: - Macros

@attached(
  extension,
  conformances: SchemaCodable,
  names: named(schema), named(init)
)
public macro SchemaCodable() =
  #externalMacro(
    module: "Macros",
    type: "SchemaCodableMacro"
  )

@attached(
  extension,
  conformances: SchemaCodable,
  names: named(schema), named(init)
)
public macro SchemaCodable(discriminatorPropertyName: String) =
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
  mutating func encodeSchemaDefinition<T: SchemaCoding.Schema>(
    _ schema: T,
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

  /// Convenience method to encode a value using a schema
  // mutating func encodeValue<T: Schema>(
  //   _ value: T.Value,
  //   using schema: T
  // ) {
  //   schema.encode(value, to: &self)
  // }

}

public import JSONSupport

public protocol SchemaCodable {

  associatedtype Schema: _ImplementationDetails._Schema<Self>

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

/// Namespace for types related to getting concrete values conforming to the `Schema` protocol
public enum SchemaProvider {

  public static func schema<Value: SchemaCodable>(
    representing: Value.Type
  ) -> some Schema<Value> {
    Value.schema
  }

}

extension Schema where ValueDecodingState == Void {

  var initialValueDecodingState: Void { () }

}

public struct SchemaCodingKey: Sendable, Hashable {
  internal let stringValue: String

  public init(_ value: StaticString) {
    self.stringValue = String(describing: value)
  }
}

extension SchemaCodingKey: ExpressibleByStringLiteral {
  public init(stringLiteral value: StaticString) {
    self.init(value)
  }
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

// MARK: - Internal API

extension Schema {

  var mayAcceptNullValue: Bool {
    /// Schemas must explicitly opt out of accepting null values by conforming to `InternalSchema`
    (self as? any InternalSchema)?.mayAcceptNullValue ?? true
  }

}

protocol InternalSchema: Schema {

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

  public func encodeSchemaDefinition(to encoder: inout SchemaEncoder) {
    let description = encoder.contextualDescription(nil)
    encoder.stream.encodeObject { encoder in
      if let description {
        encoder.encodeProperty(name: "description") { $0.encode(description) }
      }
      encoder.encodeProperty(name: "type") { $0.encode(type) }
    }
  }

}

// MARK: - Implementation Details

/// Because there is a `SchemaCodable` protocol in the `SchemaCodable` target, we can't reference top-level type that have been shadowed by local parameters. To work around this we use `_ImplementationDetails`.
public enum _ImplementationDetails {
  public typealias _Schema = Schema
}

// MARK: - Convenience

extension JSON.EncodingStream {

  /// Convenience method to encode a schema definition
  mutating func encodeSchemaDefinition<T: Schema>(
    _ schema: T,
    descriptionPrefix: String? = nil,
    descriptionSuffix: String? = nil
  ) {
    var encoder = SchemaEncoder(
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

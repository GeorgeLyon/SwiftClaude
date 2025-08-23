import JSONSupport

// MARK: - Namespaces

public enum SchemaCoding {

  public enum Support {

  }

}

// MARK: - Schema

typealias Schema = SchemaCoding.Support.Schema

extension SchemaCoding {

  public typealias Schema = Support.Schema

}

extension SchemaCoding.Support {

  public protocol Schema<Value>: Sendable {

    associatedtype Value: Sendable

    func encode(_ value: Value, to encoder: inout Encoder)

    associatedtype ValueDecodingState: Sendable = Void

    var initialValueDecodingState: ValueDecodingState { get }

    func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value>

    #if ENABLE_META_SCHEMA
      associatedtype MetaSchema: SchemaCoding.Schema where MetaSchema.Value == Self

      /// Schemas define their own meta-schema, so that we can also encode the schemas themselves.
      /// They are not, however, `SchemaCodable` themselves because they may have be configured with runtime values like a description.
      func metaSchema(in context: SchemaContext) -> MetaSchema
    #endif

    /// Metadata about the schema.
    /// This is used by composite schemas to select the best representation.
    var schemaMetadata: SchemaMetadata { get }

  }

  public struct SchemaContext: Sendable {
    init(
      descriptionPrefix: String? = nil,
      descriptionSuffix: String? = nil
    ) {
      self.descriptionPrefix = descriptionPrefix
      self.descriptionSuffix = descriptionSuffix
    }
    func contextualDescription(for description: String?) -> String? {
      combineDescriptions([descriptionPrefix, description, descriptionSuffix])
    }
    fileprivate let descriptionPrefix: String?
    fileprivate let descriptionSuffix: String?
  }

  public struct SchemaMetadata {
    let primitiveRepresentation: String?
    let mayAcceptNull: Bool
  }

}

extension Schema where ValueDecodingState == Void {
  public var initialValueDecodingState: Void {}
}

extension SchemaCoding.Support.Schema {

  public var metaSchema: MetaSchema {
    metaSchema()
  }

  func metaSchema(
    descriptionPrefix: String? = nil,
    descriptionSuffix: String? = nil
  ) -> MetaSchema {
    metaSchema(
      in: SchemaCoding.Support.SchemaContext(
        descriptionPrefix: descriptionPrefix,
        descriptionSuffix: descriptionSuffix
      )
    )
  }

}

// MARK: - Schema Codable

extension SchemaCoding {

  public typealias SchemaCodable = Support.SchemaCodable

}

extension SchemaCoding.Support {

  public static func schema<Value: SchemaCodable>(
    representing: Value.Type = Value.self
  ) -> Value.Schema {
    Value.schema
  }

  public protocol SchemaCodable: Sendable {
    associatedtype Schema: SchemaCoding.Schema where Schema.Value == Self
    static var schema: Schema { get }
  }

}

// MARK: - Encoding

extension SchemaCoding.Support {

  public struct Encoder: ~Copyable {
    public init() {
      self.stream = JSON.EncodingStream()
    }
    init(stream: consuming JSON.EncodingStream) {
      self.stream = stream
    }
    var stream: JSON.EncodingStream
  }

}

// MARK: - Decoding

extension SchemaCoding.Support {

  public struct Decoder: ~Copyable {
    public init() {
      self.stream = JSON.DecodingStream()
    }

    var stream: JSON.DecodingStream
    init(stream: consuming JSON.DecodingStream) {
      self.stream = stream
    }
  }

  public struct DecodingResult<Value: Sendable>: Sendable {

    public var isComplete: Bool {
      switch kind {
      case .incomplete:
        return false
      case .decoded:
        return true
      }
    }

    public var value: Value {
      get throws {
        switch kind {
        case .incomplete:
          throw Error.incompleteValue
        case .decoded(let value):
          return value
        }
      }
    }

    static var incomplete: Self {
      Self(kind: .incomplete)
    }

    static func decoded(_ value: Value) -> Self {
      Self(kind: .decoded(value))
    }

    enum Kind {
      case incomplete
      case decoded(Value)
    }
    let kind: Kind

    func map<NewValue>(
      _ transform: (Value) throws -> NewValue
    ) rethrows -> DecodingResult<NewValue> {
      switch kind {
      case .incomplete:
        return .incomplete
      case .decoded(let value):
        let transformed = try transform(value)
        return DecodingResult<NewValue>(kind: .decoded(transformed))
      }
    }

  }

}

extension SchemaCoding.Support.DecodingResult where Value == Void {

  static var decoded: Self {
    Self(kind: .decoded(()))
  }

}

// MARK: - Style

extension SchemaCoding.Support {

  public protocol Style: Sendable {

  }

  public struct InferredStyle: Style, Sendable {
    fileprivate init() {}
  }

}

extension SchemaCoding.Support.Style
where Self == SchemaCoding.Support.InferredStyle {
  public static var inferred: Self {
    Self()
  }
}

// MARK: - Coding Key Conversion Strategy

extension SchemaCoding.Support {

  public enum CodingKeyConversionStrategy: Sendable {
    case none
    case convertToSnakeCase
  }

}

// MARK: - Errors

private enum Error: Swift.Error {
  case incompleteValue
}

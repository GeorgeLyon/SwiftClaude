import SchemaCodingSupport

// MARK: - Namespaces

public enum SchemaCoding {

  public enum Support {

  }

}

// MARK: - Schema

extension SchemaCoding {

  public typealias Schema = Support.Schema

}

extension SchemaCoding.Support {

  public protocol Schema<Value> {

    associatedtype Value

    func encode(_ value: Value, to encoder: inout Encoder)

    associatedtype ValueDecodingState

    func beginDecodingValue(
      from decoder: borrowing Decoder
    ) -> ValueDecodingState

    func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value>

    associatedtype MetaSchema: Schema where MetaSchema.Value == Self
    var metaSchema: MetaSchema { get }

    var metadata: SchemaMetadata { get set }

  }

  public struct SchemaMetadata {
    init(description: String? = nil) {
      self.description = description
    }
    mutating func prependDescription(_ prefix: String?) {
      guard let prefix else { return }
      if let description {
        self.description = [
          prefix,
          description,
        ].joined(separator: "\n")
      } else {
        self.description = prefix
      }
    }
    mutating func appendDescription(_ suffix: String?) {
      guard let suffix else { return }
      if let description {
        self.description = [
          description,
          suffix,
        ].joined(separator: "\n")
      } else {
        self.description = suffix
      }
    }
    private(set) var description: String?
  }

}

extension SchemaCoding.Support.Schema {

  var description: String? {
    metadata.description
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

  public protocol SchemaCodable {
    associatedtype Schema: SchemaCoding.Schema<Self>
    static var schema: Schema { get }
  }

}

// MARK: - Schema Coding Key

extension SchemaCoding.Support {

  public struct SchemaCodingKey: ExpressibleByStringLiteral {

    public init(stringLiteral value: StaticString) {
      stringValue = "\(value)"
    }
    let stringValue: String

    static var description: Self { "description" }
    static var properties: Self { "properties" }
    static var required: Self { "required" }
    static var items: Self { "items" }
    static var prefixItems: Self { "prefixItems" }
    static var `enum`: Self { "enum" }
    static var oneOf: Self { "oneOf" }
    static var type: Self { "type" }
    static var value: Self { "value" }
    static var const: Self { "const" }

  }

}

// MARK: - Schema Style

extension SchemaCoding.Support {

  public protocol Style {

  }

  public struct InferredStyle: Style {
    fileprivate init() {}
  }

}

extension SchemaCoding.Support.Style
where Self == SchemaCoding.Support.InferredStyle {
  public static var inferred: Self {
    Self()
  }
}

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

  public protocol Schema<Value>: Sendable {

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
    func metaSchema(in context: SchemaContext) -> MetaSchema

  }

  public struct SchemaContext {
    var description: String {
      fatalError()
    }
  }
}

// MARK: - Schema Codable

extension SchemaCoding {

  public typealias SchemaCodable = Support.SchemaCodable

}

extension SchemaCoding.Support {

  public protocol SchemaCodable {
    associatedtype Schema: SchemaCoding.Schema<Self>
    static var schema: Schema { get }
  }

}

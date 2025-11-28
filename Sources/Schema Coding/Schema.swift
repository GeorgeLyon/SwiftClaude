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

    var initialValueDecodingState: ValueDecodingState { get }

    func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value>

    associatedtype MetaSchema: Schema where MetaSchema.Value == Self
    func metaSchema(in context: inout SchemaContext) -> MetaSchema

  }

  public struct SchemaContext: ~Copyable {
    var arenaArchetype: Arena.Archetype
  }
}

public import SchemaCoding

@attached(
  extension,
  conformances: SchemaCodable,
  names: named(schema), named(init)
)
macro APICodable() =
  #externalMacro(
    module: "Macros",
    type: "APICodableMacro"
  )

public enum APICodable {

  /// Alias SchemaCoding Types
  public typealias SchemaCodable = SchemaCoding.SchemaCodable
  public typealias Schema = SchemaCoding.Schema
  public typealias ExtendableSchema = SchemaCoding.ExtendableSchema
  public typealias SchemaResolver = SchemaCoding.SchemaResolver
  public typealias SchemaCodingKey = SchemaCoding.SchemaCodingKey
  public typealias SchemaEncoder = SchemaCoding.SchemaEncoder
  public typealias StructSchemaDecoder = SchemaCoding.StructSchemaDecoder
  public typealias EnumCaseEncoder = SchemaCoding.EnumCaseEncoder
  public typealias InternallyTaggedEnumCaseEncoder = SchemaCoding.InternallyTaggedEnumCaseEncoder

}

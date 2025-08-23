public import SchemaCoding

@attached(
  extension,
  conformances: APICodable.SchemaCodable,
  names: named(schema), named(init)
)
macro APICodable(
  style: SchemaCoding.SchemaCodingSupport.SchemaStyle? = nil
) =
  #externalMacro(
    module: "Macros",
    type: "APICodableMacro"
  )

public enum APICodable {
  public typealias Schema = SchemaCoding.Schema
  public typealias ObjectSchema = SchemaCoding.ObjectSchema
  public typealias SchemaCodable = SchemaCoding.SchemaCodable
  public typealias SchemaCodingSupport = SchemaCoding.SchemaCodingSupport
}

public import SchemaCoding

@attached(
  extension,
  conformances: APICodable.SchemaCodable,
  names: named(schema), named(init)
)
macro APICodable() =
  #externalMacro(
    module: "Macros",
    type: "APICodableMacro"
  )

public enum APICodable {

  public typealias Schema = SchemaCoding.Schema
  public typealias SchemaCodable = SchemaCoding.SchemaCodable
  public typealias SchemaCodingSupport = SchemaCoding.SchemaCodingSupport

}

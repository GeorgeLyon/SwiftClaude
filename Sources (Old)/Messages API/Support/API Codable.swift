public import SchemaCoding

@attached(
  extension,
  conformances: APICodable.SchemaCodable,
  names: named(schema), named(init)
)
macro APICodable(
  style: SchemaCoding.Support.Style? = nil
) =
  #externalMacro(
    module: "Macros",
    type: "APICodableMacro"
  )

public enum APICodable {
  public typealias Schema = SchemaCoding.Schema
  public typealias SchemaCodable = SchemaCoding.SchemaCodable
  public typealias ObjectSchema = SchemaCoding.ObjectSchema
  public typealias StructDecoder = SchemaCoding.StructDecoder
  public typealias StructSinglePropertyDecoder = SchemaCoding.StructSinglePropertyDecoder
  public typealias EnumCaseDecoder = SchemaCoding.EnumCaseDecoder
  public typealias EnumSingleAssociatedValueCaseDecoder = SchemaCoding
    .EnumSingleAssociatedValueCaseDecoder
  public typealias Support = SchemaCoding.Support
}

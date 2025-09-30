@attached(
  extension,
  conformances: SchemaCoding.SchemaCodable,
  names: named(schema), named(init)
)
public macro SchemaCodable(
  description: String? = nil,
  style: SchemaCoding.Support.Style = .inferred,
  codingKeyConversionStrategy: SchemaCoding.Support.CodingKeyConversionStrategy = .none,
) =
  #externalMacro(
    module: "Macros",
    type: "SchemaCodableMacro"
  )

@attached(peer)
public macro SchemaDetails(
  description: String? = nil
) =
  #externalMacro(
    module: "Macros",
    type: "SchemaDetailsMacro"
  )

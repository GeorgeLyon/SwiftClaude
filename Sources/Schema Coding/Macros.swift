@attached(
  extension,
  conformances: SchemaCoding.SchemaCodable,
  names: named(schema), named(init)
)
public macro SchemaCodable(
  description: String? = nil,
  style: SchemaCoding.Support.Style = .inferred,
  keyConversionStrategy: SchemaCoding.Support.KeyConversionStrategy = .none,
) =
  #externalMacro(
    module: "Macros",
    type: "SchemaCodableMacro"
  )

@attached(peer)
public macro SchemaProperty(
  description: String? = nil
) =
  #externalMacro(
    module: "Macros",
    type: "SchemaPropertyMacro"
  )

@attached(peer)
public macro SchemaCase(
  description: String? = nil
) =
  #externalMacro(
    module: "Macros",
    type: "SchemaCaseMacro"
  )

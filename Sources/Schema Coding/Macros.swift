@attached(
  extension,
  conformances: SchemaCodable,
  names: named(schema), named(init)
)
public macro SchemaCodable() =
  #externalMacro(
    module: "SchemaCodingMacros",
    type: "SchemaCodableMacro"
  )

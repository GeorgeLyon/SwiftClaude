@attached(
  extension,
  conformances: Tool,
  names: named(definition), named(Input), named(invoke)
)
public macro Tool() =
  #externalMacro(
    module: "ToolMacros",
    type: "ToolMacro"
  )

@attached(
  extension,
  conformances: SchemaCodable,
  names: named(toolInputSchema), named(init)
)
public macro ToolInput() =
  #externalMacro(
    module: "ToolMacros",
    type: "ToolInputMacro"
  )

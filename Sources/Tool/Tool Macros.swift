@attached(extension)
@attached(
  extension,
  conformances: Tool,
  names: named(definition), named(Input), named(invoke)
)
public macro Tool(name: String? = nil) =
  #externalMacro(
    module: "ToolMacros",
    type: "ToolMacro"
  )

@attached(extension)
@attached(
  extension,
  conformances: ToolInput.SchemaCodable,
  names: named(toolInputSchema), named(ToolInputSchemaCaseKey)
)
public macro ToolInput() =
  #externalMacro(
    module: "ToolMacros",
    type: "ToolInputMacro"
  )

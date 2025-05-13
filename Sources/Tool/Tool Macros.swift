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
  names: named(toolInputSchema), named(init)
)
public macro ToolInput() =
  #externalMacro(
    module: "ToolMacros",
    type: "ToolInputMacro"
  )

@attached(extension)
@attached(
extension,
conformances: Tool,
names: named(description), named(invoke)
)
public macro Tool() =
#externalMacro(
  module: "ToolMacros",
  type: "ToolMacro"
)

@attached(extension)
@attached(
extension,
conformances: ToolInput.SchemaCodable,
names: named(toolInputSchema), named(init)
)
public macro Action() =
#externalMacro(
  module: "ToolMacros",
  type: "ActionMacro"
)

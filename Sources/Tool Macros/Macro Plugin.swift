import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main struct ClaudeMacroPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    ToolMacro.self,
    ActionMacro.self,
    ToolInputMacro.self
  ]
}

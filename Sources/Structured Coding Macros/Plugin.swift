import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main struct ClaudeMacroPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    StructuredCodableMacro.self,
    StructuredActionMacro.self,
    StructuredToolMacro.self,
    StructuredPropertyMacro.self,
    StructuredCaseMacro.self,
    APICodableMacro.self,
    ToolInputMacro.self,
  ]
}

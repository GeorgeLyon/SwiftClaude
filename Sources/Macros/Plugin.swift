import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main struct ClaudeMacroPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    SchemaCodableMacro.self,
    SchemaParametersMacro.self,
    APICodableMacro.self,
    ToolInputMacro.self,
    // ToolMacro.self,
  ]
}

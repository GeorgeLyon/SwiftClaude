import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main struct ClaudeMacroPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    StructuredCodableMacro.self,
    SchemaCallableMacro.self,
    StructuredPropertyMacro.self,
    StructuredCaseMacro.self,
    APICodableMacro.self,
    ToolInputMacro.self,
    // ToolMacro.self,
  ]
}

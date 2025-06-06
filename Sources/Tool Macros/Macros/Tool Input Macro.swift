import MacrosSupport
import SchemaCodingMacrosSupport
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct ToolInputMacro: ExtensionMacro {

  static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    try DiagnosticError.diagnose(in: context) {
      [
        try .schemaCodableConformance(
          for: declaration,
          of: type,
          schemaCodableNamespace: "ToolInput",
          in: context
        )
      ]
    }
  }

}

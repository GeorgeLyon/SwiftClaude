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
    do {
      return try [
        .toolInputConformance(for: declaration, of: type)
      ]
    } catch let error as DiagnosticError {
      context.diagnose(error.diagnostic)
      return []
    }
  }

}

extension ExtensionDeclSyntax {

  static func toolInputConformance(
    for declaration: some DeclGroupSyntax,
    of type: some TypeSyntaxProtocol
  ) throws -> ExtensionDeclSyntax {
    let memberModifiers = declaration.accessModifiersForRequiredMembers

    return try ExtensionDeclSyntax(
      extendedType: type,
      inheritanceClause: InheritanceClauseSyntax {
        InheritedTypeSyntax(
          type: MemberTypeSyntax(
            baseType: IdentifierTypeSyntax(name: .identifier("ToolInput")),
            name: .identifier("SchemaCodable")
          )
        )
      }
    ) {
      if let structDecl = declaration.as(StructDeclSyntax.self) {
        try structDecl.toolInputMembers
      } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
        try ToolInputEnumMembers(
          modifiers: memberModifiers,
          forExtensionOf: enumDecl
        ).block
      } else {
        throw DiagnosticError(
          node: declaration,
          severity: .error,
          message: "Unsupported declaration of kind: \(declaration.kind)"
        )
      }
    }
  }

}

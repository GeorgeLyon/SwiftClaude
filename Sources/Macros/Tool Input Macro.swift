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

    let extensionMembers: MemberBlockItemListSyntax
    if let structDecl = declaration.as(StructDeclSyntax.self) {
      extensionMembers = try ToolInputStructMembers(
        modifiers: memberModifiers,
        forExtensionOf: structDecl
      ).block
    } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
      extensionMembers = try ToolInputEnumMembers(
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

    return try ExtensionDeclSyntax("extension \(type.trimmed): Claude.ToolInput") {
      extensionMembers
    }
  }

}

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// A variant of `SchemaCodableMacro` that selects defaults appropriate for interacting with Anthropic's API.
/// Specifically, we convert keys to snake case and use internally-tagged enums.
struct APICodableMacro: ExtensionMacro {

  static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    try DiagnosticError.diagnose(in: context) {
      let members =
        if let structDecl = declaration.as(StructDeclSyntax.self) {
          try structDecl.schemaCodableMembers(
            schemaCodingNamespace: "APICodable",
            codingKeyConversionFunction: { String.convertToSnakeCase($0) },
            in: context
          )
        } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
          enumDecl.schemaCodableMembers(
            schemaCodingNamespace: "APICodable",
            enumSchemaFunctionName: "internallyTaggedEnumSchema",
            enumAssociatedValueSchemaFunctionName: "enumCaseAssociatedValuesSchema",
            discriminatorPropertyName: StringLiteralExprSyntax(content: "type"),
            codingKeyConversionFunction: { String.convertToSnakeCase($0) },
            in: context
          )
        } else {
          throw DiagnosticError(
            node: node,
            severity: .error,
            message: "Unsupported declaration of kind: \(node.kind)"
          )
        }
      return [
        .schemaCodableConformance(
          for: declaration,
          of: type,
          schemaCodingNamespace: "APICodable",
          members: members,
          in: context
        )
      ]
    }
  }

}

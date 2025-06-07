import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct SchemaCodableMacro: ExtensionMacro {

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
          schemaCodingNamespace: "SchemaCoding",
          in: context
        )
      ]
    }
  }

}

struct InternallyTaggedEnumSchemaCodableMacro: ExtensionMacro {

  static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    try DiagnosticError.diagnose(in: context) {
      guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
        throw DiagnosticError(
          node: declaration,
          severity: .error,
          message:
            "Using `discriminatorPropertyName` with `@SchemaCodable` macro is only valid for enum declarations.",
        )
      }
      guard
        case .argumentList(let arguments)? = node.arguments,
        let argument = arguments.first(
          where: {
            $0.label == "discriminatorPropertyName"
          }
        ),
        let literal = argument.expression.as(StringLiteralExprSyntax.self)
      else {
        throw DiagnosticError(
          node: node,
          severity: .error,
          message:
            "`discriminatorPropertyName` must be a string literal",
        )
      }
      return [
        .schemaCodableConformance(
          for: declaration,
          of: type,
          schemaCodingNamespace: "SchemaSupport",
          members: enumDecl.schemaCodableMembers(
            schemaCodingNamespace: "SchemaSupport",
            enumSchemaFunctionName: "internallyTaggedEnumSchema",
            enumAssociatedValueSchemaFunctionName: "internallyTaggedEnumCaseSchema",
            discriminatorPropertyName: literal,
            in: context
          ),
          in: context
        )
      ]
    }
  }

}

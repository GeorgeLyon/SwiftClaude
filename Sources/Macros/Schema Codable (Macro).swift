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
          codingKeyConversionFunction: node.codingKeyConversionFunction,
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
            $0.label?.identifier?.name == "discriminatorPropertyName"
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
          schemaCodingNamespace: "SchemaCoding",
          members: enumDecl.schemaCodableMembers(
            schemaCodingNamespace: "SchemaCoding",
            enumSchemaFunctionName: "internallyTaggedEnumSchema",
            enumAssociatedValueSchemaFunctionName: "internallyTaggedEnumCaseSchema",
            discriminatorPropertyName: literal,
            codingKeyConversionFunction: try node.codingKeyConversionFunction,
            in: context
          ),
          in: context
        )
      ]
    }
  }

}

// MARK: - Implementation Details

extension AttributeSyntax {

  var codingKeyConversionFunction: (String) -> String {
    get throws {
      if case .argumentList(let arguments)? = arguments,
        let argument = arguments.first(
          where: {
            $0.label?.identifier?.name == "codingKeyConversionStrategy"
          }
        ),
        let memberAccess = argument.expression.as(MemberAccessExprSyntax.self)
      {
        let identifier = memberAccess.declName.baseName.identifier?.name
        switch identifier {
        case "convertToSnakeCase":
          return { String.convertToSnakeCase($0) }
        case "none", nil:
          return { $0 }
        default:
          throw DiagnosticError(
            node: self,
            severity: .error,
            message: "Unknown coding key conversion strategy: \(identifier ?? "<none>")")
        }
      } else {
        return { $0 }
      }
    }
  }

}

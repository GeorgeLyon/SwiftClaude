import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum SchemaCallableMacro: PeerMacro {

  static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
      throw DiagnosticError(
        node: declaration,
        severity: .error,
        message: "@SchemaCallable can only be applied to functions"
      )
    }

    // Parse arguments from the attribute
    let arguments: LabeledExprListSyntax
    switch node.arguments {
    case .argumentList(let argumentList):
      arguments = argumentList
    case .none:
      arguments = []
    default:
      context.diagnose(
        DiagnosticError(
          node: node,
          severity: .error,
          message: "Expected argument list"
        )
      )
      arguments = []
    }

    let (description, keyConversionStrategy) = arguments.parse(
      ofAttribute: "SchemaCallable",
      as: (DescriptionArgument.self, KeyConversionStrategyArgument.self),
      in: context
    )

    let additionalArguments: LabeledExprListSyntax = .fromArguments(description)

    let namespace: StructuredCodingNamespace = "SchemaCoding"

    let callable = funcDecl.callableSchema(
      namespace: namespace,
      additionalArguments: additionalArguments,
      keyConversionStrategy: keyConversionStrategy?.value ?? .none,
      in: context
    )

    return [DeclSyntax(callable.sidecarFunction())]
  }

}

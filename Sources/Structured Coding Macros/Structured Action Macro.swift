import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum StructuredActionMacro: PeerMacro {

  static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
      context.diagnose(
        DiagnosticError(
          node: declaration,
          severity: .error,
          message: "@StructuredAction can only be applied to functions"
        )
      )
      return []
    }

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

    let (description, inputDescription, outputDescription, keyConversionStrategy) =
      arguments.parse(
        ofAttribute: "StructuredAction",
        as: (
          DescriptionArgument.self, InputDescriptionArgument.self,
          OutputDescriptionArgument.self, KeyConversionStrategyArgument.self
        ),
        in: context
      )

    guard
      let callable = funcDecl.callableSchema(
        namespace: "StructuredCoding",
        description: description?.expression,
        inputDescription: inputDescription?.expression,
        outputDescription: outputDescription?.expression,
        keyConversionStrategy: keyConversionStrategy?.value ?? .none,
        in: context
      )
    else {
      return []
    }

    return callable.peerDeclarations()
  }

}

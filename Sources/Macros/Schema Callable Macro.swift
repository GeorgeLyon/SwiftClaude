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

    let namespace: SchemaCodingNamespace = "SchemaCoding"

    let callable = funcDecl.callableSchema(
      namespace: namespace,
      in: context
    )

    return [DeclSyntax(callable.sidecarFunction())]
  }

}

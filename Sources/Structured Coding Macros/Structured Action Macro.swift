import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// A marker: it generates nothing — its job is validating that actions are
/// declared directly in a `@StructuredTool` type's body, context the tool
/// macro cannot see.
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
    let name = funcDecl.name

    guard let innermost = context.lexicalContext.first else {
      context.diagnose(
        DiagnosticError(
          node: name,
          severity: .error,
          message:
            "@StructuredAction cannot be applied to top-level functions; actions must be members of a @StructuredTool type"
        )
      )
      return []
    }
    guard innermost.asProtocol(DeclGroupSyntax.self) != nil else {
      context.diagnose(
        DiagnosticError(
          node: name,
          severity: .error,
          message: "@StructuredAction cannot be applied to local functions"
        )
      )
      return []
    }
    guard !innermost.is(ProtocolDeclSyntax.self) else {
      context.diagnose(
        DiagnosticError(
          node: name,
          severity: .error,
          message: "@StructuredAction cannot be applied to protocol requirements"
        )
      )
      return []
    }
    /// An extension names its type but reveals nothing else about it — in
    /// particular whether it is an actor, which decides the generated glue's
    /// isolation. Requiring actions in the type's body keeps that decision
    /// decidable, and keeps `@StructuredTool`'s member scan complete: it
    /// cannot see extensions either.
    guard !innermost.is(ExtensionDeclSyntax.self) else {
      context.diagnose(
        DiagnosticError(
          node: name,
          severity: .error,
          message:
            "@StructuredAction cannot be applied to functions in extensions; declare actions in the type's body"
        )
      )
      return []
    }
    /// A marker on a type `@StructuredTool` never visits would silently do
    /// nothing.
    if let attributed = innermost.asProtocol(WithAttributesSyntax.self),
      !attributed.attributes.hasAttribute("StructuredTool")
    {
      context.diagnose(
        DiagnosticError(
          node: name,
          severity: .error,
          message: "@StructuredAction requires the enclosing type to be marked @StructuredTool"
        )
      )
    }
    return []
  }

}

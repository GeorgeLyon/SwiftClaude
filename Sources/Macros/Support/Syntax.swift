import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension DeclModifierListSyntax {

  static var `public`: Self {
    DeclModifierListSyntax {
      DeclModifierSyntax(name: .keyword(.public))
    }
  }

  static var `private`: Self {
    DeclModifierListSyntax {
      DeclModifierSyntax(name: .keyword(.private))
    }
  }

}

extension DeclModifierSyntax {

  var isPublic: Bool {
    name.tokenKind == .keyword(.public)
  }

  var isStatic: Bool {
    name.tokenKind == .keyword(.static)
  }

}

extension TokenSyntax {

  var identifierOrText: String {
    identifier?.name ?? text
  }

}

extension AttributeListSyntax {

  func attribute(
    _ type: TypeSyntax,
    in context: MacroExpansionContext
  ) -> AttributeSyntax? {
    let attributes = compactMap { attribute in
      switch attribute {
      case .attribute(let attribute):
        return attribute
      case .ifConfigDecl:
        context.diagnose(
          DiagnosticError(
            node: attribute,
            severity: .error,
            message: "`ifConfigDecl` not supported"
          )
        )
        return nil
      }
    }

    guard let attribute = attributes.first else {
      return nil
    }

    if let attribute = attributes.dropFirst().first {
      context.diagnose(
        DiagnosticError(
          node: attribute,
          severity: .error,
          message: "Multiple attributes of type `\(type)`"
        )
      )
      return nil
    } else {
      return attribute
    }

  }

}

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

  func hasAttribute(_ name: String) -> Bool {
    contains { element in
      guard case .attribute(let attribute) = element else {
        return false
      }
      guard let identifier = attribute.attributeName.as(IdentifierTypeSyntax.self) else {
        return false
      }
      return identifier.name.text == name
    }
  }

}

extension VariableDeclSyntax {

  func hasAttribute(_ name: String) -> Bool {
    attributes.hasAttribute(name)
  }

}

extension EnumCaseDeclSyntax {

  func hasAttribute(_ name: String) -> Bool {
    attributes.hasAttribute(name)
  }

}

extension ExprSyntax {

  var inferredLiteralType: TypeSyntax? {
    if self.is(StringLiteralExprSyntax.self) {
      return "String"
    } else if self.is(IntegerLiteralExprSyntax.self) {
      return "Int"
    } else {
      return nil
    }
  }

}

import SwiftSyntax

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
    name == .keyword(.public)
  }

}

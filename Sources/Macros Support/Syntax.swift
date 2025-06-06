public import SwiftSyntax

extension DeclModifierListSyntax {

  public static var `public`: Self {
    DeclModifierListSyntax {
      DeclModifierSyntax(name: .keyword(.public))
    }
  }

  public static var `private`: Self {
    DeclModifierListSyntax {
      DeclModifierSyntax(name: .keyword(.private))
    }
  }

}

extension DeclModifierSyntax {

  public var isPublic: Bool {
    name == .keyword(.public)
  }

}

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct SchemaCodingNamespace: ExpressibleByStringLiteral {

  func member(name memberName: TokenSyntax) -> some ExprSyntaxProtocol {
    MemberAccessExprSyntax(
      base: DeclReferenceExprSyntax(
        baseName: name
      ),
      name: memberName
    )
  }

  func memberType(
    name memberName: TokenSyntax,
    genericArgumentClause: GenericArgumentClauseSyntax? = nil
  ) -> some TypeSyntaxProtocol {
    MemberTypeSyntax(
      baseType: IdentifierTypeSyntax(
        name: name
      ),
      name: memberName,
      genericArgumentClause: genericArgumentClause
    )
  }

  func supportMember(name memberName: TokenSyntax) -> some ExprSyntaxProtocol {
    MemberAccessExprSyntax(
      base: member(name: "Support"),
      name: memberName
    )
  }

  func supportMemberType(
    name memberName: TokenSyntax,
    genericArgumentClause: GenericArgumentClauseSyntax? = nil
  ) -> some TypeSyntaxProtocol {
    MemberTypeSyntax(
      baseType: memberType(name: "Support"),
      name: memberName,
      genericArgumentClause: genericArgumentClause
    )
  }

  init(stringLiteral value: StringLiteralType) {
    name = TokenSyntax(stringLiteral: value)
  }

  private let name: TokenSyntax

}

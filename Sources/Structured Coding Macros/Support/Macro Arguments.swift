import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

protocol ParsableArgument {
  static var label: TokenSyntax { get }
  static var defaultValue: Self? { get }
  init?(_ expression: ExprSyntax, in context: MacroExpansionContext)

  associatedtype Expr: ExprSyntaxProtocol
  var expression: Expr { get }
}

extension ParsableArgument {
  static var defaultValue: Self? { nil }

  func labeledExpr(trailingComma: TokenSyntax? = nil) -> LabeledExprSyntax {
    LabeledExprSyntax(
      label: Self.label,
      colon: .colonToken(),
      expression: expression,
      trailingComma: trailingComma
    )
  }
}

protocol InferredBaseMemberAccessExprArgument: ParsableArgument, RawRepresentable
where RawValue == String {
}

extension InferredBaseMemberAccessExprArgument {
  init?(_ expression: ExprSyntax, in context: MacroExpansionContext) {
    guard
      let memberAccessExpr = expression.as(MemberAccessExprSyntax.self),
      memberAccessExpr.base == nil,
      memberAccessExpr.declName.argumentNames == nil
    else {
      context.diagnose(
        DiagnosticError(
          node: expression,
          severity: .error,
          message: "Expected expression of the form \\.<member>"
        )
      )
      return nil
    }

    let rawValue = memberAccessExpr.declName.baseName.trimmed.text
    guard
      let value = Self(rawValue: rawValue)
    else {
      context.diagnose(
        DiagnosticError(
          node: expression,
          severity: .error,
          message: "Unknown value: \(rawValue)"
        )
      )
      return nil
    }
    self = value
  }

  var expression: MemberAccessExprSyntax {
    MemberAccessExprSyntax(
      declName: DeclReferenceExprSyntax(baseName: "\(raw: rawValue)")
    )
  }
}

extension VariableDeclSyntax {

  func parseArguments<each T: ParsableArgument>(
    ofAttribute attribute: TypeSyntax,
    as argumentTypes: (repeat (each T).Type),
    in context: MacroExpansionContext
  ) -> (repeat (each T)?) {
    attributes.parseArguments(
      ofAttribute: attribute,
      as: (repeat each argumentTypes),
      in: context
    )
  }

}

extension EnumCaseDeclSyntax {

  func parseArguments<each T: ParsableArgument>(
    ofAttribute attribute: TypeSyntax,
    as argumentTypes: (repeat (each T).Type),
    in context: MacroExpansionContext
  ) -> (repeat (each T)?) {
    attributes.parseArguments(
      ofAttribute: attribute,
      as: (repeat each argumentTypes),
      in: context
    )
  }

}

extension DeclGroupSyntax {

  func parseArguments<each T: ParsableArgument>(
    ofAttribute attribute: TypeSyntax,
    as argumentTypes: (repeat (each T).Type),
    in context: MacroExpansionContext
  ) -> (repeat (each T)?) {
    attributes.parseArguments(
      ofAttribute: attribute,
      as: (repeat each argumentTypes),
      in: context
    )
  }

}

extension AttributeListSyntax {

  func parseArguments<each T: ParsableArgument>(
    ofAttribute attribute: TypeSyntax,
    as argumentTypes: (repeat (each T).Type),
    in context: MacroExpansionContext
  ) -> (repeat (each T)?) {
    var arguments: LabeledExprListSyntax
    switch self.attribute(attribute, in: context)?.arguments {
    case .argumentList(let argumentList):
      arguments = argumentList
    case .none:
      arguments = []
    default:
      context.diagnose(
        DiagnosticError(
          node: self,
          severity: .error,
          message: "Expected argument list"
        )
      )
      arguments = []
    }

    return arguments.parse(
      ofAttribute: attribute,
      as: (repeat each argumentTypes),
      in: context
    )
  }

}

extension LabeledExprListSyntax {

  func parse<each T: ParsableArgument>(
    ofAttribute attribute: TypeSyntax,
    as argumentTypes: (repeat (each T).Type),
    in context: MacroExpansionContext
  ) -> (repeat (each T)?) {
    var mutableSelf = self
    func parseArgument<U: ParsableArgument>(
      _ argumentType: U.Type
    ) -> U? {
      guard
        let argumentIndex =
          mutableSelf
          .firstIndex(where: { $0.label?.trimmed.text == argumentType.label.text })
      else {
        return argumentType.defaultValue
      }
      return U(mutableSelf.remove(at: argumentIndex).expression, in: context)
    }

    let parsed = (repeat parseArgument(each argumentTypes))
    if !mutableSelf.isEmpty {
      context.diagnose(
        DiagnosticError(
          node: self,
          severity: .error,
          message:
            "Unexpected arguments: \(mutableSelf.map(\.label?.trimmed.text).compactMap { $0 }.joined(separator: ", "))"
        )
      )
    }
    return parsed
  }

}

extension LabeledExprListSyntax {

  @LabeledExprListBuilder
  static func fromArguments<each T: ParsableArgument>(
    _ parsedArguments: (repeat (each T)?)
  ) -> LabeledExprListSyntax {
    for parsedArgument in repeat each parsedArguments {
      if let parsedArgument {
        parsedArgument.labeledExpr(
          trailingComma: .commaToken(trailingTrivia: .newline)
        )
      }
    }
  }

}

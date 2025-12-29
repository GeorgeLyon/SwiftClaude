import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct DescriptionArgument: ParsableArgument {
  static let label: TokenSyntax = "description"
  init?(_ expression: ExprSyntax, in context: MacroExpansionContext) {
    guard let expression = expression.as(StringLiteralExprSyntax.self) else {
      context.diagnose(
        DiagnosticError(
          node: expression,
          severity: .error,
          message: "Expected string literal"
        )
      )
      return nil
    }
    self.expression = expression
  }
  let expression: StringLiteralExprSyntax
}

enum KeyConversionStrategyArgument: String, InferredBaseMemberAccessExprArgument {
  static let label: TokenSyntax = "keyConversionStrategy"
  case convertToSnakeCase
  case none

  var value: KeyConversionStrategy {
    switch self {
    case .convertToSnakeCase:
      return .convertToSnakeCase
    case .none:
      return .none
    }
  }
}

enum EnumStyleArgument: ParsableArgument {
  static let label: TokenSyntax = "style"
  case object
  case internallyTagged(discriminatorPropertyName: StringLiteralExprSyntax)

  init?(_ expression: ExprSyntax, in context: any MacroExpansionContext) {
    if let memberAccessExpr = expression.as(MemberAccessExprSyntax.self),
      memberAccessExpr.base == nil,
      memberAccessExpr.declName.argumentNames == nil
    {
      let rawValue = memberAccessExpr.declName.baseName.trimmed
      switch rawValue {
      case "object":
        self = .object
      default:
        context.diagnose(
          DiagnosticError(
            node: memberAccessExpr.declName,
            severity: .error,
            message: "Unknown style: \(rawValue)"
          )
        )
        return nil
      }
    } else if let functionCallExpr = expression.as(FunctionCallExprSyntax.self) {
      let calledExpression = functionCallExpr.calledExpression
      guard
        let memberAccessExpr = calledExpression.as(MemberAccessExprSyntax.self),
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
      let rawValue = memberAccessExpr.declName.baseName.trimmed
      switch rawValue.text {
      case "internallyTagged":
        let arguments = functionCallExpr.arguments
        guard
          let argument = arguments.first,
          arguments.count == 1,
          let discriminatorPropertyName = argument.expression.as(StringLiteralExprSyntax.self)
        else {
          context.diagnose(
            DiagnosticError(
              node: arguments,
              severity: .error,
              message:
                "`internallyTagged` expects exactly one string argument with no interpolations."
            )
          )
          return nil
        }
        self = .internallyTagged(discriminatorPropertyName: discriminatorPropertyName)
      default:
        context.diagnose(
          DiagnosticError(
            node: memberAccessExpr.declName,
            severity: .error,
            message: "Unknown style: \(rawValue)"
          )
        )
        return nil
      }
    } else {
      context.diagnose(
        DiagnosticError(
          node: expression,
          severity: .error,
          message: "Expected expression of the form \\.<member> or <function>(<argument>)"
        )
      )
      return nil
    }
  }

  var expression: ExprSyntax {
    switch self {
    case .object:
      ExprSyntax(MemberAccessExprSyntax(name: "object"))
    case .internallyTagged(let discriminatorPropertyName):
      ExprSyntax(
        FunctionCallExprSyntax(
          calledExpression: MemberAccessExprSyntax(
            name: "internallyTagged"
          ),
          leftParen: .leftParenToken(trailingTrivia: .newline),
          arguments: LabeledExprListSyntax {
            LabeledExprSyntax(
              label: "discriminatorPropertyName",
              colon: .colonToken(),
              expression: discriminatorPropertyName
            )
          },
          rightParen: .rightParenToken(leadingTrivia: .newline)
        )
      )
    }
  }
}

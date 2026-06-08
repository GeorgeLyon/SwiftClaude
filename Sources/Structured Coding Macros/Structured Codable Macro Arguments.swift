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

/// `compatibilityMode: .variadicGenerics`, `[.variadicGenerics]`, or `[]` —
/// an option-set literal built from inferred-base member accesses.
struct CompatibilityModeArgument: ParsableArgument {
  static let label: TokenSyntax = "compatibilityMode"

  init?(_ expression: ExprSyntax, in context: MacroExpansionContext) {
    let elements: [ExprSyntax]
    if let arrayExpr = expression.as(ArrayExprSyntax.self) {
      elements = arrayExpr.elements.map(\.expression)
    } else {
      elements = [expression]
    }

    var modes: CompatibilityModes = []
    for element in elements {
      guard
        let memberAccessExpr = element.as(MemberAccessExprSyntax.self),
        memberAccessExpr.base == nil,
        memberAccessExpr.declName.argumentNames == nil
      else {
        context.diagnose(
          DiagnosticError(
            node: element,
            severity: .error,
            message: "Expected expression of the form .<member> or [.<member>, …]"
          )
        )
        return nil
      }
      let rawValue = memberAccessExpr.declName.baseName.trimmed
      switch rawValue.text {
      case "variadicGenerics":
        modes.insert(.variadicGenerics)
      case "omitSchema":
        modes.insert(.omitSchema)
      default:
        context.diagnose(
          DiagnosticError(
            node: memberAccessExpr.declName,
            severity: .error,
            message: "Unknown compatibility mode: \(rawValue)"
          )
        )
        return nil
      }
    }
    self.modes = modes
  }

  let modes: CompatibilityModes

  var expression: ArrayExprSyntax {
    ArrayExprSyntax {
      if modes.contains(.variadicGenerics) {
        ArrayElementSyntax(
          expression: MemberAccessExprSyntax(name: "variadicGenerics")
        )
      }
      if modes.contains(.omitSchema) {
        ArrayElementSyntax(
          expression: MemberAccessExprSyntax(name: "omitSchema")
        )
      }
    }
  }
}

enum StructStyleArgument: String, InferredBaseMemberAccessExprArgument {
  static let label: TokenSyntax = "style"
  case standard
  case wrapper
}

enum EnumStyleArgument: ParsableArgument {
  static let label: TokenSyntax = "style"
  case objectProperties
  case internallyTagged(discriminatorPropertyName: StringLiteralExprSyntax)
  case typeDiscriminated

  init?(_ expression: ExprSyntax, in context: any MacroExpansionContext) {
    if let memberAccessExpr = expression.as(MemberAccessExprSyntax.self),
      memberAccessExpr.base == nil,
      memberAccessExpr.declName.argumentNames == nil
    {
      let rawValue = memberAccessExpr.declName.baseName.trimmed
      switch rawValue.text {
      case "objectProperties":
        self = .objectProperties
      case "typeDiscriminated":
        self = .typeDiscriminated
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
    case .objectProperties:
      ExprSyntax(MemberAccessExprSyntax(name: "objectProperties"))
    case .typeDiscriminated:
      ExprSyntax(MemberAccessExprSyntax(name: "typeDiscriminated"))
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

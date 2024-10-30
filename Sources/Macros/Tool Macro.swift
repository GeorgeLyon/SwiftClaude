import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct ToolMacro: ExtensionMacro {

  static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    do {
      let toolName: any ExprSyntaxProtocol
      do {
        let segments: StringLiteralSegmentListSyntax
        if case .argumentList(let arguments) = node.arguments,
          let first = arguments.first
        {
          toolName = first.expression
        } else {
          /// `"\(Self.self)"`
          toolName = StringLiteralExprSyntax.init(
            openingQuote: .stringQuoteToken(),
            segments: StringLiteralSegmentsSyntax {
              StringSegmentSyntax(content: .stringSegment(""))
              ExpressionSegmentSyntax(
                expressions: LabeledExprListSyntax {
                  LabeledExprSyntax(
                    expression: MemberAccessExprSyntax(
                      base: DeclReferenceExprSyntax(baseName: "Self"),
                      declName: DeclReferenceExprSyntax(baseName: "self")
                    )
                  )
                }
              )
              StringSegmentSyntax(content: .stringSegment(""))
            },
            closingQuote: .stringQuoteToken()
          )
        }
      }

      let functionName = "invoke"

      let functions = declaration.memberBlock.members
        .lazy
        .compactMap { $0.decl.as(FunctionDeclSyntax.self) }
        .filter { $0.name.text == functionName }

      guard let function = functions.first else {
        throw DiagnosticError(
          node: declaration,
          severity: .error,
          message: "The `@Tool` macro requires a single `\(functionName)` function to be defined."
        )
      }

      guard functions.count == 1 else {
        throw DiagnosticError(
          node: functions.dropFirst().first!,
          severity: .error,
          message: "The `@Tool` macro requires a single `\(functionName)` function to be defined."
        )
      }

      let docComment = function.leadingTrivia
        .compactMap { trivia in
          switch trivia {
          case let .docLineComment(comment):
            return comment.trimmingPrefix("///")
          case let .docBlockComment(comment):
            var body = comment.trimmingPrefix("/**")
            guard body.hasSuffix("*/") else {
              assertionFailure()
              return body
            }
            body.removeLast("*/".count)
            return body
          default:
            return nil
          }
        }
        .joined(separator: "\n")

      let modifiers = declaration.accessModifiersForRequiredMembers

      var toolInputMembers = ToolInputStructMembers(modifiers: modifiers)
      var invokeFunctionArguments = LabeledExprListSyntax()
      var toolInputStoredProperties = MemberBlockItemListSyntax()

      let invokeFunctionIsAsync =
        function.signature.effectSpecifiers?.asyncSpecifier?.tokenKind == .keyword(.async)

      for parameter in function.signature.parameterClause.parameters {

        /// Get the parameter's raw name, which may be a raw identifier like (one surrounded by backticks
        let possiblyRawName: TokenSyntax
        do {
          let parameterName = parameter.secondName ?? parameter.firstName
          switch parameterName.tokenKind {
          case .identifier:
            possiblyRawName = parameterName.trimmed
          case .wildcard:
            throw DiagnosticError(
              node: parameterName,
              message: DiagnosticMessage(
                severity: .error,
                message:
                  "The `@Tool` macro requires all parameters in the `\(functionName)` function have names"
              )
            )
          default:
            throw DiagnosticError(
              node: parameterName,
              message: DiagnosticMessage(
                severity: .error,
                message: "The `@Tool` does not support \(parameterName) as a parameter name"
              )
            )
          }
        }

        let kind: InvokeFunctionParameterKind

        /// Detect parameter kind
        if let type = parameter.type.as(AttributedTypeSyntax.self),
          type.specifiers.contains(where: \.isIsolated)
        {
          kind = .isolation
        } else {
          kind = .input
        }

        /// Unwrap raw identifiers
        let name: TokenSyntax
        do {
          if let string = possiblyRawName.identifier?.name,
            string.hasPrefix("`"),
            string.hasSuffix("`")
          {
            name = .identifier(String(string.dropFirst().dropLast()))
          } else {
            name = possiblyRawName
          }
        }

        /// For input parameters, add it to the generated `ToolInput` type
        if kind == .input {
          toolInputMembers.appendStoredProperty(name: name, type: parameter.type)
          toolInputStoredProperties.append(
            MemberBlockItemSyntax(
              decl: VariableDeclSyntax(
                bindingSpecifier: .keyword(.let),
                bindings: PatternBindingListSyntax {
                  PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: name),
                    typeAnnotation: TypeAnnotationSyntax(type: parameter.type)
                  )
                }
              )
            )
          )
        }

        /// `invoke(…)` arguments
        invokeFunctionArguments.append(prependingCommaIfNeeded: true) {
          let expression: any ExprSyntaxProtocol =
            switch kind {
            case .input:
              MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: "input"),
                name: name
              )
            case .isolation:
              DeclReferenceExprSyntax(baseName: name)
            }
          switch parameter.firstName.tokenKind {
          case .wildcard:
            LabeledExprSyntax(expression: expression)
          default:
            LabeledExprSyntax(
              label: parameter.firstName,
              colon: .colonToken(),
              expression: expression
            )
          }
        }
      }

      let invokeSingature: FunctionSignatureSyntax
      do {
        /// Detect `Output` type

        let outputType: any TypeSyntaxProtocol
        if let returnsClause = function.signature.returnClause {
          outputType = returnsClause.type.trimmed
        } else {
          outputType = IdentifierTypeSyntax(name: "Void")
        }

        /// Keep singature the same, but replace parameters with `ToolInput`
        var signature = function.signature
        signature.parameterClause = FunctionParameterClauseSyntax {
          FunctionParameterSyntax(
            firstName: "with",
            secondName: "input",
            type: IdentifierTypeSyntax(name: "Input"),
            trailingComma: .commaToken()
          )
          FunctionParameterSyntax(
            firstName: "in",
            secondName: "context",
            type: MemberTypeSyntax(
              baseType: IdentifierTypeSyntax(name: "Claude"),
              name: "ToolInvocationContext",
              genericArgumentClause: GenericArgumentClauseSyntax {
                GenericArgumentSyntax(
                  argument: IdentifierTypeSyntax(name: "Self")
                )
              }
            )
          )
          FunctionParameterSyntax(
            firstName: "isolation",
            type: AttributedTypeSyntax(
              specifiers: TypeSpecifierListSyntax {
                SimpleTypeSpecifierSyntax(
                  specifier: .keyword(SwiftSyntax.Keyword.isolated)
                )
              },
              baseType: IdentifierTypeSyntax(name: "Actor")
            )
          )
        }

        /// The wrapped invoke function is always `async`
        if var effectSpecifiers = signature.effectSpecifiers {
          effectSpecifiers.asyncSpecifier = .keyword(.async)
          signature.effectSpecifiers = effectSpecifiers
        } else {
          signature.effectSpecifiers = FunctionEffectSpecifiersSyntax(
            asyncSpecifier: .keyword(.async)
          )
        }

        invokeSingature = signature
      }

      /// Create the function call expression
      let functionCall: any ExprSyntaxProtocol
      do {
        let functionCallWithoutEffectSpecifiers = FunctionCallExprSyntax(
          calledExpression: DeclReferenceExprSyntax(baseName: function.name),
          leftParen: .leftParenToken(),
          arguments: invokeFunctionArguments,
          rightParen: .rightParenToken()
        )
        let effectSpecifiers = function.signature.effectSpecifiers
        let invokeFunctionThrows =
          effectSpecifiers?.throwsClause?.throwsSpecifier.tokenKind == .keyword(.throws)
        if invokeFunctionIsAsync, invokeFunctionThrows {
          functionCall = TryExprSyntax(
            expression: AwaitExprSyntax(expression: functionCallWithoutEffectSpecifiers))
        } else if invokeFunctionIsAsync {
          functionCall = AwaitExprSyntax(expression: functionCallWithoutEffectSpecifiers)
        } else if invokeFunctionThrows {
          functionCall = TryExprSyntax(expression: functionCallWithoutEffectSpecifiers)
        } else {
          functionCall = functionCallWithoutEffectSpecifiers
        }
      }

      return [
        ExtensionDeclSyntax(
          extendedType: type,
          inheritanceClause: InheritanceClauseSyntax {
            for `protocol` in protocols {
              InheritedTypeSyntax(type: `protocol`)
            }
          },
          memberBlock: MemberBlockSyntax {

            /// `var toolDefinition: Claude.ToolDefinition { … }`
            VariableDeclSyntax(
              modifiers: modifiers,
              bindingSpecifier: .keyword(.var),
              bindingsBuilder: {
                PatternBindingSyntax(
                  pattern: IdentifierPatternSyntax(identifier: "definition"),
                  typeAnnotation: TypeAnnotationSyntax(
                    type: MemberTypeSyntax(
                      baseType: IdentifierTypeSyntax(name: "Claude"),
                      name: "ToolDefinition",
                      genericArgumentClause: GenericArgumentClauseSyntax {
                        GenericArgumentSyntax(
                          argument: IdentifierTypeSyntax(name: "Self")
                        )
                      }
                    )
                  ),
                  accessorBlock: AccessorBlockSyntax(
                    accessors: .getter(
                      CodeBlockItemListSyntax {
                        FunctionCallExprSyntax(
                          calledExpression: MemberAccessExprSyntax(
                            base: MemberAccessExprSyntax(
                              base: DeclReferenceExprSyntax(baseName: "Claude"),
                              name: "ToolDefinition"
                            ),
                            name: "userDefined"
                          ),
                          leftParen: .leftParenToken(),
                          arguments: LabeledExprListSyntax {
                            LabeledExprSyntax(
                              label: "tool",
                              colon: .colonToken(),
                              expression: MemberAccessExprSyntax(
                                base: DeclReferenceExprSyntax(baseName: "Self"),
                                name: "self"
                              )
                            )
                            LabeledExprSyntax(
                              label: "name",
                              colon: .colonToken(),
                              expression: toolName
                            )
                            LabeledExprSyntax(
                              label: "description",
                              colon: .colonToken(),
                              expression: StringLiteralExprSyntax(
                                openingQuote: .multilineStringQuoteToken(),
                                content: docComment,
                                closingQuote: .multilineStringQuoteToken()
                              )
                            )
                          },
                          rightParen: .rightParenToken()
                        )
                      }
                    )
                  )
                )
              }
            )

            /// `struct ToolInput: Claude.ToolInput { … }`
            StructDeclSyntax(
              modifiers: modifiers,
              name: "Input",
              inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeSyntax(
                  type: MemberTypeSyntax(
                    baseType: IdentifierTypeSyntax(name: "Claude"),
                    name: "ToolInput"
                  )
                )
              },
              memberBlock: MemberBlockSyntax {
                toolInputStoredProperties
                toolInputMembers.block
              }
            )

            /// `func invoke(with toolInput: ToolInput) { … }`
            FunctionDeclSyntax(
              modifiers: modifiers,
              name: function.name,
              signature: invokeSingature,
              body: CodeBlockSyntax {
                functionCall
              }
            )
          }
        )
      ]
    } catch let error as DiagnosticError {
      context.diagnose(error.diagnostic)
      return []
    }
  }
}

// MARK: - Implementation Details

private enum InvokeFunctionParameterKind {
  case input, isolation
}

extension TypeSpecifierListSyntax.Element {

  fileprivate var isIsolated: Bool {
    switch self {
    case .simpleTypeSpecifier(let specifier):
      return specifier.specifier.tokenKind == .keyword(.isolated)
    default:
      return false
    }
  }

  fileprivate var isInout: Bool {
    switch self {
    case .simpleTypeSpecifier(let specifier):
      return specifier.specifier.tokenKind == .keyword(.inout)
    default:
      return false
    }
  }

}

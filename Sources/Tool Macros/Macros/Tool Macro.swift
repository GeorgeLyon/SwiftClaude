import MacrosSupport
import SchemaCodingMacrosSupport
import SwiftDiagnostics
public import SwiftSyntax
import SwiftSyntaxBuilder
public import SwiftSyntaxMacros

public struct ToolMacro: ExtensionMacro {

  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    try DiagnosticError.diagnose(in: context) {
      [
        try .toolConformance(for: declaration, of: type, in: context)
      ]
    }
  }

}

// MARK: - Implementation

extension ExtensionDeclSyntax {

  fileprivate static func toolConformance(
    for declaration: some DeclGroupSyntax,
    of type: some TypeSyntaxProtocol,
    in context: MacroExpansionContext
  ) throws -> ExtensionDeclSyntax {
    return try ExtensionDeclSyntax(
      extendedType: type,
      inheritanceClause: InheritanceClauseSyntax {
        InheritedTypeSyntax(
          type: IdentifierTypeSyntax(name: "Tool")
        )
      }
    ) {
      try declaration.toolMembers(in: context)
    }
  }

}

extension DeclGroupSyntax {

  fileprivate func toolMembers(
    in context: MacroExpansionContext
  ) throws
    -> MemberBlockItemListSyntax
  {
    let toolTypeName = context.makeUniqueName("Tool")

    let isPublic = modifiers.contains(where: \.isPublic)

    let invokeFunction = try toolInvocationFunction

    let isolationParameter = FunctionParameterSyntax(
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

    let storedProperties: [StructDeclSyntax.StoredProperty] =
      try invokeFunction
      .signature
      .parameterClause
      .parameters
      .compactMap { parameter in
        guard let identifier = (parameter.secondName ?? parameter.firstName).identifier else {
          throw DiagnosticError(
            node: parameter,
            severity: .error,
            message: "All parameters must be named")
        }
        guard !parameter.type.isIsolated else {
          /// Skip the isolation parameter
          return nil
        }
        return StructDeclSyntax.StoredProperty(
          name: .identifier(identifier.name),
          type: parameter.type,
          comment: nil
        )
      }

    let inputInvocationTrampoline = FunctionDeclSyntax(
      modifiers: DeclModifierListSyntax {
        DeclModifierSyntax(name: .keyword(.fileprivate))
      },
      name: context.makeUniqueName("invoke"),
      signature: FunctionSignatureSyntax(
        parameterClause: FunctionParameterClauseSyntax(
          parameters: FunctionParameterListSyntax {
            FunctionParameterSyntax(
              firstName: "tool",
              type: IdentifierTypeSyntax(name: toolTypeName)
            )
            isolationParameter
          },
        ),
        effectSpecifiers: FunctionEffectSpecifiersSyntax(
          asyncSpecifier: .keyword(.async),
          throwsClause: invokeFunction.signature.effectSpecifiers?.throwsClause
        ),
        returnClause: ReturnClauseSyntax(
          arrow: .arrowToken(),
          type: MemberTypeSyntax(
            baseType: IdentifierTypeSyntax(name: toolTypeName),
            name: "Output"
          )
        )
      ),
      body: try CodeBlockSyntax {
        try invokeFunction.callExpr(
          on: DeclReferenceExprSyntax(baseName: "tool"),
          forceAwait: self.is(ActorDeclSyntax.self),
          arguments: storedProperties.map { property in
            MemberAccessExprSyntax(
              base: DeclReferenceExprSyntax(baseName: "self"),
              name: property.name
            )
          },
          in: context
        )
      }
    )

    return try MemberBlockItemListSyntax {
      /// `var definition: some ToolDefinition<Schema> { … }`
      toolDefinition

      /// `func invoke(with input: Input, isolation: isolated Actor)`
      FunctionDeclSyntax(
        modifiers: DeclModifierListSyntax {
          if isPublic {
            DeclModifierSyntax(name: .keyword(.public))
          }
        },
        name: "invoke",
        signature: FunctionSignatureSyntax(
          parameterClause: FunctionParameterClauseSyntax {
            FunctionParameterSyntax(
              firstName: "with",
              secondName: "input",
              type: IdentifierTypeSyntax(name: "Input")
            )
            isolationParameter
          },
          effectSpecifiers: FunctionEffectSpecifiersSyntax(
            asyncSpecifier: .keyword(.async),
            throwsClause: invokeFunction.signature.effectSpecifiers?.throwsClause
          ),
          returnClause: invokeFunction.signature.returnClause
        ),
        body: try CodeBlockSyntax {
          try inputInvocationTrampoline.callExpr(
            on: DeclReferenceExprSyntax(baseName: "input"),
            arguments: [
              DeclReferenceExprSyntax(baseName: "self")
            ],
            in: context
          )
        }
      )

      /// struct Input: SchemaCodable { … }
      StructDeclSyntax.schemaCodable(
        description: comment,
        name: "Input",
        schemaCodingNamespace: "ToolInput",
        isPublic: isPublic,
        storedProperties: storedProperties,
        additionalMembers: MemberBlockItemListSyntax {
          inputInvocationTrampoline
        },
        in: context
      )

      /// typealias `Self` so we can reference it inside of `Input` even if this is nested in a different type
      TypeAliasDeclSyntax(
        name: toolTypeName,
        initializer: TypeInitializerClauseSyntax(
          value: try selfType(in: context)
        )
      )

    }
  }

  private func selfType(
    in context: MacroExpansionContext
  ) throws -> any TypeSyntaxProtocol {
    var path =
      try [
        [declName.trimmed],
        context.lexicalContext.map { try $0.declName.trimmed },
      ].joined().reversed().makeIterator()
    var type: any TypeSyntaxProtocol = IdentifierTypeSyntax(name: path.next()!)
    while let next = path.next() {
      type = MemberTypeSyntax(
        baseType: type,
        name: next
      )
    }
    return type
  }

  private var toolDefinition: VariableDeclSyntax {
    VariableDeclSyntax(
      modifiers: DeclModifierListSyntax {
        DeclModifierSyntax(name: "nonisolated")
        if modifiers.contains(where: \.isPublic) {
          DeclModifierSyntax(name: "public")
        }
      },
      bindingSpecifier: .keyword(.var),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: "definition"),
          typeAnnotation: TypeAnnotationSyntax(
            type: SomeOrAnyTypeSyntax(
              someOrAnySpecifier: .keyword(.some),
              constraint: IdentifierTypeSyntax(
                name: "ToolDefinition",
                genericArgumentClause: GenericArgumentClauseSyntax {
                  GenericArgumentSyntax(
                    argument: IdentifierTypeSyntax(name: "Input")
                  )
                }
              )
            )
          ),
          accessorBlock: AccessorBlockSyntax(
            leftBrace: .leftBraceToken(trailingTrivia: .newline),
            accessors: .getter(
              CodeBlockItemListSyntax {
                FunctionCallExprSyntax(
                  calledExpression: DeclReferenceExprSyntax(
                    baseName: "ClientDefinedToolDefinition"),
                  leftParen: .leftParenToken(trailingTrivia: .newline),
                  arguments: LabeledExprListSyntax {
                    LabeledExprSyntax(
                      label: "name",
                      colon: .colonToken(),
                      expression: StringLiteralExprSyntax(
                        openingQuote: .stringQuoteToken(),
                        segments: StringLiteralSegmentListSyntax {
                          StringSegmentSyntax(content: .stringSegment(""))
                          ExpressionSegmentSyntax(
                            expressions: LabeledExprListSyntax {
                              LabeledExprSyntax(
                                expression: MemberAccessExprSyntax(
                                  base: DeclReferenceExprSyntax(baseName: "Self"),
                                  name: "self"
                                )
                              )
                            }
                          )
                          StringSegmentSyntax(content: .stringSegment(""))
                        },
                        closingQuote: .stringQuoteToken()
                      ),
                      trailingComma: .commaToken(trailingTrivia: .newline)
                    )
                    descriptionArgument
                    LabeledExprSyntax(
                      label: "inputSchema",
                      expression: MemberAccessExprSyntax(
                        base: DeclReferenceExprSyntax(baseName: "Input"),
                        name: "schema"
                      )
                    )
                  },
                  rightParen: .rightParenToken(leadingTrivia: .newline)
                )
              }
            ),
            rightBrace: .rightBraceToken(trailingTrivia: .newline)
          )
        )
      }
    )
  }

  private var toolInvocationFunction: FunctionDeclSyntax {
    get throws {
      let functionName = "invoke"
      let functions = memberBlock.members
        .compactMap { $0.decl.as(FunctionDeclSyntax.self) }
        .filter { $0.name.text == functionName }
      guard let function = functions.first else {
        throw DiagnosticError(
          node: self,
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
      return function
    }
  }

}

extension FunctionDeclSyntax {

  func callExpr<Argument: ExprSyntaxProtocol>(
    on callee: some ExprSyntaxProtocol,
    forceAwait: Bool = false,
    arguments: [Argument],
    in context: MacroExpansionContext
  ) throws -> some ExprSyntaxProtocol {
    let effectSpecifiers = signature.effectSpecifiers

    let isAsync =
      switch effectSpecifiers?.asyncSpecifier?.tokenKind {
      case .keyword(.async):
        true
      case .none:
        false
      case .some(let kind):
        throw DiagnosticError(
          node: self,
          severity: .error,
          message: "`\(kind)` is not supported"
        )
      }
    let isThrows =
      switch effectSpecifiers?.throwsClause?.throwsSpecifier.tokenKind {
      case .keyword(.throws):
        true
      case .none:
        false
      case .some(let kind):
        throw DiagnosticError(
          node: self,
          severity: .error,
          message: "`\(kind)` is not supported"
        )
      }

    let functionCall: FunctionCallExprSyntax
    do {
      var labeledArguments = LabeledExprListSyntax()
      var arguments = arguments.makeIterator()
      for (offset, parameter) in signature.parameterClause.parameters.enumerated() {
        let expr: ExprSyntax

        if parameter.type.isIsolated {
          expr = ExprSyntax(
            MacroExpansionExprSyntax(
              macroName: "isolation",
              arguments: LabeledExprListSyntax {

              }
            )
          )
        } else if let argument = arguments.next() {
          expr = ExprSyntax(argument)
        } else {
          let name = parameter.firstName.identifier?.name ?? "\(offset)"
          context.diagnose(
            DiagnosticError(
              node: self,
              severity: .error,
              message: "Internal Error: Missing argument for parameter `\(name)`"
            )
          )
          expr = ExprSyntax(NilLiteralExprSyntax())
        }

        let labledExpr: LabeledExprSyntax
        if let label = parameter.firstName.identifier {
          labledExpr = LabeledExprSyntax(
            label: .identifier(label.name),
            colon: .colonToken(),
            expression: expr,
            trailingComma: .commaToken(trailingTrivia: .newline)
          )
        } else {
          labledExpr = LabeledExprSyntax(
            expression: expr,
            trailingComma: .commaToken(trailingTrivia: .newline)
          )
        }
        labeledArguments.append(labledExpr)
      }
      if arguments.next() != nil {
        context.diagnose(
          DiagnosticError(
            node: self,
            severity: .error,
            message: "Internal Error: More arguments provided than parameters"
          )
        )
      }

      /// Remvoe last trailing comma
      do {
        if let lastIndex = labeledArguments.indices.last {
          labeledArguments[lastIndex].trailingComma = nil
        }
      }

      functionCall = FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: callee,
          name: name
        ),
        leftParen: .leftParenToken(trailingTrivia: .newline),
        arguments: labeledArguments,
        rightParen: .rightParenToken(leadingTrivia: .newline)
      )
    }

    return switch (forceAwait || isAsync, isThrows) {
    case (true, true):
      ExprSyntax(TryExprSyntax(expression: AwaitExprSyntax(expression: functionCall)))
    case (true, false):
      ExprSyntax(
        AwaitExprSyntax(
          expression: functionCall))
    case (false, true):
      ExprSyntax(TryExprSyntax(expression: functionCall))
    case (false, false):
      ExprSyntax(functionCall)
    }
  }

}

extension TypeSyntax {

  var isIsolated: Bool {
    guard let type = self.as(AttributedTypeSyntax.self) else {
      return false
    }
    return type.specifiers.contains { specifier in
      guard let specifier = specifier.as(SimpleTypeSpecifierSyntax.self) else {
        return false
      }
      return specifier.specifier.tokenKind == .keyword(.isolated)
    }
  }

}

extension SyntaxProtocol {

  fileprivate var declName: TokenSyntax {
    get throws {
      if let decl = self.as(ActorDeclSyntax.self) {
        decl.name
      } else if let decl = self.as(ClassDeclSyntax.self) {
        decl.name
      } else if let decl = self.as(StructDeclSyntax.self) {
        decl.name
      } else if let decl = self.as(EnumDeclSyntax.self) {
        decl.name
      } else {
        throw DiagnosticError(
          node: self,
          severity: .error,
          message: "`\(self.kind)` is not supported with the @Tool macro"
        )
      }
    }
  }

}

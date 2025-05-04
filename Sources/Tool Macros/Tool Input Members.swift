import SwiftSyntax
import SwiftSyntaxBuilder

// MARK: - Struct

struct ToolInputStructMembers: ToolInputMembers {

  var block: MemberBlockItemListSyntax {
    MemberBlockItemListSyntax {
      toolInputSchemaTypealias
      toolInputSchemaAccessor
      initializer
      toolInputSchemaDescribedValueAccessor
    }
  }

  init(
    modifiers: DeclModifierListSyntax
  ) {
    self.modifiers = modifiers
  }

  init(
    modifiers: DeclModifierListSyntax,
    forExtensionOf declaration: StructDeclSyntax
  ) throws {
    self.modifiers = modifiers

    for member in declaration.memberBlock.members {
      guard let variable = member.decl.as(VariableDeclSyntax.self) else {
        continue
      }
      guard !variable.bindings.contains(where: { $0.accessorBlock != nil }) else {
        /// This is a computed property
        continue
      }
      guard let type = variable.bindings.last?.typeAnnotation?.type else {
        throw DiagnosticError(
          node: variable,
          severity: .error,
          message: "Missing type annotation"
        )
      }

      for binding in variable.bindings {
        guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier else {
          throw DiagnosticError(
            node: binding, severity: .error, message: "Binding pattern does not have an identifier")
        }
        appendStoredProperty(name: name, type: type)
      }
    }
  }

  mutating func appendStoredProperty(name: TokenSyntax, type: TypeSyntax) {
    storedProperties.append(StoredProperty(name: name, type: type))

    appendSchemaField(name: name, type: type)

    /// `var toolInputSchemaDescribedValue: ToolInputSchema.DescribedValue { … }`
    describedValueTupleElements.append(prependingCommaIfNeeded: true) {
      LabeledExprSyntax(
        label: nil,
        expression: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: name),
          name: "toolInputSchemaDescribedValue"
        )
      )
    }
  }

  fileprivate let modifiers: DeclModifierListSyntax

  /// `init(toolInputSchemaDescribedValue value: ToolInputSchema.DescribedValue) throws { … }`
  fileprivate var initializerBody: CodeBlockItemListSyntax {
    CodeBlockItemListSyntax {
      if let property = storedProperties.first, storedProperties.count == 1 {
        /// Single-element tuples need to feel special
        "self.\(property.name) = try .init(toolInputSchemaDescribedValue: value)"
      } else {
        for (offset, storedProperty) in storedProperties.enumerated() {
          "self.\(storedProperty.name) = try .init(toolInputSchemaDescribedValue: value.\(raw: offset))"
        }
      }
    }
  }
  @CodeBlockItemListBuilder
  fileprivate var describedValueAccessorBody: CodeBlockItemListSyntax {
    TupleExprSyntax(elements: describedValueTupleElements)
  }
  fileprivate let schemaType: TokenSyntax = "ToolInputKeyedTupleSchema"
  fileprivate var schemaTypeGenericArguments = GenericArgumentListSyntax()
  fileprivate var schemaInitializerArguments = LabeledExprListSyntax()

  private struct StoredProperty {
    let name: TokenSyntax
    let type: TypeSyntax
  }
  private var storedProperties: [StoredProperty] = []
  private var describedValueTupleElements = LabeledExprListSyntax()
}

// MARK: - Enum

struct ToolInputEnumMembers: ToolInputMembers {

  var block: MemberBlockItemListSyntax {
    MemberBlockItemListSyntax {
      toolInputSchemaTypealias
      toolInputSchemaAccessor
      initializer
      toolInputSchemaDescribedValueAccessor
    }
  }

  init(
    modifiers: DeclModifierListSyntax,
    forExtensionOf declaration: EnumDeclSyntax
  ) throws {
    self.modifiers = modifiers

    let elements = declaration
      .memberBlock
      .members
      .compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }
      .flatMap(\.elements)

    for (offset, element) in elements.enumerated() {
      let parameters = element.parameterClause?.parameters ?? []

      /// `init(toolInputSchemaDescribedValue value: ToolInputSchema.DescribedValue) throws { … }`
      do {
        let binding: ExprSyntaxProtocol
        let assignment: CodeBlockItemListSyntax
        if parameters.isEmpty {
          binding = MemberAccessExprSyntax(name: "some")
          assignment = "self = .\(element.name)"
        } else {
          binding = FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(name: "some"),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax {
              LabeledExprSyntax(
                expression: PatternExprSyntax(
                  pattern: ValueBindingPatternSyntax(
                    bindingSpecifier: .keyword(.let),
                    pattern: IdentifierPatternSyntax(identifier: "value")
                  )
                )
              )
            },
            rightParen: .rightParenToken()
          )
          assignment = CodeBlockItemListSyntax {
            InfixOperatorExprSyntax(
              leftOperand: DeclReferenceExprSyntax(baseName: "self"),
              operator: AssignmentExprSyntax(),
              rightOperand: FunctionCallExprSyntax(
                calledExpression: MemberAccessExprSyntax(name: element.name),
                leftParen: .leftParenToken(),
                rightParen: .rightParenToken(),
                argumentsBuilder: {
                  if let parameter = parameters.first, parameters.count == 1 {
                    LabeledExprSyntax(
                      label: parameter.firstName,
                      colon: parameter.firstName == nil ? .none : .colonToken(),
                      expression: DeclReferenceExprSyntax(baseName: "value")
                    )
                  } else {
                    for (offset, parameter) in parameters.enumerated() {
                      LabeledExprSyntax(
                        label: parameter.firstName,
                        colon: parameter.firstName == nil ? .none : .colonToken(),
                        expression: MemberAccessExprSyntax(
                          base: DeclReferenceExprSyntax(baseName: "value"),
                          name: .integerLiteral("\(offset)")
                        )
                      )
                    }
                  }
                }
              )
            )
          }
        }

        for isFallback in [false, true] {
          initializerCases.append(
            .switchCase(
              SwitchCaseSyntax(
                label: .case(
                  SwitchCaseLabelSyntax {
                    SwitchCaseItemListSyntax {
                      SwitchCaseItemSyntax(
                        pattern: ExpressionPatternSyntax(
                          expression: TupleExprSyntax {
                            for (caseOffset, _) in elements.enumerated() {
                              let expression: ExprSyntaxProtocol =
                                if caseOffset == offset {
                                  binding
                                } else if isFallback {
                                  DiscardAssignmentExprSyntax()
                                } else {
                                  MemberAccessExprSyntax(name: "none")
                                }
                              LabeledExprSyntax(expression: expression)
                            }
                          }
                        )
                      )
                    }
                  }
                ),
                statements: CodeBlockItemListSyntax {
                  if isFallback {
                    FunctionCallExprSyntax(
                      calledExpression: DeclReferenceExprSyntax(baseName: "assertionFailure"),
                      leftParen: .leftParenToken(),
                      arguments: LabeledExprListSyntax(),
                      rightParen: .rightParenToken()
                    )
                  }
                  assignment
                }
              )
            )
          )
        }
      }

      /// `static var toolInputSchema: ToolInputSchema { … }`
      do {
        let expression: ExprSyntaxProtocol =
          if parameters.isEmpty {
            MemberAccessExprSyntax(name: element.name)
          } else {
            FunctionCallExprSyntax(
              calledExpression: MemberAccessExprSyntax(name: element.name),
              leftParen: .leftParenToken(),
              arguments: LabeledExprListSyntax {
                if parameters.count == 1 {
                  LabeledExprSyntax(
                    expression: PatternExprSyntax(
                      pattern: ValueBindingPatternSyntax(
                        bindingSpecifier: .keyword(.let),
                        pattern: IdentifierPatternSyntax(identifier: "value")
                      )
                    )
                  )
                } else {
                  for (offset, _) in parameters.enumerated() {
                    LabeledExprSyntax(
                      expression: PatternExprSyntax(
                        pattern: ValueBindingPatternSyntax(
                          bindingSpecifier: .keyword(.let),
                          pattern: IdentifierPatternSyntax(identifier: "value_\(raw: offset)")
                        )
                      )
                    )
                  }
                }
              },
              rightParen: .rightParenToken()
            )
          }
        accessorCases.append(
          .switchCase(
            SwitchCaseSyntax(
              label: .case(
                SwitchCaseLabelSyntax {
                  SwitchCaseItemListSyntax {
                    SwitchCaseItemSyntax(
                      pattern: ExpressionPatternSyntax(
                        expression: expression
                      )
                    )
                  }
                }
              ),
              statements: CodeBlockItemListSyntax {
                TupleExprSyntax {
                  for (caseOffset, _) in elements.enumerated() {
                    let expression: ExprSyntaxProtocol =
                      if caseOffset == offset {
                        if parameters.isEmpty {
                          TupleExprSyntax {}
                        } else if parameters.dropFirst().isEmpty {
                          DeclReferenceExprSyntax(baseName: "value")
                        } else {
                          TupleExprSyntax {
                            for (parameterOffset, _) in parameters.enumerated() {
                              LabeledExprSyntax(
                                expression: DeclReferenceExprSyntax(
                                  baseName: "value_\(raw: parameterOffset)")
                              )
                            }
                          }
                        }
                      } else {
                        MemberAccessExprSyntax(name: "none")
                      }
                    LabeledExprSyntax(expression: expression)
                  }
                }
              }
            )
          )
        )
      }

      /// Schema
      if parameters.isEmpty {
        /// `case name`
        appendSchemaField(
          name: element.name,
          schemaType: MemberTypeSyntax(
            baseType: IdentifierTypeSyntax(name: "Claude"),
            name: "ToolInputVoidSchema"
          ),
          schemaValue: FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
              base: DeclReferenceExprSyntax(baseName: "Claude"),
              name: "ToolInputVoidSchema"
            ),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax {},
            rightParen: .rightParenToken()
          )
        )

      } else if let parameter = parameters.first, parameters.count == 1 {
        /// `case name(parameter)`
        appendSchemaField(name: element.name, type: parameter.type)

      } else {
        /// `case name(parameters...)`
        appendSchemaField(
          name: element.name,
          schemaType: MemberTypeSyntax(
            baseType: IdentifierTypeSyntax(
              name: "Claude"
            ),
            name: "ToolInputKeyedTupleSchema",
            genericArgumentClause: GenericArgumentClauseSyntax {
              for parameter in parameters {
                GenericArgumentSyntax(
                  argument: MemberTypeSyntax(
                    baseType: parameter.type,
                    name: "ToolInputSchema"
                  )
                )
              }
            }
          ),
          schemaValue: FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(
              baseName: "Claude.ToolInputKeyedTupleSchema"),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax {
              for (offset, parameter) in parameters.enumerated() {
                let name = parameter.firstName ?? "_\(raw: offset)"
                LabeledExprSyntax(
                  expression: TupleExprSyntax {
                    LabeledExprSyntax(
                      label: "key",
                      expression: FunctionCallExprSyntax(
                        calledExpression: MemberAccessExprSyntax(
                          base: DeclReferenceExprSyntax(baseName: "Claude"),
                          name: "ToolInputSchemaKey"
                        ),
                        leftParen: .leftParenToken(),
                        arguments: LabeledExprListSyntax {
                          LabeledExprSyntax(expression: StringLiteralExprSyntax(content: "\(name)"))
                        },
                        rightParen: .rightParenToken()
                      )
                    )
                    LabeledExprSyntax(
                      label: "schema",
                      expression: MemberAccessExprSyntax(
                        base: DeclReferenceExprSyntax(baseName: "\(parameter.type.trimmed)"),
                        name: "toolInputSchema"
                      )
                    )
                  }
                )
              }
            },
            rightParen: .rightParenToken()
          )
        )
      }
    }

    /// Add case where all elements are `none`
    initializerCases.append(
      .switchCase(
        SwitchCaseSyntax(
          label: .case(
            SwitchCaseLabelSyntax {
              SwitchCaseItemListSyntax {
                SwitchCaseItemSyntax(
                  pattern: ExpressionPatternSyntax(
                    expression: TupleExprSyntax {
                      for _ in elements {
                        LabeledExprSyntax(expression: MemberAccessExprSyntax(name: "none"))
                      }
                    }
                  )
                )
              }
            }
          ),
          statements: CodeBlockItemListSyntax {
            ThrowStmtSyntax(
              expression: FunctionCallExprSyntax(
                calledExpression: MemberAccessExprSyntax(
                  base: DeclReferenceExprSyntax(baseName: "Claude"),
                  name: "ToolInputEnumNoCaseSpecified"
                ),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax(),
                rightParen: .rightParenToken()
              )
            )
          }
        )
      )
    )
  }

  fileprivate let modifiers: DeclModifierListSyntax
  @CodeBlockItemListBuilder
  fileprivate var initializerBody: CodeBlockItemListSyntax {
    SwitchExprSyntax(
      subject: DeclReferenceExprSyntax(baseName: "value"),
      cases: initializerCases
    )
  }
  @CodeBlockItemListBuilder
  fileprivate var describedValueAccessorBody: CodeBlockItemListSyntax {
    SwitchExprSyntax(
      subject: DeclReferenceExprSyntax(baseName: "self"),
      cases: accessorCases
    )
  }
  fileprivate let schemaType: TokenSyntax = "ToolInputEnumSchema"
  fileprivate var schemaTypeGenericArguments = GenericArgumentListSyntax()
  fileprivate var schemaInitializerArguments = LabeledExprListSyntax()

  private var storedPropertyCount = 0
  private var initializerCases = SwitchCaseListSyntax()
  private var accessorCases = SwitchCaseListSyntax()
}

// MARK: - Shared

private protocol ToolInputMembers {
  var modifiers: DeclModifierListSyntax { get }
  var initializerBody: CodeBlockItemListSyntax { get }
  var describedValueAccessorBody: CodeBlockItemListSyntax { get }

  var schemaType: TokenSyntax { get }
  var schemaTypeGenericArguments: GenericArgumentListSyntax { get set }
  var schemaInitializerArguments: LabeledExprListSyntax { get set }
}

extension ToolInputMembers {
  fileprivate mutating func appendSchemaField(
    name: TokenSyntax,
    type: some TypeSyntaxProtocol
  ) {
    appendSchemaField(
      name: name,
      schemaType: MemberTypeSyntax(
        baseType: type,
        name: "ToolInputSchema"
      ),
      schemaValue: MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: "\(type.trimmed)"),
        name: "toolInputSchema"
      )
    )
  }

  fileprivate mutating func appendSchemaField(
    name: TokenSyntax,
    schemaType: some TypeSyntaxProtocol,
    schemaValue: some ExprSyntaxProtocol
  ) {
    /// `typealias ToolInputSchema = ToolInputKeyedTupleSchema<…>`
    if let index = schemaTypeGenericArguments.indices.last {
      schemaTypeGenericArguments[index].trailingComma = .commaToken()
    }
    schemaTypeGenericArguments.append(
      GenericArgumentSyntax(argument: schemaType)
    )

    /// `static var toolInputSchema: ToolInputSchema { … }`
    schemaInitializerArguments.append(prependingCommaIfNeeded: true) {
      LabeledExprSyntax(
        expression: TupleExprSyntax {
          LabeledExprSyntax(
            label: "key",
            expression: FunctionCallExprSyntax(
              calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: "Claude"),
                name: "ToolInputSchemaKey"
              ),
              leftParen: .leftParenToken(),
              arguments: LabeledExprListSyntax {
                LabeledExprSyntax(expression: StringLiteralExprSyntax(content: "\(name)"))
              },
              rightParen: .rightParenToken()
            )
          )
          LabeledExprSyntax(
            label: "schema",
            expression: schemaValue
          )
        }
      )
    }
  }

  fileprivate var toolInputSchemaTypealias: TypeAliasDeclSyntax {
    /// `typealias ToolInputSchema = ToolInputKeyedTupleSchema<…>`
    TypeAliasDeclSyntax(
      modifiers: modifiers,
      name: "ToolInputSchema",
      initializer: TypeInitializerClauseSyntax(
        value: MemberTypeSyntax(
          baseType: IdentifierTypeSyntax(
            name: "Claude"
          ),
          name: schemaType,
          genericArgumentClause: GenericArgumentClauseSyntax(
            arguments: schemaTypeGenericArguments
          )
        )
      )
    )
  }

  fileprivate var toolInputSchemaAccessor: VariableDeclSyntax {
    /// `static var toolInputSchema: ToolInputSchema { … }`
    VariableDeclSyntax.init(
      modifiers: modifiers + [DeclModifierSyntax.init(name: .keyword(.static))],
      bindingSpecifier: .keyword(.var),
      bindingsBuilder: {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: "toolInputSchema"),
          typeAnnotation: TypeAnnotationSyntax(type: IdentifierTypeSyntax(name: "ToolInputSchema")),
          accessorBlock: AccessorBlockSyntax(
            accessors: .getter(
              CodeBlockItemListSyntax {
                FunctionCallExprSyntax(
                  calledExpression: DeclReferenceExprSyntax(baseName: "ToolInputSchema"),
                  leftParen: .leftParenToken(),
                  arguments: schemaInitializerArguments,
                  rightParen: .rightParenToken()
                )
              }
            )
          )
        )
      }
    )
  }

  fileprivate var initializer: InitializerDeclSyntax {
    /// `init(toolInputSchemaDescribedValue value: ToolInputSchema.DescribedValue) throws { … }`
    InitializerDeclSyntax(
      modifiers: modifiers,
      signature: FunctionSignatureSyntax(
        parameterClause: FunctionParameterClauseSyntax(
          parameters: FunctionParameterListSyntax {
            FunctionParameterSyntax(
              firstName: "toolInputSchemaDescribedValue",
              secondName: "value",
              type: MemberTypeSyntax(
                baseType: IdentifierTypeSyntax(name: "ToolInputSchema"),
                name: "DescribedValue"
              )
            )
          }
        ),
        effectSpecifiers: FunctionEffectSpecifiersSyntax(
          throwsClause: ThrowsClauseSyntax(
            throwsSpecifier: .keyword(.throws)
          )
        )
      ),
      body: CodeBlockSyntax(statements: initializerBody)
    )
  }

  fileprivate var toolInputSchemaDescribedValueAccessor: VariableDeclSyntax {
    /// `var toolInputSchemaDescribedValue: ToolInputSchema.DescribedValue { … }`
    VariableDeclSyntax(
      modifiers: modifiers,
      bindingSpecifier: .keyword(.var),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: "toolInputSchemaDescribedValue"),
          typeAnnotation: TypeAnnotationSyntax(
            type: MemberTypeSyntax(
              baseType: IdentifierTypeSyntax(name: "ToolInputSchema"),
              name: "DescribedValue"
            )
          ),
          accessorBlock: AccessorBlockSyntax(
            accessors: .getter(describedValueAccessorBody)
          )
        )
      }
    )
  }
}

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct ToolInputMacro: ExtensionMacro {

  static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    try DiagnosticError.diagnose(in: context) {
      [
        try .toolInputConformance(for: declaration, of: type, in: context)
      ]
    }
  }

}

// MARK: - Implementation

extension ExtensionDeclSyntax {

  fileprivate static func toolInputConformance(
    for declaration: some DeclGroupSyntax,
    of type: some TypeSyntaxProtocol,
    in context: MacroExpansionContext
  ) throws -> ExtensionDeclSyntax {
    return try ExtensionDeclSyntax(
      extendedType: type,
      inheritanceClause: InheritanceClauseSyntax {
        InheritedTypeSyntax(
          type: MemberTypeSyntax(
            baseType: IdentifierTypeSyntax(name: "ToolInput"),
            name: "SchemaCodable"
          )
        )
      }
    ) {
      try declaration.toolInputMembers(in: context)
    }
  }

}

extension DeclGroupSyntax {

  fileprivate func toolInputMembers(in context: MacroExpansionContext) throws
    -> MemberBlockItemListSyntax
  {
    if let structDecl = self.as(StructDeclSyntax.self) {
      try structDecl.toolInputMembers(in: context)
    } else if let enumDecl = self.as(EnumDeclSyntax.self) {
      enumDecl.toolInputMembers(in: context)
    } else {
      throw DiagnosticError(
        node: self,
        severity: .error,
        message: "Unsupported declaration of kind: \(self.kind)"
      )
    }
  }

}

// MARK: Struct

extension StructDeclSyntax {

  fileprivate func toolInputMembers(in context: MacroExpansionContext) throws
    -> MemberBlockItemListSyntax
  {
    Self.toolInputMembers(
      for: try storedProperties,
      description: comment,
      isPublic: modifiers.contains(where: \.isPublic),
      in: context
    )
  }

  static func toolInput(
    description: String?,
    name: TokenSyntax,
    isPublic: Bool,
    storedProperties: [StoredProperty],
    additionalMembers: MemberBlockItemListSyntax,
    in context: MacroExpansionContext
  ) -> StructDeclSyntax {
    StructDeclSyntax(
      modifiers: DeclModifierListSyntax {
        if isPublic {
          DeclModifierSyntax(name: .keyword(.public))
        }
      },
      name: name,
      inheritanceClause: InheritanceClauseSyntax {
        InheritedTypeSyntax(
          type: MemberTypeSyntax(
            baseType: IdentifierTypeSyntax(name: "ToolInput"),
            name: "SchemaCodable"
          )
        )
      },
      memberBlock: MemberBlockSyntax {

        for storedProperty in storedProperties {
          VariableDeclSyntax.init(
            leadingTrivia: storedProperty.comment.map { Trivia.blockComment($0) } ?? [],
            modifiers: DeclModifierListSyntax {
              DeclModifierSyntax(name: .keyword(.private))
            },
            .let,
            name: PatternSyntax(
              IdentifierPatternSyntax(
                identifier: storedProperty.name
              )
            ),
            type: TypeAnnotationSyntax(
              type: storedProperty.type
            )
          )
        }

        toolInputMembers(
          for: storedProperties,
          description: description,
          isPublic: isPublic,
          in: context
        )

        for member in additionalMembers {
          member
        }

      }
    )

  }

  fileprivate static func toolInputMembers(
    for storedProperties: some Collection<StoredProperty>,
    description: String?,
    isPublic: Bool,
    in context: MacroExpansionContext
  )
    -> MemberBlockItemListSyntax
  {
    let propertyKeyName = context.makeUniqueName("PropertyKey")

    /// var toolInputSchema: some ToolInput.Schema<Self> { … }
    let toolInputSchemaProperty: VariableDeclSyntax = .toolInputSchemaProperty(
      isPublic: isPublic
    ) {
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: "ToolInput"),
          name: "structSchema"
        ),
        leftParen: .leftParenToken(trailingTrivia: .newline),
        arguments: LabeledExprListSyntax {
          /// representing: Self.self
          LabeledExprSyntax(
            label: "representing",
            colon: .colonToken(),
            expression: MemberAccessExprSyntax(
              base: DeclReferenceExprSyntax(baseName: "Self"),
              name: "self"
            ),
            trailingComma: .commaToken(trailingTrivia: .newline)
          )

          /// description: ...
          LabeledExprSyntax.descriptionArgument(description)

          /// keyedBy: propertyKey.self
          LabeledExprSyntax(
            label: "keyedBy",
            colon: .colonToken(),
            expression: MemberAccessExprSyntax(
              base: DeclReferenceExprSyntax(
                baseName: propertyKeyName
              ),
              name: "self"
            ),
            trailingComma: .commaToken(trailingTrivia: .newline)
          )

          /// properties: ( ... )
          LabeledExprSyntax(
            label: "properties",
            colon: .colonToken(),
            expression: TupleExprSyntax(
              elements: LabeledExprListSyntax {
                for property in storedProperties {
                  LabeledExprSyntax(
                    expression: property.structSchemaPropertyArgument(
                      propertyKeyName: propertyKeyName
                    )
                  )
                }
              },
              rightParen: .rightParenToken(leadingTrivia: .newline)
            ),
            trailingComma: .commaToken(trailingTrivia: .newline)
          )

          /// initializer: Self.init(structSchemaDecoder:)
          LabeledExprSyntax(
            label: "initializer",
            colon: .colonToken(),
            expression: MemberAccessExprSyntax(
              base: DeclReferenceExprSyntax(
                baseName: "Self"
              ),
              declName: DeclReferenceExprSyntax(
                baseName: "init",
                argumentNames: DeclNameArgumentsSyntax(
                  arguments: DeclNameArgumentListSyntax {
                    DeclNameArgumentSyntax(name: "structSchemaDecoder")
                  }
                )
              )
            ),
            trailingTrivia: .newline
          )
        },
        rightParen: .rightParenToken()
      )
    }

    /// private enum ToolInputSchemaPropertyKey: CodingKey { … }
    let propertyKeyEnum =
      EnumDeclSyntax(
        modifiers: .private,
        name: propertyKeyName,
        inheritanceClause: InheritanceClauseSyntax(
          colon: .colonToken(),
          inheritedTypes: InheritedTypeListSyntax {
            InheritedTypeSyntax(
              type: MemberTypeSyntax(
                baseType: IdentifierTypeSyntax(name: "Swift"),
                name: "CodingKey"
              )
            )
          }
        ),
        memberBlock: MemberBlockSyntax(
          membersBuilder: {
            for property in storedProperties {
              EnumCaseDeclSyntax {
                EnumCaseElementSyntax(name: property.name)
              }
            }
          }
        )
      )

    let initializer = InitializerDeclSyntax(
      modifiers: .private,
      signature: FunctionSignatureSyntax(
        parameterClause: FunctionParameterClauseSyntax(
          parameters: FunctionParameterListSyntax {
            FunctionParameterSyntax(
              firstName: "structSchemaDecoder",
              type: MemberTypeSyntax(
                baseType: IdentifierTypeSyntax(name: "ToolInput"),
                name: "StructSchemaDecoder",
                genericArgumentClause: GenericArgumentClauseSyntax {
                  for property in storedProperties {
                    GenericArgumentSyntax(
                      argument: property.type
                    )
                  }
                }
              )
            )
          }
        )
      ),
      body: CodeBlockSyntax {
        if storedProperties.count == 1 {
          /// Single-element tuples are cursed, so we need to special-case this
          for property in storedProperties {
            InfixOperatorExprSyntax(
              leftOperand: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: "self"),
                name: property.name
              ),
              operator: AssignmentExprSyntax(),
              rightOperand: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: "structSchemaDecoder"),
                name: "propertyValues"
              )
            )
          }
        } else {
          /// self.propertyName = structSchemaDecoder.propertyValues.n
          for (offset, property) in storedProperties.enumerated() {
            InfixOperatorExprSyntax(
              leftOperand: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: "self"),
                name: property.name
              ),
              operator: AssignmentExprSyntax(),
              rightOperand: MemberAccessExprSyntax(
                base: MemberAccessExprSyntax(
                  base: DeclReferenceExprSyntax(baseName: "structSchemaDecoder"),
                  name: "propertyValues"
                ),
                name: "\(raw: offset)"
              )
            )
          }
        }
      }

    )

    return MemberBlockItemListSyntax {
      toolInputSchemaProperty
      propertyKeyEnum
      initializer
    }

  }

}

// MARK: Struct Properties

extension StructDeclSyntax {

  struct StoredProperty {
    let name: TokenSyntax
    let type: TypeSyntax
    let comment: String?
  }

  fileprivate var storedProperties: some Collection<StoredProperty> {
    get throws {
      var storedProperties: [StoredProperty] = []
      for member in memberBlock.members {
        guard let variable = member.decl.as(VariableDeclSyntax.self) else {
          continue
        }
        guard !variable.bindings.contains(where: { $0.accessorBlock != nil }) else {
          /// This is a computed property
          continue
        }

        let comment = member.comment

        /// In order to handle complex declarations such as `let a, b: Bool, c: String`, we iterate over the bindings in reverse and store the last type annotation.
        /// Note that these will be in reverse order in the expanded source.
        var lastTypeAnnotation: TypeSyntax?
        for binding in variable.bindings.reversed() {

          guard let type = binding.typeAnnotation?.type ?? lastTypeAnnotation else {
            throw DiagnosticError(
              node: variable,
              severity: .error,
              message: "Missing type annotation"
            )
          }
          lastTypeAnnotation = type

          guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier else {
            throw DiagnosticError(
              node: binding, severity: .error,
              message: "Binding pattern does not have an identifier")
          }

          storedProperties.append(
            StoredProperty(
              name: name,
              type: type,
              comment: comment
            )
          )
        }
      }
      return storedProperties
    }
  }

}

extension StructDeclSyntax.StoredProperty {

  fileprivate func structSchemaPropertyArgument(propertyKeyName: TokenSyntax)
    -> some ExprSyntaxProtocol
  {
    TupleExprSyntax(
      leftParen: .leftParenToken(leadingTrivia: .newline, trailingTrivia: .newline),
      elements: LabeledExprListSyntax {
        /// description
        if let description = comment {
          LabeledExprSyntax(
            label: "description",
            colon: .colonToken(),
            expression: StringLiteralExprSyntax(
              openDelimiter: .rawStringPoundDelimiter("#"),
              openingQuote: .multilineStringQuoteToken(),
              content: description,
              closingQuote: .multilineStringQuoteToken(),
              closeDelimiter: .rawStringPoundDelimiter("#")
            ),
            trailingComma: .commaToken(trailingTrivia: .newline)
          )
        } else {
          LabeledExprSyntax(
            label: "description",
            colon: .colonToken(),
            expression: NilLiteralExprSyntax(),
            trailingComma: .commaToken(trailingTrivia: .newline)
          )
        }

        /// keyPath: \Self.propertyName
        LabeledExprSyntax(
          label: "keyPath",
          colon: .colonToken(),
          expression: KeyPathExprSyntax(
            root: IdentifierTypeSyntax(name: "Self"),
            components: KeyPathComponentListSyntax {
              KeyPathComponentSyntax(
                period: .periodToken(),
                component: .property(
                  KeyPathPropertyComponentSyntax(
                    declName: DeclReferenceExprSyntax(baseName: name)
                  )
                )
              )
            }
          ),
          trailingComma: .commaToken(trailingTrivia: .newline)
        )

        /// key: propertyKey.propertyName
        LabeledExprSyntax(
          label: "key",
          colon: .colonToken(),
          expression: MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(
              baseName: propertyKeyName
            ),
            name: name
          ),
          trailingComma: .commaToken(trailingTrivia: .newline)
        )

        /// schema: ToolInput.schema(representing: <type>.self)
        LabeledExprSyntax(
          label: "schema",
          colon: .colonToken(),
          expression: type.toolInputSchema
        )
      }
    )
  }

}

// MARK: Enum

extension EnumDeclSyntax {

  func toolInputMembers(in context: MacroExpansionContext) -> MemberBlockItemListSyntax {
    let caseKeyName = context.makeUniqueName("CaseKey")

    let caseDecls = memberBlock
      .members
      .compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }

    let toolInputSchemaProperty: VariableDeclSyntax = .toolInputSchemaProperty(
      isPublic: modifiers.contains(where: \.isPublic)
    ) {
      for (caseDeclOffset, caseDecl) in caseDecls.enumerated() {
        for (elementOffset, element) in caseDecl.elements.enumerated() {
          VariableDeclSyntax(
            .let,
            name: PatternSyntax(
              IdentifierPatternSyntax(
                identifier: "associatedValuesSchema_\(raw: caseDeclOffset)_\(raw: elementOffset)"
              )
            ),
            initializer: InitializerClauseSyntax(
              value: element.associatedValuesSchema(caseKeyName: caseKeyName)
            )
          )
        }
      }

      /// return ToolInput.enumSchema(…)
      ReturnStmtSyntax(
        expression: FunctionCallExprSyntax(
          calledExpression: MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: "ToolInput"),
            name: "enumSchema"
          ),
          leftParen: .leftParenToken(trailingTrivia: .newline),
          arguments: LabeledExprListSyntax {
            /// representing: Self.self
            LabeledExprSyntax(
              label: "representing",
              colon: .colonToken(),
              expression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: "Self"),
                name: "self"
              ),
              trailingComma: .commaToken(trailingTrivia: .newline)
            )

            /// description: ...
            descriptionArgument

            /// keyedBy: ToolInputSchemaCaseKey.self
            LabeledExprSyntax(
              label: "keyedBy",
              colon: .colonToken(),
              expression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: caseKeyName),
                name: "self"
              ),
              trailingComma: .commaToken(trailingTrivia: .newline)
            )

            /// cases: (…)
            LabeledExprSyntax(
              label: "cases",
              colon: .colonToken(),
              expression: TupleExprSyntax(
                leftParen: .leftParenToken(),
                elements: LabeledExprListSyntax {
                  for (caseDeclOffset, caseDecl) in caseDecls.enumerated() {
                    let descriptionArgument = caseDecl.descriptionArgument
                    for (elementOffset, element) in caseDecl.elements.enumerated() {
                      LabeledExprSyntax(
                        expression: element.enumSchemaCaseArgument(
                          descriptionArgument: descriptionArgument,
                          caseKeyName: caseKeyName,
                          associatedValuesSchema: DeclReferenceExprSyntax(
                            baseName:
                              "associatedValuesSchema_\(raw: caseDeclOffset)_\(raw: elementOffset)"
                          )
                        )
                      )
                    }
                  }
                },
                rightParen: .rightParenToken(leadingTrivia: .newline)
              ),
              trailingComma: .commaToken(trailingTrivia: .newline)
            )

            /// caseEncoder: { … }
            LabeledExprSyntax(
              label: "caseEncoder",
              colon: .colonToken(),
              expression: ClosureExprSyntax(
                signature: ClosureSignatureSyntax(
                  attributes: AttributeListSyntax {
                    AttributeSyntax(
                      atSign: .atSignToken(),
                      attributeName: IdentifierTypeSyntax(name: "Sendable")
                    )
                  },
                  parameterClause: .simpleInput(
                    ClosureShorthandParameterListSyntax {
                      ClosureShorthandParameterSyntax(
                        name: "value"
                      )
                      for (offset, _) in caseDecls.flatMap(\.elements).enumerated() {
                        ClosureShorthandParameterSyntax(
                          name: "encoder_\(raw: offset)"
                        )
                      }
                    }
                  )
                ),
                statements: CodeBlockItemListSyntax {
                  SwitchExprSyntax(
                    subject: DeclReferenceExprSyntax(baseName: "value"),
                    cases: SwitchCaseListSyntax {
                      for (offset, element) in caseDecls.flatMap(\.elements).enumerated() {
                        element.switchCase(encoderName: "encoder_\(raw: offset)")
                      }
                    }
                  )
                }
              )
            )
          },
          rightParen: .rightParenToken(leadingTrivia: .newline)

        )
      )
    }

    let codingKey = InheritanceClauseSyntax {
      InheritedTypeSyntax(
        type: MemberTypeSyntax(
          baseType: IdentifierTypeSyntax(name: "Swift"),
          name: "CodingKey"
        )
      )
    }
    let caseKeyDefinition = EnumDeclSyntax(
      modifiers: .private,
      name: caseKeyName,
      inheritanceClause: codingKey,
      memberBlock: MemberBlockSyntax {
        for element in caseDecls.flatMap(\.elements) {
          EnumCaseDeclSyntax {
            EnumCaseElementSyntax(
              name: element.name
            )
          }
        }

        EnumDeclSyntax(
          name: "AssociatedValuesKey",
          memberBlock: MemberBlockSyntax {
            for element in caseDecls.flatMap(\.elements) {
              EnumDeclSyntax(
                name: element.name,
                inheritanceClause: codingKey,
                memberBlock: MemberBlockSyntax {
                  if let parameters = element.parameterClause?.parameters {
                    for parameter in parameters {
                      if let name = parameter.name {
                        EnumCaseDeclSyntax {
                          EnumCaseElementSyntax(name: name)
                        }
                      }
                    }
                  }
                }
              )
            }
          }
        )
      }
    )

    return MemberBlockItemListSyntax {
      toolInputSchemaProperty
      caseKeyDefinition
    }
  }

}

extension EnumCaseElementListSyntax.Element {

  fileprivate func associatedValuesSchema(caseKeyName: TokenSyntax) -> FunctionCallExprSyntax {
    let associatedValuesKey = associatedValuesKey(caseKeyName: caseKeyName)
    return FunctionCallExprSyntax(
      calledExpression: MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: "ToolInput"),
        name: "enumCaseAssociatedValuesSchema"
      ),
      leftParen: .leftParenToken(trailingTrivia: .newline),
      arguments: LabeledExprListSyntax {

        /// values: (…)
        LabeledExprSyntax(
          label: "values",
          colon: .colonToken(),
          expression: TupleExprSyntax(
            leftParen: .leftParenToken(trailingTrivia: .newline),
            elements: LabeledExprListSyntax {
              if let parameters = parameterClause?.parameters {
                for parameter in parameters {
                  LabeledExprSyntax(
                    expression: parameter.associatedValuesSchemaArgument(
                      key: associatedValuesKey
                    )
                  )
                }
              }
            },
            rightParen: .rightParenToken(leadingTrivia: .newline)
          )
        )

        /// keyedBy: caseKey.AssociatedValue<case>.self
        LabeledExprSyntax(
          leadingTrivia: .newline,
          label: "keyedBy",
          colon: .colonToken(),
          expression: MemberAccessExprSyntax(
            base: associatedValuesKey,
            name: "self"
          )
        )
      },
      rightParen: .rightParenToken(leadingTrivia: .newline)
    )
  }

  fileprivate func enumSchemaCaseArgument(
    descriptionArgument: LabeledExprSyntax,
    caseKeyName: TokenSyntax,
    associatedValuesSchema: some ExprSyntaxProtocol
  ) -> TupleExprSyntax {
    return TupleExprSyntax(
      leftParen: .leftParenToken(leadingTrivia: .newline, trailingTrivia: .newline),
      elements: LabeledExprListSyntax {
        /// key: caseKey.first,
        LabeledExprSyntax(
          label: "key",
          colon: .colonToken(),
          expression: MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: caseKeyName),
            name: name
          ),
          trailingComma: .commaToken(trailingTrivia: .newline)
        )

        /// description: "A string",
        descriptionArgument

        /// associatedValuesSchema:,
        LabeledExprSyntax(
          label: "associatedValuesSchema",
          colon: .colonToken(),
          expression: associatedValuesSchema,
          trailingComma: .commaToken(trailingTrivia: .newline)
        )

        /// initializer: { @Sendable first in .first(first) }
        LabeledExprSyntax(
          label: "initializer",
          colon: .colonToken(),
          expression: ClosureExprSyntax(
            signature: ClosureSignatureSyntax(
              attributes: AttributeListSyntax {
                AttributeSyntax(
                  atSign: .atSignToken(),
                  attributeName: IdentifierTypeSyntax(name: "Sendable")
                )
              },
              parameterClause: .simpleInput(
                ClosureShorthandParameterListSyntax {
                  ClosureShorthandParameterSyntax(name: "values")
                }
              )
            ),
            statements: CodeBlockItemListSyntax {
              let initializer = MemberAccessExprSyntax(
                name: name
              )
              if let parameters = parameterClause?.parameters {
                FunctionCallExprSyntax(
                  calledExpression: initializer,
                  leftParen: .leftParenToken(),
                  arguments: LabeledExprListSyntax {
                    if parameters.count > 1 {
                      for (offset, parameter) in parameters.enumerated() {
                        LabeledExprSyntax(
                          label: parameter.firstName,
                          colon: parameter.firstName == nil ? nil : .colonToken(),
                          expression: MemberAccessExprSyntax(
                            base: DeclReferenceExprSyntax(baseName: "values"),
                            name: "\(raw: offset)"
                          )
                        )
                      }
                    } else if let parameter = parameters.first {
                      LabeledExprSyntax(
                        label: parameter.firstName,
                        colon: parameter.firstName == nil ? nil : .colonToken(),
                        expression: DeclReferenceExprSyntax(baseName: "values")
                      )
                    }
                  },
                  rightParen: .rightParenToken()
                )
              } else {
                initializer
              }
            }
          )
        )
      },
      rightParen: .rightParenToken(leadingTrivia: .newline)
    )
  }

  private func associatedValuesKey(caseKeyName: TokenSyntax) -> some ExprSyntaxProtocol {
    MemberAccessExprSyntax(
      base: MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: caseKeyName),
        name: "AssociatedValuesKey"
      ),
      name: name
    )
  }

  fileprivate func switchCase(encoderName: TokenSyntax) -> SwitchCaseSyntax {
    SwitchCaseSyntax(
      /// case .enumCase…
      label: .case(
        SwitchCaseLabelSyntax {
          SwitchCaseItemListSyntax {
            if let parameters = parameterClause?.parameters {
              /// case .enumCase(…):
              SwitchCaseItemSyntax(
                pattern: ExpressionPatternSyntax(
                  expression: FunctionCallExprSyntax(
                    calledExpression: MemberAccessExprSyntax(
                      name: name
                    ),
                    leftParen: .leftParenToken(),
                    arguments: LabeledExprListSyntax {
                      for (parameterName, _) in parameters.named() {
                        LabeledExprSyntax(
                          expression: PatternExprSyntax(
                            pattern: ValueBindingPatternSyntax(
                              bindingSpecifier: .keyword(.let),
                              pattern: IdentifierPatternSyntax(
                                identifier: parameterName
                              )
                            )
                          )
                        )
                      }
                    },
                    rightParen: .rightParenToken()
                  )
                )
              )
            } else {
              /// case .enumCase:
              SwitchCaseItemSyntax(
                pattern: ExpressionPatternSyntax(
                  expression: MemberAccessExprSyntax(
                    name: name
                  )
                )
              )
            }
          }
        }
      ),
      /// case .enumCase(…):
      statements: CodeBlockItemListSyntax {
        /// enumCaseEncoder(…)
        FunctionCallExprSyntax(
          calledExpression: DeclReferenceExprSyntax(baseName: encoderName),
          leftParen: .leftParenToken(),
          arguments: LabeledExprListSyntax {
            LabeledExprSyntax(
              expression: TupleExprSyntax {
                let parameters = parameterClause?.parameters ?? []
                for (name, _) in parameters.named() {
                  LabeledExprSyntax(
                    expression: DeclReferenceExprSyntax(baseName: name)
                  )
                }
              }
            )
          },
          rightParen: .rightParenToken()
        )
      }
    )
  }

}

extension Sequence where Element == EnumCaseParameterSyntax {

  func named() -> some Sequence<(name: TokenSyntax, parameter: Element)> {
    enumerated()
      .map { pair in
        (
          name: pair.element.name ?? "_\(raw: pair.offset)",
          parameter: pair.element
        )
      }
  }

}

extension EnumCaseParameterListSyntax.Element {

  fileprivate func associatedValuesSchemaArgument(key: some ExprSyntaxProtocol) -> TupleExprSyntax {
    TupleExprSyntax(
      leftParen: .leftParenToken(trailingTrivia: .newline),
      elements: LabeledExprListSyntax {
        if let name = name {
          /// key: ToolInputSchemaCaseKey.AssociatedValue<case>.name,
          LabeledExprSyntax(
            label: "key",
            colon: .colonToken(),
            expression: MemberAccessExprSyntax(
              base: key,
              name: name
            ),
            trailingComma: .commaToken(trailingTrivia: .newline)
          )
        } else {
          /// key: ToolInputSchemaCaseKey.AssociatedValue<case>?.none,
          LabeledExprSyntax(
            label: "key",
            colon: .colonToken(),
            expression: MemberAccessExprSyntax(
              base: OptionalChainingExprSyntax(
                expression: key
              ),
              name: "none"
            ),
            trailingComma: .commaToken(trailingTrivia: .newline)
          )
        }

        /// schema: ToolInput.schema(representing: <Type>.self),
        LabeledExprSyntax(
          label: "schema",
          colon: .colonToken(),
          expression: type.toolInputSchema
        )

      },
      rightParen: .rightParenToken()
    )
  }

  fileprivate var name: TokenSyntax? {
    switch secondName {
    case .wildcardToken(), nil:
      switch firstName {
      case .wildcardToken(), nil:
        return nil
      case let name:
        return name
      }
    case let name?:
      return name
    }
  }

}

// MARK: Shared

extension VariableDeclSyntax {

  fileprivate static func toolInputSchemaProperty(
    isPublic: Bool,
    @CodeBlockItemListBuilder _ builder: () -> CodeBlockItemListSyntax
  )
    -> VariableDeclSyntax
  {
    VariableDeclSyntax(
      modifiers: DeclModifierListSyntax {
        if isPublic {
          DeclModifierSyntax(name: "public")
        }
        DeclModifierSyntax(name: .keyword(.static))
      },
      bindingSpecifier: .keyword(.var),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: "toolInputSchema"),
          typeAnnotation: TypeAnnotationSyntax(
            type: SomeOrAnyTypeSyntax(
              someOrAnySpecifier: .keyword(.some),
              constraint: MemberTypeSyntax(
                baseType: IdentifierTypeSyntax(name: "ToolInput"),
                name: "Schema",
                genericArgumentClause: GenericArgumentClauseSyntax {
                  GenericArgumentSyntax(
                    argument: IdentifierTypeSyntax(name: "Self")
                  )
                }
              )
            )
          ),
          accessorBlock: AccessorBlockSyntax(
            accessors: .getter(
              CodeBlockItemListSyntax(itemsBuilder: builder)
            )
          )
        )
      }
    )
  }

}

extension TypeSyntax {

  var toolInputSchema: some ExprSyntaxProtocol {
    FunctionCallExprSyntax(
      calledExpression: MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: "ToolInput"),
        name: "schema"
      ),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax {
        LabeledExprSyntax(
          label: "representing",
          colon: .colonToken(),
          expression: MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: "\(trimmed)"),
            name: "self"
          )
        )
      },
      rightParen: .rightParenToken(),
      trailingTrivia: .newline
    )
  }

}

import MacrosSupport
import SwiftDiagnostics
public import SwiftSyntax
import SwiftSyntaxBuilder
public import SwiftSyntaxMacros

extension ExtensionDeclSyntax {

  public static func schemaCodableConformance(
    for declaration: some DeclGroupSyntax,
    of type: some TypeSyntaxProtocol,
    schemaCodableNamespace: TokenSyntax,
    in context: MacroExpansionContext
  ) throws -> ExtensionDeclSyntax {
    return try ExtensionDeclSyntax(
      extendedType: type,
      inheritanceClause: InheritanceClauseSyntax {
        InheritedTypeSyntax(
          type: MemberTypeSyntax(
            baseType: IdentifierTypeSyntax(name: schemaCodableNamespace),
            name: "SchemaCodable"
          )
        )
      }
    ) {
      try declaration.schemaCodableMembers(in: context)
    }
  }

}

extension DeclGroupSyntax {

  fileprivate func schemaCodableMembers(in context: MacroExpansionContext) throws
    -> MemberBlockItemListSyntax
  {
    if let structDecl = self.as(StructDeclSyntax.self) {
      try structDecl.schemaCodableMembers(in: context)
    } else if let enumDecl = self.as(EnumDeclSyntax.self) {
      enumDecl.schemaCodableMembers(in: context)
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

  fileprivate func schemaCodableMembers(in context: MacroExpansionContext) throws
    -> MemberBlockItemListSyntax
  {
    Self.schemaCodableMembers(
      for: try storedProperties,
      description: comment,
      isPublic: modifiers.contains(where: \.isPublic),
      in: context
    )
  }

  public static func schemaCodable(
    description: String?,
    name: TokenSyntax,
    schemaCodableNamespace: TokenSyntax,
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
            baseType: IdentifierTypeSyntax(name: schemaCodableNamespace),
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

        schemaCodableMembers(
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

  fileprivate static func schemaCodableMembers(
    for storedProperties: some Collection<StoredProperty>,
    description: String?,
    isPublic: Bool,
    in context: MacroExpansionContext
  )
    -> MemberBlockItemListSyntax
  {
    /// var schema: some SchemaCoding.Schema<Self> { … }
    let schemaProperty: VariableDeclSyntax = .schemaProperty(
      isPublic: isPublic
    ) {
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: "SchemaProvider"),
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

          /// properties: ( ... )
          LabeledExprSyntax(
            label: "properties",
            colon: .colonToken(),
            expression: TupleExprSyntax(
              elements: LabeledExprListSyntax {
                for property in storedProperties {
                  LabeledExprSyntax(
                    expression: property.structSchemaPropertyArgument()
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

    let initializer = InitializerDeclSyntax(
      modifiers: .private,
      signature: FunctionSignatureSyntax(
        parameterClause: FunctionParameterClauseSyntax(
          parameters: FunctionParameterListSyntax {
            FunctionParameterSyntax(
              firstName: "structSchemaDecoder",
              type: MemberTypeSyntax(
                baseType: IdentifierTypeSyntax(name: "SchemaProvider"),
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
      schemaProperty
      initializer
    }

  }

}

// MARK: Struct Properties

extension StructDeclSyntax {

  public struct StoredProperty {
    public init(
      name: TokenSyntax,
      type: TypeSyntax,
      comment: String?
    ) {
      self.name = name
      self.type = type
      self.comment = comment
    }
    public let name: TokenSyntax
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

  fileprivate func structSchemaPropertyArgument()
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

        /// key: "propertyName"
        LabeledExprSyntax(
          label: "key",
          colon: .colonToken(),
          expression: AsExprSyntax(
            expression: StringLiteralExprSyntax(
              content: name.identifierOrText
            ),
            asKeyword: .keyword(.as, trailingTrivia: .space),
            type: TypeSyntax(stringLiteral: "SchemaCodingKey")
          ),
          trailingComma: .commaToken(trailingTrivia: .newline)
        )

        /// schema: Schema(representing: <type>.self)
        LabeledExprSyntax(
          label: "schema",
          colon: .colonToken(),
          expression: type.schema
        )
      }
    )
  }

}

// MARK: Enum

extension EnumDeclSyntax {

  func schemaCodableMembers(in context: MacroExpansionContext) -> MemberBlockItemListSyntax {
    let caseDecls = memberBlock
      .members
      .compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }

    let schemaProperty: VariableDeclSyntax = .schemaProperty(
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
              value: element.associatedValuesSchema()
            )
          )
        }
      }

      /// return ToolInput.enumSchema(…)
      ReturnStmtSyntax(
        expression: FunctionCallExprSyntax(
          calledExpression: MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: "SchemaProvider"),
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

    return MemberBlockItemListSyntax {
      schemaProperty
    }
  }

}

extension EnumCaseElementListSyntax.Element {

  fileprivate func associatedValuesSchema() -> FunctionCallExprSyntax {
    return FunctionCallExprSyntax(
      calledExpression: MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: "SchemaProvider"),
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
                    expression: parameter.associatedValuesSchemaArgument()
                  )
                }
              }
            },
            rightParen: .rightParenToken(leadingTrivia: .newline)
          )
        )
      },
      rightParen: .rightParenToken(leadingTrivia: .newline)
    )
  }

  fileprivate func enumSchemaCaseArgument(
    descriptionArgument: LabeledExprSyntax,
    associatedValuesSchema: some ExprSyntaxProtocol
  ) -> TupleExprSyntax {
    return TupleExprSyntax(
      leftParen: .leftParenToken(leadingTrivia: .newline, trailingTrivia: .newline),
      elements: LabeledExprListSyntax {
        /// key: "first",
        LabeledExprSyntax(
          label: "key",
          colon: .colonToken(),
          expression: AsExprSyntax(
            expression: StringLiteralExprSyntax(
              content: name.identifierOrText
            ),
            asKeyword: .keyword(.as, trailingTrivia: .space),
            type: TypeSyntax(stringLiteral: "SchemaCodingKey")
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

  fileprivate func associatedValuesSchemaArgument() -> TupleExprSyntax {
    TupleExprSyntax(
      leftParen: .leftParenToken(trailingTrivia: .newline),
      elements: LabeledExprListSyntax {
        if let name = name {
          /// key: "name",
          LabeledExprSyntax(
            label: "key",
            colon: .colonToken(),
            expression: AsExprSyntax(
              expression: StringLiteralExprSyntax(
                content: name.identifierOrText
              ),
              asKeyword: .keyword(.as, trailingTrivia: .space),
              type: TypeSyntax(stringLiteral: "SchemaCodingKey")
            ),
            trailingComma: .commaToken(trailingTrivia: .newline)
          )
        } else {
          /// key: nil,
          LabeledExprSyntax(
            label: "key",
            colon: .colonToken(),
            expression: NilLiteralExprSyntax(),
            trailingComma: .commaToken(trailingTrivia: .newline)
          )
        }

        /// schema: Schema(representing: <Type>.self),
        LabeledExprSyntax(
          label: "schema",
          colon: .colonToken(),
          expression: type.schema
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

  fileprivate static func schemaProperty(
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
          pattern: IdentifierPatternSyntax(identifier: "schema"),
          typeAnnotation: TypeAnnotationSyntax(
            type: SomeOrAnyTypeSyntax(
              someOrAnySpecifier: .keyword(.some),
              constraint: IdentifierTypeSyntax(
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

  var schema: some ExprSyntaxProtocol {
    FunctionCallExprSyntax(
      calledExpression: MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: "SchemaProvider"),
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

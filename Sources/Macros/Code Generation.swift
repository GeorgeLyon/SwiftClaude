import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - Schema Codable

extension SchemaCodableType {

  @MemberBlockItemListBuilder
  var members: MemberBlockItemListSyntax {
    switch schemaKind {
    case .struct(let schema):
      VariableDeclSyntax.schemaProperty(
        namespace: namespace,
        isPublic: isPublic,
        schemaProtocolName: schema.style == .wrapper ? "Schema" : "ObjectSchema",
        getter: {
          schema.expr(propertyNameConversionStrategy: keyConversionStrategy)
        }
      )

      InitializerDeclSyntax.schemaCodableStructInitializer(
        namespace: namespace,
        properties: schema.properties,
        style: schema.style
      )
    case .enum(let schema):
      VariableDeclSyntax.schemaProperty(
        namespace: namespace,
        isPublic: isPublic,
        schemaProtocolName: "Schema",
        getter: {
          schema.expr(caseNameConversionStrategy: keyConversionStrategy)
        }
      )
    }
  }

}

extension DeclSyntaxProtocol where Self == VariableDeclSyntax {

  fileprivate static func schemaProperty(
    namespace: SchemaCodingNamespace,
    isPublic: Bool,
    schemaProtocolName: TokenSyntax,
    @CodeBlockItemListBuilder getter: () -> CodeBlockItemListSyntax
  ) -> VariableDeclSyntax {
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
              constraint: namespace.memberType(
                name: schemaProtocolName,
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
              CodeBlockItemListSyntax(itemsBuilder: getter)
            )
          )
        )
      }
    )
  }

}

extension DeclSyntaxProtocol where Self == InitializerDeclSyntax {

  fileprivate static func schemaCodableStructInitializer(
    namespace: SchemaCodingNamespace,
    properties: [StructSchema.Property],
    style: StructStyleArgument?
  ) -> Self {
    let useSinglePropertyDecoder = properties.count == 1
    let decoderTypeName: TokenSyntax =
      useSinglePropertyDecoder ? "StructSinglePropertyDecoder" : "StructDecoder"

    return InitializerDeclSyntax(
      modifiers: .private,
      signature: FunctionSignatureSyntax(
        parameterClause: FunctionParameterClauseSyntax(
          parameters: FunctionParameterListSyntax {
            FunctionParameterSyntax(
              firstName: "structDecoder",
              type: namespace.memberType(
                name: decoderTypeName,
                genericArgumentClause: GenericArgumentClauseSyntax {
                  for property in properties {
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
        let propertyValues = properties.enumerated().map { index, _ in
          MemberAccessExprSyntax(
            base: MemberAccessExprSyntax(
              base: DeclReferenceExprSyntax(baseName: "structDecoder"),
              name: "propertyValues"
            ),
            name: "\(raw: index)"
          )
        }

        for (property, value) in zip(properties, propertyValues) {
          let accessExpr = MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: "self"),
            name: .identifier(property.name.name)
          )
          if property.isInitializedConstantProperty {
            FunctionCallExprSyntax(
              calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: "structDecoder"),
                name: "verifyInitializedConstantPropertyValue"
              ),
              leftParen: .leftParenToken(trailingTrivia: .newline),
              arguments: LabeledExprListSyntax {
                LabeledExprSyntax(
                  label: "initialized",
                  colon: .colonToken(),
                  expression: accessExpr
                )
                LabeledExprSyntax(
                  label: "decoded",
                  colon: .colonToken(),
                  expression: value
                )
              },
              rightParen: .rightParenToken(leadingTrivia: .newline),
            )
          } else {
            InfixOperatorExprSyntax(
              leftOperand: accessExpr,
              operator: AssignmentExprSyntax(),
              rightOperand: value
            )
          }
        }
      }
    )
  }

}

// MARK: - Schema Expressions

extension StructSchema {

  func expr(
    propertyNameConversionStrategy: KeyConversionStrategy
  ) -> FunctionCallExprSyntax {
    FunctionCallExprSyntax(
      calledExpression: namespace.supportMember(name: "structSchema"),
      leftParen: .leftParenToken(trailingTrivia: .newline),
      arguments: LabeledExprListSyntax {
        additionalArguments

        if let style {
          LabeledExprSyntax(
            label: "style",
            colon: .colonToken(),
            expression: MemberAccessExprSyntax(name: .identifier(style.rawValue)),
            trailingComma: .commaToken(trailingTrivia: .newline)
          )
        }

        LabeledExprSyntax(
          label: "properties",
          colon: .colonToken(),
          expression: ClosureExprSyntax {
            for property in properties {
              FunctionCallExprSyntax(
                calledExpression: namespace.supportMember(name: "structProperty"),
                leftParen: .leftParenToken(trailingTrivia: .newline),
                arguments: LabeledExprListSyntax {

                  LabeledExprSyntax(
                    label: "name",
                    colon: .colonToken(),
                    expression: StringLiteralExprSyntax(
                      content: propertyNameConversionStrategy.convert(property.name.identifier.name)
                    ),
                    trailingComma: .commaToken(trailingTrivia: .newline)
                  )

                  LabeledExprSyntax(
                    label: "keyPath",
                    colon: .colonToken(),
                    expression: KeyPathExprSyntax(
                      root: IdentifierTypeSyntax(name: typeName),
                      components: KeyPathComponentListSyntax {
                        KeyPathComponentSyntax(
                          period: .periodToken(),
                          component: .property(
                            KeyPathPropertyComponentSyntax(
                              declName: DeclReferenceExprSyntax(
                                baseName: .identifier(property.name.name))
                            )
                          )
                        )
                      }
                    ),
                    trailingComma: .commaToken(trailingTrivia: .newline)
                  )

                  LabeledExprSyntax(
                    label: "schema",
                    colon: .colonToken(),
                    expression: .schema(
                      namespace: namespace,
                      representing: property.type,
                      additionalArguments: property.additionalArguments
                    )
                  )

                },
                rightParen: .rightParenToken(leadingTrivia: .newline)
              )
            }

          },
          trailingComma: .commaToken(trailingTrivia: .newline)
        )

        LabeledExprSyntax(
          label: "finishDecoding",
          colon: .colonToken(),
          expression: MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(
              baseName: "Self"
            ),
            declName: DeclReferenceExprSyntax(
              baseName: "init",
              argumentNames: DeclNameArgumentsSyntax(
                arguments: DeclNameArgumentListSyntax {
                  DeclNameArgumentSyntax(name: "structDecoder")
                }
              )
            )
          )
        )
      },
      rightParen: .rightParenToken(leadingTrivia: .newline)
    )
  }

}

extension EnumSchema {

  func expr(
    caseNameConversionStrategy: KeyConversionStrategy
  ) -> FunctionCallExprSyntax {
    FunctionCallExprSyntax(
      calledExpression: namespace.supportMember(name: "enumSchema"),
      leftParen: .leftParenToken(trailingTrivia: .newline),
      arguments: LabeledExprListSyntax {
        additionalArguments

        LabeledExprSyntax(
          label: "cases",
          colon: .colonToken(),
          expression: ClosureExprSyntax {
            for `case` in cases {
              FunctionCallExprSyntax(
                calledExpression: namespace.supportMember(name: "enumSchemaCase"),
                leftParen: .leftParenToken(trailingTrivia: .newline),
                arguments: LabeledExprListSyntax {

                  LabeledExprSyntax(
                    label: "name",
                    colon: .colonToken(),
                    expression: StringLiteralExprSyntax(
                      content: caseNameConversionStrategy.convert(`case`.name.identifier.name)
                    ),
                    trailingComma: .commaToken(trailingTrivia: .newline)
                  )

                  `case`.additionalArguments

                  LabeledExprSyntax(
                    label: "associatedValues",
                    colon: .colonToken(),
                    expression: ClosureExprSyntax {
                      for associatedValue in `case`.associatedValues {
                        FunctionCallExprSyntax(
                          calledExpression: namespace.supportMember(
                            name: "enumSchemaCaseAssociatedValue"
                          ),
                          leftParen: .leftParenToken(trailingTrivia: .newline),
                          arguments: LabeledExprListSyntax {
                            if let label = associatedValue.argumentLabel {
                              LabeledExprSyntax(
                                label: "label",
                                colon: .colonToken(),
                                expression: StringLiteralExprSyntax(
                                  content: label.text
                                ),
                                trailingComma: .commaToken(trailingTrivia: .newline)
                              )
                            }

                            LabeledExprSyntax(
                              label: "schema",
                              colon: .colonToken(),
                              expression: .schema(
                                namespace: namespace,
                                representing: associatedValue.type,
                                additionalArguments: LabeledExprListSyntax()
                              )
                            )
                          },
                          rightParen: .rightParenToken(leadingTrivia: .newline)
                        )
                      }
                    },
                    trailingComma: .commaToken(trailingTrivia: .newline)
                  )

                  LabeledExprSyntax(
                    label: "finishDecoding",
                    colon: .colonToken(),
                    expression: `case`.finishDecodingClosure(namespace: namespace, typeName: typeName)
                  )
                },
                rightParen: .rightParenToken(leadingTrivia: .newline)
              )
            }
          },
          trailingComma: .commaToken(trailingTrivia: .newline)
        )

        LabeledExprSyntax(
          label: "encodeValue",
          colon: .colonToken(),
          expression: ClosureExprSyntax(
            signature: ClosureSignatureSyntax(
              parameterClause: .simpleInput(
                ClosureShorthandParameterListSyntax {
                  ClosureShorthandParameterSyntax(name: "value")
                  ClosureShorthandParameterSyntax(name: "encoder")
                }
              )
            ),
            statements: CodeBlockItemListSyntax {
              VariableDeclSyntax(
                bindingSpecifier: .keyword(.let),
                bindings: PatternBindingListSyntax {
                  PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: "encodings"),
                    initializer: InitializerClauseSyntax(
                      value: MemberAccessExprSyntax(
                        base: DeclReferenceExprSyntax(baseName: "encoder"),
                        name: "encodings"
                      )
                    )
                  )
                }
              )
              SwitchExprSyntax(
                subject: DeclReferenceExprSyntax(baseName: "value"),
                cases: SwitchCaseListSyntax {
                  for (offset, `case`) in cases.enumerated() {
                    SwitchCaseSyntax(
                      label: .case(
                        SwitchCaseLabelSyntax {
                          SwitchCaseItemListSyntax {
                            if `case`.associatedValues.isEmpty {
                              /// case .enumCase: …
                              SwitchCaseItemSyntax(
                                pattern: ExpressionPatternSyntax(
                                  expression: MemberAccessExprSyntax(
                                    name: .identifier(`case`.name.name)
                                  )
                                )
                              )
                            } else {
                              /// case .enumCase(…):
                              SwitchCaseItemSyntax(
                                pattern: ExpressionPatternSyntax(
                                  expression: FunctionCallExprSyntax(
                                    calledExpression: MemberAccessExprSyntax(
                                      name: .identifier(`case`.name.name)
                                    ),
                                    leftParen: .leftParenToken(),
                                    arguments: LabeledExprListSyntax {
                                      for associatedValue in `case`.associatedValues {
                                        LabeledExprSyntax(
                                          expression: PatternExprSyntax(
                                            pattern: ValueBindingPatternSyntax(
                                              bindingSpecifier: .keyword(.let),
                                              pattern: IdentifierPatternSyntax(
                                                identifier: associatedValue.bindingName
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
                            }
                          }
                        }
                      ),
                      statements: CodeBlockItemListSyntax {
                        VariableDeclSyntax(
                          bindingSpecifier: .keyword(.let),
                          bindings: PatternBindingListSyntax {
                            PatternBindingSyntax(
                              pattern: IdentifierPatternSyntax(identifier: "encoding"),
                              initializer: InitializerClauseSyntax(
                                value: MemberAccessExprSyntax(
                                  base: DeclReferenceExprSyntax(baseName: "encodings"),
                                  name: "\(raw: offset)"
                                )
                              )
                            )
                          }
                        )

                        /// encoder.encode(…)
                        FunctionCallExprSyntax(
                          calledExpression: MemberAccessExprSyntax(
                            base: DeclReferenceExprSyntax(baseName: "encoder"),
                            name: "encode"
                          ),
                          leftParen: .leftParenToken(),
                          arguments: LabeledExprListSyntax {
                            /// (…)
                            LabeledExprSyntax(
                              expression: TupleExprSyntax {
                                for associatedValue in `case`.associatedValues {
                                  LabeledExprSyntax(
                                    expression: DeclReferenceExprSyntax(
                                      baseName: associatedValue.bindingName
                                    )
                                  )
                                }
                              }
                            )

                            LabeledExprSyntax(
                              label: "using",
                              colon: .colonToken(),
                              expression: DeclReferenceExprSyntax(baseName: "encoding")
                            )
                          },
                          rightParen: .rightParenToken()
                        )
                      }
                    )
                  }
                }
              )
            }
          )
        )
      },
      rightParen: .rightParenToken(leadingTrivia: .newline),
    )
  }

}

extension ExprSyntaxProtocol where Self == FunctionCallExprSyntax {

  fileprivate static func schema(
    namespace: SchemaCodingNamespace,
    representing type: TypeSyntax,
    additionalArguments: LabeledExprListSyntax = LabeledExprListSyntax()
  ) -> Self {
    var arguments = LabeledExprListSyntax {
      LabeledExprSyntax(
        label: "representing",
        colon: .colonToken(),
        expression: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: "\(type.trimmed)"),
          name: "self"
        )
      )
      additionalArguments
    }
    arguments[arguments.indices.last!].trailingComma = nil
    return FunctionCallExprSyntax(
      calledExpression: namespace.supportMember(name: "schema"),
      leftParen: .leftParenToken(trailingTrivia: .newline),
      arguments: arguments,
      rightParen: .rightParenToken(leadingTrivia: .newline)
    )
  }

}

// MARK: - Enum Case finishDecoding

extension EnumSchema.Case {


  func finishDecodingClosure(
    namespace: SchemaCodingNamespace,
    typeName: TokenSyntax
  ) -> ClosureExprSyntax {
    let useSingleValueDecoder = associatedValues.count == 1
    let decoderTypeName: TokenSyntax =
      useSingleValueDecoder ? "EnumSingleAssociatedValueCaseDecoder" : "EnumCaseDecoder"

    return ClosureExprSyntax(
      signature: ClosureSignatureSyntax(
        parameterClause: .parameterClause(
          ClosureParameterClauseSyntax(
            parameters: ClosureParameterListSyntax {
              ClosureParameterSyntax(
                firstName: "decoder",
                colon: .colonToken(),
                type: namespace.memberType(
                  name: decoderTypeName,
                  genericArgumentClause: GenericArgumentClauseSyntax {
                    for associatedValue in associatedValues {
                      GenericArgumentSyntax(
                        argument: associatedValue.type
                      )
                    }
                  }
                )
              )
            }
          )
        )
      ),
      statements: CodeBlockItemListSyntax {
        if associatedValues.isEmpty {
          MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: typeName),
            name: name.token
          )
        } else {
          FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
              base: DeclReferenceExprSyntax(baseName: typeName),
              name: name.token
            ),
            leftParen: .leftParenToken(trailingTrivia: .newline),
            arguments: LabeledExprListSyntax {
              for (index, associatedValue) in associatedValues.enumerated() {
                LabeledExprSyntax(
                  label: associatedValue.argumentLabel,
                  colon: associatedValue.argumentLabel.map { _ in .colonToken() },
                  expression: MemberAccessExprSyntax(
                    base: MemberAccessExprSyntax(
                      base: DeclReferenceExprSyntax(baseName: "decoder"),
                      name: "associatedValues"
                    ),
                    name: "\(raw: index)"
                  )
                )
              }
            },
            rightParen: .rightParenToken(leadingTrivia: .newline)
          )
        }
      }
    )
  }

}

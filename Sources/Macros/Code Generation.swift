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
        isComplexSchema: schema.style != .wrapper,
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
        isComplexSchema: true,
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
    isComplexSchema: Bool,
    @CodeBlockItemListBuilder getter: () -> CodeBlockItemListSyntax
  ) -> VariableDeclSyntax {
    let schemaType = namespace.memberType(
      name: schemaProtocolName,
      genericArgumentClause: GenericArgumentClauseSyntax {
        GenericArgumentSyntax(
          argument: IdentifierTypeSyntax(name: "Self")
        )
      }
    )

    let constraintType: TypeSyntaxProtocol
    if isComplexSchema {
      constraintType = CompositionTypeSyntax(
        elements: CompositionTypeElementListSyntax {
          CompositionTypeElementSyntax(
            type: schemaType,
            ampersand: .binaryOperator("&")
          )
          CompositionTypeElementSyntax(
            type: namespace.supportMemberType(name: "ComplexSchema")
          )
        }
      )
    } else {
      constraintType = schemaType
    }

    return VariableDeclSyntax(
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
              constraint: TypeSyntax(fromProtocol: constraintType)
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
                            name: "parameter"
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
                    expression: `case`.finishDecodingClosure(
                      namespace: namespace, typeName: typeName)
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
                              expression: MemberAccessExprSyntax(
                                base: MemberAccessExprSyntax(
                                  base: DeclReferenceExprSyntax(baseName: "encoder"),
                                  name: "encodings"
                                ),
                                name: "\(raw: offset)"
                              )
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

// MARK: - Callable Schema Code Generation

extension CallableSchema {

  /// Generates the complete sidecar function declaration
  func sidecarFunction() -> FunctionDeclSyntax {
    FunctionDeclSyntax(
      modifiers: DeclModifierListSyntax {
        DeclModifierSyntax(name: .keyword(.static))
      },
      name: "__schema__\(raw: name.text)",
      signature: FunctionSignatureSyntax(
        parameterClause: sidecarParameterClause(),
        returnClause: ReturnClauseSyntax(
          type: callableSchemaReturnType()
        )
      ),
      body: CodeBlockSyntax {
        // let inputSchema = ...
        VariableDeclSyntax(
          bindingSpecifier: .keyword(.let),
          bindings: PatternBindingListSyntax {
            PatternBindingSyntax(
              pattern: IdentifierPatternSyntax(identifier: "inputSchema"),
              initializer: InitializerClauseSyntax(
                value: inputSchemaExpr()
              )
            )
          }
        )

        // let outputSchema = ...
        VariableDeclSyntax(
          bindingSpecifier: .keyword(.let),
          bindings: PatternBindingListSyntax {
            PatternBindingSyntax(
              pattern: IdentifierPatternSyntax(identifier: "outputSchema"),
              initializer: InitializerClauseSyntax(
                value: outputSchemaExpr()
              )
            )
          }
        )

        // return CallableSchema(...)
        ReturnStmtSyntax(
          expression: callableSchemaInitExpr()
        )
      }
    )
  }

  /// Generates parameters like: bar: Bool.Type = Bool.self, _ baz: Bool.Type = Bool.self
  private func sidecarParameterClause() -> FunctionParameterClauseSyntax {
    FunctionParameterClauseSyntax(
      parameters: FunctionParameterListSyntax {
        for param in parameters {
          FunctionParameterSyntax(
            firstName: param.firstName,
            secondName: param.secondName,
            type: MemberTypeSyntax(
              baseType: param.type,
              name: "Type"
            ),
            defaultValue: InitializerClauseSyntax(
              value: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: "\(param.type.trimmed)"),
                name: "self"
              )
            )
          )
        }
      }
    )
  }

  /// Generates the CallableSchema<...> return type
  private func callableSchemaReturnType() -> some TypeSyntaxProtocol {
    // Callee type: Void for standalone, Self for methods
    let calleeType: TypeSyntax = isMethod ? "Self" : "Void"

    // Input value type
    let inputValueType = tupleType(from: parameters.map(\.type))

    // Output value type
    let outputValueType = outputTupleType()

    // SyncInput: Never for async, inputValueType for sync
    let syncInputType: TypeSyntax = isAsync ? "Never" : inputValueType

    // Failure type
    let failureType = failureTypeSyntax()

    return namespace.supportMemberType(
      name: "CallableSchema",
      genericArgumentClause: GenericArgumentClauseSyntax {
        GenericArgumentSyntax(argument: calleeType)
        GenericArgumentSyntax(
          argument: TypeSyntax(
            SomeOrAnyTypeSyntax(
              someOrAnySpecifier: .keyword(.some),
              constraint: namespace.memberType(
                name: "Schema",
                genericArgumentClause: GenericArgumentClauseSyntax {
                  GenericArgumentSyntax(argument: inputValueType)
                }
              )
            )
          )
        )
        GenericArgumentSyntax(
          argument: TypeSyntax(
            SomeOrAnyTypeSyntax(
              someOrAnySpecifier: .keyword(.some),
              constraint: namespace.memberType(
                name: "Schema",
                genericArgumentClause: GenericArgumentClauseSyntax {
                  GenericArgumentSyntax(argument: outputValueType)
                }
              )
            )
          )
        )
        GenericArgumentSyntax(argument: syncInputType)
        GenericArgumentSyntax(argument: failureType)
      }
    )
  }

  /// Generates inputSchema = parameterClauseSchema { ... }
  private func inputSchemaExpr() -> FunctionCallExprSyntax {
    FunctionCallExprSyntax(
      calledExpression: namespace.supportMember(name: "parameterClauseSchema"),
      arguments: [],
      trailingClosure: ClosureExprSyntax(
        statements: CodeBlockItemListSyntax {
          for param in parameters {
            parameterCallExpr(
              label: param.isLabeled ? param.firstName.text : nil,
              type: param.type
            )
          }
        }
      )
    )
  }

  /// Generates outputSchema = parameterClauseSchema { ... }
  private func outputSchemaExpr() -> FunctionCallExprSyntax {
    FunctionCallExprSyntax(
      calledExpression: namespace.supportMember(name: "parameterClauseSchema"),
      arguments: [],
      trailingClosure: ClosureExprSyntax(
        statements: outputSchemaStatements()
      )
    )
  }

  private func outputSchemaStatements() -> CodeBlockItemListSyntax {
    switch returnType {
    case .void:
      // Empty closure for Void return
      return CodeBlockItemListSyntax()

    case .single(let type):
      // Single unlabeled parameter
      return CodeBlockItemListSyntax {
        parameterCallExpr(label: nil, type: type)
      }

    case .tuple(let elements):
      return CodeBlockItemListSyntax {
        for (label, type) in elements {
          let labelText: String? =
            if let label, label.tokenKind != .wildcard {
              label.text
            } else {
              nil
            }
          parameterCallExpr(label: labelText, type: type)
        }
      }
    }
  }

  /// Helper to generate a parameter(...) call
  private func parameterCallExpr(label: String?, type: TypeSyntax) -> FunctionCallExprSyntax {
    var arguments = LabeledExprListSyntax()

    if let label {
      arguments.append(
        LabeledExprSyntax(
          label: "label",
          colon: .colonToken(),
          expression: StringLiteralExprSyntax(content: label),
          trailingComma: .commaToken(trailingTrivia: .newline)
        )
      )
    }

    arguments.append(
      LabeledExprSyntax(
        label: "schema",
        colon: .colonToken(),
        expression: .schema(namespace: namespace, representing: type)
      )
    )

    return FunctionCallExprSyntax(
      calledExpression: namespace.supportMember(name: "parameter"),
      leftParen: .leftParenToken(trailingTrivia: .newline),
      arguments: arguments,
      rightParen: .rightParenToken(leadingTrivia: .newline)
    )
  }

  /// Generates CallableSchema(...) initializer call
  private func callableSchemaInitExpr() -> FunctionCallExprSyntax {
    // Build argument names for function reference
    var argumentNamesList = DeclNameArgumentListSyntax()
    for param in parameters {
      argumentNamesList.append(
        DeclNameArgumentSyntax(
          name: param.isLabeled ? param.firstName : .wildcardToken()
        )
      )
    }

    return FunctionCallExprSyntax(
      calledExpression: namespace.supportMember(name: "CallableSchema"),
      leftParen: .leftParenToken(trailingTrivia: .newline),
      arguments: LabeledExprListSyntax {
        // name: "foo(bar:_:)"
        LabeledExprSyntax(
          label: "name",
          colon: .colonToken(),
          expression: StringLiteralExprSyntax(content: fullName),
          trailingComma: .commaToken(trailingTrivia: .newline)
        )

        // inputSchema: inputSchema
        LabeledExprSyntax(
          label: "inputSchema",
          colon: .colonToken(),
          expression: DeclReferenceExprSyntax(baseName: "inputSchema"),
          trailingComma: .commaToken(trailingTrivia: .newline)
        )

        // outputSchema: outputSchema
        LabeledExprSyntax(
          label: "outputSchema",
          colon: .colonToken(),
          expression: DeclReferenceExprSyntax(baseName: "outputSchema"),
          trailingComma: .commaToken(trailingTrivia: .newline)
        )

        // invoke: foo(bar:_:)
        LabeledExprSyntax(
          label: "invoke",
          colon: .colonToken(),
          expression: DeclReferenceExprSyntax(
            baseName: name,
            argumentNames: DeclNameArgumentsSyntax(arguments: argumentNamesList)
          )
        )
      },
      rightParen: .rightParenToken(leadingTrivia: .newline)
    )
  }

  // MARK: - Helper Methods

  private func tupleType(from types: [TypeSyntax]) -> TypeSyntax {
    if types.isEmpty {
      return "Void"
    }
    if types.count == 1 {
      return types[0]
    }
    let elements = TupleTypeElementListSyntax {
      for type in types {
        TupleTypeElementSyntax(
          type: type
        )
      }
    }
    return TypeSyntax(TupleTypeSyntax(elements: elements))
  }

  private func outputTupleType() -> TypeSyntax {
    switch returnType {
    case .void:
      return "Void"
    case .single(let type):
      return type
    case .tuple(let elements):
      if elements.isEmpty {
        return "Void"
      }
      let tupleElements = TupleTypeElementListSyntax {
        for (_, type) in elements {
          TupleTypeElementSyntax(type: type)
        }
      }
      return TypeSyntax(TupleTypeSyntax(elements: tupleElements))
    }
  }

  private func failureTypeSyntax() -> TypeSyntax {
    guard let throwsClause else {
      return "Never"  // Non-throwing
    }

    if let typedError = throwsClause.type {
      return typedError  // Typed throws
    }

    // Untyped throws -> any Error
    return TypeSyntax(
      SomeOrAnyTypeSyntax(
        someOrAnySpecifier: .keyword(.any),
        constraint: IdentifierTypeSyntax(name: "Error")
      )
    )
  }

}

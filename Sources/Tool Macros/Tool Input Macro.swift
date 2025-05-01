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
    do {
      return try [
        .toolInputConformance(for: declaration, of: type)
      ]
    } catch let error as DiagnosticError {
      context.diagnose(error.diagnostic)
      return []
    }
  }

}

// MARK: - Implementation Details

extension ExtensionDeclSyntax {

  fileprivate static func toolInputConformance(
    for declaration: some DeclGroupSyntax,
    of type: some TypeSyntaxProtocol
  ) throws -> ExtensionDeclSyntax {
    let memberModifiers = declaration.accessModifiersForRequiredMembers

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
      if let structDecl = declaration.as(StructDeclSyntax.self) {
        try structDecl.toolInputMembers
      } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
        enumDecl.toolInputMembers
      } else {
        throw DiagnosticError(
          node: declaration,
          severity: .error,
          message: "Unsupported declaration of kind: \(declaration.kind)"
        )
      }
    }
  }

}

// MARK: Struct

extension StructDeclSyntax {

  fileprivate var toolInputMembers: MemberBlockItemListSyntax {
    get throws {
      let storedProperties = try self.storedProperties

      /// var toolInputSchema: some ToolInput.Schema<Self> { … }
      let toolInputSchemaProperty: VariableDeclSyntax = .toolInputSchema {
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
            descriptionArgument

            /// keyedBy: ToolInputSchemaPropertyKey.self
            LabeledExprSyntax(
              label: "keyedBy",
              colon: .colonToken(),
              expression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(
                  baseName: "ToolInputSchemaPropertyKey"
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
                      expression: property.structSchemaPropertyArgument
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
          name: "ToolInputSchemaPropertyKey",
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
          /// self.propertyName = structSchemaDecoder.propertyValues.0
          for (index, property) in storedProperties.enumerated() {
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
                name: "\(raw: index)"
              )
            )
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

}

// MARK: Struct Properties

extension StructDeclSyntax {

  fileprivate struct StoredProperty {
    let name: TokenSyntax
    let type: TypeSyntax
    let comment: String?
  }

  fileprivate var storedProperties: some Sequence<StoredProperty> {
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

  fileprivate var structSchemaPropertyArgument: some ExprSyntaxProtocol {
    TupleExprSyntax(
      leftParen: .leftParenToken(leadingTrivia: .newline, trailingTrivia: .newline),
      elements: LabeledExprListSyntax {
        /// description
        if let description = comment {
          LabeledExprSyntax(
            label: "description",
            colon: .colonToken(),
            expression: StringLiteralExprSyntax(
              openingQuote: .multilineStringQuoteToken(),
              content: description,
              closingQuote: .multilineStringQuoteToken()
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

        /// key: ToolInputSchemaPropertyKey.propertyName
        LabeledExprSyntax(
          label: "key",
          colon: .colonToken(),
          expression: MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(
              baseName: "ToolInputSchemaPropertyKey"
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

  var toolInputMembers: MemberBlockItemListSyntax {
    let caseDecls = memberBlock
      .members
      .compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }

    let toolInputSchemaProperty: VariableDeclSyntax = .toolInputSchema {
      /// let <case>AssociatedValuesSchema = ToolInput.enumCaseAssociatedValuesSchema(…)
      for caseDeclElement in caseDecls.flatMap(\.elements) {
        caseDeclElement.associatedValuesSchema
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
                base: DeclReferenceExprSyntax(
                  baseName: "ToolInputSchemaCaseKey"
                ),
                name: "self"
              ),
              trailingComma: .commaToken(trailingTrivia: .newline)
            )

            /// cases: (…)
            LabeledExprSyntax(
              label: "cases",
              colon: .colonToken(),
              expression: TupleExprSyntax(
                leftParen: .leftParenToken(trailingTrivia: .newline),
                elements: LabeledExprListSyntax {
                  for caseDecl in caseDecls {
                    let descriptionArgument = caseDecl.descriptionArgument
                    for element in caseDecl.elements {
                      LabeledExprSyntax(
                        expression: element.enumSchemaCaseArgument(
                          descriptionArgument: descriptionArgument
                        ),
                        trailingComma: .commaToken(trailingTrivia: .newline)
                      )
                    }
                  }
                },
                rightParen: .rightParenToken(leadingTrivia: .newline)
              )
            )

          }
        )
      )
    }

    return MemberBlockItemListSyntax {
      toolInputSchemaProperty
    }
  }

}

extension EnumCaseElementListSyntax.Element {

  fileprivate var associatedValuesSchema: VariableDeclSyntax {
    VariableDeclSyntax(
      bindingSpecifier: .keyword(.let),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: associatedValuesSchemaName),
          initializer: InitializerClauseSyntax(
            value: FunctionCallExprSyntax(
              calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: "ToolInput"),
                name: "enumCaseAssociatedValuesSchema"
              ),
              leftParen: .leftParenToken(trailingTrivia: .newline),
              arguments: LabeledExprListSyntax {
                let associatedValuesKey = MemberAccessExprSyntax(
                  base: DeclReferenceExprSyntax(baseName: "ToolInputSchemaCaseKey"),
                  name: "AssociatedValue\(name)"
                )

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

                /// keyedBy: ToolInputSchemaCaseKey.AssociatedValue<case>.self
                LabeledExprSyntax(
                  label: "keyedBy",
                  colon: .colonToken(),
                  expression: MemberAccessExprSyntax(
                    base: associatedValuesKey,
                    name: "self"
                  )
                )
              },
              rightParen: .rightParenToken()
            )
          )
        )
      }
    )
  }

  fileprivate func enumSchemaCaseArgument(
    descriptionArgument: LabeledExprSyntax
  ) -> TupleExprSyntax {
    TupleExprSyntax(
      leftParen: .leftParenToken(trailingTrivia: .newline),
      elements: LabeledExprListSyntax {
        /// key: ToolInputSchemaCaseKey.first,
        LabeledExprSyntax(
          label: "key",
          colon: .colonToken(),
          expression: MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: "ToolInputSchemaCaseKey"),
            name: name
          ),
          trailingComma: .commaToken(trailingTrivia: .newline)
        )

        /// description: "A string",
        descriptionArgument

        /// associatedValuesSchema: associatedValues_first,
        LabeledExprSyntax(
          label: "associatedValuesSchema",
          colon: .colonToken(),
          expression: DeclReferenceExprSyntax(baseName: associatedValuesSchemaName),
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
                },
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

  private var associatedValuesSchemaName: TokenSyntax {
    "\(name)AssociatedValuesSchema"
  }

}

extension EnumCaseParameterListSyntax.Element {

  fileprivate func associatedValuesSchemaArgument(key: some ExprSyntaxProtocol) -> TupleExprSyntax {
    TupleExprSyntax(
      leftParen: .leftParenToken(trailingTrivia: .newline),
      elements: LabeledExprListSyntax {
        if let name = secondName ?? firstName {
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
      rightParen: .rightParenToken(leadingTrivia: .newline)
    )
  }

}

// MARK: Shared

extension VariableDeclSyntax {

  fileprivate static func toolInputSchema(
    @CodeBlockItemListBuilder _ builder: () -> CodeBlockItemListSyntax
  )
    -> Self
  {
    VariableDeclSyntax(
      modifiers: DeclModifierListSyntax {
        DeclModifierSyntax(name: .keyword(.static))
      },
      bindingSpecifier: .keyword(.var)
    ) {
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

extension DeclModifierListSyntax {

  fileprivate static var `private`: Self {
    DeclModifierListSyntax {
      DeclModifierSyntax(name: .keyword(.private))
    }
  }

}

extension SyntaxProtocol {

  fileprivate var descriptionArgument: LabeledExprSyntax {
    /// description: ...
    if let comment {
      LabeledExprSyntax(
        label: "description",
        colon: .colonToken(),
        expression: StringLiteralExprSyntax(
          openingQuote: .multilineStringQuoteToken(),
          content: comment,
          closingQuote: .multilineStringQuoteToken()
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
  }

}

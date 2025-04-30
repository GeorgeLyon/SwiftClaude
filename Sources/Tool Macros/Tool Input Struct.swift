import SwiftSyntax
import SwiftSyntaxBuilder

extension StructDeclSyntax {

  var toolInputMembers: MemberBlockItemListSyntax {
    get throws {
      let storedProperties = try self.storedProperties

      /// var toolInputSchema: some ToolInput.Schema<Self> { … }
      let toolInputSchemaProperty = 
        VariableDeclSyntax(
          modifiers: DeclModifierListSyntax {
            DeclModifierSyntax(name: .keyword(.static))
          },
          bindingSpecifier: .keyword(.var)
        ) {
          PatternBindingSyntax(
            pattern: IdentifierPatternSyntax(identifier: "toolInputSchema"),
            typeAnnotation: .someSchemaOfSelf,
            accessorBlock: AccessorBlockSyntax(
              accessors: .getter(
                CodeBlockItemListSyntax {
                  FunctionCallExprSyntax(
                    calledExpression: MemberAccessExprSyntax(
                      base: DeclReferenceExprSyntax(baseName: "ToolInput"),
                      name: "structSchema"
                    ),
                    leftParen: .leftParenToken(trailingTrivia: .newline),
                    arguments: LabeledExprListSyntax {
                      /// representing
                      LabeledExprSyntax(
                        label: "representing",
                        colon: .colonToken(),
                        expression: MemberAccessExprSyntax(
                          base: DeclReferenceExprSyntax(baseName: "Self"),
                          name: "self"
                        ),
                        trailingComma: .commaToken(trailingTrivia: .newline)
                      )

                      /// description
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

                      /// keyedBy
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

                      /// properties
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

                      /// initializer
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
              )
            )
          )
        }
        
      /// private enum ToolInputSchemaPropertyKey: CodingKey { … }
      let propertyKeyEnum = 
        EnumDeclSyntax(
          modifiers: DeclModifierListSyntax {
            DeclModifierSyntax(name: .keyword(.private))
          },
          identifier: "ToolInputSchemaPropertyKey",
          inheritanceClause: InheritanceClauseSyntax(
            colon: .colonToken(),
            inheritedType: MemberTypeSyntax(
              baseType: IdentifierTypeSyntax(name: "CodingKey")
            )
          ),
          memberBlock: CodeBlockSyntax {
            for property in storedProperties {
              EnumCaseDeclSyntax(
                caseKeyword: .caseToken(trailingTrivia: .newline),
                identifier: property.name,
                trailingComma: .commaToken(trailingTrivia: .newline)
              )
            }
          }
        )
      }

      return MemberBlockItemListSyntax {
        toolInputSchemaProperty
    }
  }

}

// MARK: - Implementation Details

extension TypeAnnotationSyntax {

  fileprivate static var someSchemaOfSelf: Self {
    TypeAnnotationSyntax(
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
    )
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

        /// keyPath: \Self.propertName
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

        /// schema
        LabeledExprSyntax(
          label: "schema",
          colon: .colonToken(),
          expression: FunctionCallExprSyntax(
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
                  base: DeclReferenceExprSyntax(baseName: "\(raw: type.trimmed)"),
                  name: "self"
                )
              )
            },
            rightParen: .rightParenToken(),
            trailingTrivia: .newline
          )

        )
      }
    )
  }

}

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

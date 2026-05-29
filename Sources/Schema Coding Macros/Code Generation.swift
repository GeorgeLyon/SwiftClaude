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
      if schema.style == .wrapper {
        VariableDeclSyntax.schemaProperty(
          namespace: namespace,
          isPublic: isPublic,
          schemaProtocolName: "Schema",
          isComplexSchema: false,
          getter: {
            schema.expr(propertyNameConversionStrategy: keyConversionStrategy)
          }
        )

        InitializerDeclSyntax.schemaCodableStructInitializer(
          namespace: namespace,
          properties: schema.properties,
          style: schema.style
        )
      } else {
        VariableDeclSyntax.objectSchemaProperty(isPublic: isPublic)

        StructDeclSyntax.objectSchemaStruct(
          schema: schema,
          valueType: typeSyntax,
          isPublic: isPublic,
          keyConversionStrategy: keyConversionStrategy
        )
      }
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

// MARK: - Schema Parameter

extension SchemaParameter {

  /// Generates a `parameter(label: "...", schema: ...)` call
  func parameterCallExpr(
    namespace: SchemaCodingNamespace,
    keyConversionStrategy: KeyConversionStrategy
  ) -> FunctionCallExprSyntax {
    var arguments = LabeledExprListSyntax()

    if let label {
      arguments.append(
        LabeledExprSyntax(
          label: "label",
          colon: .colonToken(),
          expression: StringLiteralExprSyntax(
            content: keyConversionStrategy.convert(label.text)
          ),
          trailingComma: .commaToken(trailingTrivia: .newline)
        )
      )
    }

    arguments.append(
      LabeledExprSyntax(
        label: "schema",
        colon: .colonToken(),
        expression: .schema(namespace: namespace, representing: type.syntax)
      )
    )

    return FunctionCallExprSyntax(
      calledExpression: namespace.supportMember(name: "parameter"),
      leftParen: .leftParenToken(trailingTrivia: .newline),
      arguments: arguments,
      rightParen: .rightParenToken(leadingTrivia: .newline)
    )
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
          argument: GenericArgumentSyntax.Argument(IdentifierTypeSyntax(name: "Self"))
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

extension DeclSyntaxProtocol where Self == VariableDeclSyntax {

  fileprivate static func objectSchemaProperty(
    isPublic: Bool
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
            type: IdentifierTypeSyntax(name: "Schema")
          ),
          accessorBlock: AccessorBlockSyntax(
            accessors: .getter(
              CodeBlockItemListSyntax {
                FunctionCallExprSyntax(
                  calledExpression: DeclReferenceExprSyntax(baseName: "Schema"),
                  leftParen: .leftParenToken(),
                  arguments: LabeledExprListSyntax(),
                  rightParen: .rightParenToken()
                )
              }
            )
          )
        )
      }
    )
  }

}

extension DeclSyntaxProtocol where Self == StructDeclSyntax {

  fileprivate static func objectSchemaStruct(
    schema: StructSchema,
    valueType: TypeSyntax,
    isPublic: Bool,
    keyConversionStrategy: KeyConversionStrategy
  ) -> StructDeclSyntax {
    let ns = schema.namespace
    let properties = schema.properties

    return StructDeclSyntax(
      modifiers: DeclModifierListSyntax {
        if isPublic {
          DeclModifierSyntax(name: "public")
        }
      },
      name: "Schema",
      inheritanceClause: InheritanceClauseSyntax {
        InheritedTypeSyntax(
          type: ns.supportMemberType(name: "ObjectSchema")
        )
      }
    ) {
      // typealias Value = {valueType}
      TypeAliasDeclSyntax(
        modifiers: DeclModifierListSyntax {
          if isPublic {
            DeclModifierSyntax(name: "public")
          }
        },
        name: "Value",
        initializer: TypeInitializerClauseSyntax(
          value: valueType
        )
      )

      // typealias {PA} = {Type}.Schema.ObjectProperty per property
      for property in properties {
        TypeAliasDeclSyntax(
          modifiers: DeclModifierListSyntax {
            if isPublic {
              DeclModifierSyntax(name: "public")
            }
          },
          name: property.propertyTypeAliasName,
          initializer: TypeInitializerClauseSyntax(
            value: MemberTypeSyntax(
              baseType: MemberTypeSyntax(
                baseType: IdentifierTypeSyntax(
                  name: "\(property.type.syntax.trimmed)"
                ),
                name: "Schema"
              ),
              name: "ObjectProperty"
            )
          )
        )
      }

      // typealias ObjectPropertyTypeMetadatas = (...)
      TypeAliasDeclSyntax(
        modifiers: DeclModifierListSyntax {
          if isPublic {
            DeclModifierSyntax(name: "public")
          }
        },
        name: "ObjectPropertyTypeMetadatas",
        initializer: TypeInitializerClauseSyntax(
          value: TupleTypeSyntax(
            elements: TupleTypeElementListSyntax {
              for property in properties {
                TupleTypeElementSyntax(
                  type: ns.supportMemberType(
                    name: "ObjectPropertyTypeMetadata",
                    genericArgumentClause: GenericArgumentClauseSyntax {
                      GenericArgumentSyntax(
                        argument: GenericArgumentSyntax.Argument(IdentifierTypeSyntax(name: "Value"))
                      )
                      GenericArgumentSyntax(
                        argument: GenericArgumentSyntax.Argument(IdentifierTypeSyntax(
                          name: property.propertyTypeAliasName
                        ))
                      )
                    }
                  )
                )
              }
            }
          )
        )
      )

      // static func propertyTypeMetadatas() -> ObjectPropertyTypeMetadatas
      FunctionDeclSyntax(
        modifiers: DeclModifierListSyntax {
          if isPublic {
            DeclModifierSyntax(name: "public")
          }
          DeclModifierSyntax(name: .keyword(.static))
        },
        name: "propertyTypeMetadatas",
        signature: FunctionSignatureSyntax(
          parameterClause: FunctionParameterClauseSyntax(
            parameters: FunctionParameterListSyntax()
          ),
          returnClause: ReturnClauseSyntax(
            type: IdentifierTypeSyntax(name: "ObjectPropertyTypeMetadatas")
          )
        ),
        body: CodeBlockSyntax {
          TupleExprSyntax {
            for property in properties {
              LabeledExprSyntax(
                expression: FunctionCallExprSyntax(
                  calledExpression: ns.supportMember(name: "ObjectPropertyTypeMetadata"),
                  leftParen: .leftParenToken(trailingTrivia: .newline),
                  arguments: LabeledExprListSyntax {
                    LabeledExprSyntax(
                      label: "name",
                      colon: .colonToken(),
                      expression: StringLiteralExprSyntax(
                        content: keyConversionStrategy.convert(
                          property.name.identifier.name
                        )
                      ),
                      trailingComma: .commaToken(trailingTrivia: .newline)
                    )
                    LabeledExprSyntax(
                      label: "keyPath",
                      colon: .colonToken(),
                      expression: KeyPathExprSyntax(
                        root: IdentifierTypeSyntax(name: "Value"),
                        components: KeyPathComponentListSyntax {
                          KeyPathComponentSyntax(
                            period: .periodToken(),
                            component: .property(
                              KeyPathPropertyComponentSyntax(
                                declName: DeclReferenceExprSyntax(
                                  baseName: .identifier(property.name.name)
                                )
                              )
                            )
                          )
                        }
                      )
                    )
                  },
                  rightParen: .rightParenToken(leadingTrivia: .newline)
                )
              )
            }
          }
        }
      )

      // typealias Properties = ({PA1}, {PA2}, ...)
      TypeAliasDeclSyntax(
        modifiers: DeclModifierListSyntax {
          if isPublic {
            DeclModifierSyntax(name: "public")
          }
        },
        name: "Properties",
        initializer: TypeInitializerClauseSyntax(
          value: TupleTypeSyntax(
            elements: TupleTypeElementListSyntax {
              for property in properties {
                TupleTypeElementSyntax(
                  type: IdentifierTypeSyntax(
                    name: property.propertyTypeAliasName
                  )
                )
              }
            }
          )
        )
      )

      // static func create(from properties: Properties) -> Self
      FunctionDeclSyntax(
        modifiers: DeclModifierListSyntax {
          if isPublic {
            DeclModifierSyntax(name: "public")
          }
          DeclModifierSyntax(name: .keyword(.static))
        },
        name: "create",
        signature: FunctionSignatureSyntax(
          parameterClause: FunctionParameterClauseSyntax(
            parameters: FunctionParameterListSyntax {
              FunctionParameterSyntax(
                firstName: "from",
                secondName: "properties",
                type: IdentifierTypeSyntax(name: "Properties")
              )
            }
          ),
          returnClause: ReturnClauseSyntax(
            type: IdentifierTypeSyntax(name: "Self")
          )
        ),
        body: CodeBlockSyntax {
          FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(baseName: "Self"),
            leftParen: .leftParenToken(trailingTrivia: .newline),
            arguments: LabeledExprListSyntax {
              /// A single-element parenthesized type collapses to its element, so
              /// `properties` is the value itself rather than a tuple — pass it
              /// directly instead of accessing `.0`.
              if properties.count == 1 {
                LabeledExprSyntax(
                  expression: DeclReferenceExprSyntax(baseName: "properties")
                )
              } else {
                for (index, _) in properties.enumerated() {
                  LabeledExprSyntax(
                    expression: MemberAccessExprSyntax(
                      base: DeclReferenceExprSyntax(baseName: "properties"),
                      name: "\(raw: index)"
                    )
                  )
                }
              }
            },
            rightParen: .rightParenToken(leadingTrivia: .newline)
          )
        }
      )

      // func properties() -> Properties
      FunctionDeclSyntax(
        modifiers: DeclModifierListSyntax {
          if isPublic {
            DeclModifierSyntax(name: "public")
          }
        },
        name: "properties",
        signature: FunctionSignatureSyntax(
          parameterClause: FunctionParameterClauseSyntax(
            parameters: FunctionParameterListSyntax()
          ),
          returnClause: ReturnClauseSyntax(
            type: IdentifierTypeSyntax(name: "Properties")
          )
        ),
        body: CodeBlockSyntax {
          TupleExprSyntax {
            for property in properties {
              LabeledExprSyntax(
                expression: DeclReferenceExprSyntax(
                  baseName: property.storedPropertyName
                )
              )
            }
          }
        }
      )

      // typealias PropertyValues = ({Type1}, {Type2}, ...)
      TypeAliasDeclSyntax(
        modifiers: DeclModifierListSyntax {
          if isPublic {
            DeclModifierSyntax(name: "public")
          }
        },
        name: "PropertyValues",
        initializer: TypeInitializerClauseSyntax(
          value: TupleTypeSyntax(
            elements: TupleTypeElementListSyntax {
              for property in properties {
                TupleTypeElementSyntax(
                  type: property.type.syntax
                )
              }
            }
          )
        )
      )

      // static func value(from propertyValues: PropertyValues) throws -> Value
      FunctionDeclSyntax(
        modifiers: DeclModifierListSyntax {
          if isPublic {
            DeclModifierSyntax(name: "public")
          }
          DeclModifierSyntax(name: .keyword(.static))
        },
        name: "value",
        signature: FunctionSignatureSyntax(
          parameterClause: FunctionParameterClauseSyntax(
            parameters: FunctionParameterListSyntax {
              FunctionParameterSyntax(
                firstName: "from",
                secondName: "propertyValues",
                type: IdentifierTypeSyntax(name: "PropertyValues")
              )
            }
          ),
          effectSpecifiers: FunctionEffectSpecifiersSyntax(
            throwsClause: ThrowsClauseSyntax(
              throwsSpecifier: .keyword(.throws)
            )
          ),
          returnClause: ReturnClauseSyntax(
            type: IdentifierTypeSyntax(name: "Value")
          )
        ),
        body: CodeBlockSyntax {
          // let value = Value(nonConstantProp1: propertyValues.0, ...)
          VariableDeclSyntax(
            bindingSpecifier: .keyword(.let)
          ) {
            PatternBindingSyntax(
              pattern: IdentifierPatternSyntax(identifier: "value"),
              initializer: InitializerClauseSyntax(
                value: FunctionCallExprSyntax(
                  calledExpression: DeclReferenceExprSyntax(baseName: "Value"),
                  leftParen: .leftParenToken(trailingTrivia: .newline),
                  arguments: LabeledExprListSyntax {
                    /// A single-element parenthesized type collapses to its element,
                    /// so `propertyValues` is the value itself rather than a tuple —
                    /// pass it directly instead of accessing `.0`.
                    if properties.count == 1, let property = properties.first,
                      !property.isInitializedConstantProperty
                    {
                      LabeledExprSyntax(
                        label: .identifier(property.name.name),
                        colon: .colonToken(),
                        expression: DeclReferenceExprSyntax(baseName: "propertyValues")
                      )
                    } else {
                      for (index, property) in properties.enumerated()
                      where !property.isInitializedConstantProperty {
                        LabeledExprSyntax(
                          label: .identifier(property.name.name),
                          colon: .colonToken(),
                          expression: MemberAccessExprSyntax(
                            base: DeclReferenceExprSyntax(baseName: "propertyValues"),
                            name: "\(raw: index)"
                          )
                        )
                      }
                    }
                  },
                  rightParen: .rightParenToken(leadingTrivia: .newline)
                )
              )
            )
          }
          // try Self.validate(constantPropertyValue: value.X, isEqualToDecodedValue: propertyValues.N)
          for (index, property) in properties.enumerated()
          where property.isInitializedConstantProperty {
            TryExprSyntax(
              expression: FunctionCallExprSyntax(
                calledExpression: ns.supportMember(name: "validate"),
                leftParen: .leftParenToken(trailingTrivia: .newline),
                arguments: LabeledExprListSyntax {
                  LabeledExprSyntax(
                    label: "constantPropertyValue",
                    colon: .colonToken(),
                    expression: MemberAccessExprSyntax(
                      base: DeclReferenceExprSyntax(baseName: "value"),
                      name: "\(raw: property.name.name)"
                    )
                  )
                  LabeledExprSyntax(
                    label: "isEqualToDecodedValue",
                    colon: .colonToken(),
                    expression: MemberAccessExprSyntax(
                      base: DeclReferenceExprSyntax(baseName: "propertyValues"),
                      name: "\(raw: index)"
                    )
                  )
                },
                rightParen: .rightParenToken(leadingTrivia: .newline)
              )
            )
          }
          // return value
          ReturnStmtSyntax(
            expression: DeclReferenceExprSyntax(baseName: "value")
          )
        }
      )

      // static func propertyValues(from value: Value) -> PropertyValues
      FunctionDeclSyntax(
        modifiers: DeclModifierListSyntax {
          if isPublic {
            DeclModifierSyntax(name: "public")
          }
          DeclModifierSyntax(name: .keyword(.static))
        },
        name: "propertyValues",
        signature: FunctionSignatureSyntax(
          parameterClause: FunctionParameterClauseSyntax(
            parameters: FunctionParameterListSyntax {
              FunctionParameterSyntax(
                firstName: "from",
                secondName: "value",
                type: IdentifierTypeSyntax(name: "Value")
              )
            }
          ),
          returnClause: ReturnClauseSyntax(
            type: IdentifierTypeSyntax(name: "PropertyValues")
          )
        ),
        body: CodeBlockSyntax {
          TupleExprSyntax {
            for property in properties {
              LabeledExprSyntax(
                expression: MemberAccessExprSyntax(
                  base: DeclReferenceExprSyntax(baseName: "value"),
                  name: .identifier(property.name.name)
                )
              )
            }
          }
        }
      )

      // typealias MetaSchema = {ns}.Support.ObjectMetaSchema<Self, {PA1}, {PA2}, ...>
      TypeAliasDeclSyntax(
        modifiers: DeclModifierListSyntax {
          if isPublic {
            DeclModifierSyntax(name: "public")
          }
        },
        name: "MetaSchema",
        initializer: TypeInitializerClauseSyntax(
          value: TypeSyntax(
            fromProtocol: ns.supportMemberType(
              name: "ObjectMetaSchema",
              genericArgumentClause: GenericArgumentClauseSyntax {
                GenericArgumentSyntax(
                  argument: GenericArgumentSyntax.Argument(IdentifierTypeSyntax(name: "Self"))
                )
                for property in properties {
                  GenericArgumentSyntax(
                    argument: GenericArgumentSyntax.Argument(IdentifierTypeSyntax(
                      name: property.propertyTypeAliasName
                    ))
                  )
                }
              }
            )
          )
        )
      )

      // var metaSchema: MetaSchema { _metaSchema() }
      VariableDeclSyntax(
        modifiers: DeclModifierListSyntax {
          if isPublic {
            DeclModifierSyntax(name: "public")
          }
        },
        bindingSpecifier: .keyword(.var),
        bindings: PatternBindingListSyntax {
          PatternBindingSyntax(
            pattern: IdentifierPatternSyntax(identifier: "metaSchema"),
            typeAnnotation: TypeAnnotationSyntax(
              type: IdentifierTypeSyntax(name: "MetaSchema")
            ),
            accessorBlock: AccessorBlockSyntax(
              accessors: .getter(
                CodeBlockItemListSyntax {
                  FunctionCallExprSyntax(
                    calledExpression: DeclReferenceExprSyntax(
                      baseName: "_metaSchema"
                    ),
                    leftParen: .leftParenToken(),
                    arguments: LabeledExprListSyntax(),
                    rightParen: .rightParenToken()
                  )
                }
              )
            )
          )
        }
      )

      // func initialValueForDecoding(isMutable: Bool) -> Value? { _initialValueForDecoding(isMutable: isMutable) }
      FunctionDeclSyntax(
        modifiers: DeclModifierListSyntax {
          if isPublic {
            DeclModifierSyntax(name: "public")
          }
        },
        name: "initialValueForDecoding",
        signature: FunctionSignatureSyntax(
          parameterClause: FunctionParameterClauseSyntax(
            parameters: FunctionParameterListSyntax {
              FunctionParameterSyntax(
                firstName: "isMutable",
                type: IdentifierTypeSyntax(name: "Bool")
              )
            }
          ),
          returnClause: ReturnClauseSyntax(
            type: OptionalTypeSyntax(
              wrappedType: IdentifierTypeSyntax(name: "Value")
            )
          )
        ),
        body: CodeBlockSyntax {
          FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(
              baseName: "_initialValueForDecoding"
            ),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax {
              LabeledExprSyntax(
                label: "isMutable",
                colon: .colonToken(),
                expression: DeclReferenceExprSyntax(baseName: "isMutable")
              )
            },
            rightParen: .rightParenToken()
          )
        }
      )

      // var metadata = {ns}.Support.SchemaMetadata()
      VariableDeclSyntax(
        modifiers: DeclModifierListSyntax {
          if isPublic {
            DeclModifierSyntax(name: "public")
          }
        },
        bindingSpecifier: .keyword(.var),
        bindings: PatternBindingListSyntax {
          PatternBindingSyntax(
            pattern: IdentifierPatternSyntax(identifier: "metadata"),
            initializer: InitializerClauseSyntax(
              value: FunctionCallExprSyntax(
                calledExpression: ns.supportMember(name: "SchemaMetadata"),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax(),
                rightParen: .rightParenToken()
              )
            )
          )
        }
      )

      // private let {sp}: {PA} per property
      for property in properties {
        VariableDeclSyntax(
          modifiers: .private,
          bindingSpecifier: .keyword(.let),
          bindings: PatternBindingListSyntax {
            PatternBindingSyntax(
              pattern: IdentifierPatternSyntax(
                identifier: property.storedPropertyName
              ),
              typeAnnotation: TypeAnnotationSyntax(
                type: IdentifierTypeSyntax(
                  name: property.propertyTypeAliasName
                )
              )
            )
          }
        )
      }

      // init() — self.{sp} = {PA}(schema: {Type}.schema)
      InitializerDeclSyntax(
        modifiers: DeclModifierListSyntax {
          if isPublic {
            DeclModifierSyntax(name: "public")
          }
        },
        signature: FunctionSignatureSyntax(
          parameterClause: FunctionParameterClauseSyntax(
            parameters: FunctionParameterListSyntax()
          )
        ),
        body: CodeBlockSyntax {
          for property in properties {
            InfixOperatorExprSyntax(
              leftOperand: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: "self"),
                name: property.storedPropertyName
              ),
              operator: AssignmentExprSyntax(),
              rightOperand: FunctionCallExprSyntax(
                calledExpression: DeclReferenceExprSyntax(
                  baseName: property.propertyTypeAliasName
                ),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax {
                  LabeledExprSyntax(
                    label: "schema",
                    colon: .colonToken(),
                    expression: MemberAccessExprSyntax(
                      base: DeclReferenceExprSyntax(
                        baseName: "\(property.type.syntax.trimmed)"
                      ),
                      name: "schema"
                    )
                  )
                },
                rightParen: .rightParenToken()
              )
            )
          }
        }
      )

      // private init(_ sp0: PA0, _ sp1: PA1, ...) — memberwise init for create(from:)
      InitializerDeclSyntax(
        modifiers: .private,
        signature: FunctionSignatureSyntax(
          parameterClause: FunctionParameterClauseSyntax(
            parameters: FunctionParameterListSyntax {
              for property in properties {
                FunctionParameterSyntax(
                  firstName: .wildcardToken(),
                  secondName: property.storedPropertyName,
                  type: IdentifierTypeSyntax(
                    name: property.propertyTypeAliasName
                  )
                )
              }
            }
          )
        ),
        body: CodeBlockSyntax {
          for property in properties {
            InfixOperatorExprSyntax(
              leftOperand: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: "self"),
                name: property.storedPropertyName
              ),
              operator: AssignmentExprSyntax(),
              rightOperand: DeclReferenceExprSyntax(
                baseName: property.storedPropertyName
              )
            )
          }
        }
      )
    }
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
                      argument: GenericArgumentSyntax.Argument(property.type.syntax)
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
                      representing: property.type.syntax,
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
                        associatedValue.parameterCallExpr(
                          namespace: namespace,
                          keyConversionStrategy: keyConversionStrategy
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
                        argument: GenericArgumentSyntax.Argument(associatedValue.type.syntax)
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
                  label: associatedValue.label,
                  colon: associatedValue.label.map { _ in .colonToken() },
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
              baseType: param.type.syntax,
              name: "Type"
            ),
            defaultValue: InitializerClauseSyntax(
              value: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: "\(param.type.syntax.trimmed)"),
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
    let inputValueType = tupleType(from: parameters.map(\.type.syntax))

    // Output value type
    let outputValueType = outputTupleType()

    // SyncInput: Never for async, inputValueType for sync
    let syncInputType: TypeSyntax = isAsync ? "Never" : inputValueType

    // Failure type
    let failureType = failureTypeSyntax()

    return namespace.supportMemberType(
      name: "CallableSchema",
      genericArgumentClause: GenericArgumentClauseSyntax {
        GenericArgumentSyntax(argument: GenericArgumentSyntax.Argument(calleeType))
        GenericArgumentSyntax(
          argument: GenericArgumentSyntax.Argument(TypeSyntax(
            SomeOrAnyTypeSyntax(
              someOrAnySpecifier: .keyword(.some),
              constraint: namespace.memberType(
                name: "Schema",
                genericArgumentClause: GenericArgumentClauseSyntax {
                  GenericArgumentSyntax(argument: GenericArgumentSyntax.Argument(inputValueType))
                }
              )
            )
          ))
        )
        GenericArgumentSyntax(
          argument: GenericArgumentSyntax.Argument(TypeSyntax(
            SomeOrAnyTypeSyntax(
              someOrAnySpecifier: .keyword(.some),
              constraint: namespace.memberType(
                name: "Schema",
                genericArgumentClause: GenericArgumentClauseSyntax {
                  GenericArgumentSyntax(argument: GenericArgumentSyntax.Argument(outputValueType))
                }
              )
            )
          ))
        )
        GenericArgumentSyntax(argument: GenericArgumentSyntax.Argument(syncInputType))
        GenericArgumentSyntax(argument: GenericArgumentSyntax.Argument(failureType))
      }
    )
  }

  /// Generates inputSchema = parameterClauseSchema { ... }
  private func inputSchemaExpr() -> FunctionCallExprSyntax {
    FunctionCallExprSyntax(
      calledExpression: namespace.supportMember(name: "parameterClauseSchema"),
      leftParen: .leftParenToken(),
      arguments: [],
      rightParen: .rightParenToken(),
      trailingClosure: ClosureExprSyntax(
        statements: CodeBlockItemListSyntax {
          for param in parameters {
            param.parameterCallExpr(
              namespace: namespace,
              keyConversionStrategy: keyConversionStrategy
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
      leftParen: .leftParenToken(),
      arguments: [],
      rightParen: .rightParenToken(),
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
          expression: StringLiteralExprSyntax(content: keyConversionStrategy.convert(label)),
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

        // description: "..." (if provided)
        additionalArguments

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

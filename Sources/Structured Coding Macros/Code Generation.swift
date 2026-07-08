import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - Conformance Members

extension StructuredCodableType {

  /// The protocol the generated extension conforms the type to.
  var conformanceType: some TypeSyntaxProtocol {
    switch kind {
    case .object:
      namespace.memberType(name: "StructuredObject")
    case .wrapper:
      namespace.memberType(name: "StructuredWrapper")
    case .enumeration:
      namespace.memberType(name: "StructuredEnumeration")
    }
  }

  @MemberBlockItemListBuilder
  var members: MemberBlockItemListSyntax {
    switch kind {
    case .object(let schema), .wrapper(let schema):
      schema.conformanceMembers(isPublic: isPublic)
    case .enumeration(let schema):
      schema.conformanceMembers(isPublic: isPublic)
    }
  }

}

// MARK: - Object Code Generation

extension ObjectSchema {

  /// The `StructuredObject` witnesses to add to the decorated type's conformance.
  @MemberBlockItemListBuilder
  func conformanceMembers(isPublic: Bool) -> MemberBlockItemListSyntax {
    // typealias <unique> = {ns}.StructuredObjectProperty<Self, {definition}>
    for property in properties {
      TypeAliasDeclSyntax(
        modifiers: .visibility(isPublic),
        name: property.propertyTypeAliasName,
        initializer: TypeInitializerClauseSyntax(
          value: namespace.memberType(
            name: "StructuredObjectProperty",
            genericArgumentClause: GenericArgumentClauseSyntax {
              GenericArgumentSyntax(
                argument: GenericArgumentSyntax.Argument(IdentifierTypeSyntax(name: "Self"))
              )
              GenericArgumentSyntax(
                argument: GenericArgumentSyntax.Argument(property.definition.typeSyntax(in: namespace))
              )
            }
          )
        )
      )
    }

    // static var schema: some {ns}.StructuredCodingSchema { _schema(…) }
    // The shared {ns}.StructuredObject._schema implementation is generic over
    // the property-definition pack, and an opaque result type on a generic
    // function cannot witness the `Schema` associated type — so each concrete
    // type gets this non-generic trampoline. (`Schema` is inferred from its
    // opaque return; the underlying schema type stays non-generic because
    // naming a schema type parameterized by the property-definition pack
    // crashes the runtime demangler.)
    schemaTrampoline(in: namespace, isPublic: isPublic, typeDescription: description)

    // typealias StructuredObjectProperties = (<unique>, ...)
    TypeAliasDeclSyntax(
      modifiers: .visibility(isPublic),
      name: "StructuredObjectProperties",
      initializer: TypeInitializerClauseSyntax(
        value: tupleOrSingle(properties.map { property in
          TypeSyntax(IdentifierTypeSyntax(name: property.propertyTypeAliasName))
        })
      )
    )

    // static func properties() -> StructuredObjectProperties { ... }
    FunctionDeclSyntax(
      modifiers: .visibility(isPublic, static: true),
      name: "properties",
      signature: FunctionSignatureSyntax(
        parameterClause: FunctionParameterClauseSyntax(parameters: FunctionParameterListSyntax()),
        returnClause: ReturnClauseSyntax(type: IdentifierTypeSyntax(name: "StructuredObjectProperties"))
      ),
      body: CodeBlockSyntax {
        tupleOrSingleExpr(
          properties.map { property in
            ExprSyntax(
              property.propertyExpr(
                keyConversionStrategy: keyConversionStrategy,
                compatibilityModes: compatibilityModes
              )
            )
          }
        )
      }
    )

    // typealias ObjectDecoderValues = (<unique>.ObjectDecoderValue, ...)
    TypeAliasDeclSyntax(
      modifiers: .visibility(isPublic),
      name: "ObjectDecoderValues",
      initializer: TypeInitializerClauseSyntax(
        value: tupleOrSingle(properties.map { property in
          TypeSyntax(
            MemberTypeSyntax(
              baseType: IdentifierTypeSyntax(name: property.propertyTypeAliasName),
              name: "ObjectDecoderValue"
            )
          )
        })
      )
    )

    // static func decode(from objectDecoder: sending {ns}.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self { ... }
    FunctionDeclSyntax(
      modifiers: .visibility(isPublic, static: true),
      name: "decode",
      signature: FunctionSignatureSyntax(
        parameterClause: decoderParameterClause(),
        returnClause: ReturnClauseSyntax(
          type: sendingType(IdentifierTypeSyntax(name: "Self"))
        )
      ),
      body: CodeBlockSyntax {
        if isSynthesized {
          // A synthesized associated-value object has no user-written initializer,
          // so its implicit memberwise initializer is always available — and it must
          // stay available for the enum case's accessor to construct it, which an
          // in-body `private init` would suppress.
          decodeInitializerCallExpr()
        } else {
          // Self(from: objectDecoder)
          FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(baseName: "Self"),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax {
              LabeledExprSyntax(
                label: "from",
                colon: .colonToken(),
                expression: DeclReferenceExprSyntax(baseName: "objectDecoder")
              )
            },
            rightParen: .rightParenToken()
          )
        }
      }
    )

    // private init(from objectDecoder: …) { self.x = … } — assigns the stored
    // properties directly rather than relying on a memberwise initializer the type
    // may not have. Synthesized objects use the memberwise path above instead.
    if !isSynthesized {
      decoderInitializer()
    }
  }

  /// The full nested type declaration synthesized for an all-labeled enum case:
  /// the stored properties plus the `StructuredObject` conformance.
  func synthesizedStructDecl(isPublic: Bool) -> StructDeclSyntax {
    StructDeclSyntax(
      modifiers: .visibility(isPublic),
      name: rootType,
      inheritanceClause: InheritanceClauseSyntax {
        InheritedTypeSyntax(type: namespace.memberType(name: "StructuredObject"))
      }
    ) {
      for property in properties {
        VariableDeclSyntax(
          modifiers: .visibility(isPublic),
          bindingSpecifier: .keyword(.var),
          bindings: PatternBindingListSyntax {
            PatternBindingSyntax(
              pattern: IdentifierPatternSyntax(identifier: property.name.token),
              typeAnnotation: TypeAnnotationSyntax(type: property.definition.declaredType)
            )
          }
        )
      }
      conformanceMembers(isPublic: isPublic)
    }
  }

  /// `Self(label0: objectDecoder.values.0, label2: objectDecoder.values.2 ?? <default>)`,
  /// omitting constant (immutable-default) properties so the type's own
  /// initializer supplies them.
  private func decodeInitializerCallExpr() -> FunctionCallExprSyntax {
    let isSingle = properties.count == 1
    var arguments = LabeledExprListSyntax()
    for (index, property) in properties.enumerated() {
      let expression: ExprSyntax
      switch property.definition.defaulting {
      case .immutable:
        // Omitted — the initializer's own default supplies the constant.
        continue
      case .none:
        expression = property.decoderValueExpr(index: index, isSingle: isSingle)
      case .mutable(let defaultValue):
        expression = ExprSyntax(
          InfixOperatorExprSyntax(
            leftOperand: property.decoderValueExpr(index: index, isSingle: isSingle),
            operator: BinaryOperatorExprSyntax(
              operator: .binaryOperator("??", leadingTrivia: .space, trailingTrivia: .space)
            ),
            rightOperand: defaultValue.trimmed
          )
        )
      }
      arguments.append(
        LabeledExprSyntax(
          label: .identifier(property.name.name),
          colon: .colonToken(),
          expression: expression,
          trailingComma: .commaToken(trailingTrivia: .newline)
        )
      )
    }
    guard let lastIndex = arguments.indices.last else {
      // No decoded arguments (e.g. an empty object, or one whose every property is
      // a constant supplied by the initializer's own defaults) — `Self()`.
      return FunctionCallExprSyntax(
        calledExpression: DeclReferenceExprSyntax(baseName: "Self"),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax(),
        rightParen: .rightParenToken()
      )
    }
    arguments[lastIndex].trailingComma = nil
    return FunctionCallExprSyntax(
      calledExpression: DeclReferenceExprSyntax(baseName: "Self"),
      leftParen: .leftParenToken(trailingTrivia: .newline),
      arguments: arguments,
      rightParen: .rightParenToken(leadingTrivia: .newline)
    )
  }

  /// `(from objectDecoder: sending {ns}.StructuredObjectDecoder<ObjectDecoderValues>)`,
  /// shared by `decode` and the private initializer.
  private func decoderParameterClause() -> FunctionParameterClauseSyntax {
    FunctionParameterClauseSyntax {
      FunctionParameterSyntax(
        firstName: "from",
        secondName: "objectDecoder",
        type: sendingType(
          namespace.memberType(
            name: "StructuredObjectDecoder",
            genericArgumentClause: GenericArgumentClauseSyntax {
              GenericArgumentSyntax(
                argument: GenericArgumentSyntax.Argument(
                  IdentifierTypeSyntax(name: "ObjectDecoderValues")))
            }
          )
        )
      )
    }
  }

  /// `private init(from objectDecoder: …) { self.x = … }` — assigns each stored
  /// property directly so the type need not expose a memberwise initializer:
  /// - plain properties are assigned unconditionally;
  /// - default-initialized `var`s are assigned only when a value was decoded
  ///   (`if let`), otherwise keeping their declared default;
  /// - default-initialized `let`s keep their declared value (left as a comment).
  private func decoderInitializer() -> InitializerDeclSyntax {
    let isSingle = properties.count == 1
    var statements = CodeBlockItemListSyntax()
    var pendingTrivia = Trivia()

    func appendStatement(_ expression: some ExprSyntaxProtocol) {
      var element = CodeBlockItemSyntax(item: .expr(ExprSyntax(expression)))
      element.leadingTrivia = pendingTrivia + element.leadingTrivia
      pendingTrivia = Trivia()
      statements.append(element)
    }

    for (index, property) in properties.enumerated() {
      let storedProperty = MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: "self"),
        name: property.name.token
      )
      switch property.definition.defaulting {
      case .immutable:
        pendingTrivia =
          pendingTrivia
          + .lineComment(
            "// `\(property.name.name)` is a default-initialized `let`; its declared value is kept.")
          + .newline
      case .none:
        // self.x = objectDecoder.values.N
        appendStatement(
          InfixOperatorExprSyntax(
            leftOperand: storedProperty,
            operator: AssignmentExprSyntax(),
            rightOperand: property.decoderValueExpr(index: index, isSingle: isSingle)
          )
        )
      case .mutable:
        // if let x = objectDecoder.values.N { self.x = x }
        appendStatement(
          IfExprSyntax(
            conditions: ConditionElementListSyntax {
              ConditionElementSyntax(
                condition: .optionalBinding(
                  OptionalBindingConditionSyntax(
                    bindingSpecifier: .keyword(.let),
                    pattern: IdentifierPatternSyntax(identifier: property.name.token),
                    initializer: InitializerClauseSyntax(
                      value: property.decoderValueExpr(index: index, isSingle: isSingle)
                    )
                  )
                )
              )
            },
            body: CodeBlockSyntax {
              InfixOperatorExprSyntax(
                leftOperand: storedProperty,
                operator: AssignmentExprSyntax(),
                rightOperand: DeclReferenceExprSyntax(baseName: property.name.token)
              )
            }
          )
        )
      }
    }

    return InitializerDeclSyntax(
      modifiers: .private,
      signature: FunctionSignatureSyntax(parameterClause: decoderParameterClause()),
      body: CodeBlockSyntax(
        statements: statements,
        rightBrace: .rightBraceToken(
          leadingTrivia: pendingTrivia.isEmpty ? .newline : .newline + pendingTrivia
        )
      )
    )
  }

}

extension ObjectSchema.Property {

  /// `<unique>(name: "json", keyPath: \.swiftName, schema: <unique>.Definition.CodingValue.schema)`,
  /// or with `.variadicGenerics` compatibility
  /// `<unique>(name: "json", getter: { $0.swiftName }, schema: <unique>.Definition.CodingValue.schema)`.
  /// A `@StructuredProperty(description:)` annotation adds `description: "..."`
  /// after the name; the initializer prepends it onto the property's schema.
  fileprivate func propertyExpr(
    keyConversionStrategy: KeyConversionStrategy,
    compatibilityModes: CompatibilityModes
  ) -> FunctionCallExprSyntax {
    FunctionCallExprSyntax(
      calledExpression: DeclReferenceExprSyntax(baseName: propertyTypeAliasName),
      leftParen: .leftParenToken(trailingTrivia: .newline),
      arguments: LabeledExprListSyntax {
        LabeledExprSyntax(
          label: "name",
          colon: .colonToken(),
          expression: StringLiteralExprSyntax(
            content: keyConversionStrategy.convert(name.identifier.name)
          ),
          trailingComma: .commaToken(trailingTrivia: .newline)
        )
        if let description {
          LabeledExprSyntax(
            label: "description",
            colon: .colonToken(),
            expression: description.trimmed,
            trailingComma: .commaToken(trailingTrivia: .newline)
          )
        }
        if compatibilityModes.contains(.variadicGenerics) {
          // Key path literals rooted in a pack-generic type crash at runtime;
          // see `StructuredCodingCompatibilityMode.variadicGenerics`.
          LabeledExprSyntax(
            label: "getter",
            colon: .colonToken(),
            expression: ClosureExprSyntax(
              statements: CodeBlockItemListSyntax {
                MemberAccessExprSyntax(
                  base: DeclReferenceExprSyntax(baseName: .dollarIdentifier("$0")),
                  declName: DeclReferenceExprSyntax(baseName: .identifier(name.name))
                )
              }
            ),
            trailingComma: .commaToken(trailingTrivia: .newline)
          )
        } else {
          LabeledExprSyntax(
            label: "keyPath",
            colon: .colonToken(),
            expression: KeyPathExprSyntax(
              components: KeyPathComponentListSyntax {
                KeyPathComponentSyntax(
                  period: .periodToken(),
                  component: .property(
                    KeyPathPropertyComponentSyntax(
                      declName: DeclReferenceExprSyntax(baseName: .identifier(name.name))
                    )
                  )
                )
              }
            ),
            trailingComma: .commaToken(trailingTrivia: .newline)
          )
        }
        LabeledExprSyntax(
          label: "schema",
          colon: .colonToken(),
          expression: MemberAccessExprSyntax(
            base: MemberAccessExprSyntax(
              base: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: propertyTypeAliasName),
                name: "Definition"
              ),
              name: "CodingValue"
            ),
            name: "schema"
          )
        )
      },
      rightParen: .rightParenToken(leadingTrivia: .newline)
    )
  }

  /// `objectDecoder.values` (single property) or `objectDecoder.values.N`.
  fileprivate func decoderValueExpr(index: Int, isSingle: Bool) -> ExprSyntax {
    let values = MemberAccessExprSyntax(
      base: DeclReferenceExprSyntax(baseName: "objectDecoder"),
      name: "values"
    )
    if isSingle {
      return ExprSyntax(values)
    } else {
      return ExprSyntax(MemberAccessExprSyntax(base: values, name: "\(raw: index)"))
    }
  }

}

extension ObjectSchema.Property.Definition {

  /// The property definition specialization for this property, resolved
  /// through the declared type — e.g. `Int._StructuredObjectPropertyDefinition`
  /// or `{ns}.StructuredMutableDefaultInitializedPropertyDefinition<
  /// Int._StructuredObjectPropertyDefinition>` — so that the *type system*
  /// decides how the property codes.
  func typeSyntax(in namespace: StructuredCodingNamespace) -> TypeSyntax {
    let coreType = TypeSyntax(
      MemberTypeSyntax(
        baseType: declaredType.memberTypeBase,
        name: "_StructuredObjectPropertyDefinition"
      )
    )

    let wrapperName: TokenSyntax?
    switch defaulting {
    case .none:
      wrapperName = nil
    case .immutable:
      wrapperName = "StructuredImmutableDefaultInitializedPropertyDefinition"
    case .mutable:
      wrapperName = "StructuredMutableDefaultInitializedPropertyDefinition"
    }

    guard let wrapperName else {
      return coreType
    }
    return TypeSyntax(
      namespace.memberType(
        name: wrapperName,
        genericArgumentClause: GenericArgumentClauseSyntax {
          GenericArgumentSyntax(argument: GenericArgumentSyntax.Argument(coreType))
        }
      )
    )
  }

  /// The property's Swift type as written — used for the stored property of
  /// a synthesized associated-value object.
  var declaredType: TypeSyntax {
    valueType.trimmed
  }

}

extension TypeSyntax {

  /// The type, ready to serve as the base of a member type reference.
  /// Optional sugar cannot (`String?._Member` does not parse), so it is
  /// expanded to `Swift.Optional<String>` — a purely syntactic rewrite, since
  /// `T?` *is* `Swift.Optional<T>` by language definition, unlike the
  /// semantic optionality guesses this member-type emission replaces.
  fileprivate var memberTypeBase: TypeSyntax {
    guard let optionalType = self.as(OptionalTypeSyntax.self) else {
      return self
    }
    return TypeSyntax(
      MemberTypeSyntax(
        baseType: IdentifierTypeSyntax(name: "Swift"),
        name: "Optional",
        genericArgumentClause: GenericArgumentClauseSyntax {
          GenericArgumentSyntax(
            argument: GenericArgumentSyntax.Argument(optionalType.wrappedType)
          )
        }
      )
    )
  }

}

// MARK: - Enumeration Code Generation

extension EnumerationSchema {

  @MemberBlockItemListBuilder
  func conformanceMembers(isPublic: Bool) -> MemberBlockItemListSyntax {
    // static var codingStyle: <StyleType> { <styleExpr> }  (non-default styles only)
    if let codingStyleMember = codingStyle.codingStyleMember(in: namespace, isPublic: isPublic) {
      codingStyleMember
    }

    // static var schema: some {ns}.StructuredCodingSchema { _schema(…) }
    // The style-constrained {ns}.StructuredEnumeration._schema implementations
    // are generic over the associated-value pack, and an opaque result type on
    // a generic function cannot witness the `Schema` associated type — so each
    // concrete enumeration gets this non-generic trampoline.
    schemaTrampoline(in: namespace, isPublic: isPublic, typeDescription: description)

    // typealias Cases = ({ns}.StructuredEnumerationCase<Self, <associated>>, ...)
    TypeAliasDeclSyntax(
      modifiers: .visibility(isPublic),
      name: "Cases",
      initializer: TypeInitializerClauseSyntax(
        value: tupleOrSingle(cases.map { `case` in
          TypeSyntax(
            namespace.memberType(
              name: "StructuredEnumerationCase",
              genericArgumentClause: GenericArgumentClauseSyntax {
                GenericArgumentSyntax(
                  argument: GenericArgumentSyntax.Argument(IdentifierTypeSyntax(name: "Self")))
                GenericArgumentSyntax(
                  argument: GenericArgumentSyntax.Argument(
                    `case`.associatedValue.typeSyntax(in: namespace)))
              }
            )
          )
        })
      )
    )

    // static func cases() -> Cases { ... }
    FunctionDeclSyntax(
      modifiers: .visibility(isPublic, static: true),
      name: "cases",
      signature: FunctionSignatureSyntax(
        parameterClause: FunctionParameterClauseSyntax(parameters: FunctionParameterListSyntax()),
        returnClause: ReturnClauseSyntax(type: IdentifierTypeSyntax(name: "Cases"))
      ),
      body: CodeBlockSyntax {
        tupleOrSingleExpr(
          cases.map { `case` in
            ExprSyntax(
              `case`.caseExpr(in: namespace, keyConversionStrategy: keyConversionStrategy))
          }
        )
      }
    )

    // Nested `StructuredObject` types synthesized for all-labeled cases.
    for `case` in cases {
      if case .object(let objectSchema) = `case`.associatedValue {
        objectSchema.synthesizedStructDecl(isPublic: isPublic)
      }
    }
  }

}

extension EnumerationSchema.CodingStyle {

  /// `static var codingStyle: <StyleType> { <expr> }`, or `nil` for the default
  /// object-properties style (which the protocol supplies).
  fileprivate func codingStyleMember(
    in namespace: StructuredCodingNamespace,
    isPublic: Bool
  ) -> VariableDeclSyntax? {
    let styleTypeName: TokenSyntax
    let valueExpr: ExprSyntax
    switch self {
    case .objectProperties:
      return nil
    case .internallyTagged(let discriminatorPropertyName):
      styleTypeName = "StructuredEnumerationCodingStyleInternallyTagged"
      valueExpr = ExprSyntax(
        FunctionCallExprSyntax(
          calledExpression: MemberAccessExprSyntax(name: "internallyTagged"),
          leftParen: .leftParenToken(),
          arguments: LabeledExprListSyntax {
            LabeledExprSyntax(
              label: "discriminatorPropertyName",
              colon: .colonToken(),
              expression: discriminatorPropertyName.trimmed
            )
          },
          rightParen: .rightParenToken()
        )
      )
    case .typeDiscriminated:
      styleTypeName = "StructuredEnumerationCodingStyleTypeDiscriminated"
      valueExpr = ExprSyntax(MemberAccessExprSyntax(name: "typeDiscriminated"))
    }

    return VariableDeclSyntax(
      modifiers: .visibility(isPublic, static: true),
      bindingSpecifier: .keyword(.var),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: "codingStyle"),
          typeAnnotation: TypeAnnotationSyntax(
            type: namespace.memberType(name: styleTypeName)
          ),
          accessorBlock: AccessorBlockSyntax(
            accessors: .getter(CodeBlockItemListSyntax { valueExpr })
          )
        )
      }
    )
  }

}

extension EnumerationSchema.Case {

  /// `{ns}.StructuredEnumerationCase(name: "...", accessor: { ... }, initializer: { ... })`.
  /// A `@StructuredCase(description:)` annotation adds `description: "..."`
  /// after the name; without one the argument is omitted and the initializer's
  /// `nil` default applies.
  fileprivate func caseExpr(
    in namespace: StructuredCodingNamespace,
    keyConversionStrategy: KeyConversionStrategy
  ) -> FunctionCallExprSyntax {
    FunctionCallExprSyntax(
      calledExpression: namespace.member(name: "StructuredEnumerationCase"),
      leftParen: .leftParenToken(trailingTrivia: .newline),
      arguments: LabeledExprListSyntax {
        LabeledExprSyntax(
          label: "name",
          colon: .colonToken(),
          expression: StringLiteralExprSyntax(
            content: keyConversionStrategy.convert(name.identifier.name)
          ),
          trailingComma: .commaToken(trailingTrivia: .newline)
        )
        if let description {
          LabeledExprSyntax(
            label: "description",
            colon: .colonToken(),
            expression: description.trimmed,
            trailingComma: .commaToken(trailingTrivia: .newline)
          )
        }
        LabeledExprSyntax(
          label: "accessor",
          colon: .colonToken(),
          expression: accessorClosure(in: namespace),
          trailingComma: .commaToken(trailingTrivia: .newline)
        )
        LabeledExprSyntax(
          label: "initializer",
          colon: .colonToken(),
          expression: initializerClosure()
        )
      },
      rightParen: .rightParenToken(leadingTrivia: .newline)
    )
  }

  /// `{ value in guard case .name(let v0, ...) = value else { return nil }; return <wrapper> }`
  private func accessorClosure(in namespace: StructuredCodingNamespace) -> ClosureExprSyntax {
    let bindingNames = associatedValue.bindingNames
    let returnExpr = associatedValue.accessorReturnExpr(
      caseName: name, in: namespace, bindingNames: bindingNames)

    return ClosureExprSyntax(
      signature: ClosureSignatureSyntax(
        parameterClause: .simpleInput(
          ClosureShorthandParameterListSyntax {
            ClosureShorthandParameterSyntax(name: "value")
          }
        )
      ),
      statements: CodeBlockItemListSyntax {
        GuardStmtSyntax(
          conditions: ConditionElementListSyntax {
            ConditionElementSyntax(
              condition: .matchingPattern(
                MatchingPatternConditionSyntax(
                  pattern: casePattern(bindingNames: bindingNames),
                  initializer: InitializerClauseSyntax(
                    value: DeclReferenceExprSyntax(baseName: "value")
                  )
                )
              )
            )
          },
          body: CodeBlockSyntax {
            ReturnStmtSyntax(expression: NilLiteralExprSyntax())
          }
        )
        ReturnStmtSyntax(expression: returnExpr)
      }
    )
  }

  /// `.name(let v0, let v1)` (or `.name` with no bindings) as an expression pattern.
  private func casePattern(bindingNames: [TokenSyntax]) -> ExpressionPatternSyntax {
    let caseAccess = MemberAccessExprSyntax(name: name.token)
    guard !bindingNames.isEmpty else {
      return ExpressionPatternSyntax(expression: caseAccess)
    }
    return ExpressionPatternSyntax(
      expression: FunctionCallExprSyntax(
        calledExpression: caseAccess,
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax {
          for bindingName in bindingNames {
            LabeledExprSyntax(
              expression: PatternExprSyntax(
                pattern: ValueBindingPatternSyntax(
                  bindingSpecifier: .keyword(.let),
                  pattern: IdentifierPatternSyntax(identifier: bindingName)
                )
              )
            )
          }
        },
        rightParen: .rightParenToken()
      )
    )
  }

  /// `{ .name($0) }`, `{ .name(label: $0.values.0, ...) }`, etc.
  private func initializerClosure() -> ClosureExprSyntax {
    switch associatedValue {
    case .none:
      return ClosureExprSyntax(
        signature: ClosureSignatureSyntax(
          parameterClause: .simpleInput(
            ClosureShorthandParameterListSyntax {
              ClosureShorthandParameterSyntax(name: .wildcardToken())
            }
          )
        ),
        statements: CodeBlockItemListSyntax {
          MemberAccessExprSyntax(name: name.token)
        }
      )
    case .single(let element):
      return initializerClosure(
        arguments: LabeledExprListSyntax {
          labeledArgument(label: element.label, expression: dollarArgument())
        }
      )
    case .tuple(let elements):
      return initializerClosure(
        arguments: LabeledExprListSyntax {
          for (index, element) in elements.enumerated() {
            labeledArgument(
              label: element.label,
              expression: dollarMember("values", "\(index)")
            )
          }
        }
      )
    case .object(let objectSchema):
      return initializerClosure(
        arguments: LabeledExprListSyntax {
          for property in objectSchema.properties {
            labeledArgument(
              label: property.name.token,
              expression: dollarMember(property.name.name)
            )
          }
        }
      )
    }
  }

  private func initializerClosure(arguments: LabeledExprListSyntax) -> ClosureExprSyntax {
    ClosureExprSyntax(
      statements: CodeBlockItemListSyntax {
        FunctionCallExprSyntax(
          calledExpression: MemberAccessExprSyntax(name: name.token),
          leftParen: .leftParenToken(),
          arguments: arguments,
          rightParen: .rightParenToken()
        )
      }
    )
  }

  private func labeledArgument(label: TokenSyntax?, expression: some ExprSyntaxProtocol)
    -> LabeledExprSyntax
  {
    if let label {
      LabeledExprSyntax(
        label: .identifier(label.identifierOrText),
        colon: .colonToken(),
        expression: expression
      )
    } else {
      LabeledExprSyntax(expression: expression)
    }
  }

  /// `$0`
  private func dollarArgument() -> DeclReferenceExprSyntax {
    DeclReferenceExprSyntax(baseName: .dollarIdentifier("$0"))
  }

  /// `$0.<components...>`
  private func dollarMember(_ components: String...) -> ExprSyntax {
    var expression = ExprSyntax(dollarArgument())
    for component in components {
      expression = ExprSyntax(
        MemberAccessExprSyntax(base: expression, name: .identifier(component)))
    }
    return expression
  }

}

extension EnumerationSchema.Case.AssociatedValue {

  /// The single type the `StructuredEnumerationCase` wraps.
  func typeSyntax(in namespace: StructuredCodingNamespace) -> TypeSyntax {
    switch self {
    case .none:
      return TypeSyntax(namespace.memberType(name: "StructuredEmptyObject"))
    case .single(let element):
      return element.type.trimmed
    case .tuple(let elements):
      return TypeSyntax(
        namespace.memberType(
          name: "StructuredTuple",
          genericArgumentClause: GenericArgumentClauseSyntax {
            for element in elements {
              GenericArgumentSyntax(
                argument: GenericArgumentSyntax.Argument(element.type.trimmed))
            }
          }
        )
      )
    case .object(let objectSchema):
      return TypeSyntax(IdentifierTypeSyntax(name: objectSchema.rootType))
    }
  }

  /// The positional binding names introduced by the case pattern (`v0`, `v1`, …),
  /// empty for a value-less case.
  fileprivate var bindingNames: [TokenSyntax] {
    let count =
      switch self {
      case .none: 0
      case .single: 1
      case .tuple(let elements): elements.count
      case .object(let objectSchema): objectSchema.properties.count
      }
    return (0..<count).map { .identifier("v\($0)") }
  }

  /// The value returned from the accessor once the case has matched.
  fileprivate func accessorReturnExpr(
    caseName: IdentifiableToken,
    in namespace: StructuredCodingNamespace,
    bindingNames: [TokenSyntax]
  ) -> ExprSyntax {
    switch self {
    case .none:
      return ExprSyntax(
        FunctionCallExprSyntax(
          calledExpression: namespace.member(name: "StructuredEmptyObject"),
          leftParen: .leftParenToken(),
          arguments: LabeledExprListSyntax(),
          rightParen: .rightParenToken()
        )
      )
    case .single:
      return ExprSyntax(DeclReferenceExprSyntax(baseName: bindingNames[0]))
    case .tuple:
      return ExprSyntax(
        FunctionCallExprSyntax(
          calledExpression: namespace.member(name: "StructuredTuple"),
          leftParen: .leftParenToken(),
          arguments: LabeledExprListSyntax {
            for bindingName in bindingNames {
              LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: bindingName))
            }
          },
          rightParen: .rightParenToken()
        )
      )
    case .object(let objectSchema):
      return ExprSyntax(
        FunctionCallExprSyntax(
          calledExpression: DeclReferenceExprSyntax(baseName: objectSchema.rootType),
          leftParen: .leftParenToken(),
          arguments: LabeledExprListSyntax {
            for (property, bindingName) in zip(objectSchema.properties, bindingNames) {
              LabeledExprSyntax(
                label: .identifier(property.name.name),
                colon: .colonToken(),
                expression: DeclReferenceExprSyntax(baseName: bindingName)
              )
            }
          },
          rightParen: .rightParenToken()
        )
      )
    }
  }

}

// MARK: - Generation Helpers

/// `static var schema: some {ns}.StructuredCodingSchema { _schema() }` — the
/// non-generic `Schema` witness emitted into every object and enumeration;
/// see the call sites for why the trampoline is required.
/// A `@StructuredCodable(description:)` annotation adds its string literal as
/// `_schema`'s `typeDescription:` argument.
private func schemaTrampoline(
  in namespace: StructuredCodingNamespace,
  isPublic: Bool,
  typeDescription: StringLiteralExprSyntax?
) -> VariableDeclSyntax {
  VariableDeclSyntax(
    modifiers: .visibility(isPublic, static: true),
    bindingSpecifier: .keyword(.var)
  ) {
    PatternBindingSyntax(
      pattern: IdentifierPatternSyntax(identifier: "schema"),
      typeAnnotation: TypeAnnotationSyntax(
        type: SomeOrAnyTypeSyntax(
          someOrAnySpecifier: .keyword(.some),
          constraint: namespace.memberType(name: "StructuredCodingSchema")
        )
      ),
      accessorBlock: AccessorBlockSyntax(
        accessors: .getter(
          CodeBlockItemListSyntax {
            FunctionCallExprSyntax(
              calledExpression: DeclReferenceExprSyntax(baseName: "_schema"),
              leftParen: .leftParenToken(),
              arguments: LabeledExprListSyntax {
                if let typeDescription {
                  LabeledExprSyntax(
                    label: "typeDescription",
                    colon: .colonToken(),
                    expression: typeDescription.trimmed
                  )
                }
              },
              rightParen: .rightParenToken()
            )
          }
        )
      )
    )
  }
}

/// Wraps a type in the `sending` parameter/result specifier.
private func sendingType(_ base: some TypeSyntaxProtocol) -> AttributedTypeSyntax {
  AttributedTypeSyntax(
    specifiers: TypeSpecifierListSyntax {
      SimpleTypeSpecifierSyntax(specifier: .keyword(.sending))
    },
    baseType: base
  )
}

/// A tuple type of `elements`, collapsing to the bare element when there is
/// exactly one (Swift unwraps a single-element parenthesized type) and to `()`
/// when empty — matching the fixtures' `StructuredObjectProperties` / `Cases` / `ObjectDecoderValues`.
private func tupleOrSingle(_ elements: [TypeSyntax]) -> TypeSyntax {
  if elements.count == 1 {
    return elements[0]
  }
  return TypeSyntax(
    TupleTypeSyntax(
      elements: TupleTypeElementListSyntax {
        for element in elements {
          TupleTypeElementSyntax(type: element)
        }
      }
    )
  )
}

/// The expression form of `tupleOrSingle`: a bare expression for one element, a
/// parenthesized tuple otherwise (`()` when empty).
private func tupleOrSingleExpr(_ elements: [ExprSyntax]) -> ExprSyntax {
  if elements.count == 1 {
    return elements[0]
  }
  return ExprSyntax(
    TupleExprSyntax(
      elements: LabeledExprListSyntax {
        for element in elements {
          LabeledExprSyntax(expression: element)
        }
      }
    )
  )
}

extension DeclModifierListSyntax {

  /// `public` when `isPublic`, optionally followed by `static`.
  fileprivate static func visibility(_ isPublic: Bool, static isStatic: Bool = false)
    -> DeclModifierListSyntax
  {
    DeclModifierListSyntax {
      if isPublic {
        DeclModifierSyntax(name: "public")
      }
      if isStatic {
        DeclModifierSyntax(name: .keyword(.static))
      }
    }
  }

}

// MARK: - Callable Schema Code Generation

extension SchemaParameter {

  /// Generates a `parameter(label: "...", schema: ...)` call
  func parameterCallExpr(
    namespace: StructuredCodingNamespace,
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

extension ExprSyntaxProtocol where Self == FunctionCallExprSyntax {

  fileprivate static func schema(
    namespace: StructuredCodingNamespace,
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

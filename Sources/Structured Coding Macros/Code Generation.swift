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
                in: namespace,
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
        expression = property.definition.unwrappedValueExpr(
          property.decoderValueExpr(index: index, isSingle: isSingle)
        )
      case .mutable(let defaultValue):
        expression = ExprSyntax(
          InfixOperatorExprSyntax(
            leftOperand: property.decodedValueOrNilExpr(index: index, isSingle: isSingle),
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
            rightOperand: property.definition.unwrappedValueExpr(
              property.decoderValueExpr(index: index, isSingle: isSingle)
            )
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
                rightOperand: property.definition.unwrappedValueExpr(
                  ExprSyntax(DeclReferenceExprSyntax(baseName: property.name.token))
                )
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
  /// A tuple-upgraded property always uses a getter — one that wraps the
  /// stored tuple in `StructuredTuple`, which no key path can produce.
  /// A `@StructuredProperty(description:)` annotation adds `description: "..."`
  /// after the name; the initializer prepends it onto the property's schema.
  fileprivate func propertyExpr(
    in namespace: StructuredCodingNamespace,
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
        if let tupleUpgrade = definition.tupleUpgrade {
          LabeledExprSyntax(
            label: "getter",
            colon: .colonToken(),
            expression: tupleGetterClosure(for: tupleUpgrade, in: namespace),
            trailingComma: .commaToken(trailingTrivia: .newline)
          )
        } else if compatibilityModes.contains(.variadicGenerics) {
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

  /// The wrapping getter for a tuple-upgraded property:
  /// `{ {ns}.StructuredTuple($0.x.0, $0.x.1) }` — expanding a pack tuple with
  /// `repeat each` instead of by index — or, through an optional,
  /// `{ $0.x.map { {ns}.StructuredTuple($0.0, $0.1) } }` (the inner `$0` is
  /// `map`'s tuple argument).
  private func tupleGetterClosure(
    for tupleUpgrade: ObjectSchema.Property.TupleUpgrade,
    in namespace: StructuredCodingNamespace
  ) -> ClosureExprSyntax {
    func wrapExpr(tuple: ExprSyntax) -> FunctionCallExprSyntax {
      FunctionCallExprSyntax(
        calledExpression: namespace.member(name: "StructuredTuple"),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax {
          if tupleUpgrade.isPack {
            LabeledExprSyntax(
              expression: PackExpansionExprSyntax(
                repeatKeyword: .keyword(.repeat, trailingTrivia: .space),
                repetitionPattern: PackElementExprSyntax(
                  eachKeyword: .keyword(.each, trailingTrivia: .space),
                  pack: tuple
                )
              )
            )
          } else {
            for index in tupleUpgrade.genericArguments.indices {
              LabeledExprSyntax(
                expression: MemberAccessExprSyntax(base: tuple, name: "\(raw: index)")
              )
            }
          }
        },
        rightParen: .rightParenToken()
      )
    }

    let storedTuple = ExprSyntax(
      MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: .dollarIdentifier("$0")),
        declName: DeclReferenceExprSyntax(baseName: .identifier(name.name))
      )
    )

    guard tupleUpgrade.isOptional else {
      return ClosureExprSyntax(
        statements: CodeBlockItemListSyntax {
          wrapExpr(tuple: storedTuple)
        }
      )
    }
    return ClosureExprSyntax(
      statements: CodeBlockItemListSyntax {
        FunctionCallExprSyntax(
          calledExpression: MemberAccessExprSyntax(base: storedTuple, name: "map"),
          leftParen: nil,
          arguments: LabeledExprListSyntax(),
          rightParen: nil,
          trailingClosure: ClosureExprSyntax(
            statements: CodeBlockItemListSyntax {
              wrapExpr(tuple: ExprSyntax(DeclReferenceExprSyntax(baseName: .dollarIdentifier("$0"))))
            }
          )
        )
      }
    )
  }

  /// The decoded value for a default-initialized property, `nil` when the
  /// property was omitted (`objectDecoder.values.N`, whose value is
  /// `PropertyValue?`); a tuple-upgraded property unwraps the wrapper inside
  /// the optional (`objectDecoder.values.N.map { $0.values }`), leaving the
  /// omitted case `nil` for the caller's `?? <default>`.
  fileprivate func decodedValueOrNilExpr(index: Int, isSingle: Bool) -> ExprSyntax {
    let decoderValue = decoderValueExpr(index: index, isSingle: isSingle)
    guard definition.tupleUpgrade != nil else {
      return decoderValue
    }
    return ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(base: decoderValue, name: "map"),
        leftParen: nil,
        arguments: LabeledExprListSyntax(),
        rightParen: nil,
        trailingClosure: ClosureExprSyntax(
          statements: CodeBlockItemListSyntax {
            definition.unwrappedValueExpr(
              ExprSyntax(DeclReferenceExprSyntax(baseName: .dollarIdentifier("$0")))
            )
          }
        )
      )
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
        baseType: codingType(in: namespace),
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

  /// The type the property codes through: the declared type, except tuples
  /// are upgraded to `{ns}.StructuredTuple` (preserving optional sugar) —
  /// see `TupleUpgrade`.
  private func codingType(in namespace: StructuredCodingNamespace) -> TypeSyntax {
    guard let tupleUpgrade else {
      return declaredType
    }
    let tupleType = TypeSyntax(
      namespace.memberType(
        name: "StructuredTuple",
        genericArgumentClause: GenericArgumentClauseSyntax {
          for argument in tupleUpgrade.genericArguments {
            GenericArgumentSyntax(argument: GenericArgumentSyntax.Argument(argument))
          }
        }
      )
    )
    guard tupleUpgrade.isOptional else {
      return tupleType
    }
    return TypeSyntax(OptionalTypeSyntax(wrappedType: tupleType))
  }

  /// Converts an expression of the property's *coded* type back to the
  /// declared type: for a tuple-upgraded property this unwraps the
  /// `StructuredTuple` (`.values`, chaining through an optional as
  /// `?.values`); every other property's coded value already is the
  /// declared value.
  func unwrappedValueExpr(_ codedValue: ExprSyntax) -> ExprSyntax {
    guard let tupleUpgrade else {
      return codedValue
    }
    let base: ExprSyntax =
      tupleUpgrade.isOptional
      ? ExprSyntax(OptionalChainingExprSyntax(expression: codedValue))
      : codedValue
    return ExprSyntax(MemberAccessExprSyntax(base: base, name: "values"))
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
    let returnExpr = associatedValue.representationExpr(
      packing: bindingNames.map { ExprSyntax(DeclReferenceExprSyntax(baseName: $0)) },
      in: namespace
    )

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
    case .single, .tuple, .object:
      return ClosureExprSyntax(
        statements: CodeBlockItemListSyntax {
          FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(name: name.token),
            leftParen: .leftParenToken(),
            arguments: associatedValue.argumentList(
              unpacking: DeclReferenceExprSyntax(baseName: .dollarIdentifier("$0"))
            ),
            rightParen: .rightParenToken()
          )
        }
      )
    }
  }

}

// MARK: - Parameter Clause Code Generation

extension ParameterClauseSchema {

  /// The single `StructuredCodable` type the clause collapses onto.
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

  /// How many values of the original clause the collapsed representation
  /// carries — the arity of the case pattern (enum) or of the returned tuple
  /// (callable output).
  var componentCount: Int {
    switch self {
    case .none: 0
    case .single: 1
    case .tuple(let elements): elements.count
    case .object(let objectSchema): objectSchema.properties.count
    }
  }

  /// The positional binding names introduced by the case pattern (`v0`, `v1`, …),
  /// empty for a value-less case.
  fileprivate var bindingNames: [TokenSyntax] {
    (0..<componentCount).map { .identifier("v\($0)") }
  }

  /// The original labeled argument list, recovered from the collapsed
  /// representation `base` — `(base)`, `(label: base.values.0, ...)`, or
  /// `(name: base.name, ...)`. Used to reconstruct an enum case
  /// (`.name(label: $0.values.0)`) and to call a `@StructuredAction`
  /// function (`foo(label: input.values.0, ...)`).
  func argumentList(unpacking base: some ExprSyntaxProtocol) -> LabeledExprListSyntax {
    switch self {
    case .none:
      return LabeledExprListSyntax()
    case .single(let element):
      return LabeledExprListSyntax {
        labeledArgument(label: element.label, expression: base)
      }
    case .tuple(let elements):
      return LabeledExprListSyntax {
        for (index, element) in elements.enumerated() {
          labeledArgument(
            label: element.label,
            expression: member(base, "values", "\(index)")
          )
        }
      }
    case .object(let objectSchema):
      return LabeledExprListSyntax {
        for property in objectSchema.properties {
          labeledArgument(
            label: property.name.token,
            expression: member(base, property.name.name)
          )
        }
      }
    }
  }

  /// The collapsed representation, constructed from the clause's component
  /// values — `StructuredEmptyObject()`, the value itself,
  /// `StructuredTuple(v0, v1)`, or `RootType(name0: v0, ...)`. `components`
  /// are the matched case-pattern bindings (enum accessor) or the positional
  /// accesses into a callable's returned tuple.
  func representationExpr(
    packing components: [ExprSyntax],
    in namespace: StructuredCodingNamespace
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
      return components[0]
    case .tuple:
      return ExprSyntax(
        FunctionCallExprSyntax(
          calledExpression: namespace.member(name: "StructuredTuple"),
          leftParen: .leftParenToken(),
          arguments: LabeledExprListSyntax {
            for component in components {
              LabeledExprSyntax(expression: component)
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
            for (property, component) in zip(objectSchema.properties, components) {
              LabeledExprSyntax(
                label: .identifier(property.name.name),
                colon: .colonToken(),
                expression: component
              )
            }
          },
          rightParen: .rightParenToken()
        )
      )
    }
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

}

// MARK: - Generation Helpers

/// `<base>.<name>`
private func member(
  _ base: some ExprSyntaxProtocol, _ name: String
) -> some ExprSyntaxProtocol {
  MemberAccessExprSyntax(base: base, name: .identifier(name))
}

/// `<base>.<name0>.<name1>`
private func member(
  _ base: some ExprSyntaxProtocol, _ name0: String, _ name1: String
) -> some ExprSyntaxProtocol {
  member(member(base, name0), name1)
}

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

extension CallableSchema {

  /// The peer declarations for a `@StructuredAction` function: the
  /// synthesized `Input`/`Output` objects (when the corresponding clause
  /// collapses onto one) and the sidecar function returning the
  /// `StructuredAction`.
  func peerDeclarations() -> [DeclSyntax] {
    var declarations: [DeclSyntax] = []
    if case .object(let objectSchema) = input {
      declarations.append(DeclSyntax(objectSchema.synthesizedStructDecl(isPublic: isPublic)))
    }
    if case .object(let objectSchema) = output {
      declarations.append(DeclSyntax(objectSchema.synthesizedStructDecl(isPublic: isPublic)))
    }
    declarations.append(DeclSyntax(sidecarFunction()))
    return declarations
  }

  /// `static func __structuredAction_foo(bar: Bool.Type = Bool.self) -> {ns}.StructuredAction<…> { … }`
  ///
  /// The defaulted metatype parameters mirror the decorated function's, so
  /// overloads of the same base name get distinct sidecars; call sites only
  /// pass them to disambiguate.
  private func sidecarFunction() -> FunctionDeclSyntax {
    FunctionDeclSyntax(
      modifiers: .visibility(isPublic, static: true),
      name: sidecarName,
      signature: FunctionSignatureSyntax(
        parameterClause: sidecarParameterClause(),
        returnClause: ReturnClauseSyntax(type: callableType())
      ),
      body: CodeBlockSyntax {
        callableInitExpr()
      }
    )
  }

  /// `(bar: Bool.Type = Bool.self, _ baz: Bool.Type = Bool.self)`
  private func sidecarParameterClause() -> FunctionParameterClauseSyntax {
    FunctionParameterClauseSyntax(
      parameters: FunctionParameterListSyntax {
        for parameter in parameters {
          FunctionParameterSyntax(
            firstName: parameter.firstName.trimmed,
            secondName: parameter.secondName?.trimmed,
            type: MemberTypeSyntax(
              baseType: parameter.type.trimmed,
              name: "Type"
            ),
            defaultValue: InitializerClauseSyntax(
              value: MemberAccessExprSyntax(
                base: TypeExprSyntax(type: parameter.type.trimmed),
                name: "self"
              )
            )
          )
        }
      }
    )
  }

  /// `{ns}.StructuredAction<Callee, {ns}.StructuredActionSignature<Input, Output, SyncInput, Failure>>`
  private func callableType() -> TypeSyntax {
    TypeSyntax(
      namespace.memberType(
        name: "StructuredAction",
        genericArgumentClause: GenericArgumentClauseSyntax {
          GenericArgumentSyntax(argument: GenericArgumentSyntax.Argument(calleeType))
          GenericArgumentSyntax(argument: GenericArgumentSyntax.Argument(signatureType()))
        }
      )
    )
  }

  private func signatureType() -> TypeSyntax {
    TypeSyntax(
      namespace.memberType(
        name: "StructuredActionSignature",
        genericArgumentClause: GenericArgumentClauseSyntax {
          GenericArgumentSyntax(
            argument: GenericArgumentSyntax.Argument(input.typeSyntax(in: namespace)))
          GenericArgumentSyntax(
            argument: GenericArgumentSyntax.Argument(output.typeSyntax(in: namespace)))
          GenericArgumentSyntax(
            argument: GenericArgumentSyntax.Argument(
              isEffectivelyAsync ? TypeSyntax("Never") : input.typeSyntax(in: namespace)))
          GenericArgumentSyntax(argument: GenericArgumentSyntax.Argument(failureType))
        }
      )
    )
  }

  /// `Void` for static functions, the enclosing type's name for instance
  /// methods.
  private var calleeType: TypeSyntax {
    switch context {
    case .staticMember:
      "Void"
    case .instanceMember(let calleeType):
      calleeType
    }
  }

  private var failureType: TypeSyntax {
    switch failure {
    case .never:
      "Never"
    case .typed(let type):
      type.trimmed
    case .untyped:
      TypeSyntax(
        SomeOrAnyTypeSyntax(
          someOrAnySpecifier: .keyword(.any),
          constraint: IdentifierTypeSyntax(name: "Error")
        )
      )
    }
  }

  private var isThrowing: Bool {
    switch failure {
    case .never:
      false
    case .typed, .untyped:
      true
    }
  }

  /// `{ns}.StructuredAction(name: "foo", …, invoke: { … })`
  private func callableInitExpr() -> FunctionCallExprSyntax {
    FunctionCallExprSyntax(
      calledExpression: namespace.member(name: "StructuredAction"),
      leftParen: .leftParenToken(trailingTrivia: .newline),
      arguments: LabeledExprListSyntax {
        LabeledExprSyntax(
          label: "name",
          colon: .colonToken(),
          expression: StringLiteralExprSyntax(content: baseName.text),
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
        if let inputDescription {
          LabeledExprSyntax(
            label: "inputDescription",
            colon: .colonToken(),
            expression: inputDescription.trimmed,
            trailingComma: .commaToken(trailingTrivia: .newline)
          )
        }
        if let outputDescription {
          LabeledExprSyntax(
            label: "outputDescription",
            colon: .colonToken(),
            expression: outputDescription.trimmed,
            trailingComma: .commaToken(trailingTrivia: .newline)
          )
        }
        LabeledExprSyntax(
          label: "invoke",
          colon: .colonToken(),
          expression: glueClosure()
        )
      },
      rightParen: .rightParenToken(leadingTrivia: .newline)
    )
  }

  /// `{ (callee, input) throws in … }` — unpacks the collapsed `Input` into
  /// the original argument list, calls the decorated function, and packs the
  /// result into the collapsed `Output`. Always the two-parameter shape so
  /// exactly one `StructuredAction` initializer matches; unused parameters
  /// are wildcards.
  private func glueClosure() -> ClosureExprSyntax {
    ClosureExprSyntax(
      signature: ClosureSignatureSyntax(
        parameterClause: .parameterClause(
          ClosureParameterClauseSyntax(
            parameters: ClosureParameterListSyntax {
              ClosureParameterSyntax(
                firstName: isInstanceMember ? "callee" : .wildcardToken()
              )
              ClosureParameterSyntax(
                firstName: input.componentCount == 0 ? .wildcardToken() : "input"
              )
            }
          )
        ),
        effectSpecifiers: closureEffectSpecifiers()
      ),
      statements: glueClosureStatements()
    )
  }

  private func closureEffectSpecifiers() -> TypeEffectSpecifiersSyntax? {
    let throwsClause: ThrowsClauseSyntax? =
      switch failure {
      case .never:
        nil
      case .untyped:
        ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))
      case .typed(let type):
        ThrowsClauseSyntax(
          throwsSpecifier: .keyword(.throws),
          leftParen: .leftParenToken(),
          type: type.trimmed,
          rightParen: .rightParenToken()
        )
      }
    guard isEffectivelyAsync || throwsClause != nil else {
      return nil
    }
    return TypeEffectSpecifiersSyntax(
      asyncSpecifier: isEffectivelyAsync ? .keyword(.async) : nil,
      throwsClause: throwsClause
    )
  }

  @CodeBlockItemListBuilder
  private func glueClosureStatements() -> CodeBlockItemListSyntax {
    switch output {
    case .single:
      // A single expression — the closure's implicit return.
      callExpr()
    case .none:
      // The call is pure effect; the representation is an empty object.
      callExpr()
      ReturnStmtSyntax(
        expression: output.representationExpr(packing: [], in: namespace)
      )
    case .tuple, .object:
      VariableDeclSyntax(
        bindingSpecifier: .keyword(.let),
        bindings: PatternBindingListSyntax {
          PatternBindingSyntax(
            pattern: IdentifierPatternSyntax(identifier: "output"),
            initializer: InitializerClauseSyntax(value: callExpr())
          )
        }
      )
      ReturnStmtSyntax(
        expression: output.representationExpr(
          packing: (0..<output.componentCount).map { index in
            ExprSyntax(member(DeclReferenceExprSyntax(baseName: "output"), "\(index)"))
          },
          in: namespace
        )
      )
    }
  }

  /// `try await callee.foo(bar: input.values.0, input.values.1)`
  private func callExpr() -> ExprSyntax {
    let call = FunctionCallExprSyntax(
      calledExpression: calledExpression,
      leftParen: .leftParenToken(),
      arguments: input.argumentList(unpacking: DeclReferenceExprSyntax(baseName: "input")),
      rightParen: .rightParenToken()
    )
    switch (isEffectivelyAsync, isThrowing) {
    case (false, false):
      return ExprSyntax(call)
    case (true, false):
      return ExprSyntax(AwaitExprSyntax(expression: call))
    case (false, true):
      return ExprSyntax(TryExprSyntax(expression: call))
    case (true, true):
      return ExprSyntax(TryExprSyntax(expression: AwaitExprSyntax(expression: call)))
    }
  }

  /// `callee.foo` for instance methods, `foo` otherwise — a static sidecar's
  /// unqualified reference resolves to the static member.
  private var calledExpression: ExprSyntax {
    switch context {
    case .instanceMember:
      ExprSyntax(
        MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: "callee"),
          name: baseName
        )
      )
    case .staticMember:
      ExprSyntax(DeclReferenceExprSyntax(baseName: baseName))
    }
  }

}

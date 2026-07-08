import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - Declaration Dispatch

extension DeclGroupSyntax {

  func structuredCodableType(
    in context: StructuredCodableMacroContext
  ) -> StructuredCodableType? {
    if let structDecl = self.as(StructDeclSyntax.self) {
      guard let kind = structDecl.structuredCodableKind(in: context) else {
        return nil
      }
      return StructuredCodableType(
        isPublic: structDecl.modifiers.contains(where: \.isPublic),
        typeSyntax: context.extendedType.bindingGenericParameters(
          structDecl.genericParameterClause
        ),
        kind: kind
      )
    } else if let classDecl = self.as(ClassDeclSyntax.self) {
      return StructuredCodableType(
        isPublic: classDecl.modifiers.contains(where: \.isPublic),
        typeSyntax: context.extendedType.bindingGenericParameters(
          classDecl.genericParameterClause
        ),
        kind: .object(classDecl.objectSchema(in: context))
      )
    } else if let enumDecl = self.as(EnumDeclSyntax.self) {
      return StructuredCodableType(
        isPublic: enumDecl.modifiers.contains(where: \.isPublic),
        typeSyntax: context.extendedType.bindingGenericParameters(
          enumDecl.genericParameterClause
        ),
        kind: .enumeration(enumDecl.enumerationSchema(in: context))
      )
    } else {
      context.expansionContext.diagnose(
        DiagnosticError(
          node: self,
          severity: .error,
          message: "Unsupported declaration of kind: \(self.kind)"
        )
      )
      return nil
    }
  }

}

// MARK: - Object Schema Parsing

extension StructDeclSyntax {

  /// A struct lowers onto `StructuredObject` by default; `style: .wrapper`
  /// selects `StructuredWrapper` instead, which requires exactly one stored
  /// property, neither optional nor defaulted. Returns `nil` (after
  /// diagnosing) when the wrapper requirements are violated, so no
  /// conformance is generated.
  fileprivate func structuredCodableKind(
    in context: StructuredCodableMacroContext
  ) -> StructuredCodableType.Kind? {
    let arguments = parseArguments(
      ofAttribute: context.macroAttribute,
      as: (
        DescriptionArgument.self, StructStyleArgument.self,
        KeyConversionStrategyArgument.self, CompatibilityModeArgument.self
      ),
      in: context.expansionContext
    )
    let schema = memberBlock.objectSchema(
      description: arguments.0,
      keyConversionStrategy: arguments.2,
      compatibilityMode: arguments.3,
      in: context
    )

    guard let style = arguments.1 else {
      return .object(schema)
    }
    switch style {
    case .wrapper:
      guard schema.properties.count == 1 else {
        context.expansionContext.diagnose(
          DiagnosticError(
            node: name,
            severity: .error,
            message: "A wrapper struct must declare exactly one stored property."
          )
        )
        return nil
      }
      return .wrapper(schema)
    }
  }
}

extension ClassDeclSyntax {

  fileprivate func objectSchema(
    in context: StructuredCodableMacroContext
  ) -> ObjectSchema {
    let arguments = parseArguments(
      ofAttribute: context.macroAttribute,
      as: (
        DescriptionArgument.self, KeyConversionStrategyArgument.self,
        CompatibilityModeArgument.self
      ),
      in: context.expansionContext
    )
    return memberBlock.objectSchema(
      description: arguments.0,
      keyConversionStrategy: arguments.1,
      compatibilityMode: arguments.2,
      in: context
    )
  }
}

extension MemberBlockSyntax {

  fileprivate func objectSchema(
    description: DescriptionArgument?,
    keyConversionStrategy: KeyConversionStrategyArgument?,
    compatibilityMode: CompatibilityModeArgument?,
    in context: StructuredCodableMacroContext
  ) -> ObjectSchema {
    ObjectSchema(
      namespace: context.namespace,
      rootType: "Self",
      isSynthesized: false,
      keyConversionStrategy: keyConversionStrategy?.value
        ?? context.defaultKeyConversionStrategy,
      compatibilityModes: compatibilityMode?.modes ?? [],
      description: description?.expression,
      properties: parseObjectProperties(in: context)
    )
  }

  fileprivate func parseObjectProperties(
    in context: StructuredCodableMacroContext
  ) -> [ObjectSchema.Property] {
    members.flatMap { member -> [ObjectSchema.Property] in
      guard let variable = member.decl.as(VariableDeclSyntax.self) else {
        return []
      }
      guard !variable.bindings.contains(where: { $0.accessorBlock != nil }) else {
        /// This is a computed property
        return []
      }
      guard !variable.modifiers.contains(where: \.isStatic) else {
        /// This is a static property
        return []
      }

      // Validate: @StructuredCase should not be used on struct properties
      if variable.hasAttribute("StructuredCase") {
        context.expansionContext.diagnose(
          DiagnosticError(
            node: variable,
            severity: .error,
            message:
              "@StructuredCase cannot be used on struct properties. Use @StructuredProperty instead."
          )
        )
      }

      let description =
        variable.parseArguments(
          ofAttribute: "StructuredProperty",
          as: DescriptionArgument.self,
          in: context.expansionContext
        )

      let isMutable = variable.bindingSpecifier.tokenKind == .keyword(.var)

      /// In order to handle complex declarations such as `let a, b: Bool, c: String`, we iterate over the bindings in reverse and store the last type annotation.
      var lastTypeAnnotation: TypeSyntax?
      return variable.bindings
        .reversed()
        .compactMap { binding -> ObjectSchema.Property? in
          guard
            let type = binding.typeAnnotation?.type
              ?? lastTypeAnnotation
              ?? binding.initializer?.value.inferredLiteralType
          else {
            context.expansionContext.diagnose(
              DiagnosticError(
                node: variable,
                severity: .error,
                message: "Property must specify an explicit type."
              )
            )
            return nil
          }
          lastTypeAnnotation = type

          guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier else {
            context.expansionContext.diagnose(
              DiagnosticError(
                node: binding,
                severity: .error,
                message: "Binding pattern does not have an identifier."
              )
            )
            return nil
          }

          guard let identifier = name.identifier else {
            context.expansionContext.diagnose(
              DiagnosticError(
                node: name,
                severity: .error,
                message: "Name must be an identifier."
              )
            )
            return nil
          }

          let defaulting: ObjectSchema.Property.Defaulting
          if let initializer = binding.initializer {
            defaulting = isMutable ? .mutable(defaultValue: initializer.value) : .immutable
          } else {
            defaulting = .none
          }

          return ObjectSchema.Property(
            name: IdentifiableToken(
              identifier: identifier,
              token: name
            ),
            definition: ObjectSchema.Property.Definition(
              valueType: type,
              defaulting: defaulting
            ),
            propertyTypeAliasName: context.expansionContext.makeUniqueName(
              identifier.name
            ),
            description: description?.expression
          )

        }
        .reversed()
    }
  }
}

// MARK: - Enumeration Schema Parsing

extension EnumDeclSyntax {

  fileprivate func enumerationSchema(
    in context: StructuredCodableMacroContext
  ) -> EnumerationSchema {
    let (description, style, keyConversionStrategyArgument, compatibilityModeArgument) =
      parseArguments(
        ofAttribute: context.macroAttribute,
        as: (
          DescriptionArgument.self,
          EnumStyleArgument.self,
          KeyConversionStrategyArgument.self,
          CompatibilityModeArgument.self
        ),
        in: context.expansionContext
      )
    let keyConversionStrategy =
      keyConversionStrategyArgument?.value ?? context.defaultKeyConversionStrategy
    let compatibilityModes = compatibilityModeArgument?.modes ?? []

    return EnumerationSchema(
      namespace: context.namespace,
      typeName: "Self",
      keyConversionStrategy: keyConversionStrategy,
      compatibilityModes: compatibilityModes,
      codingStyle: (style ?? context.defaultEnumStyle).codingStyle,
      description: description?.expression,
      cases: memberBlock
        .members
        .flatMap { member -> [EnumerationSchema.Case] in
          guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
            return []
          }
          // Validate: @StructuredProperty should not be used on enum cases
          if caseDecl.hasAttribute("StructuredProperty") {
            context.expansionContext.diagnose(
              DiagnosticError(
                node: caseDecl,
                severity: .error,
                message: "@StructuredProperty cannot be used on enum cases. Use @StructuredCase instead."
              )
            )
          }

          let description = caseDecl.parseArguments(
            ofAttribute: "StructuredCase",
            as: DescriptionArgument.self,
            in: context.expansionContext
          )

          return caseDecl.elements.compactMap { element -> EnumerationSchema.Case? in
            guard let name = element.name.identifier else {
              context.expansionContext.diagnose(
                DiagnosticError(
                  node: element.name,
                  severity: .error,
                  message: "Missing Identifier"
                )
              )
              return nil
            }

            return EnumerationSchema.Case(
              name: IdentifiableToken(
                identifier: name,
                token: element.name
              ),
              associatedValue: element.associatedValue(
                caseName: name,
                keyConversionStrategy: keyConversionStrategy,
                compatibilityModes: compatibilityModes,
                in: context
              ),
              description: description?.expression
            )
          }
        }
    )
  }

}

extension EnumCaseElementSyntax {

  /// Collapses a case's 0/1/N associated values onto the single type a
  /// `StructuredEnumerationCase` wraps, following the rules in `AssociatedValue`.
  fileprivate func associatedValue(
    caseName: Identifier,
    keyConversionStrategy: KeyConversionStrategy,
    compatibilityModes: CompatibilityModes,
    in context: StructuredCodableMacroContext
  ) -> EnumerationSchema.Case.AssociatedValue {
    let elements: [EnumerationSchema.Case.Element] =
      parameterClause?.parameters.map { parameter in
        let label: TokenSyntax?
        if let firstName = parameter.firstName, firstName.tokenKind != .wildcard {
          label = firstName
        } else {
          label = nil
        }
        return EnumerationSchema.Case.Element(label: label, type: parameter.type)
      } ?? []

    switch elements.count {
    case 0:
      return .none
    case 1:
      // A label names an object property, so a labeled value synthesizes a
      // one-property object exactly as labels do on multi-value cases (and
      // an internally-tagged payload must be an object for the discriminator
      // to live alongside its properties).
      if elements[0].label != nil {
        return .object(
          synthesizedObject(
            for: elements,
            caseName: caseName,
            keyConversionStrategy: keyConversionStrategy,
            compatibilityModes: compatibilityModes,
            in: context
          )
        )
      }
      return .single(elements[0])
    default:
      if elements.allSatisfy({ $0.label != nil }) {
        return .object(
          synthesizedObject(
            for: elements,
            caseName: caseName,
            keyConversionStrategy: keyConversionStrategy,
            compatibilityModes: compatibilityModes,
            in: context
          )
        )
      } else {
        return .tuple(elements)
      }
    }
  }

  /// Builds the `StructuredObject` that stands in for an all-labeled case,
  /// assigning it and each of its properties a unique macro-generated name.
  private func synthesizedObject(
    for elements: [EnumerationSchema.Case.Element],
    caseName: Identifier,
    keyConversionStrategy: KeyConversionStrategy,
    compatibilityModes: CompatibilityModes,
    in context: StructuredCodableMacroContext
  ) -> ObjectSchema {
    ObjectSchema(
      namespace: context.namespace,
      rootType: context.expansionContext.makeUniqueName(caseName.name),
      isSynthesized: true,
      keyConversionStrategy: keyConversionStrategy,
      compatibilityModes: compatibilityModes,
      description: nil,
      properties: elements.compactMap { element in
        guard let label = element.label, let identifier = label.identifier else {
          return nil
        }
        return ObjectSchema.Property(
          name: IdentifiableToken(identifier: identifier, token: label),
          definition: ObjectSchema.Property.Definition(
            valueType: element.type,
            defaulting: .none
          ),
          propertyTypeAliasName: context.expansionContext.makeUniqueName(identifier.name),
          description: nil
        )
      }
    )
  }

}

extension Optional where Wrapped == EnumStyleArgument {

  /// Maps the parsed `@StructuredCodable(style:)` argument (or its absence) onto the
  /// definition's coding style.
  fileprivate var codingStyle: EnumerationSchema.CodingStyle {
    switch self {
    case .none, .objectProperties:
      return .objectProperties
    case .internallyTagged(let discriminatorPropertyName):
      return .internallyTagged(discriminatorPropertyName: discriminatorPropertyName)
    case .typeDiscriminated:
      return .typeDiscriminated
    }
  }

}

// MARK: - Callable Schema Parsing

extension FunctionDeclSyntax {

  func callableSchema(
    namespace: StructuredCodingNamespace,
    additionalArguments: LabeledExprListSyntax,
    keyConversionStrategy: KeyConversionStrategy,
    in context: some MacroExpansionContext
  ) -> CallableSchema {
    let signature = self.signature

    // Parse parameters
    let parameters = signature.parameterClause.parameters.enumerated().map { (offset, param) in
      SchemaParameter(
        firstName: param.firstName,
        secondName: param.secondName,
        type: param.type.schemaType,
        bindingName: "__param_\(raw: offset)"
      )
    }

    // Parse return type
    let returnType = parseReturnType(signature.returnClause?.type)

    // Parse effect specifiers
    let isAsync = signature.effectSpecifiers?.asyncSpecifier != nil
    let throwsClause = signature.effectSpecifiers?.throwsClause

    // Build full function name like "foo(bar:_:)"
    let fullName = buildFullName(baseName: name, parameters: parameters)

    // Instance methods require a callee; static methods do not
    let isMethod = !context.lexicalContext.isEmpty && !modifiers.contains(where: \.isStatic)

    return CallableSchema(
      namespace: namespace,
      name: name,
      fullName: fullName,
      additionalArguments: additionalArguments,
      keyConversionStrategy: keyConversionStrategy,
      parameters: parameters,
      returnType: returnType,
      isAsync: isAsync,
      throwsClause: throwsClause,
      isMethod: isMethod
    )
  }

  private func parseReturnType(_ type: TypeSyntax?) -> CallableSchema.ReturnType {
    guard let type else {
      return .void
    }

    // Check for Void identifier
    if let identifier = type.as(IdentifierTypeSyntax.self),
      identifier.name.text == "Void"
    {
      return .void
    }

    // Check for tuple type
    if let tupleType = type.as(TupleTypeSyntax.self) {
      // Empty tuple is Void
      guard !tupleType.elements.isEmpty else {
        return .void
      }

      // Single unlabeled element is treated as single type
      if tupleType.elements.count == 1,
        let element = tupleType.elements.first,
        element.firstName == nil
      {
        return .single(element.type)
      }

      // Multi-element or labeled tuple
      let elements = tupleType.elements.map { element in
        (label: element.firstName, type: element.type)
      }
      return .tuple(elements)
    }

    // Single type
    return .single(type)
  }

  private func buildFullName(
    baseName: TokenSyntax,
    parameters: [SchemaParameter]
  ) -> String {
    let labels = parameters.map { param -> String in
      if param.firstName.tokenKind == .wildcard {
        return "_:"
      } else {
        return "\(param.firstName.text):"
      }
    }.joined()
    return "\(baseName.text)(\(labels))"
  }

}

// MARK: - SchemaType Parsing

extension TypeSyntax {

  var schemaType: SchemaType {
    // Check for optional wrapping a tuple: (A, B)?
    if let optionalType = self.as(OptionalTypeSyntax.self),
      let tupleType = optionalType.wrappedType.as(TupleTypeSyntax.self),
      tupleType.elements.count >= 2
    {
      return SchemaType(
        syntax: self,
        kind: .optionalTuple(tupleType.elements.map(\.type))
      )
    }

    // Check for tuple: (A, B)
    if let tupleType = self.as(TupleTypeSyntax.self),
      tupleType.elements.count >= 2
    {
      return SchemaType(
        syntax: self,
        kind: .tuple(tupleType.elements.map(\.type))
      )
    }

    // Everything else
    return SchemaType(syntax: self, kind: .other(self))
  }

  /// Returns this type with generic arguments appended to its terminal segment,
  /// referencing each generic parameter by name. For nil or empty parameter
  /// clauses returns self unchanged.
  func bindingGenericParameters(
    _ genericParameters: GenericParameterClauseSyntax?
  ) -> TypeSyntax {
    guard let parameters = genericParameters?.parameters, !parameters.isEmpty else {
      return self
    }
    let argumentClause = GenericArgumentClauseSyntax {
      for param in parameters {
        GenericArgumentSyntax(
          argument: GenericArgumentSyntax.Argument(IdentifierTypeSyntax(name: param.name))
        )
      }
    }
    if var identifier = self.as(IdentifierTypeSyntax.self) {
      identifier.genericArgumentClause = argumentClause
      return TypeSyntax(identifier)
    } else if var member = self.as(MemberTypeSyntax.self) {
      member.genericArgumentClause = argumentClause
      return TypeSyntax(member)
    }
    return self
  }

}

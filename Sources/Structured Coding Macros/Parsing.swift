import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - Compatibility Mode Inference

extension CompatibilityModes {

  /// The modes a declaration needs without spelling them explicitly:
  /// `.variadicGenerics` is inferred when the decorated type — or any type or
  /// function it is lexically nested in — declares a parameter pack, since
  /// key path literals rooted in such a type crash at runtime. The inference
  /// is syntactic, so it cannot see a pack hidden behind an extension
  /// (`extension Outer { @StructuredCodable struct Inner {} }` where `Outer`
  /// is pack-generic); those types must still spell the mode explicitly.
  init(
    inferredFrom declaration: some DeclGroupSyntax,
    in expansionContext: MacroExpansionContext
  ) {
    self.init(inferredFromAnyOf: [Syntax(declaration)] + expansionContext.lexicalContext)
  }

  /// The variant for peer macros (`@StructuredCallable`), which decorate a
  /// declaration that cannot itself introduce a pack (generic functions are
  /// rejected) but may be nested in one.
  init(inferredFromLexicalContextOf expansionContext: some MacroExpansionContext) {
    self.init(inferredFromAnyOf: expansionContext.lexicalContext)
  }

  private init(inferredFromAnyOf enclosingDeclarations: [Syntax]) {
    let declaresParameterPack = enclosingDeclarations.contains { declaration in
      declaration
        .asProtocol(WithGenericParametersSyntax.self)?
        .genericParameterClause?
        .parameters
        .contains { parameter in
          parameter.specifier?.tokenKind == .keyword(.each)
        }
        ?? false
    }
    self = declaresParameterPack ? .variadicGenerics : []
  }

}

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
      compatibilityModes: (compatibilityMode?.modes ?? [])
        .union(context.inferredCompatibilityModes),
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
    let compatibilityModes = (compatibilityModeArgument?.modes ?? [])
      .union(context.inferredCompatibilityModes)

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
              associatedValue: ParameterClauseSchema(
                collapsing: element.parameterClause?.parameters.parameterClauseElements ?? [],
                synthesizedObjectNameSeed: name.name,
                namespace: context.namespace,
                keyConversionStrategy: keyConversionStrategy,
                compatibilityModes: compatibilityModes,
                in: context.expansionContext
              ),
              description: description?.expression
            )
          }
        }
    )
  }

}

// MARK: - Parameter Clause Parsing

extension ParameterClauseSchema {

  /// Collapses a clause's 0/1/N elements onto the single type that represents
  /// it, following the rules documented on the cases.
  ///
  /// Takes its dependencies piecewise rather than as a
  /// `StructuredCodableMacroContext` because it is shared with the
  /// `@StructuredCallable` peer macro, which has no such context.
  init(
    collapsing elements: [Element],
    synthesizedObjectNameSeed nameSeed: String,
    namespace: StructuredCodingNamespace,
    keyConversionStrategy: KeyConversionStrategy,
    compatibilityModes: CompatibilityModes,
    in expansionContext: MacroExpansionContext
  ) {
    switch elements.count {
    case 0:
      self = .none
    case 1 where elements[0].label == nil:
      self = .single(elements[0])
    default:
      // A label names an object property, so a single labeled value
      // synthesizes a one-property object exactly as labels do on
      // multi-value clauses (and an internally-tagged payload must be an
      // object for the discriminator to live alongside its properties).
      guard elements.allSatisfy({ $0.label != nil }) else {
        self = .tuple(elements)
        return
      }
      // The `StructuredObject` that stands in for an all-labeled clause,
      // assigning it and each of its properties a unique macro-generated name.
      self = .object(
        ObjectSchema(
          namespace: namespace,
          rootType: expansionContext.makeUniqueName(nameSeed),
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
                defaulting: element.defaultValue
                  .map { .mutable(defaultValue: $0) } ?? .none
              ),
              propertyTypeAliasName: expansionContext.makeUniqueName(identifier.name),
              description: nil
            )
          }
        )
      )
    }
  }

}

extension EnumCaseParameterListSyntax {

  var parameterClauseElements: [ParameterClauseSchema.Element] {
    map { parameter in
      let label: TokenSyntax?
      if let firstName = parameter.firstName, firstName.tokenKind != .wildcard {
        label = firstName
      } else {
        label = nil
      }
      return ParameterClauseSchema.Element(
        label: label,
        type: parameter.type,
        defaultValue: parameter.defaultValue?.value
      )
    }
  }

}

extension TupleTypeElementListSyntax {

  var parameterClauseElements: [ParameterClauseSchema.Element] {
    map { element in
      let label: TokenSyntax?
      if let firstName = element.firstName, firstName.tokenKind != .wildcard {
        label = firstName
      } else {
        label = nil
      }
      return ParameterClauseSchema.Element(
        label: label,
        type: element.type,
        defaultValue: nil
      )
    }
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

  /// Lowers a `@StructuredCallable`-decorated function onto the IR the
  /// sidecar generator consumes, or `nil` (after diagnosing) when the
  /// function cannot be represented.
  func callableSchema(
    namespace: StructuredCodingNamespace,
    description: StringLiteralExprSyntax?,
    inputDescription: StringLiteralExprSyntax?,
    outputDescription: StringLiteralExprSyntax?,
    keyConversionStrategy: KeyConversionStrategy,
    in context: some MacroExpansionContext
  ) -> CallableSchema? {
    guard name.identifier != nil else {
      context.diagnose(
        DiagnosticError(
          node: name,
          severity: .error,
          message: "@StructuredCallable requires a function with an identifier name"
        )
      )
      return nil
    }

    // Generic functions have no concrete Input/Output types to collapse onto.
    if let unsupported = genericParameterClause.map(Syntax.init) ?? genericWhereClause.map(Syntax.init) {
      context.diagnose(
        DiagnosticError(
          node: unsupported,
          severity: .error,
          message: "@StructuredCallable does not support generic functions"
        )
      )
      return nil
    }

    for modifier in modifiers {
      switch modifier.name.tokenKind {
      case .keyword(.mutating), .keyword(.borrowing), .keyword(.consuming):
        context.diagnose(
          DiagnosticError(
            node: modifier,
            severity: .error,
            message: "@StructuredCallable does not support `\(modifier.name.trimmed)` methods"
          )
        )
        return nil
      default:
        break
      }
    }

    let isAsync: Bool
    switch signature.effectSpecifiers?.asyncSpecifier?.tokenKind {
    case .none:
      isAsync = false
    case .keyword(.async):
      isAsync = true
    case .some:
      context.diagnose(
        DiagnosticError(
          node: signature.effectSpecifiers!,
          severity: .error,
          message: "@StructuredCallable does not support `reasync`"
        )
      )
      return nil
    }

    let failure: CallableSchema.Failure
    if let throwsClause = signature.effectSpecifiers?.throwsClause {
      switch throwsClause.throwsSpecifier.tokenKind {
      case .keyword(.throws):
        failure = throwsClause.type.map { .typed($0) } ?? .untyped
      default:
        context.diagnose(
          DiagnosticError(
            node: throwsClause,
            severity: .error,
            message: "@StructuredCallable does not support `rethrows`"
          )
        )
        return nil
      }
    } else {
      failure = .never
    }

    let callableContext: CallableSchema.Context
    if let innermost = context.lexicalContext.first {
      guard innermost.asProtocol(DeclGroupSyntax.self) != nil else {
        context.diagnose(
          DiagnosticError(
            node: name,
            severity: .error,
            message: "@StructuredCallable cannot be applied to local functions"
          )
        )
        return nil
      }
      guard !innermost.is(ProtocolDeclSyntax.self) else {
        context.diagnose(
          DiagnosticError(
            node: name,
            severity: .error,
            message: "@StructuredCallable cannot be applied to protocol requirements"
          )
        )
        return nil
      }
      callableContext = modifiers.contains(where: \.isStatic) ? .staticMember : .instanceMember
    } else {
      callableContext = .topLevel
    }

    guard
      let inputElements = signature.parameterClause.parameters.parameterClauseElements(in: context)
    else {
      return nil
    }

    let compatibilityModes = CompatibilityModes(inferredFromLexicalContextOf: context)

    let input = ParameterClauseSchema(
      collapsing: inputElements,
      synthesizedObjectNameSeed: "\(overloadSeed)_Input",
      namespace: namespace,
      keyConversionStrategy: keyConversionStrategy,
      compatibilityModes: compatibilityModes,
      in: context
    )

    // Defaults survive only in the `.object` collapse, where they lower like
    // defaulted struct properties; in the other collapses the representation
    // has nowhere to record them.
    if case .single = input {
      diagnoseIgnoredDefaults(inputElements, in: context)
    } else if case .tuple = input {
      diagnoseIgnoredDefaults(inputElements, in: context)
    }

    let output = ParameterClauseSchema(
      collapsing: returnClauseElements(signature.returnClause?.type),
      synthesizedObjectNameSeed: "\(overloadSeed)_Output",
      namespace: namespace,
      keyConversionStrategy: keyConversionStrategy,
      compatibilityModes: compatibilityModes,
      in: context
    )

    return CallableSchema(
      namespace: namespace,
      isPublic: modifiers.contains(where: \.isPublic),
      baseName: name.trimmed,
      fullName: fullName,
      parameters: signature.parameterClause.parameters,
      input: input,
      output: output,
      isAsync: isAsync,
      failure: failure,
      context: callableContext,
      description: description,
      inputDescription: inputDescription,
      outputDescription: outputDescription
    )
  }

  /// A deterministic seed for the synthesized Input/Output type names that no
  /// two overloads of the same base name can share. `makeUniqueName` alone is
  /// not enough: its discriminator is derived from the decorated declaration's
  /// *name*, so two `over(x:)` overloads would collide. Folding the full
  /// signature into the seed (sanitized to identifier characters) keeps the
  /// generated names distinct — labels, parameter types, return type, and
  /// `async` are exactly the axes Swift allows overloading on.
  private var overloadSeed: String {
    var seed = name.text
    for parameter in signature.parameterClause.parameters {
      seed += "_\(parameter.firstName.text)_\(parameter.type.trimmedDescription)"
    }
    if let returnType = signature.returnClause?.type {
      seed += "_\(returnType.trimmedDescription)"
    }
    if signature.effectSpecifiers?.asyncSpecifier != nil {
      seed += "_async"
    }
    return String(seed.map { $0.isLetter || $0.isNumber ? $0 : "_" })
  }

  /// `"foo(bar:_:)"`
  private var fullName: String {
    let labels = signature.parameterClause.parameters
      .map { parameter -> String in
        if parameter.firstName.tokenKind == .wildcard {
          return "_:"
        } else {
          return "\(parameter.firstName.trimmed):"
        }
      }
      .joined()
    return "\(name.trimmed)(\(labels))"
  }

  /// The return type as parameter-clause elements: `Void` in any spelling is
  /// empty, a parenthesized single type unwraps, a tuple contributes its
  /// elements, and anything else is a single unlabeled element.
  private func returnClauseElements(_ type: TypeSyntax?) -> [ParameterClauseSchema.Element] {
    guard let type else {
      return []
    }

    if let identifier = type.as(IdentifierTypeSyntax.self),
      identifier.name.text == "Void"
    {
      return []
    }

    if let tupleType = type.as(TupleTypeSyntax.self) {
      guard !tupleType.elements.isEmpty else {
        return []
      }

      if tupleType.elements.count == 1,
        let element = tupleType.elements.first,
        element.firstName == nil
      {
        return returnClauseElements(element.type)
      }

      return tupleType.elements.parameterClauseElements
    }

    return [ParameterClauseSchema.Element(label: nil, type: type, defaultValue: nil)]
  }

  private func diagnoseIgnoredDefaults(
    _ elements: [ParameterClauseSchema.Element],
    in context: some MacroExpansionContext
  ) {
    for element in elements {
      guard let defaultValue = element.defaultValue else { continue }
      context.diagnose(
        DiagnosticError(
          node: defaultValue,
          severity: .warning,
          message:
            "Default value is ignored: only functions whose parameters are all labeled can encode defaults"
        )
      )
    }
  }

}

extension FunctionParameterListSyntax {

  /// Lowers a function's parameters to parameter-clause elements, or `nil`
  /// (after diagnosing) when a parameter cannot be represented. The internal
  /// name (`secondName`) only ever names the binding inside the function
  /// body, so only the label survives lowering.
  func parameterClauseElements(
    in context: some MacroExpansionContext
  ) -> [ParameterClauseSchema.Element]? {
    var elements: [ParameterClauseSchema.Element] = []
    for parameter in self {
      guard parameter.ellipsis == nil else {
        context.diagnose(
          DiagnosticError(
            node: parameter,
            severity: .error,
            message: "@StructuredCallable does not support variadic parameters"
          )
        )
        return nil
      }

      if let specifier = parameter.type.as(AttributedTypeSyntax.self)?.specifiers.first {
        context.diagnose(
          DiagnosticError(
            node: parameter,
            severity: .error,
            message: "@StructuredCallable does not support `\(specifier.trimmed)` parameters"
          )
        )
        return nil
      }

      let label: TokenSyntax?
      if parameter.firstName.tokenKind == .wildcard {
        label = nil
      } else {
        guard parameter.firstName.identifier != nil else {
          context.diagnose(
            DiagnosticError(
              node: parameter.firstName,
              severity: .error,
              message: "Parameter labels must be identifiers"
            )
          )
          return nil
        }
        label = parameter.firstName
      }

      elements.append(
        ParameterClauseSchema.Element(
          label: label,
          type: parameter.type,
          defaultValue: parameter.defaultValue?.value
        )
      )
    }
    return elements
  }

}

extension TypeSyntax {

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

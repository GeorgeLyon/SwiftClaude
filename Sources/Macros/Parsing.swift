import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension DeclGroupSyntax {

  func schemaCodableType(
    in context: SchemaCodableMacroContext
  ) -> SchemaCodableType? {
    if let structDecl = self.as(StructDeclSyntax.self) {
      return SchemaCodableType(
        isPublic: structDecl.modifiers.contains(where: \.isPublic),
        schemaKind: .struct(structDecl.schema(in: context))
      )
    } else if let enumDecl = self.as(EnumDeclSyntax.self) {
      return SchemaCodableType(
        isPublic: enumDecl.modifiers.contains(where: \.isPublic),
        schemaKind: .enum(enumDecl.schema(in: context))
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

extension StructDeclSyntax {

  fileprivate func schema(
    in context: SchemaCodableMacroContext
  ) -> StructSchema {

    let (description, style, keyConversionStrategy) = parseArguments(
      ofAttribute: context.macroAttribute,
      as: (
        DescriptionArgument.self,
        StructStyleArgument.self,
        KeyConversionStrategyArgument.self
      ),
      in: context.expansionContext
    )

    return StructSchema(
      namespace: context.namespace,
      typeName: "Self",
      additionalArguments: .fromArguments(description),
      style: style,
      keyConversionStrategy: keyConversionStrategy?.value
        ?? context.defaultKeyConversionStrategy,
      properties: memberBlock.members
        .flatMap { member -> [StructSchema.Property] in
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

          // Validate: @SchemaCase should not be used on struct properties
          if variable.hasAttribute("SchemaCase") {
            context.expansionContext.diagnose(
              DiagnosticError(
                node: variable,
                severity: .error,
                message: "@SchemaCase cannot be used on struct properties. Use @SchemaProperty instead."
              )
            )
          }

          // Validate: @SchemaProperty should not be used on wrapper struct properties
          if style == .wrapper, variable.hasAttribute("SchemaProperty") {
            context.expansionContext.diagnose(
              DiagnosticError(
                node: variable,
                severity: .error,
                message: "@SchemaProperty cannot be used on wrapper struct properties."
              )
            )
          }

          let additionalArguments: LabeledExprListSyntax =
            .fromArguments(
              variable.parseArguments(
                ofAttribute: "SchemaProperty",
                as: DescriptionArgument.self,
                in: context.expansionContext
              )
            )

          /// In order to handle complex declarations such as `let a, b: Bool, c: String`, we iterate over the bindings in reverse and store the last type annotation.
          var lastTypeAnnotation: TypeSyntax?
          return variable.bindings
            .reversed()
            .compactMap { binding -> StructSchema.Property? in
              guard let type = binding.typeAnnotation?.type ?? lastTypeAnnotation else {
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

              return StructSchema.Property(
                name: IdentifiableToken(
                  identifier: identifier,
                  token: name
                ),
                type: type,
                additionalArguments: additionalArguments,
                isInitializedConstantProperty: [
                  variable.bindingSpecifier.tokenKind == .keyword(.let),
                  binding.initializer != nil,
                ].allSatisfy { $0 }
              )

            }
            .reversed()
        }
    )
  }
}

extension EnumDeclSyntax {

  fileprivate func schema(in context: SchemaCodableMacroContext) -> EnumSchema {
    let (description, style, keyConversionStrategy) = parseArguments(
      ofAttribute: context.macroAttribute,
      as: (
        DescriptionArgument.self,
        EnumStyleArgument.self,
        KeyConversionStrategyArgument.self
      ),
      in: context.expansionContext
    )
    return EnumSchema(
      namespace: context.namespace,
      typeName: "Self",
      additionalArguments: .fromArguments(
        (description, style ?? context.defaultEnumStyle)
      ),
      keyConversionStrategy: keyConversionStrategy?.value
        ?? context.defaultKeyConversionStrategy,
      cases: memberBlock
        .members
        .flatMap { member -> [EnumSchema.Case] in
          guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
            return []
          }
          // Validate: @SchemaProperty should not be used on enum cases
          if caseDecl.hasAttribute("SchemaProperty") {
            context.expansionContext.diagnose(
              DiagnosticError(
                node: caseDecl,
                severity: .error,
                message: "@SchemaProperty cannot be used on enum cases. Use @SchemaCase instead."
              )
            )
          }

          let additionalArguments: LabeledExprListSyntax = .fromArguments(
            caseDecl.parseArguments(
              ofAttribute: "SchemaCase",
              as: DescriptionArgument.self,
              in: context.expansionContext
            )
          )
          return caseDecl.elements.compactMap { element -> EnumSchema.Case? in

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

            var associatedValues: [EnumSchema.AssociatedValue] = []

            if let parameterClause = element.parameterClause {
              for (offset, parameter) in parameterClause.parameters.enumerated() {
                /// The argument label we need to use when creating a value of this case
                let argumentLabel: TokenSyntax? =
                  if let firstName = parameter.firstName,
                    firstName.tokenKind != .wildcard
                  {
                    firstName
                  } else {
                    nil
                  }

                let identifier: IdentifiableToken?
                if let name = (parameter.secondName ?? parameter.firstName),
                  /// If the second name is a wildcard, the first name must also be a wildcard.
                  name.tokenKind != .wildcard
                {
                  guard let nameIdentifier = name.identifier else {
                    context.expansionContext.diagnose(
                      DiagnosticError(
                        node: name,
                        severity: .error,
                        message: "Name must be an identifier."
                      )
                    )
                    continue
                  }
                  identifier = IdentifiableToken(
                    identifier: nameIdentifier,
                    token: name
                  )
                } else {
                  identifier = nil
                }

                associatedValues.append(
                  EnumSchema.AssociatedValue(
                    name: identifier,
                    argumentLabel: argumentLabel,
                    bindingName: "__value_\(raw: offset)",
                    type: parameter.type
                  )
                )
              }
            }

            return EnumSchema.Case(
              name: IdentifiableToken(
                identifier: name,
                token: element.name
              ),
              additionalArguments: additionalArguments,
              associatedValues: associatedValues
            )
          }
        }
    )
  }

}

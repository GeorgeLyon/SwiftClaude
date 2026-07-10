import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Gathers the annotated type's `@StructuredAction` functions into a single
/// generated member:
///
/// ```swift
/// static var definition: some StructuredCoding.StructuredToolDefinitionProtocol<Calculator> {
///   StructuredCoding.StructuredToolDefinition(
///     name: "\(Self.self)",
///     actions: (__structuredAction_add(), __structuredAction_fetch())
///   )
/// }
/// ```
///
/// The property is pure data gathering: every generic argument is inferred
/// from the sidecar return types (so the peer macro's `makeUniqueName`d
/// synthesized Input/Output names are never spelled here), and all
/// interpretation — schema shape, dispatch — lives in the runtime's
/// `StructuredToolDefinition`.
enum StructuredToolMacro: MemberMacro {

  static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    let namespace: StructuredCodingNamespace = "StructuredCoding"

    guard let typeName = declaration.nominalTypeName else {
      context.diagnose(
        DiagnosticError(
          node: node,
          severity: .error,
          message: "@StructuredTool can only be applied to a struct, class, actor, or enum"
        )
      )
      return []
    }

    let arguments: LabeledExprListSyntax
    switch node.arguments {
    case .argumentList(let argumentList):
      arguments = argumentList
    case .none:
      arguments = []
    default:
      context.diagnose(
        DiagnosticError(
          node: node,
          severity: .error,
          message: "Expected argument list"
        )
      )
      arguments = []
    }

    let (name, description) = arguments.parse(
      ofAttribute: "StructuredTool",
      as: (NameArgument.self, DescriptionArgument.self),
      in: context
    )

    let actionFunctions = declaration.memberBlock.members.compactMap { member in
      member.decl.as(FunctionDeclSyntax.self).flatMap { function in
        function.attributes.hasAttribute("StructuredAction") ? function : nil
      }
    }

    guard !actionFunctions.isEmpty else {
      context.diagnose(
        DiagnosticError(
          node: node,
          severity: .error,
          message: "@StructuredTool requires at least one @StructuredAction function"
        )
      )
      return []
    }

    /// Tools dispatch actions by base name (the enumeration schema's property
    /// names), so duplicates cannot be represented; static functions produce
    /// `Callee == Void` sidecars that cannot join a `Callee == <Type>` tuple.
    var seenActionNames: Set<String> = []
    var isValid = true
    for function in actionFunctions {
      if function.modifiers.contains(where: \.isStatic) {
        context.diagnose(
          DiagnosticError(
            node: function.name,
            severity: .error,
            message: "static @StructuredAction functions are not supported in a @StructuredTool"
          )
        )
        isValid = false
      }
      if !seenActionNames.insert(function.name.text).inserted {
        context.diagnose(
          DiagnosticError(
            node: function.name,
            severity: .error,
            message:
              "Duplicate action name `\(function.name.text)`; a tool's actions must have unique names"
          )
        )
        isValid = false
      }
    }
    guard isValid else {
      return []
    }

    let definition = definitionProperty(
      typeName: typeName,
      name: name.map { ExprSyntax($0.expression) } ?? ExprSyntax(#""\(Self.self)""#),
      description: description?.expression,
      actionFunctions: actionFunctions,
      isPublic: declaration.modifiers.contains(where: \.isPublic),
      namespace: namespace
    )
    return [DeclSyntax(definition)]
  }

  /// `static var definition: some {ns}.StructuredToolDefinitionProtocol<TypeName> { … }`
  private static func definitionProperty(
    typeName: TokenSyntax,
    name: ExprSyntax,
    description: StringLiteralExprSyntax?,
    actionFunctions: [FunctionDeclSyntax],
    isPublic: Bool,
    namespace: StructuredCodingNamespace
  ) -> VariableDeclSyntax {
    VariableDeclSyntax(
      modifiers: DeclModifierListSyntax {
        if isPublic {
          DeclModifierSyntax(name: "public")
        }
        DeclModifierSyntax(name: .keyword(.static))
      },
      bindingSpecifier: .keyword(.var)
    ) {
      PatternBindingSyntax(
        pattern: IdentifierPatternSyntax(identifier: "definition"),
        typeAnnotation: TypeAnnotationSyntax(
          type: SomeOrAnyTypeSyntax(
            someOrAnySpecifier: .keyword(.some),
            constraint: namespace.memberType(
              name: "StructuredToolDefinitionProtocol",
              genericArgumentClause: GenericArgumentClauseSyntax {
                GenericArgumentSyntax(
                  argument: GenericArgumentSyntax.Argument(
                    IdentifierTypeSyntax(name: typeName)
                  )
                )
              }
            )
          )
        ),
        accessorBlock: AccessorBlockSyntax(
          accessors: .getter(
            CodeBlockItemListSyntax {
              FunctionCallExprSyntax(
                calledExpression: namespace.member(name: "StructuredToolDefinition"),
                leftParen: .leftParenToken(trailingTrivia: .newline),
                arguments: LabeledExprListSyntax {
                  LabeledExprSyntax(
                    label: "name",
                    colon: .colonToken(),
                    expression: name.trimmed,
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
                    label: "actions",
                    colon: .colonToken(),
                    expression: TupleExprSyntax(
                      leftParen: .leftParenToken(trailingTrivia: .newline),
                      elements: LabeledExprListSyntax {
                        for (index, function) in actionFunctions.enumerated() {
                          LabeledExprSyntax(
                            expression: FunctionCallExprSyntax(
                              calledExpression: DeclReferenceExprSyntax(
                                baseName: "__structuredAction_\(raw: function.name.text)"
                              ),
                              leftParen: .leftParenToken(),
                              arguments: LabeledExprListSyntax(),
                              rightParen: .rightParenToken()
                            ),
                            trailingComma: index == actionFunctions.count - 1
                              ? nil
                              : .commaToken(trailingTrivia: .newline)
                          )
                        }
                      },
                      rightParen: .rightParenToken(leadingTrivia: .newline)
                    )
                  )
                },
                rightParen: .rightParenToken(leadingTrivia: .newline)
              )
            }
          )
        )
      )
    }
  }

}

extension DeclGroupSyntax {

  fileprivate var nominalTypeName: TokenSyntax? {
    if let decl = self.as(StructDeclSyntax.self) {
      return decl.name.trimmed
    } else if let decl = self.as(ClassDeclSyntax.self) {
      return decl.name.trimmed
    } else if let decl = self.as(ActorDeclSyntax.self) {
      return decl.name.trimmed
    } else if let decl = self.as(EnumDeclSyntax.self) {
      return decl.name.trimmed
    } else {
      return nil
    }
  }

}

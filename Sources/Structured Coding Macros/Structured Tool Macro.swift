import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Generates everything for the annotated type's `@StructuredAction`
/// functions — the markers themselves generate nothing. Each action's
/// synthesized `Input`/`Output` objects are added as members (named with
/// `makeUniqueName`, so they are context-private), and the actions are
/// inline `StructuredAction` initializer expressions in a single gathered
/// member — no other name is introduced:
///
/// ```swift
/// static var definition: some StructuredCoding.StructuredToolDefinitionProtocol<Calculator> {
///   StructuredCoding.StructuredToolDefinition(
///     name: "\(Self.self)",
///     actions: (
///       StructuredCoding.StructuredAction(
///         name: "add",
///         failure: Never.self,
///         invoke: { (callee: Calculator, input: __macro_local_…) -> Int in
///           callee.add(amount: input.amount)
///         }
///       ),
///       …
///     )
///   )
/// }
/// ```
///
/// Every generic argument is inferred from the initializer expressions, and
/// all interpretation — schema shape, dispatch — lives in the runtime's
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
    /// names), so duplicates cannot be represented; static functions have no
    /// callee to join a `Callee == <Type>` tuple.
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

    let calleeType = TypeSyntax(IdentifierTypeSyntax(name: typeName))
    let isCalleeActor = declaration.is(ActorDeclSyntax.self)
    let compatibilityModes = CompatibilityModes(inferredFrom: declaration, in: context)

    var members: [DeclSyntax] = []
    var actionExprs: [FunctionCallExprSyntax] = []
    for function in actionFunctions {
      let (description, inputDescription, outputDescription, keyConversionStrategy) =
        function.attributes.parseArguments(
          ofAttribute: "StructuredAction",
          as: (
            DescriptionArgument.self, InputDescriptionArgument.self,
            OutputDescriptionArgument.self, KeyConversionStrategyArgument.self
          ),
          in: context
        )
      guard
        let schema = function.callableSchema(
          namespace: namespace,
          calleeType: calleeType,
          isCalleeActor: isCalleeActor,
          description: description?.expression,
          inputDescription: inputDescription?.expression,
          outputDescription: outputDescription?.expression,
          keyConversionStrategy: keyConversionStrategy?.value ?? .none,
          compatibilityModes: compatibilityModes,
          in: context
        )
      else {
        isValid = false
        continue
      }
      members.append(contentsOf: schema.synthesizedMemberDeclarations())
      actionExprs.append(schema.actionInitExpr())
    }
    guard isValid else {
      return []
    }

    members.append(
      DeclSyntax(
        definitionProperty(
          typeName: typeName,
          name: name.map { ExprSyntax($0.expression) } ?? ExprSyntax(#""\(Self.self)""#),
          description: description?.expression,
          actionExprs: actionExprs,
          isPublic: declaration.modifiers.contains(where: \.isPublic),
          namespace: namespace
        )
      )
    )
    return members
  }

  /// `static var definition: some {ns}.StructuredToolDefinitionProtocol<TypeName> { … }`
  private static func definitionProperty(
    typeName: TokenSyntax,
    name: ExprSyntax,
    description: StringLiteralExprSyntax?,
    actionExprs: [FunctionCallExprSyntax],
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
                        for (index, actionExpr) in actionExprs.enumerated() {
                          LabeledExprSyntax(
                            expression: actionExpr,
                            trailingComma: index == actionExprs.count - 1
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

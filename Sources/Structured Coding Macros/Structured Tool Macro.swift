import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum StructuredToolMacro: MemberMacro, ExtensionMacro {

  static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    let namespace: StructuredCodingNamespace = "StructuredCoding"
    guard
      declaration.nominalTypeName != nil,
      !protocols.isEmpty,
      validatedActionFunctions(of: declaration, attribute: node, diagnosingIn: nil) != nil
    else {
      return []
    }
    return [
      ExtensionDeclSyntax(
        extendedType: type,
        inheritanceClause: InheritanceClauseSyntax {
          InheritedTypeSyntax(type: namespace.memberType(name: "StructuredToolProtocol"))
        }
      ) {}
    ]
  }

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

    guard
      let actionFunctions = validatedActionFunctions(
        of: declaration,
        attribute: node,
        diagnosingIn: context
      )
    else {
      return []
    }

    let calleeType = TypeSyntax(IdentifierTypeSyntax(name: typeName))
    var isValid = true
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

    let isPublic = declaration.modifiers.contains(where: \.isPublic)
    members.append(
      DeclSyntax(
        definitionStruct(
          typeName: typeName,
          name: name.map { ExprSyntax($0.expression.trimmed) }
            ?? ExprSyntax(StringLiteralExprSyntax(content: typeName.text)),
          description: description?.expression.trimmed,
          actionExprs: actionExprs,
          isPublic: isPublic,
          namespace: namespace
        )
      )
    )
    members.append(DeclSyntax(definitionProperty(isPublic: isPublic)))
    return members
  }

  private static func validatedActionFunctions(
    of declaration: some DeclGroupSyntax,
    attribute node: AttributeSyntax,
    diagnosingIn context: (any MacroExpansionContext)?
  ) -> [FunctionDeclSyntax]? {
    let actionFunctions = declaration.memberBlock.members.compactMap { member in
      member.decl.as(FunctionDeclSyntax.self).flatMap { function in
        function.attributes.hasAttribute("StructuredAction") ? function : nil
      }
    }

    guard !actionFunctions.isEmpty else {
      context?.diagnose(
        DiagnosticError(
          node: node,
          severity: .error,
          message: "@StructuredTool requires at least one @StructuredAction function"
        )
      )
      return nil
    }

    var seenActionNames: Set<String> = []
    var isValid = true
    for function in actionFunctions {
      if function.modifiers.contains(where: \.isStatic) {
        context?.diagnose(
          DiagnosticError(
            node: function.name,
            severity: .error,
            message: "static @StructuredAction functions are not supported in a @StructuredTool"
          )
        )
        isValid = false
      }
      if !seenActionNames.insert(function.name.text).inserted {
        context?.diagnose(
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
    return isValid ? actionFunctions : nil
  }

  private static func definitionStruct(
    typeName: TokenSyntax,
    name: ExprSyntax,
    description: StringLiteralExprSyntax?,
    actionExprs: [FunctionCallExprSyntax],
    isPublic: Bool,
    namespace: StructuredCodingNamespace
  ) -> StructDeclSyntax {
    let memberModifiers = DeclModifierListSyntax {
      if isPublic {
        DeclModifierSyntax(name: "public")
      }
    }
    return StructDeclSyntax(
      modifiers: memberModifiers,
      name: "Definition",
      inheritanceClause: InheritanceClauseSyntax {
        InheritedTypeSyntax(type: namespace.memberType(name: "StructuredToolDefinitionProtocol"))
      }
    ) {
      TypeAliasDeclSyntax(
        modifiers: memberModifiers,
        name: "Callee",
        initializer: TypeInitializerClauseSyntax(
          value: IdentifierTypeSyntax(name: typeName)
        )
      )
      VariableDeclSyntax(
        modifiers: memberModifiers,
        bindingSpecifier: .keyword(.let)
      ) {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: "name"),
          initializer: InitializerClauseSyntax(value: name)
        )
      }
      VariableDeclSyntax(
        modifiers: memberModifiers,
        bindingSpecifier: .keyword(.let)
      ) {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: "description"),
          typeAnnotation: TypeAnnotationSyntax(
            type: OptionalTypeSyntax(wrappedType: IdentifierTypeSyntax(name: "String"))
          ),
          initializer: InitializerClauseSyntax(
            value: description.map { ExprSyntax($0) } ?? ExprSyntax(NilLiteralExprSyntax())
          )
        )
      }
      VariableDeclSyntax(
        modifiers: memberModifiers,
        bindingSpecifier: .keyword(.let)
      ) {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: "actions"),
          initializer: InitializerClauseSyntax(
            value: FunctionCallExprSyntax(
              calledExpression: MemberAccessExprSyntax(
                base: namespace.member(name: "StructuredAction"),
                name: "build"
              ),
              leftParen: nil,
              arguments: LabeledExprListSyntax(),
              rightParen: nil,
              trailingClosure: ClosureExprSyntax(
                statements: CodeBlockItemListSyntax {
                  for actionExpr in actionExprs {
                    actionExpr
                  }
                }
              )
            )
          )
        )
      }
    }
  }

  private static func definitionProperty(isPublic: Bool) -> VariableDeclSyntax {
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
          type: IdentifierTypeSyntax(name: "Definition")
        ),
        accessorBlock: AccessorBlockSyntax(
          accessors: .getter(
            CodeBlockItemListSyntax {
              FunctionCallExprSyntax(
                calledExpression: DeclReferenceExprSyntax(baseName: "Definition"),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax(),
                rightParen: .rightParenToken()
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

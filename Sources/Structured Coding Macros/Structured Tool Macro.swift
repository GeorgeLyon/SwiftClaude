import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Generates everything for the annotated type's `@StructuredAction`
/// functions — the markers themselves generate nothing. Each action's
/// synthesized `Input`/`Output` objects are added as members (named with
/// `makeUniqueName`, so they are context-private), and the actions are
/// inline `StructuredAction` initializer expressions — one statement per
/// action in the `StructuredAction.build` builder closure — gathered into a
/// nested `Definition` container:
///
/// ```swift
/// struct Definition: StructuredCoding.StructuredToolDefinitionProtocol {
///   typealias Callee = Calculator
///   let name = "Calculator"
///   let description: String? = nil
///   let actions = StructuredCoding.StructuredAction.build {
///     StructuredCoding.StructuredAction(
///       name: "add",
///       failure: Never.self,
///       invoke: { (callee: Calculator, input: __macro_local_…) -> Int in
///         callee.add(amount: input.amount)
///       }
///     )
///     …
///   }
/// }
/// static var definition: Definition {
///   Definition()
/// }
/// ```
///
/// The macro emits this one form *unconditionally* — no arity branching
/// anywhere: `StructuredAction.build`'s builder keeps one action a leaf
/// `StructuredAction` and folds several into a composed `StructuredAction`
/// at its placeholder instantiation. The container shape carries the whole
/// design:
///
/// - `actions` is a *stored* `let` whose initializer infers its type, so the
///   concrete leaf/composed type is never spelled anywhere — yet the
///   protocol's `Actions` associated type is inferred from that witness and
///   stays fully concrete, which is what lets consumers with wire-format
///   policy (the Messages API's `ToolDefinition`) classify tools statically
///   by constraining on `Tool.Definition.Actions`' shape.
/// - `static var definition` is *computed*, returning a fresh value, so
///   Swift 6's concurrency-safe-statics rule (which forbids non-`Sendable`
///   static storage) never applies.
/// - Statics are nonisolated on actors, and the storage lives in the nested
///   struct — so actor tools need no `nonisolated` tricks and enum tools
///   work despite enums having no stored instance properties. The inline
///   `invoke` closures capture nothing (the callee arrives as a parameter),
///   so property-initializer restrictions don't bite.
///
/// `name` and `description` are stored on the container too: the macro
/// emits the tool-name literal directly (the attribute's `name:` when
/// provided, the type's name otherwise — it knows both, so no
/// `"\(Self.self)"` machinery exists anywhere), and a `nil`-defaulted
/// `description` when the attribute provides none.
enum StructuredToolMacro: MemberMacro, ExtensionMacro {

  /// Conforms the tool type to `StructuredToolProtocol`; the member
  /// expansion's `definition` witnesses the requirement. Diagnosing an
  /// invalid declaration is the member expansion's job — this expansion runs
  /// the same basic validation silently, so an invalid tool (which gets no
  /// `actions`) is not additionally saddled with a does-not-conform
  /// error (an invalid tool gets no `Definition` either). `protocols` is
  /// empty when the conformance is already declared explicitly.
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

  /// The declaration's `@StructuredAction` functions, or `nil` when the
  /// tool's basic shape is invalid: no actions at all, static actions (no
  /// callee to join a `Callee == <Type>` tuple), or duplicate action names
  /// (tools dispatch actions by base name — the enumeration schema's
  /// property names — so duplicates cannot be represented). Diagnostics are
  /// emitted only through `context`: the member expansion diagnoses, and the
  /// extension expansion re-validates silently.
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

  /// The nested `Definition` container:
  ///
  /// ```swift
  /// struct Definition: {ns}.StructuredToolDefinitionProtocol {
  ///   typealias Callee = TypeName
  ///   let name = "TypeName"
  ///   let description: String? = nil
  ///   let actions = {ns}.StructuredAction.build { … }
  /// }
  /// ```
  ///
  /// Every member is stored: `actions`' initializer infers the concrete
  /// leaf/group type — nothing spells it, yet the protocol's `Actions`
  /// associated type stays fully concrete for downstream static
  /// classification — and `name`/`description` are emitted as literals (the
  /// macro knows the type name, so the default needs no `"\(Self.self)"`
  /// machinery; `description` defaults to `nil` when the attribute provides
  /// none, since the protocol requirement needs a witness). The container is
  /// a struct even inside actors and enums: statics are nonisolated on
  /// actors and a struct can store what an enum cannot, so no declaration
  /// kind needs special casing.
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

  /// `static var definition: Definition { Definition() }` — computed, so the
  /// non-`Sendable` definition value is built fresh on each read and Swift
  /// 6's concurrency-safe-statics rule never applies.
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

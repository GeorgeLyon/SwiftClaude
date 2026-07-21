// MARK: - Tool Protocol

/// A type whose functions are exposed through Structured Coding as a tool.
/// The `@StructuredTool` macro generates the conformance: a nested
/// `Definition` container carrying the tool's name, its optional
/// description, and the type's gathered `@StructuredAction` functions — one
/// action stays a leaf `StructuredAction`, several fold into a composed
/// `StructuredAction` whose input nests `StructuredActionSelection` (see
/// `StructuredAction.build`).
///
/// `definition` is a *computed* static returning a fresh value, so Swift 6's
/// concurrency-safe-statics rule (which forbids non-`Sendable` static
/// storage) never applies; the actions live in the nested container as a
/// stored property whose initializer *infers* the concrete leaf/composed
/// `StructuredAction` type — no generic action type is ever spelled, yet
/// `Definition.Actions` stays fully concrete for consumers that classify
/// tools statically (the Messages API's `ToolDefinition` constrains on
/// `Tool.Definition.Actions`' shape; an opaque type anywhere in the chain
/// would erase exactly the structure it constrains on).
public protocol StructuredToolProtocol: SendableMetatype {

  associatedtype Definition: StructuredToolDefinitionProtocol<Self>

  static var definition: Definition { get }

}

// MARK: - Definition Protocol

/// The container holding everything that describes a tool — its name, its
/// optional description, and its actions — conformed to by the nested
/// `Definition` struct the `@StructuredTool` macro generates (or a
/// hand-written equivalent). A separate container — rather than
/// requirements on the tool itself — so every member can be a *stored*
/// property (`actions`' initializer infers the concrete leaf/composed type):
/// statics are nonisolated on actors and a struct can store what an enum
/// cannot, so actor and enum tools need no special casing.
public protocol StructuredToolDefinitionProtocol<Callee>: SendableMetatype {

  associatedtype Callee
  /// Unconstrained: consumers classify a tool's actions by constraining on
  /// the concrete `StructuredAction` shape (a composed action is just the
  /// shape whose input is a `StructuredActionSelection`), so no protocol
  /// abstraction over actions exists — a constraint here would have
  /// nothing to name.
  associatedtype Actions

  var name: String { get }
  var description: String? { get }
  var actions: Actions { get }

}

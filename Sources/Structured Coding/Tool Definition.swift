// MARK: - Tool Protocol

/// A type whose functions are exposed through Structured Coding as a tool.
/// The `@StructuredTool` macro generates the conformance.
public protocol StructuredToolProtocol: SendableMetatype {

  associatedtype Definition: StructuredToolDefinitionProtocol<Self>

  static var definition: Definition { get }

}

// MARK: - Definition Protocol

public protocol StructuredToolDefinitionProtocol<Callee>: SendableMetatype {

  associatedtype Callee
  associatedtype Actions

  var name: String { get }
  var description: String? { get }
  var actions: Actions { get }

}

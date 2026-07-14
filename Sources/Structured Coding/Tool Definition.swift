private import JavaScriptObjectNotation

// MARK: - Tool Protocol

/// A type whose functions are exposed through Structured Coding as a tool.
/// The `@StructuredTool` macro generates the conformance: `definition`
/// gathers the type's `@StructuredAction` functions, and the macro's opaque
/// return type witnesses `Definition`. Generic code — a request carrying a
/// pack of tools, say — constrains element types to this protocol to reach
/// each tool's definition.
public protocol StructuredToolProtocol: SendableMetatype {

  associatedtype Definition: StructuredToolDefinitionProtocol<Self>

  static var definition: Definition { get }

}

// MARK: - Definition Protocol

/// The interface tool consumers program against. The `@StructuredTool` macro
/// generates a `definition` property typed
/// `some StructuredToolDefinitionProtocol<Self>`, hiding the concrete
/// pack-generic `StructuredToolDefinition` so that no generic argument — in
/// particular no synthesized `Input` type name — is ever spelled outside the
/// macro expansion itself.
public protocol StructuredToolDefinitionProtocol<Callee>: SendableMetatype {

  associatedtype Callee
  /// `StructuredCodable` — not just encodable — so consumers can carry the
  /// schema as an ordinary generated-codable property (a request's tool
  /// definitions, say) without hand-written encoding.
  associatedtype InputSchema: StructuredCodable

  var name: String { get }
  var description: String? { get }

  /// The tool's reified input schema. A tool with a single action uses that
  /// action's input schema directly; a tool with several synthesizes an
  /// enumeration — a one-property object keyed by action name, the same shape
  /// as the object-properties enumeration coding style.
  var inputSchema: InputSchema { get }

  /// Decodes `inputJSON` — a complete JSON document matching `inputSchema` —
  /// invokes the selected action on `callee`, and returns the action's output
  /// encoded as JSON.
  func invoke(on callee: Callee, inputJSON: String) async throws -> String

}

// MARK: - Definition

/// A tool: a name, a description, and the actions the `@StructuredTool` macro
/// gathered from the annotated type. Plain data — every interpretation of it
/// (schema shape, dispatch) lives in the `StructuredToolDefinitionProtocol`
/// conformance below, not in generated code.
public struct StructuredToolDefinition<
  Callee,
  each Signature: StructuredActionSignatureProtocol
> {

  public init(
    name: String,
    description: String? = nil,
    actions: (repeat StructuredAction<Callee, each Signature>)
  ) {
    self.name = name
    self.description = description
    self.actions = actions
  }

  public let name: String
  public let description: String?
  public let actions: (repeat StructuredAction<Callee, each Signature>)

}

extension StructuredToolDefinition: StructuredToolDefinitionProtocol {

  public var inputSchema: some StructuredCodable {
    var count = 0
    var firstActionSchema: MetaSchema.SchemaCodable?
    for action in repeat each actions {
      count += 1
      if firstActionSchema == nil {
        firstActionSchema = singleActionInputSchema(of: action)
      }
    }
    if count == 1, let firstActionSchema {
      return firstActionSchema
    }
    return MetaSchema.SchemaCodable(
      MetaSchema.object(
        description: nil,
        maxProperties: 1,
        properties: repeat (
          (each actions).key,
          (each actions).inputSchema.prependDescription((each actions).description),
          false
        )
      )
    )
  }

  public func invoke(on callee: Callee, inputJSON: String) async throws -> String {
    var count = 0
    var firstActionNeedsEnvelope = false
    for action in repeat each actions {
      count += 1
      if count == 1 {
        firstActionNeedsEnvelope = needsInputEnvelope(action)
      }
    }

    /// Decoding produces a deferred invocation rather than invoking inline:
    /// the incremental decoder pumps its async operation synchronously, so an
    /// action that genuinely suspends would deadlock it. The invocation is
    /// handed out by assigning into state the decode closures capture — the
    /// decode machinery's results are `sending`, which a closure capturing
    /// the callee cannot be.
    let invocation: () async throws -> String
    if count == 1, firstActionNeedsEnvelope {
      invocation = try IncrementalDecoder().decode(from: inputJSON.utf8) { stream in
        var invocation: (() async throws -> String)?
        try await stream.decodeObject { objectDecoder in
          if objectDecoder.isAtEnd {
            throw StructuredToolInvocationError.noInputSpecified
          }
          try await objectDecoder.decodeProperty(
            decodeValue: { name, stream in
              guard name == "input" else {
                throw StructuredToolInvocationError.unknownInputProperty(name)
              }
              for action in repeat each actions {
                if invocation == nil {
                  try await stream.withDecoder { decoder in
                    invocation = try await decodedInvocation(
                      of: action, on: callee, from: &decoder)
                  }
                }
              }
            }
          )
          guard objectDecoder.isAtEnd else {
            throw StructuredToolInvocationError.moreThanOneInputProperty
          }
        }
        try await stream.readTrailingWhitespace()
        guard let invocation else {
          throw StructuredToolInvocationError.noInputSpecified
        }
        return invocation
      }
    } else if count == 1 {
      invocation = try IncrementalDecoder().decode(from: inputJSON.utf8) { stream in
        var invocation: (() async throws -> String)?
        try await stream.withDecoder { decoder in
          for action in repeat each actions {
            invocation = try await decodedInvocation(of: action, on: callee, from: &decoder)
          }
        }
        try await stream.readTrailingWhitespace()
        guard let invocation else {
          throw StructuredToolInvocationError.noActionSpecified
        }
        return invocation
      }
    } else {
      invocation = try IncrementalDecoder().decode(from: inputJSON.utf8) { stream in
        var invocation: (() async throws -> String)?
        try await stream.decodeObject { objectDecoder in
          if objectDecoder.isAtEnd {
            throw StructuredToolInvocationError.noActionSpecified
          }
          try await objectDecoder.decodeProperty(
            decodeValue: { name, stream in
              for action in repeat each actions {
                if invocation == nil, action.name == name {
                  try await stream.withDecoder { decoder in
                    invocation = try await decodedInvocation(
                      of: action, on: callee, from: &decoder)
                  }
                }
              }
              guard invocation != nil else {
                throw StructuredToolInvocationError.unknownAction(name)
              }
            }
          )
          guard objectDecoder.isAtEnd else {
            throw StructuredToolInvocationError.moreThanOneActionSpecified
          }
        }
        try await stream.readTrailingWhitespace()
        guard let invocation else {
          throw StructuredToolInvocationError.noActionSpecified
        }
        return invocation
      }
    }
    return try await invocation()
  }

  /// A single action's input schema stands in for the whole tool's when its
  /// metadata declares the `.object` shape. Any other schema (a scalar,
  /// tuple, `oneOf`, or a hand-written schema that declares no shape) is
  /// enveloped in an object with one required `"input"` property carrying
  /// it: the Anthropic API requires a tool's input schema to be a top-level
  /// object. The tool-level description is not folded in — consumers carry
  /// it separately (a request's tool `description` field, say).
  /// `invoke(on:inputJSON:)` applies the same rule when decoding, so the
  /// published schema and dispatch always agree.
  private func singleActionInputSchema<ActionSignature: StructuredActionSignatureProtocol>(
    of action: StructuredAction<Callee, ActionSignature>
  ) -> MetaSchema.SchemaCodable {
    guard needsInputEnvelope(action) else {
      return MetaSchema.SchemaCodable(action.inputSchema)
    }
    return MetaSchema.SchemaCodable(
      MetaSchema.object(
        description: nil,
        properties: ("input", action.inputSchema, true)
      )
    )
  }

  private func needsInputEnvelope<ActionSignature: StructuredActionSignatureProtocol>(
    _ action: StructuredAction<Callee, ActionSignature>
  ) -> Bool {
    action.inputSchema.metadata.shape != .object
  }

  /// Decodes `action`'s `Input` from `decoder` and captures it, with the
  /// callee, into the deferred invocation `invoke(on:inputJSON:)` runs once
  /// decoding completes.
  private func decodedInvocation<ActionSignature: StructuredActionSignatureProtocol>(
    of action: StructuredAction<Callee, ActionSignature>,
    on callee: Callee,
    from decoder: inout StructuredDecoder
  ) async throws -> () async throws -> String {
    let input = try await ActionSignature.Input.decode(
      from: &decoder,
      in: StructuredDecodingContext()
    )
    return {
      let output = try await action.invoke(on: callee, with: input)
      var encoder = StructuredEncoder()
      try output.encode(to: &encoder)
      return encoder.stringValue
    }
  }

}

// MARK: - Errors

enum StructuredToolInvocationError: Error {
  case noActionSpecified
  case unknownAction(String)
  case moreThanOneActionSpecified
  /// The `{"input": ...}` envelope a wrapped single-action tool expects was
  /// malformed; see `singleActionInputSchema(of:)`.
  case noInputSpecified
  case unknownInputProperty(String)
  case moreThanOneInputProperty
}

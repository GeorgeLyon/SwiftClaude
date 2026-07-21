public import StructuredCoding

@APICodable
public struct Request<each ToolInputSchema: StructuredCodable> {

  /// The pack is of `ToolDefinition` values, not bare tools: classifying a
  /// tool (direct vs enveloped vs group input schema) happens statically, in
  /// `ToolDefinition.init`'s constrained overloads, and overload resolution
  /// cannot happen inside a pack expansion — so each tool is wrapped at the
  /// concrete call site: `Request(…, tools: ToolDefinition(calculator),
  /// ToolDefinition(weather))`. The tool instances themselves are not stored
  /// yet — encoding a request only needs each definition's wire fields. A
  /// later round will keep them as the callees that responses' tool-use
  /// blocks dispatch onto.
  public init(
    model: Model,
    maxTokens: Int,
    messages: [Message],
    tools: repeat ToolDefinition<each ToolInputSchema>
  ) {
    self.model = model
    self.maxTokens = maxTokens
    self.messages = messages
    self.tools = (repeat each tools)
  }

  public let model: Model

  public let maxTokens: Int

  public let messages: [Message]

  let tools: (repeat ToolDefinition<each ToolInputSchema>)

}

// MARK: - Model

/// A Claude model identifier, encoded as the bare model-ID string (e.g.
/// `"claude-opus-4-8"`). Static accessors cover the current models; use
/// `Model(_:)` for any identifier without one.
@APICodable(style: .wrapper)
public struct Model: Sendable {
  public static var claudeFable5: Self { Self(stringValue: "claude-fable-5") }
  public static var claudeOpus4_8: Self { Self(stringValue: "claude-opus-4-8") }
  public static var claudeOpus4_7: Self { Self(stringValue: "claude-opus-4-7") }
  public static var claudeSonnet5: Self { Self(stringValue: "claude-sonnet-5") }
  public static var claudeHaiku4_5: Self { Self(stringValue: "claude-haiku-4-5") }

  let stringValue: String
}

extension Model {
  /// Creates a model from a raw Anthropic model identifier, e.g.
  /// `Model("claude-opus-4-8")`, for models without a static accessor.
  public init(_ stringValue: String) {
    self.init(stringValue: stringValue)
  }
}

// MARK: - Tools

/// The one-property wrapper a non-object tool input travels in on the wire:
/// `{"input": <value>}`. An ordinary `@APICodable` object — its schema is
/// `{"properties":{"input":<Input.schema>},"required":["input"]}`, decoding
/// is the generic object machinery (so malformed envelopes surface the
/// ordinary object-decode errors), and the `"input"` key is literally just
/// this property's name. `ToolDefinition` publishes its schema for a lone
/// non-object-input action; dispatch will decode complete values of it (see
/// the enveloped `ToolDefinition` initializer).
@APICodable
public struct ToolInputEnvelope<Input: StructuredCodable> {

  public var input: Input

}

/// A tool definition in the Anthropic wire shape: `{"name": ...,
/// "description": ..., "input_schema": ...}`, with a `nil` description
/// omitted. This is where all Anthropic tool-schema policy lives: the API
/// requires `input_schema` to be a top-level JSON object, and the three
/// constrained initializers below resolve — statically, at construction —
/// how each tool shape satisfies that:
///
/// - a single action whose input is `StructuredObjectRepresentable` publishes
///   its raw schema directly;
/// - any other single action publishes `ToolInputEnvelope`'s schema, so its
///   input travels as `{"input": <raw>}` — an envelope spelled nowhere in
///   StructuredCoding;
/// - a multi-action group's keyed enumeration is an object by construction.
///
/// The initializers take the tool *instance*, not its metatype — a later
/// round will store it as the callee that responses' tool-use blocks
/// dispatch onto — but the name, description, and actions all come from the
/// static `Tool.definition`.
@APICodable
public struct ToolDefinition<InputSchema: StructuredCodable> {

  /// Direct: a lone action whose `Input` is marked
  /// `StructuredObjectRepresentable` — every encoded instance a top-level
  /// object — publishes its raw schema as the tool's `input_schema`
  /// unchanged. Strictly more constrained than the enveloped fallback below,
  /// and the fallback is additionally `@_disfavoredOverload`, so this wins
  /// whenever the marker holds. A composed multi-action tool can never
  /// match: its signature's placeholder input deliberately lacks the marker.
  public init<
    Tool: StructuredToolProtocol,
    Input: StructuredObjectRepresentable & StructuredCodable,
    Output: StructuredCodable,
    SyncInput,
    Failure: Error
  >(
    _ tool: Tool
  )
  where
    Tool.Definition.Actions == StructuredAction<Tool, Input, Output, SyncInput, Failure>,
    InputSchema == Input.Schema
  {
    let definition = Tool.definition
    self.init(
      name: definition.name,
      description: definition.description,
      inputSchema: definition.actions.inputSchema
    )
  }

  /// Enveloped: a lone action with any other input (a scalar, tuple,
  /// type-discriminated or raw-value enumeration, or a hand-written type
  /// that doesn't adopt the marker) publishes `ToolInputEnvelope`'s schema —
  /// nothing but the schema is constructed here. Dispatch (a later round)
  /// will decode the complete `ToolInputEnvelope<Input>` value
  /// from the tool-use JSON and call the *original* action's public typed
  /// `invoke(on:with: envelope.input)`; decoding the full value first keeps
  /// the deferred-invocation machinery out of the picture entirely, and a
  /// public decode-from-JSON-text entry point will arrive as general library
  /// surface then. No accessor, no constructed action, ever.
  ///
  /// `@_disfavoredOverload` for two reasons: Swift cannot rank this against
  /// the marker-constrained overload above by specialization alone (the two
  /// bind `InputSchema` to different types), and a *composed* multi-action
  /// tool also matches this shape (its `Input` binds the group placeholder,
  /// which is `StructuredCodable`, so `ToolInputEnvelope` over it is
  /// well-formed) — disfavoring lets the fully concrete group overload
  /// below win for composed tools.
  @_disfavoredOverload
  public init<
    Tool: StructuredToolProtocol,
    Input: StructuredCodable,
    Output: StructuredCodable,
    SyncInput,
    Failure: Error
  >(
    _ tool: Tool
  )
  where
    Tool.Definition.Actions == StructuredAction<Tool, Input, Output, SyncInput, Failure>,
    InputSchema == ToolInputEnvelope<Input>.Schema
  {
    let definition = Tool.definition
    self.init(
      name: definition.name,
      description: definition.description,
      inputSchema: ToolInputEnvelope<Input>.schema
    )
  }

  /// Direct: a composed multi-action tool's keyed enumeration is a top-level
  /// object by construction, published as assembled by the builder fold.
  public init<Tool: StructuredToolProtocol>(
    _ tool: Tool
  )
  where
    Tool.Definition.Actions
      == StructuredAction<
        Tool, _StructuredActionGroupInput, _StructuredActionGroupInput, Never, Never
      >,
    InputSchema == _StructuredActionGroupSchema
  {
    let definition = Tool.definition
    self.init(
      name: definition.name,
      description: definition.description,
      inputSchema: definition.actions.inputSchema
    )
  }

  private init(name: String, description: String?, inputSchema: InputSchema) {
    self.name = name
    self.description = description
    self.inputSchema = inputSchema
  }

  let name: String

  let description: String?

  let inputSchema: InputSchema

}

// MARK: - Messages

@APICodable
public struct Message: Sendable {

  public init(role: MessageRole, content: [ContentBlock]) {
    self.role = role
    self.content = content
  }

  public let role: MessageRole

  public let content: [ContentBlock]

}

public enum MessageRole: String, CaseIterable, StructuredEnumeration, Sendable {
  case user, assistant
}

@APICodable
public enum ContentBlock: Sendable {
  case text(text: String)
  case image(source: ImageSource)

  @APICodable
  public enum ImageSource: Sendable {

    @APICodable(style: .wrapper)
    public struct Base64MediaType: Sendable {
      public static var png: Self { Self(stringValue: "image/png") }

      let stringValue: String
    }

    case base64(
      mediaType: Base64MediaType,
      data: String,
      cacheControl: CacheControl? = nil
    )
  }

}

// MARK: - Prompt Caching

@APICodable
public enum CacheControl: Sendable {

  case ephemeral(
    ttl: TimeToLive? = nil
  )

  @APICodable(style: .wrapper)
  public struct TimeToLive: Sendable {
    public static var fiveMinutes: Self { Self(stringValue: "5m") }
    public static var oneHour: Self { Self(stringValue: "1h") }
    let stringValue: String
  }

}

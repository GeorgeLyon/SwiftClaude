public import StructuredCoding

@APICodable
public struct Request<each Tool: StructuredToolProtocol> {

  /// The tool instances themselves are not stored yet — encoding a request
  /// only needs each tool type's `definition`. A later round will keep them
  /// as the callees that responses' tool-use blocks dispatch onto.
  public init(
    model: Model,
    maxTokens: Int,
    messages: [Message],
    tools: repeat each Tool
  ) {
    self.model = model
    self.maxTokens = maxTokens
    self.messages = messages
    self.tools = (repeat ToolDefinition((each Tool).definition))
  }

  public let model: Model

  public let maxTokens: Int

  public let messages: [Message]

  let tools: (repeat ToolDefinition<(each Tool).Definition>)

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

/// A tool definition in the Anthropic wire shape: `{"name": ...,
/// "description": ..., "input_schema": ...}`, with a `nil` description
/// omitted. The definition's `inputSchema` is already guaranteed to be a
/// top-level object schema (non-object single-action schemas are enveloped
/// in `{"input": ...}` by `StructuredToolDefinition`).
@APICodable
public struct ToolDefinition<Definition: StructuredToolDefinitionProtocol> {

  init(_ definition: Definition) {
    self.name = definition.name
    self.description = definition.description
    self.inputSchema = definition.inputSchema
  }

  let name: String

  let description: String?

  let inputSchema: Definition.InputSchema

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

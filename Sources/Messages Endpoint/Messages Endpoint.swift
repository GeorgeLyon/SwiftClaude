public import ClaudeClient

public typealias MessagesEndpoint = ClaudeClient.MessagesEndpoint

extension ClaudeClient {

  public func messages(
    messages: sending [MessagesEndpoint.Request.Message],
    systemPrompt: sending MessagesEndpoint.Request.Message.Content?,
    tools: sending MessagesEndpoint.Request.ToolDefinitions?,
    toolChoice: sending MessagesEndpoint.Request.ToolChoice?,
    model: Model.ID,
    maxOutputTokens: Int,
    isolation: isolated Actor = #isolation
  ) async throws -> MessagesEndpoint.Response {

    var anthropicBetaHeaders: [AnthropicBetaHeader] = []

    if !(tools?.containsCacheBreakpoints ?? false),
      !(systemPrompt?.containsCacheBreakpoints ?? false),
      !messages.contains(where: \.containsCacheBreakpoints)
    {
      /// No cache breakpoints have been specified
    } else {
      anthropicBetaHeaders.append(.promptCaching_v2024_07_31)
    }

    /// Add tool-related beta headers
    if let toolBetaHeaders = tools?.elements.compactMap(\.anthropicBetaHeader) {
      anthropicBetaHeaders.append(contentsOf: Set(toolBetaHeaders))
    }

    /// - note: Region isolation checked fails if we don't use the intermediate `events` variable
    let events = try await serverSentEvents(
      method: .post,
      path: "v1/messages",
      apiVersion: .v2023_06_01,
      anthropicBetaHeaders: anthropicBetaHeaders.isEmpty ? nil : anthropicBetaHeaders,
      body: MessagesEndpoint.Request.Body(
        model: model,
        maxOutputTokens: maxOutputTokens,
        toolChoice: toolChoice,
        tools: tools,
        systemPrompt: systemPrompt,
        messages: messages
      ),
      eventType: MessagesEndpoint.Response.Event.self
    )
    return MessagesEndpoint.Response(
      events: .init(events: events)
    )
  }

  /// Namespace for types related to the messes endpoint
  /// While some of the type names can get pretty unweildly,
  /// (i.e. `Claude.MessagesEndpoint.Request.Message.Content.Block.MediaType`),
  /// This is a low level API and we prefer it not to clutter the API of `Claude`
  public enum MessagesEndpoint {

  }

}

// MARK: - Request

extension ClaudeClient.MessagesEndpoint {
  public enum Request {
  }
}

extension ClaudeClient.MessagesEndpoint.Request {

  fileprivate struct Body: Encodable {

    init(
      model: ClaudeClient.Model.ID,
      maxOutputTokens: Int,
      toolChoice: ToolChoice?,
      tools: ToolDefinitions?,
      systemPrompt: Message.Content?,
      messages: [Message]
    ) {
      self.model = model
      self.maxTokens = maxOutputTokens
      self.toolChoice = toolChoice
      self.tools = tools
      self.system = systemPrompt
      self.messages = messages
    }

    private let stream = true

    private let model: ClaudeClient.Model.ID
    private let maxTokens: Int
    private let toolChoice: ToolChoice?
    private let tools: ToolDefinitions?
    private let system: Message.Content?
    private let messages: [Message]

  }

  public struct ToolChoice: Encodable {
    public static func auto(isParallelToolUseDisabled: Bool? = nil) -> ToolChoice {
      ToolChoice(type: .auto, isParallelToolUseDisabled: isParallelToolUseDisabled)
    }
    public static func any(isParallelToolUseDisabled: Bool? = nil) -> ToolChoice {
      ToolChoice(type: .any, isParallelToolUseDisabled: isParallelToolUseDisabled)
    }
    public static func tool(
      named name: String,
      isParallelToolUseDisabled: Bool? = nil
    ) -> ToolChoice {
      ToolChoice(
        type: .tool,
        name: name,
        isParallelToolUseDisabled: isParallelToolUseDisabled
      )
    }

    private enum Kind: String, Encodable {
      case auto, any, tool
    }
    private init(
      type: Kind,
      name: String? = nil,
      isParallelToolUseDisabled: Bool?
    ) {
      switch (type, name) {
      case (.tool, .none):
        assertionFailure("Name is required for `tool` tool choice.")
      case (_, .some):
        assertionFailure("Name is only allowed for `tool` tool choice.")
      default:
        break
      }
      self.type = type
      self.name = name
      self.disableParallelToolUse = isParallelToolUseDisabled
    }
    private let type: Kind
    private let name: String?
    private let disableParallelToolUse: Bool?
  }

}

// MARK: - Tools Use

extension ClaudeClient.MessagesEndpoint {

  public enum ToolUse {

    /// An `ID` that links tool use requests to tool use responses
    public struct ID: TypedID, Codable {
      public init(untypedValue: UntypedID) {
        self.untypedValue = untypedValue
      }
      public let untypedValue: UntypedID
    }

  }

}

extension ClaudeClient.MessagesEndpoint.Request {

  public struct ToolDefinitions: Encodable {

    public init(elements: [Element]) {
      self.elements = elements
    }

    public struct Element {

      /// A user-defined tool
      public static func tool(
        name: String,
        description: String,
        inputSchema: any Encodable
      ) -> Self {
        Self(
          component: .userDefinedTool(
            UserToolDefinition(
              name: name,
              description: description,
              inputSchema: AnyEncodable(inputSchema)
            )
          )
        )
      }

      public static func tool(
        _ tool: AnthropicToolDefinition
      ) -> Self {
        Self(component: .anthropicDefinedTool(tool))
      }

      public static func cacheBreakpoint(
        _ cacheBreakpoint: ClaudeClient.MessagesEndpoint.Request.CacheBreakpoint
      ) -> Self {
        Self(component: .cacheBreakpoint(cacheBreakpoint))
      }

      fileprivate var anthropicBetaHeader: ClaudeClient.AnthropicBetaHeader? {
        switch component {
        case .userDefinedTool, .cacheBreakpoint:
          return nil
        case .anthropicDefinedTool(let tool):
          return tool.betaHeader
        }
      }

      fileprivate typealias CacheableComponentArray = ClaudeClient.MessagesEndpoint.Request
        .CacheableComponentArray<AnyEncodable>.Element
      fileprivate var cacheableComponentArrayElement: CacheableComponentArray {
        switch component {
        case .userDefinedTool(let tool):
          .component(AnyEncodable(tool))
        case .anthropicDefinedTool(let tool):
          .component(AnyEncodable(tool.definition))
        case .cacheBreakpoint(let cacheBreakpint):
          .cacheBreakpoint(cacheBreakpint)
        }
      }

      /// A user-defined tool
      private struct UserToolDefinition: Encodable {
        init(
          name: String,
          description: String,
          inputSchema: AnyEncodable
        ) {
          self.name = name
          self.description = description
          self.inputSchema = inputSchema
        }

        private let name: String
        private let description: String
        private let inputSchema: AnyEncodable
      }

      private enum Component {
        case userDefinedTool(UserToolDefinition)
        case anthropicDefinedTool(AnthropicToolDefinition)
        case cacheBreakpoint(ClaudeClient.MessagesEndpoint.Request.CacheBreakpoint)
      }
      private let component: Component
    }
    public var elements: [Element]

    public func encode(to encoder: any Encoder) throws {
      try cacheableComponentArray.encode(to: encoder)
    }

    fileprivate var containsCacheBreakpoints: Bool {
      cacheableComponentArray.containsCacheBreakpoints
    }

    private var cacheableComponentArray:
      ClaudeClient.MessagesEndpoint.Request.CacheableComponentArray<AnyEncodable>
    {
      .init(elements: elements.map(\.cacheableComponentArrayElement))
    }

  }

}

// MARK: Anthropic-Defined Tools

extension ClaudeClient.MessagesEndpoint.Request {

  /// The definition of an Anthropic-specified tool, like `computer` or `text_editor`
  public struct AnthropicToolDefinition {

    public static func computer(
      displaySize: ClaudeClient.Image.Size,
      displayNumber: Int? = nil
    ) -> Self {
      let definition = Computer(
        displayWidthPx: displaySize.widthInPixels,
        displayHeightPx: displaySize.heightInPixels,
        displayNumber: displayNumber
      )
      return Self(
        name: definition.name,
        definition: definition,
        betaHeader: .computerUse_v2024_10_22
      )
    }

    public static var textEditor: Self {
      let definition = TextEditor()
      return Self(
        name: definition.name,
        definition: definition,
        betaHeader: .computerUse_v2024_10_22
      )
    }

    public static var bash: Self {
      let definition = Bash()
      return Self(
        name: definition.name,
        definition: definition,
        betaHeader: .computerUse_v2024_10_22
      )
    }

    /// Nonisolated because we access this property to build the tools dictionary for streaming messages
    public nonisolated let name: String

    fileprivate let definition: any Encodable & Sendable
    fileprivate let betaHeader: ClaudeClient.AnthropicBetaHeader?

    private struct Computer: Encodable, Sendable {
      let displayWidthPx: Int
      let displayHeightPx: Int
      let displayNumber: Int?
      let type = "computer_20241022"
      let name = "computer"
    }

    private struct TextEditor: Encodable, Sendable {
      let type = "text_editor_20241022"
      let name = "str_replace_editor"
    }

    private struct Bash: Encodable, Sendable {
      let type = "bash_20241022"
      let name = "bash"
    }
  }

}

// MARK: - Message

extension ClaudeClient.MessagesEndpoint.Request {

  public struct Message: Encodable {

    public enum Role: String, Encodable {
      case user, assistant
    }
    public init(role: Role, content: Content) {
      self.role = role
      self.content = content
    }

    fileprivate var containsCacheBreakpoints: Bool {
      content.containsCacheBreakpoints
    }

    private let role: Role
    private let content: Content

  }

}

// MARK: - Response

extension ClaudeClient.MessagesEndpoint {

  public struct Response {
    let events: Events
  }

}

extension ClaudeClient.MessagesEndpoint.Response {

  public struct Events: AsyncSequence {
    public typealias Element = Result<Event, Error>
    public struct AsyncIterator: AsyncIteratorProtocol {

      public mutating func next() async throws -> Element? {
        switch try await events.next() {
        case .none:
          return nil
        case .success(let event):
          return .success(event)
        case .failure(let error):
          return .failure(error)
        }
      }

      @available(macOS 15.0, iOS 18.0, *)
      public mutating func next(isolation actor: isolated (any Actor)?) async throws -> Element? {
        switch try await events.next(isolation: actor) {
        case .none:
          return nil
        case .success(let event):
          return .success(event)
        case .failure(let error):
          return .failure(error)
        }
      }

      fileprivate init(events: Events) {
        self.events = events.makeAsyncIterator()
      }
      private var events: Events.AsyncIterator
    }
    public func makeAsyncIterator() -> AsyncIterator {
      AsyncIterator(events: events)
    }

    fileprivate typealias Events = ClaudeClient.ServerSentEvents<Event>
    fileprivate init(events: Events) {
      self.events = events
    }
    private var events: Events

  }

}

extension ClaudeClient.MessagesEndpoint.Response {

  public enum Event: Decodable {

    public struct MessageStart: Decodable {
      public struct Message: Decodable {
        public struct ID: TypedID, Decodable, Hashable {
          public init(untypedValue: UntypedID) {
            self.untypedValue = untypedValue
          }
          public let untypedValue: UntypedID
        }
        public let id: ID
        public let model: ClaudeClient.Model.ID
        public let usage: ClaudeClient.MessagesEndpoint.Metadata.Usage?
      }
      public let message: Message
    }
    case messageStart(MessageStart)

    public struct MessageDelta: Decodable {
      public struct Delta: Decodable {
        public let stopReason: ClaudeClient.MessagesEndpoint.Metadata.StopReason?

        /// Only set when `stopReason` == `.stopSequence`
        public let stopSequence: String?
      }
      public let delta: Delta

      public let usage: ClaudeClient.MessagesEndpoint.Metadata.Usage?
    }
    case messageDelta(MessageDelta)

    public struct MessageStop: Decodable {

    }
    case messageStop(MessageStop)

    public struct ContentBlockStart: Decodable {

      public let index: Int

      public enum ContentBlock: Decodable {

        public struct Text: Decodable {
          public let text: String
        }
        case text(Text)

        public struct ToolUse: Decodable {
          public let name: String
          public let id: ClaudeClient.MessagesEndpoint.ToolUse.ID
        }
        case toolUse(ToolUse)

      }
      @AnthropicEnum
      public var contentBlock: ContentBlock

    }
    case contentBlockStart(ContentBlockStart)

    public struct ContentBlockDelta: Decodable {

      public let index: Int

      public enum Delta: Decodable {

        public struct TextDelta: Decodable {
          public let text: String
        }
        case textDelta(TextDelta)

        public struct InputJsonDelta: Decodable {
          public let partialJson: String
        }
        case inputJsonDelta(InputJsonDelta)

      }
      @AnthropicEnum
      public var delta: Delta
    }
    case contentBlockDelta(ContentBlockDelta)

    public struct ContentBlockStop: Decodable {
      public let index: Int
    }
    case contentBlockStop(ContentBlockStop)

  }

}

import ClaudeClient
import ClaudeMessagesEndpoint

// MARK: - Input Conversion

extension Claude {

  /// Internal-only variant of `StreamingMessage` which implements some common logic
  func streamNextMessage<
    Message: Claude.StreamingMessageProtocol
  >(
    in conversation: Conversation,
    systemPrompt: SystemPrompt? = nil,
    tools: Claude.Tools<Message.ToolOutput>? = nil,
    toolChoice: ToolChoice? = nil,
    model: Model? = nil,
    maxOutputTokens: Int? = nil,
    imagePreprocessingMode: Image.PreprocessingMode = .recommended(quality: 1),
    into message: Message,
    isolation: isolated Actor = #isolation
  ) {
    /// Create tool context
    let model = model ?? defaultModel
    let proxyTools: Claude.StreamingMessageTools<Message.ToolOutput>
    let requestTools: ClaudeClient.MessagesEndpoint.Request.ToolDefinitions?
    let messages: [ClaudeClient.MessagesEndpoint.Request.Message]
    let systemPromptContent: ClaudeClient.MessagesEndpoint.Request.Message.Content?
    do {
      var mutableProxyTools = Claude.StreamingMessageTools<Message.ToolOutput>()

      if let tools {
        var requestToolDefinitionsElements:
          [ClaudeClient.MessagesEndpoint.Request.ToolDefinitions.Element] = []

        for element in tools.elements {
          switch element {
          case .cacheBreakpoint(let breakpoint):
            requestToolDefinitionsElements.append(.cacheBreakpoint(breakpoint))
          case .tool(let tool):
            var toolWithContext: (any ToolWithContextProtocol<Message.ToolOutput>)?
            let definition = try tool.messagesRequestToolDefinition(
              for: model,
              imagePreprocessingMode: imagePreprocessingMode,
              &toolWithContext
            )
            requestToolDefinitionsElements.append(definition)
            guard let toolWithContext else {
              assertionFailure()
              throw ToolWithContextNotSetAfterMessagesRequestDescriptionCreated()
            }
            try mutableProxyTools.insert(toolWithContext)
          }
        }
        requestTools = .init(elements: requestToolDefinitionsElements)
      } else {
        requestTools = nil
      }
      proxyTools = mutableProxyTools
      messages = try conversation.messages.map { message in
        try message.messagesRequestMessage(for: model)
      }
      systemPromptContent = try systemPrompt?.messageContent
        .messagesRequestMessageContent(
          for: model,
          imagePreprocessingMode: imagePreprocessingMode
        )
    } catch {
      message.stop(dueTo: error)
      return
    }
    Task<Void, Never> {
      _ = isolation
      var proxy = StreamingMessageProxy(
        client: client,
        tools: proxyTools,
        message: message
      )
      await client.streamNextMessage(
        messages: messages,
        systemPrompt: systemPromptContent,
        tools: requestTools,
        toolChoice: toolChoice,
        model: model.id,
        maxOutputTokens: maxOutputTokens ?? model.maxOutputTokens,
        into: &proxy
      )
    }
  }

}

// MARK: - Streaming Message

extension Claude {

  protocol StreamingMessageProtocol {

    func updateMetadata(with newMetadata: Metadata)

    associatedtype ToolOutput

    func appendContentBlock(
      with event: ContentBlockStart,
      client: ClaudeClient,
      tools: StreamingMessageTools<ToolOutput>,
      isolation: isolated Actor
    ) throws -> any Claude.StreamingMessageContentBlockProtocol

    func stop(dueTo error: Error?)

  }

}

extension Claude.StreamingMessageProtocol {

  typealias Metadata = ClaudeClient.MessagesEndpoint.Metadata
  typealias ContentBlockStart = ClaudeClient.MessagesEndpoint.Response.Event.ContentBlockStart

}

extension Claude {

  protocol StreamingMessageContentBlockProtocol {

    func update(with delta: Delta) throws

    func stop(
      dueTo error: Swift.Error?,
      isolation: isolated Actor
    ) async throws

  }

}

extension Claude.StreamingMessageContentBlockProtocol {

  typealias Delta = ClaudeClient.MessagesEndpoint.Response.Event.ContentBlockDelta.Delta

}

extension Claude {

  /// A processesd `Claude.Tools` which is used by `StreamingMessage` conformers to implement tool use
  struct StreamingMessageTools<Output> {

    func tool(named name: String) throws -> any ToolWithContextProtocol<Output> {
      guard let tool = toolsByName[name] else {
        throw UnknownTool(name: name)
      }
      return tool
    }

    fileprivate mutating func insert(
      _ tool: any ToolWithContextProtocol<Output>
    ) throws {
      guard toolsByName.updateValue(tool, forKey: tool.toolName) == nil else {
        throw MultipleToolsWithSameName(name: tool.toolName)
      }
    }

    fileprivate init() {
    }

    private var toolsByName: [String: any ToolWithContextProtocol<Output>] = [:]

  }

  private struct UnknownTool: Error {
    let name: String
  }

  private struct MultipleToolsWithSameName: Error {
    let name: String
  }

  private struct ToolWithContextNotSetAfterMessagesRequestDescriptionCreated: Error {
  }

}

// MARK: - Proxy

private struct StreamingMessageProxy<
  Message: Claude.StreamingMessageProtocol
>: ClaudeClient.MessagesEndpoint.StreamingMessage {

  let client: ClaudeClient
  let tools: Claude.StreamingMessageTools<Message.ToolOutput>
  let message: Message

  var metadata = Metadata() {
    didSet {
      message.updateMetadata(with: metadata)
    }
  }

  func appendContentBlock(
    with event: ContentBlockStart,
    isolation: isolated Actor
  ) throws -> some ClaudeClient.MessagesEndpoint.StreamingMessageContentBlock {
    StreamingMessageContentBlockProxy(
      contentBlock: try message.appendContentBlock(
        with: event,
        client: client,
        tools: tools,
        isolation: isolation
      )
    )
  }

  func stop(dueTo error: (any Error)?) {
    message.stop(dueTo: error)
  }

}

private struct StreamingMessageContentBlockProxy: ClaudeClient.MessagesEndpoint
    .StreamingMessageContentBlock
{

  let contentBlock: any Claude.StreamingMessageContentBlockProtocol

  mutating func update(with delta: Delta) throws {
    try contentBlock.update(with: delta)
  }

  func stop(
    dueTo error: Swift.Error?,
    isolation: isolated Actor
  ) async throws {
    try await contentBlock.stop(dueTo: error, isolation: isolation)
  }

}

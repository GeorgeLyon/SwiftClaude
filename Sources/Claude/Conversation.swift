private import AsyncAlgorithms
public import ClaudeClient
public import ClaudeMessagesEndpoint
public import Observation

extension Claude {

  public func nextMessage<Conversation: Claude.Conversation>(
    in conversation: Conversation,
    model: Claude.Model? = nil,
    maxOutputTokens: Int? = nil,
    imagePreprocessingMode: Claude.Image.PreprocessingMode? = nil,
    invokeTools toolInvocationStrategy: ToolInvocationStrategy? = nil,
    isolation: isolated Actor = #isolation
  ) -> Conversation.AssistantMessage {
    let message = Conversation.AssistantMessage(
      /// If we make this non-optional and use `.manually` as the default argument, the region isolation checker gets confused.
      /// https://github.com/swiftlang/swift/issues/77620
      toolInvocationStrategy: toolInvocationStrategy ?? .manually
    )
    Task<Void, Never> {
      _ = isolation

      do {
        /// If we make this non-optional and use `.recommended()` as the default argument, the region isolation checker gets confused.
        /// https://github.com/swiftlang/swift/issues/77620
        let imagePreprocessingMode = imagePreprocessingMode ?? .recommended()

        let model = model ?? defaultModel

        let messages = try conversation.messagesRequestMessages(
          for: model,
          imagePreprocessingMode: imagePreprocessingMode
        )

        let systemPrompt = try conversation.systemPrompt?.messageContent
          .messagesRequestMessageContent(
            for: model,
            imagePreprocessingMode: imagePreprocessingMode
          )

        let toolKit: ToolKit<Conversation.ToolOutput>?
        let toolDefinitions: ClaudeClient.MessagesEndpoint.Request.ToolDefinitions?
        if let tools = conversation.tools {
          (toolKit, toolDefinitions) = try tools.compile(
            for: model,
            imagePreprocessingMode: imagePreprocessingMode
          )
        } else {
          toolKit = nil
          toolDefinitions = nil
        }

        let response = try await client.messagesResponse(
          messages: messages,
          systemPrompt: systemPrompt,
          tools: toolDefinitions,
          toolChoice: conversation.toolChoice,
          model: model.id,
          maxOutputTokens: maxOutputTokens ?? model.maxOutputTokens,
          isolation: isolation
        )
        conversation.append(message)
        var proxy = ConversationAssistantMessageProxy(
          client: client,
          toolKit: toolKit,
          message: message
        )
        await response.stream(into: &proxy)
      } catch {
        message.stop(dueTo: error)
      }
    }
    return message
  }

}

extension Claude {

  public protocol Conversation: Observable, AnyObject {

    associatedtype UserMessage

    associatedtype ToolOutput = Never

    associatedtype ToolUseBlock = Claude.ConversationToolUseBlockNever

    var messages: [Message] { get }

    func append(_ assistantMessage: AssistantMessage)

    var systemPrompt: SystemPrompt? { get }

    var tools: Tools<ToolOutput>? { get }

    var toolChoice: ToolChoice? { get }

    static func toolUseBlock<Tool: Claude.Tool>(
      _ toolUse: Claude.ToolUse<Tool>
    ) throws -> ToolUseBlock where Tool.Output == ToolOutput

    static func content(
      for message: UserMessage
    ) -> UserMessageContent

  }

}

extension Claude.Conversation {

  public typealias Message = Claude.ConversationMessage<Self>
  public typealias AssistantMessage = Claude.ConversationAssistantMessage<Self>

  public var systemPrompt: SystemPrompt? { nil }

  public var toolChoice: Claude.ToolChoice? { nil }

}

extension Claude.Conversation where ToolUseBlock == Claude.ConversationToolUseBlockNever {

  public static func toolUseBlock<Tool: Claude.Tool>(
    _ toolUse: Claude.ToolUse<Tool>
  ) throws -> ToolUseBlock where Tool.Output == ToolOutput {
    throw Claude.ToolUseUnavailable()
  }

  public var tools: Tools<ToolOutput>? { nil }

}

extension Claude.Conversation where UserMessage == String {

  public static func content(
    for message: String
  ) -> UserMessageContent {
    UserMessageContent(message)
  }

}

// MARK: Message

extension Claude {

  public enum ConversationMessage<Conversation: Claude.Conversation> {
    case user(Conversation.UserMessage)
    case assistant(ConversationAssistantMessage<Conversation>)
  }

}

extension Claude.ConversationMessage: Identifiable where Conversation.UserMessage: Identifiable {

  public struct ID: Hashable {

    fileprivate enum Kind: Hashable {
      case user(Conversation.UserMessage.ID)
      case assistant(Conversation.AssistantMessage.ID)
    }
    fileprivate init(kind: Kind) {
      self.kind = kind
    }

    private let kind: Kind
  }
  public var id: ID {
    switch self {
    case .user(let message):
      ID(kind: .user(message.id))
    case .assistant(let message):
      ID(kind: .assistant(message.id))
    }
  }

}

// MARK: - User Message Content

public typealias UserMessageContent = Claude.UserMessageContent

extension Claude {

  public struct UserMessageContent: MessageContentRepresentable, SupportsImagesInMessageContent {

    public init(messageContent: MessageContent) {
      self.messageContent = messageContent
    }

    public init(_ toolInvocationResults: Claude.ToolInvocationResults) {
      self.messageContent = toolInvocationResults.messageContent
    }

    public var messageContent: MessageContent

    public mutating func append(
      contentsOf toolInvocationResults: Claude.ToolInvocationResults
    ) {
      messageContent.components.append(
        contentsOf: toolInvocationResults.messageContent.components
      )
    }

  }

}

// MARK: - Text Block

extension Claude {

  @Observable
  public final class ConversationAssistantMessageTextBlock: Identifiable {

    public struct ID: Hashable {
      fileprivate init(
        messageID: MessageID,
        index: Int
      ) {
        self.messageID = messageID
        self.index = index
      }

      private let messageID: MessageID
      private let index: Int
    }
    public let id: ID

    public private(set) var currentText: String

    public var textFragments: some Claude.OpaqueAsyncSequence<Substring> {
      ObservableAppendOnlyCollectionPropertyStream(
        root: self,
        elementsKeyPath: \.currentText,
        resultKeyPath: \.result
      )
      .opaque
    }

    public func text(
      isolation: isolated Actor = #isolation
    ) async throws -> String {
      try await untilNotNil(\.result)
      return currentText
    }

    public var currentError: Error? {
      guard case .failure(let error) = result else { return nil }
      return error
    }

    fileprivate init(
      id: ID,
      initialText: String
    ) {
      self.id = id
      self.currentText = initialText
    }

    private var result: Result<Void, Error>? {
      didSet {
        assert(oldValue == nil && result != nil)
      }
    }

  }

}

// MARK: - Message

extension Claude {

  @Observable
  public final class ConversationAssistantMessage<
    Conversation: Claude.Conversation
  >: Identifiable {

    // MARK: Content Blocks

    public typealias ToolUseBlock = Conversation.ToolUseBlock
    public typealias TextBlock = ConversationAssistantMessageTextBlock
    public enum ContentBlock {
      case textBlock(TextBlock)
      case toolUseBlock(ToolUseBlock)
    }

    public var currentContentBlocks: [ContentBlock] {
      currentPrivateContentBlocks.map { block in
        switch block {
        case .textBlock(let textBlock):
          .textBlock(textBlock)
        case .toolUseBlock(let toolUseBlock, _):
          .toolUseBlock(toolUseBlock)
        }
      }
    }

    public var contentBlocks: some Claude.OpaqueAsyncSequence<ContentBlock> {
      ObservableAppendOnlyCollectionPropertyStream(
        root: self,
        elementsKeyPath: \.currentContentBlocks,
        resultKeyPath: \.streamingResult
      )
      .flatMap { $0.async }
      .opaque
    }

    fileprivate enum PrivateContentBlock {
      case textBlock(TextBlock)
      case toolUseBlock(ToolUseBlock, any ToolUseProtocol<Conversation.ToolOutput>)
    }
    fileprivate var currentPrivateContentBlocks: [PrivateContentBlock] = []

    // MARK: Metadata

    public typealias Metadata = ClaudeClient.MessagesEndpoint.Metadata
    public private(set) var currentMetadata = Metadata()

    public func metadata(
      isolation: isolated Actor = #isolation
    ) async throws -> Metadata {
      try await untilNotNil(\.streamingResult)
      return currentMetadata
    }

    public var isStreamingComplete: Bool {
      streamingResult != nil
    }

    /// Waits until streaming this message is complete
    /// - note: This does not wait for tool invocations to complete
    public func streamingComplete(
      isolation: isolated Actor = #isolation
    ) async throws {
      try await untilNotNil(\.streamingResult)
    }

    private var streamingResult: Result<Void, Error>? {
      didSet {
        assert(oldValue == nil && streamingResult != nil)
      }
    }

    // MARK: Tool Use

    /// Requests the invocation of all tool use blocks
    public func requestToolInvocations() {
      for block in currentPrivateContentBlocks {
        guard case .toolUseBlock(_, let toolUse) = block else {
          continue
        }
        toolUse.requestInvocation()
      }

      /// Subsequent content blocks will immediately request tool invocation
      toolInvocationStrategy = .whenInputAvailable
    }

    public func toolInvocationComplete(
      isolation: isolated Actor = #isolation
    ) async throws {
      try await streamingComplete()
      for block in currentPrivateContentBlocks {
        guard case .toolUseBlock(_, let toolUse) = block else {
          continue
        }
        _ = try await toolUse.output(isolation: isolation)
      }
    }

    public var isToolInvocationCompleteOrFailed: Bool {
      guard streamingResult != nil else {
        return false
      }
      for block in currentPrivateContentBlocks {
        guard case .toolUseBlock(_, let toolUse) = block else {
          continue
        }
        guard toolUse.isInvocationCompleteOrFailed else {
          return false
        }
      }
      return true
    }

    public var currentError: Error? {
      if case .failure(let error) = streamingResult {
        return error
      } else {
        for block in currentPrivateContentBlocks {
          guard case .toolUseBlock(_, let toolUse) = block else {
            continue
          }
          if let error = toolUse.currentError {
            return error
          }
        }
        return nil
      }
    }

    /// This can change, for example if `requestToolInvocations` is called while streaming, this becomes `whenInputAvailable`
    private var toolInvocationStrategy: Claude.ToolInvocationStrategy

    // MARK: Lifecycle

    fileprivate init(
      toolInvocationStrategy: Claude.ToolInvocationStrategy
    ) {
      self.toolInvocationStrategy = toolInvocationStrategy
    }

  }

}

extension Claude {

  public enum ConversationToolUseBlockNever: Identifiable {
    public var id: Never {
      switch self {

      }
    }
  }
}

extension Claude.ConversationAssistantMessage.ContentBlock: Identifiable
where Conversation.ToolUseBlock: Identifiable {

  public struct ID: Hashable {

    fileprivate enum Kind: Hashable {
      case text(Claude.ConversationAssistantMessageTextBlock.ID)
      case toolUse(Conversation.ToolUseBlock.ID)
    }

    fileprivate init(kind: Kind) {
      self.kind = kind
    }

    private let kind: Kind
  }
  public var id: ID {
    switch self {
    case .textBlock(let textBlock):
      ID(kind: .text(textBlock.id))
    case .toolUseBlock(let toolUseBlock):
      ID(kind: .toolUse(toolUseBlock.id))
    }
  }

}

// MARK: Proxies

extension Claude.ConversationAssistantMessageTextBlock {

  fileprivate typealias Delta = ClaudeClient.MessagesEndpoint.Response.Event.ContentBlockDelta.Delta
  fileprivate func update(with delta: Delta) throws {
    currentText.append(try delta.asTextDelta.text)
  }

  fileprivate func stop(dueTo error: Error?, isolation: isolated Actor) async throws {
    if let error {
      result = .failure(error)
    } else {
      result = .success(())
    }
  }

}

private struct ConversationAssistantMessageTextBlockProxy: ClaudeClient.MessagesEndpoint
    .StreamingMessageContentBlock
{

  mutating func update(with delta: Delta) throws {
    try textBlock.update(with: delta)
  }

  func stop(dueTo error: Error?, isolation: isolated Actor) async throws {
    try await textBlock.stop(dueTo: error, isolation: isolation)
  }

  fileprivate typealias TextBlock = Claude.ConversationAssistantMessageTextBlock
  fileprivate init(textBlock: TextBlock) {
    self.textBlock = textBlock
  }
  private let textBlock: TextBlock

}

extension Claude.ConversationAssistantMessage {

  fileprivate typealias ContentBlockStart = ClaudeClient.MessagesEndpoint.Response.Event
    .ContentBlockStart
  fileprivate func appendContentBlock(
    with event: ContentBlockStart,
    client: ClaudeClient,
    toolKit: ToolKit<Conversation.ToolOutput>?,
    isolation: isolated Actor
  ) throws -> any ClaudeClient.MessagesEndpoint.StreamingMessageContentBlock {
    guard let id = currentMetadata.messageID else {
      throw MissingMessageID()
    }

    switch event.contentBlock {
    case .text(let textEvent):
      let block = TextBlock(
        id: .init(
          messageID: id,
          index: event.index
        ),
        initialText: textEvent.text
      )
      currentPrivateContentBlocks.append(.textBlock(block))
      return ConversationAssistantMessageTextBlockProxy(textBlock: block)
    case .toolUse(let toolUseEvent):
      guard let toolKit else {
        throw Claude.ToolUseUnavailable()
      }
      let (toolUse, block) =
        try toolKit
        .tool(named: toolUseEvent.name)
        .toolUseAndBlock(
          for: Conversation.self,
          id: toolUseEvent.id,
          client: client,
          invocationStrategy: toolInvocationStrategy,
          isolation: isolation
        )
      currentPrivateContentBlocks.append(
        .toolUseBlock(block, toolUse)
      )
      return toolUse.proxy
    }
  }

  fileprivate func updateMetadata(with newMetadata: Metadata) {
    currentMetadata = newMetadata
  }

  fileprivate func stop(dueTo error: Error?) {
    if let error {
      streamingResult = .failure(error)
    } else {
      streamingResult = .success(())

      if case .whenStreamingSuccessful = toolInvocationStrategy.kind {
        for block in currentPrivateContentBlocks {
          guard case .toolUseBlock(_, let toolUse) = block else {
            continue
          }
          toolUse.requestInvocation()
        }
      }
    }
  }

  private struct MissingMessageID: Error {}

}

private struct ConversationAssistantMessageProxy<
  Conversation: Claude.Conversation
>: ClaudeClient.MessagesEndpoint.StreamingMessage {

  func appendContentBlock(
    with event: ContentBlockStart,
    isolation: isolated Actor
  ) throws -> any ClaudeClient.MessagesEndpoint.StreamingMessageContentBlock {
    try message.appendContentBlock(
      with: event,
      client: client,
      toolKit: toolKit,
      isolation: isolation
    )
  }

  func updateMetadata(_ newMetadata: Metadata) {
    message.updateMetadata(with: newMetadata)
  }

  func stop(dueTo error: (any Error)?) {
    message.stop(dueTo: error)
  }

  fileprivate init(
    client: ClaudeClient,
    toolKit: ToolKit<Conversation.ToolOutput>?,
    message: Conversation.AssistantMessage
  ) {
    self.client = client
    self.toolKit = toolKit
    self.message = message
  }

  private let client: ClaudeClient
  private let toolKit: ToolKit<Conversation.ToolOutput>?
  private let message: Conversation.AssistantMessage

}

// MARK: - Messages Request

extension Claude.Conversation {

  fileprivate func messagesRequestMessages(
    for model: Claude.Model,
    imagePreprocessingMode: Claude.Image.PreprocessingMode
  ) throws -> [ClaudeClient.MessagesEndpoint.Request.Message] {
    var messages: [ClaudeClient.MessagesEndpoint.Request.Message] = []
    for message in self.messages {
      switch message {
      case .user(let user):
        let content = Self.content(for: user)
        messages.append(
          .init(
            role: .user,
            content: try content.messageContent.messagesRequestMessageContent(
              for: model,
              imagePreprocessingMode: imagePreprocessingMode
            )
          )
        )
      case .assistant(let assistant):
        var assistantContent: ClaudeClient.MessagesEndpoint.Request.Message.Content = []
        // TODO: Handle stream-during-streaming case
        for block in assistant.currentPrivateContentBlocks {
          switch block {
          case .textBlock(let textBlock):
            assistantContent.append(textBlock.currentText)
          case .toolUseBlock(_, let toolUse):
            guard let input = toolUse.currentEncodableInput else {
              fatalError()
            }
            assistantContent.append(
              .toolUse(
                id: toolUse.id,
                name: toolUse.toolName,
                input: input
              )
            )
          }
        }
        messages.append(
          .init(
            role: .assistant,
            content: assistantContent
          )
        )
      }
    }
    return messages
  }

}

// MARK: - Implementation Details

private typealias MessageID = ClaudeClient.MessagesEndpoint.Response.Event.MessageStart.Message.ID

private protocol ToolUseProtocol<Output> {
  associatedtype Output

  var id: Claude.ToolUse.ID { get }
  var toolName: String { get }
  var currentEncodableInput: (Encodable & Sendable)? { get }

  var isInvocationCompleteOrFailed: Bool { get }
  var currentError: Error? { get }
  func output(
    isolation: isolated Actor
  ) async throws -> Output

  func requestInvocation()

  var proxy: any ClaudeClient.MessagesEndpoint.StreamingMessageContentBlock { get }
}

extension Claude.ToolUse: ToolUseProtocol {

}

extension Claude.ToolWithContextProtocol {

  /// Un-type-erase the tool and context
  fileprivate func toolUseAndBlock<Conversation: Claude.Conversation>(
    for: Conversation.Type,
    id: Claude.ToolUse.ID,
    client: ClaudeClient,
    invocationStrategy: Claude.ToolInvocationStrategy,
    isolation: isolated Actor
  ) throws -> (any ToolUseProtocol<Output>, Conversation.ToolUseBlock)
  where Conversation.ToolOutput == Output {
    let toolUse = Claude.ToolUse<Tool>(
      id: id,
      toolWithContext: self,
      inputDecoder: Claude.ToolInputDecoder(
        client: client,
        context: context
      ),
      invocationStrategy: invocationStrategy
    )
    return (toolUse, try Conversation.toolUseBlock(toolUse))
  }

}

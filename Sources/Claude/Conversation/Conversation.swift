import ClaudeClient
import ClaudeMessagesEndpoint

#if canImport(UIKit)
  public import UIKit
#endif

#if canImport(AppKit)
  public import AppKit
#endif

extension Claude {

  public protocol Conversation {

    associatedtype UserMessageImage = Never

    associatedtype ToolOutput = Never

    associatedtype ToolUseBlock: ConversationToolUseBlockProtocol
    where ToolUseBlock.Output == ToolOutput

    var messages: [Message] { get }

    var systemPrompt: SystemPrompt? { get }

    static func image(
      for userMessageImage: UserMessageImage
    ) throws -> Claude.Image

    static func toolUseBlock<Tool: Claude.Tool>(
      for toolUse: Claude.ToolUse<Tool>
    ) throws -> ToolUseBlock where Tool.Output == ToolOutput

    static func toolInvocationResultContent(
      for toolOutput: ToolOutput
    ) -> ToolInvocationResultContent

    var toolInputDecodingFailureEncodingStrategy: Claude.ToolInputDecodingFailureEncodingStrategy {
      get
    }

  }

}

extension Claude.Conversation {

  public typealias Message = Claude.ConversationMessage<Self>
  public typealias UserMessage = Claude.ConversationUserMessage<Self>
  public typealias AssistantMessage = Claude.ConversationAssistantMessage<Self>

  public var systemPrompt: SystemPrompt? { nil }

  public var toolInputDecodingFailureEncodingStrategy:
    Claude.ToolInputDecodingFailureEncodingStrategy
  {
    .encodeErrorInPlaceOfInput
  }

}

extension Claude.Conversation where UserMessageImage == Never {

  public static func image(
    for userMessageImage: UserMessageImage
  ) throws -> Claude.Image {

  }

}

#if canImport(UIKit)
  extension Claude.Conversation where UserMessageImage == UIImage {

    public static func image(
      for userMessageImage: UserMessageImage
    ) throws -> Claude.Image {
      Claude.PlatformImage(userMessageImage)
    }

  }
#endif

#if canImport(AppKit)
  extension Claude.Conversation where UserMessageImage == NSImage {

    public static func image(
      for userMessageImage: UserMessageImage
    ) throws -> Claude.Image {
      Claude.PlatformImage(userMessageImage)
    }

  }
#endif

extension Claude.Conversation {

  public typealias ToolUseBlock = Claude.ConversationToolUseBlock<ToolOutput>

}

extension Claude.Conversation where ToolUseBlock == Claude.ConversationToolUseBlock<ToolOutput> {

  public static func toolUseBlock<Tool: Claude.Tool>(
    for toolUse: Claude.ToolUse<Tool>
  ) throws -> ToolUseBlock where Tool.Output == ToolOutput {
    Claude.ConversationToolUseBlock(toolUse: toolUse)
  }

}

extension Claude.Conversation where ToolOutput == Never {

  public typealias ToolUseBlock = Claude.ConversationToolUseBlockNever

}

extension Claude.Conversation where ToolUseBlock == Claude.ConversationToolUseBlockNever {

  public static func toolUseBlock<Tool: Claude.Tool>(
    for toolUse: Claude.ToolUse<Tool>
  ) throws -> ToolUseBlock where Tool.Output == ToolOutput {
    throw Claude.ToolUseUnavailable()
  }

}

extension Claude.Conversation where ToolOutput == Never {

  public static func toolInvocationResultContent(
    for toolOutput: ToolOutput
  ) -> ToolInvocationResultContent {

  }

}

extension Claude.Conversation where ToolOutput == ToolInvocationResultContent {

  public static func toolInvocationResultContent(
    for toolOutput: ToolOutput
  ) -> ToolInvocationResultContent {
    toolOutput
  }

}

extension Claude.Conversation where ToolOutput == String {

  public static func toolInvocationResultContent(
    for toolOutput: String
  ) -> Claude.ToolInvocationResultContent {
    .init(toolOutput)
  }

}

// MARK: Conversation State

extension Claude {

  public enum ConversationState {
    case ready(for: ConversationNextStep)
    case responding(ConversationResponsePhase)
    case failed(Error)
  }
  
  public enum ConversationNextStep {
    /// The conversation is ready for the user to specify the next message and request a response
    /// This will still be the state if a user message has been added but a response has not been requested
    case user
    case toolUseResult
  }
  
  public enum ConversationResponsePhase {
    case streaming
    case waitingForToolInvocationResults
  }

}

extension Claude.Conversation {

  /// Returns the current state of the conversation
  /// Unlike most other properties on `SwiftClaude` types involved in streaming, there is no exact `async` (non "current-") analog.
  /// The closest thing is `nextStep`
  public var currentState: Claude.ConversationState {
    guard let lastMessage = lastMessageIfItIsAnAssitantMessage else {
      return .ready(for: .user)
    }
    if let error = lastMessage.currentError {
      return .failed(error)
    }
    guard lastMessage.isStreamingCompleteOrFailed else {
      return .responding(.streaming)
    }
    guard lastMessage.isToolInvocationCompleteOrFailed else {
      return .responding(.waitingForToolInvocationResults)
    }
    guard let stopReason = lastMessage.currentMetadata.stopReason else {
      return .failed(Claude.NoStopReasonProvided())
    }
    do {
      return .ready(for: try lastMessage.currentNextStep)
    } catch {
      return .failed(error)
    }
  }
  
  /// Waits for straming and tool invocation to complete, then returns the next step for this conversation
  public func nextStep(
    isolation: isolated Actor = #isolation
  ) async throws -> Claude.ConversationNextStep {
    guard let lastMessage = lastMessageIfItIsAnAssitantMessage else {
      return .user
    }
    try await lastMessage.toolInvocationComplete()
    return try lastMessage.currentNextStep
  }
  
  private var lastMessageIfItIsAnAssitantMessage: AssistantMessage? {
    var reversedMessages = messages.reversed().makeIterator()
    let lastMessage = reversedMessages.next()

    /// All assistant messages that are not the last messages should be complete
    #if DEBUG
      while let notLastMessage = reversedMessages.next() {
        guard case .assistant(let assistantMessage) = notLastMessage else {
          continue
        }
        assert(assistantMessage.isStreamingCompleteOrFailed)
        assert(assistantMessage.isToolInvocationCompleteOrFailed)
      }
    #endif
    
    guard case .assistant(let lastMessage) = lastMessage else {
      return nil
    }
    return lastMessage
  }

}

private extension Claude.ConversationAssistantMessage {
  
  var currentNextStep: Claude.ConversationNextStep {
    get throws {
      switch currentMetadata.stopReason {
      case .none:
        throw Claude.NoStopReasonProvided()
      case .maxTokens:
        throw Claude.MaxOutputTokensReached()
      case .stopSequence:
        /// `stopSequence` seems not super useful, so we still support it from the low level APIs but we don't make an explicit affordance for it to avoid adding complexity to the high level APIs.
        fallthrough
      case .endTurn:
        return .user
      case .toolUse:
        return .toolUseResult
      }
    }
  }
  
}

extension Claude {
  
  private struct NoStopReasonProvided: Error { }
  
  private struct MaxOutputTokensReached: Error { }
  
}


// MARK: Message

extension Claude {

  public enum ConversationMessage<Conversation: Claude.Conversation> {
    case user(ConversationUserMessage<Conversation>)
    case assistant(ConversationAssistantMessage<Conversation>)
  }

}

extension Claude.ConversationMessage: Identifiable {

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

// MARK: - Messages Request

extension Claude.Conversation {

  func messagesRequestMessages(
    for model: Claude.Model,
    imagePreprocessingMode: Claude.Image.PreprocessingMode
  ) throws -> [ClaudeClient.MessagesEndpoint.Request.Message] {
    var messages: [ClaudeClient.MessagesEndpoint.Request.Message] = []
    for message in self.messages {
      switch message {
      case .user(let userMessage):
        var content = Claude.UserMessageContent()
        for contentBlock in userMessage.contentBlocks {
          switch contentBlock {
          case .textBlock(let textBlock):
            content.append(textBlock.text)
          case .imageBlock(let imageBlock):
            content.append(try Self.image(for: imageBlock.image))
          }
        }
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
        messages.append(
          contentsOf: try assistant.messagesRequestMessages(
            for: model,
            imagePreprocessingMode: imagePreprocessingMode,
            toolInputDecodingFailureEncodingStrategy: toolInputDecodingFailureEncodingStrategy,
            renderToolOutput: Self.toolInvocationResultContent(for:)
          )
        )
      }
    }
    return messages
  }

}

private struct IncompleteConversation: Error {

}

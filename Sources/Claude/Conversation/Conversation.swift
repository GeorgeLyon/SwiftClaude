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
    case idle
    case streaming
    case waitingForToolInvocationResults
    case toolInvocationResultsAvailable
    case failed(Error)
  }

}

extension Claude.Conversation {

  public var state: Claude.ConversationState {
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
      return .idle
    }
    if let error = lastMessage.currentError {
      return .failed(error)
    }
    guard lastMessage.isStreamingCompleteOrFailed else {
      return .streaming
    }
    guard lastMessage.isToolInvocationCompleteOrFailed else {
      return .waitingForToolInvocationResults
    }
    guard let stopReason = lastMessage.currentMetadata.stopReason else {
      assertionFailure()
      return .idle
    }
    switch stopReason {
    case .endTurn, .maxTokens, .stopSequence:
      return .idle
    case .toolUse:
      return .toolInvocationResultsAvailable
    }
  }

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
          case .text(let text):
            content.append(text)
          case .image(let image):
            content.append(try Self.image(for: image))
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


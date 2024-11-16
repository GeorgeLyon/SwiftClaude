public import Observation
public import ClaudeClient
public import ClaudeMessagesEndpoint

extension Claude {
  
  @Observable
  public final class ConversationUserMessage<Conversation: Claude.Conversation>: Identifiable {
    
    public init() {
      contentBlocks = []
    }
    
    public enum ContentBlock {
      case text(String)
      case image(Conversation.UserMessageImage)
    }
    public var contentBlocks: [ContentBlock]
    
  }
  
}

// MARK: - Message Content

extension Claude {

  public struct UserMessageContent: MessageContentRepresentable, SupportsImagesInMessageContent {

    public init() {
      self.messageContent = .init()
    }
    
    public init(messageContent: MessageContent) {
      self.messageContent = messageContent
    }

    public var messageContent: MessageContent

  }

}

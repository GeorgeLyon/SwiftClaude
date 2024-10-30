public typealias SystemPrompt = Claude.SystemPrompt

extension Claude {

  public struct SystemPrompt: MessageContentRepresentable {

    public init(messageContent: MessageContent) {
      self.messageContent = messageContent
    }

    public var messageContent: MessageContent

  }

}

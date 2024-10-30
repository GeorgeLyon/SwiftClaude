public typealias AssistantMessage = Claude.AssistantMessage

extension Claude {

  public struct AssistantMessage: MessageContentRepresentable {

    public init() {
      self.messageContent = MessageContent()
    }

    public init(messageContent: MessageContent) {
      self.messageContent = messageContent
    }

    public var messageContent: MessageContent

  }

}

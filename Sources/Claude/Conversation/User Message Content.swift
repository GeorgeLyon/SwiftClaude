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

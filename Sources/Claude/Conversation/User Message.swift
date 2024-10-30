public typealias UserMessage = Claude.UserMessage

extension Claude {

  public struct UserMessage: MessageContentRepresentable, SupportsImagesInMessageContent {

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

extension Claude.MessageContentBuilder where Result == UserMessage {

  @_disfavoredOverload
  public static func buildExpression(_ expression: Claude.ToolInvocationResults) -> Component {
    Component(messageContent: expression.messageContent)
  }

}

public import ClaudeClient
public import ClaudeMessagesEndpoint

public typealias Conversation = Claude.Conversation

extension Claude {

  public struct Conversation {

    public init() {
      messages = []
    }

    public init(
      messages: [Message]
    ) {
      self.messages = messages
    }

    public mutating func append(_ message: UserMessage) {
      messages.append(.init(role: .user, content: message.messageContent))
    }

    public mutating func append(_ message: AssistantMessage) {
      messages.append(.init(role: .assistant, content: message.messageContent))
    }

    public struct Message {
      public typealias Role = ClaudeClient.MessagesEndpoint.Request.Message.Role
      public let role: Role

      public typealias Content = MessageContent
      public let content: Content

      func messagesRequestMessage(
        for model: Model,
        imagePreprocessingMode: Image.PreprocessingMode = .recommended()
      ) throws -> ClaudeClient.MessagesEndpoint.Request.Message {
        ClaudeClient.MessagesEndpoint.Request.Message(
          role: role,
          content: try content.messagesRequestMessageContent(
            for: model,
            imagePreprocessingMode: imagePreprocessingMode
          )
        )
      }
    }
    public var messages: [Message]

  }

}

// MARK: - Result Builder

extension Conversation {

  public init(@Builder _ builder: () throws -> Conversation) rethrows {
    self = try builder()
  }

  public init(@Builder _ builder: () async throws -> Conversation) async rethrows {
    self = try await builder()
  }

  @resultBuilder
  public struct Builder {

    /// `buildExpression` overload that works with string interpolation
    public static func buildExpression(_ component: Component) -> Component {
      component
    }
    @_disfavoredOverload
    public static func buildExpression(_ message: UserMessage) -> Component {
      Component(role: .user, content: message.messageContent)
    }

    @_disfavoredOverload
    public static func buildExpression(_ message: AssistantMessage) -> Component {
      Component(role: .user, content: message.messageContent)
    }

    @available(
      *,
      unavailable,
      message:
        "Cache breakpoints are not supported at the top level of the conversation. Add one to the last message's content block instead."
    )
    public static func buildExpression(_ cacheBreakpoint: CacheBreakpoint) -> Component {
      fatalError()
    }

    public static func buildBlock(_ components: Component...) -> Conversation {
      /// The first unspecified role should be `user`, and the role alternates so we start with `assistant`
      var lastRole: Message.Role = .assistant
      return Conversation(
        messages:
          components
          .flatMap(\.prototypes)
          .map { prototype in
            let role: Message.Role
            switch prototype.role {
            case .user:
              role = .user
            case .assistant:
              role = .assistant
            case .none:
              switch lastRole {
              case .assistant:
                role = .user
              case .user:
                role = .assistant
              }
            }
            lastRole = role
            return Message(role: role, content: prototype.messageContent)
          }
      )
    }

    public struct Component: Claude.SupportsImagesInMessageContent {

      public init(messageContent: MessageContent) {
        prototypes = [
          MessagePrototype(role: nil, messageContent: messageContent)
        ]
      }

      fileprivate init(role: Message.Role, content: MessageContent) {
        prototypes = [
          MessagePrototype(
            role: role,
            messageContent: content
          )
        ]
      }

      fileprivate init(prototypes: some Sequence<MessagePrototype>) {
        self.prototypes = Array(prototypes)
      }

      fileprivate struct MessagePrototype {

        /// `nil` implies "automatic"
        let role: Message.Role?

        let messageContent: MessageContent

      }
      fileprivate let prototypes: [MessagePrototype]
    }

  }
}

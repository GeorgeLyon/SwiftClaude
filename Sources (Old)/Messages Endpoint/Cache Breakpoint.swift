public import ClaudeClient

extension ClaudeClient.MessagesEndpoint.Request {

  // MARK: - Cache Breakpoints

  /// A cache breakpoint
  /// Can be added to system prompts, tool lists, or conversations
  /// Prompt caching is currently in beta.
  /// For details see https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching
  public struct CacheBreakpoint: Sendable {
    public init(cacheControl: CacheControl = .ephemeral) {
      self.cacheControl = cacheControl
    }
    let cacheControl: CacheControl
  }

  /// Controls how a prompt will be cached
  /// Prompt caching is currently in beta.
  /// For details see https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching
  public struct CacheControl: Sendable {
    public static var ephemeral: CacheControl {
      CacheControl(kind: .ephemeral(Ephemeral()))
    }

    struct Ephemeral: Encodable {
      private let type = "ephemeral"
    }

    enum Kind {
      case ephemeral(Ephemeral)
    }
    let kind: Kind
  }

}

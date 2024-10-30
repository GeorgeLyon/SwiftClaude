public import ClaudeClient
public import ClaudeMessagesEndpoint

public struct Claude {
  public init(
    backend: Backend = .production,
    authenticator: Authenticator,
    defaultModel: Model = .default
  ) {
    self.defaultModel = defaultModel
    self.client = ClaudeClient(
      backend: backend,
      authenticator: authenticator
    )
  }

  public let defaultModel: Model

  public typealias Model = ClaudeClient.Model
  public typealias Authenticator = ClaudeClient.Authenticator
  public typealias APIKey = ClaudeClient.APIKey
  public typealias Backend = ClaudeClient.Backend

  public typealias ToolUse = ClaudeClient.MessagesEndpoint.ToolUse
  public typealias ToolChoice = ClaudeClient.MessagesEndpoint.Request.ToolChoice

  #if canImport(Security)
    public typealias KeychainAuthenticator = ClaudeClient.KeychainAuthenticator
  #endif

  let client: ClaudeClient

}

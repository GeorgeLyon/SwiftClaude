public import ClaudeClient
public import ClaudeMessagesEndpoint

extension Claude {
  
  public protocol ConversationToolUseBlockProtocol: Identifiable {
    
    associatedtype Output
    
    init<Tool>(toolUse: ToolUse<Tool>) throws
      where Tool.Output == Output
    
  }
 
  public enum ConversationToolUseBlockNever: ConversationToolUseBlockProtocol {
    public typealias Output = Never
    public var id: Never {
      switch self {

      }
    }
    public init<Tool>(toolUse: ToolUse<Tool>) throws
    where Tool.Output == Output
    {
      throw ToolUseUnavailable()
    }
  }
  
  /// We can't use `ToolUseProtocol` directly in `ConversationAssistantMessage` so we wrap it in a concrete type.
  public struct ConversationToolUseBlock<Output>: ConversationToolUseBlockProtocol {
    public typealias ID = ClaudeClient.MessagesEndpoint.ToolUse.ID
    public var id: ID {
      toolUse.id
    }
    public init<Tool>(toolUse: ToolUse<Tool>)
    where Tool.Output == Output
    {
      self.toolUse = toolUse
    }
    public let toolUse: any ToolUseProtocol<Output>
  }
  
}

// MARK: - Convenience

/// For convenience, pass through `ToolUseProtocol` members
extension Claude.ConversationToolUseBlock {

  var tool: any Claude.Tool<Output> {
    toolUse.tool
  }

  var toolName: String {
    toolUse.toolName
  }

  var currentInputJSON: String {
    toolUse.currentInputJSON
  }

  var inputJSONFragments: any Claude.OpaqueAsyncSequence<Substring> {
    toolUse.inputJSONFragments
  }

  func inputJSON(
    isolation: isolated Actor = #isolation
  ) async throws -> String {
    try await toolUse.inputJSON(isolation: isolation)
  }

  var isInvocationCompleteOrFailed: Bool {
    toolUse.isInvocationCompleteOrFailed
  }

  var currentError: Error? {
    toolUse.currentError
  }

  var currentOutput: Output? {
    toolUse.currentOutput
  }

  func output(
    isolation: isolated Actor = #isolation
  ) async throws -> Output {
    try await toolUse.output(isolation: isolation)
  }

  func requestInvocation() {
    toolUse.requestInvocation()
  }

}

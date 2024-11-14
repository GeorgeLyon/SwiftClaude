public import ClaudeClient

// MARK: - Metadata

extension ClaudeClient.MessagesEndpoint {

  public struct Metadata {

    public init() {}

    public private(set) var state: State = .idle
    public private(set) var model: ClaudeClient.Model.ID?
    public private(set) var usage: Usage?
    public private(set) var stopReason: StopReason?
    public private(set) var messageID: Response.Event.MessageStart.Message.ID?

    public enum State {
      case idle
      case started
      case stopped(Error?)
    }

    public enum StopReason: String, Decodable {
      case endTurn = "end_turn"
      case maxTokens = "max_tokens"
      case toolUse = "tool_use"
      case stopSequence = "stop_sequence"
    }

    public struct Usage: Decodable {

      public private(set) var inputTokens: Int?
      public private(set) var outputTokens: Int?
      public private(set) var cacheCreationInputTokens: Int?
      public private(set) var cacheReadInputTokens: Int?

      private init() {
        /// This should only be decoded and mutated with `update`
      }

      public mutating func update(with other: Usage?) {
        guard let other = other else {
          return
        }
        if let inputTokens = other.inputTokens {
          self.inputTokens = inputTokens
        }
        if let outputTokens = other.outputTokens {
          self.outputTokens = outputTokens
        }
        if let cacheCreationInputTokens = other.cacheCreationInputTokens {
          self.cacheCreationInputTokens = cacheCreationInputTokens
        }
        if let cacheReadInputTokens = other.cacheReadInputTokens {
          self.cacheReadInputTokens = cacheReadInputTokens
        }
      }
    }
    
    init(_ start: Response.Event.MessageStart) {
      state = .started
      model = start.message.model
      if var usage = usage {
        assertionFailure()
        usage.update(with: start.message.usage)
        self.usage = usage
      } else {
        self.usage = start.message.usage
      }
      messageID = start.message.id
    }

    mutating func apply(_ start: Response.Event.MessageStart) {
      guard case .idle = state else {
        assertionFailure()
        return
      }
      state = .started
      model = start.message.model
      if var usage = usage {
        assertionFailure()
        usage.update(with: start.message.usage)
        self.usage = usage
      } else {
        self.usage = start.message.usage
      }
      messageID = start.message.id
    }

    mutating func apply(_ delta: Response.Event.MessageDelta) {
      stopReason = delta.delta.stopReason

      if var usage = usage {
        usage.update(with: delta.usage)
        self.usage = usage
      } else {
        /// `message_start` should have initialized this
        assertionFailure()
        self.usage = delta.usage
      }
    }

    mutating func apply(_ stop: Response.Event.MessageStop) {
      state = .stopped(nil)
    }

    mutating func stop(dueTo error: Error?) {
      if let error {
        state = .stopped(error)
      } else if case .stopped = state {
        /// This is expected, since we set `stopped` in `apply(_:)`
      } else {
        assertionFailure()
        state = .stopped(MetadataError.StoppingUnstoppedMessageWithoutError())
      }
    }

  }

  private enum MetadataError {
    struct StoppingUnstoppedMessageWithoutError: Error {

    }
  }

}

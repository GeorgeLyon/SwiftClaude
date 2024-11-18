public import ClaudeClient

// MARK: - Metadata

extension ClaudeClient.MessagesEndpoint {

  public struct Metadata {

    public init() {}

    public private(set) var state: State = .idle
    public private(set) var model: ClaudeClient.Model.ID?
    public private(set) var usage = Usage()
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

      fileprivate init() {}

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

    mutating func apply(_ start: Response.Event.MessageStart) throws {
      switch state {
      case .idle:
        break
      case .started:
        throw MultipleStartEvents()
      case .stopped:
        throw EventAfterStop()
      }

      state = .started
      model = start.message.model
      if let usage = start.message.usage {
        self.usage = usage
      }
      messageID = start.message.id
    }

    mutating func apply(_ delta: Response.Event.MessageDelta) throws {
      switch state {
      case .idle:
        throw MissingStartEvent()
      case .started:
        break
      case .stopped:
        throw EventAfterStop()
      }

      stopReason = delta.delta.stopReason
      usage.update(with: delta.usage)
    }

    mutating func apply(_ stop: Response.Event.MessageStop) throws {
      /// All logic is currently handled by `stop(dueTo:)`.
    }

    mutating func stop(dueTo error: Error?) throws {
      switch state {
      case .idle:
        /// It is OK for a message to go from idle to stopped, but this should only be in response to an error
        guard error != nil else {
          assertionFailure()
          throw StoppingIdleMessage()
        }
        break
      case .started:
        break
      case .stopped:
        throw EventAfterStop()
      }

      if let error {
        state = .stopped(error)
      } else {
        state = .stopped(nil)
      }
    }

  }

  private struct MultipleStartEvents: Error {}
  private struct MissingStartEvent: Error {}
  private struct StoppingIdleMessage: Error {}
  private struct EventAfterStop: Error {}

}

public import ClaudeClient

extension ClaudeClient.MessagesEndpoint {

  public protocol StreamingMessage {

    var metadata: Metadata { get set }

    associatedtype ContentBlock: StreamingMessageContentBlock

    func appendContentBlock(
      with event: ContentBlockStart,
      isolation: isolated Actor
    ) throws -> ContentBlock

    mutating func recoverFromUnknownEvent(_ error: Error) throws

    mutating func recoverFromEventAfterMessageStop(
      _ event: MessagesEndpoint.Response.Event, _ error: Error) throws

    func stop(dueTo error: Error?)

  }

  public protocol StreamingMessageContentBlock {

    mutating func update(with delta: Delta) throws

    /// `async` so it is easier for tool use blocks to invoke a specified tool on `stop`.
    func stop(
      dueTo error: Error?,
      isolation: isolated Actor
    ) async throws

  }

}

extension ClaudeClient.MessagesEndpoint.StreamingMessage {
  public typealias Metadata = MessagesEndpoint.Metadata
  public typealias ContentBlockStart = MessagesEndpoint.Response.Event.ContentBlockStart
  public func recoverFromUnknownEvent(_ error: Error) throws {
    throw error
  }
  public func recoverFromEventAfterMessageStop(
    _ event: MessagesEndpoint.Response.Event,
    _ error: Error
  ) throws {
    throw error
  }
}

extension ClaudeClient.MessagesEndpoint.StreamingMessageContentBlock {
  public typealias Delta = MessagesEndpoint.Response.Event.ContentBlockDelta.Delta
}

// MARK: - Streaming

extension ClaudeClient.MessagesEndpoint.StreamingMessage {

  @available(macOS 15.0, iOS 18.0, *)
  mutating func process<Events: AsyncSequence>(
    _ events: Events,
    isolation: isolated Actor = #isolation
  ) async where Events.Element == MessagesEndpoint.Response.Events.Element {

    /// Don't use the message's metadata as a source of truth in case it is stubbed or mutated
    var metadata = ClaudeClient.MessagesEndpoint.Metadata() {
      didSet {
        self.metadata = metadata
      }
    }

    /// Track content block states
    var contentBlocks = MessagesEndpoint.ContentBlocks<ContentBlock>()

    do {

      var events = events.makeAsyncIterator()
      while let event = try await events.next(isolation: isolation) {
        switch event {
        case .success(let event):
          switch event {

          /// Message
          case .messageStart(let event):
            metadata.apply(event)
          case .messageDelta(let event):
            metadata.apply(event)
          case .messageStop(let event):
            metadata.apply(event)

            guard try contentBlocks.allStopped else {
              throw ClaudeClient.StreamingMessageError.ContentBlocksNotStoppedAtMessageStop()
            }

            while let event = try await events.next(isolation: isolation) {
              switch event {
              case .success(let event):
                try recoverFromEventAfterMessageStop(
                  event,
                  ClaudeClient.StreamingMessageError.EventAfterMessageStop()
                )
              case .failure(let error):
                try recoverFromUnknownEvent(error)
              }
            }

            metadata.stop(dueTo: nil)
            stop(dueTo: nil)
            return

          /// Content Blocks
          case .contentBlockStart(let event):
            let block = try appendContentBlock(
              with: event,
              isolation: isolation
            )
            try contentBlocks.start(block, at: event.index)
          case .contentBlockDelta(let event):
            try contentBlocks.withContentBlock(at: event.index) { contentBlock in
              try contentBlock.update(with: event.delta)
            }
          case .contentBlockStop(let event):
            let block = try contentBlocks.stop(at: event.index)
            try await block.stop(dueTo: nil, isolation: isolation)
          }
        case .failure(let error):
          try recoverFromUnknownEvent(error)
        }
      }

      throw ClaudeClient.StreamingMessageError.MessageNotStopped()
    } catch {

      for block in contentBlocks.stopRemaining() {
        do {
          try await block.stop(dueTo: error, isolation: isolation)
        } catch {
          /// Ignore errors when stopping blocks due to a thrown error
        }
      }

      metadata.stop(dueTo: error)
      stop(dueTo: error)
    }

  }

}

// MARK: - Compound Methods

extension ClaudeClient {

  @available(macOS 15.0, iOS 18.0, *)
  public func streamNextMessage<Message: MessagesEndpoint.StreamingMessage>(
    messages: sending [MessagesEndpoint.Request.Message],
    systemPrompt: sending MessagesEndpoint.Request.Message.Content? = nil,
    tools: sending MessagesEndpoint.Request.ToolDefinitions? = nil,
    toolChoice: sending MessagesEndpoint.Request.ToolChoice? = nil,
    model: Model.ID,
    maxOutputTokens: Int,
    into message: inout Message,
    isolation: isolated Actor = #isolation
  ) async {
    let response: ClaudeClient.MessagesEndpoint.Response
    do {
      response = try await self.messages(
        messages: messages,
        systemPrompt: systemPrompt,
        tools: tools,
        toolChoice: toolChoice,
        model: model,
        maxOutputTokens: maxOutputTokens
      )
    } catch {
      message.metadata.stop(dueTo: error)
      message.stop(dueTo: error)
      return
    }
    await response.stream(into: &message)
  }

}

extension ClaudeClient.MessagesEndpoint.Response {

  public func stream<Message: ClaudeClient.MessagesEndpoint.StreamingMessage>(
    into message: inout Message,
    isolated isolation: isolated Actor = #isolation
  ) async {
    await message.process(events, isolation: isolation)
  }

}

extension ClaudeClient {

  fileprivate enum StreamingMessageError {
    struct EventAfterMessageStop: Error {}
    struct StoppingUnstoppedMessageWithoutError: Error {}
    struct ContentBlocksNotStoppedAtMessageStop: Error {}
    struct MessageNotStopped: Error {}
  }

}

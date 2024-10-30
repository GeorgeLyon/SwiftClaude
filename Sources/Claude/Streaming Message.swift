private import AsyncAlgorithms
public import ClaudeClient
public import ClaudeMessagesEndpoint
public import Observation

// MARK: - API

extension Claude {

  public func nextMessage(
    in conversation: Conversation,
    systemPrompt: SystemPrompt? = nil,
    model: Model? = nil,
    maxOutputTokens: Int? = nil,
    /// The isolation checker barfs if this has a default value other than `nil`
    imagePreprocessingMode: Image.PreprocessingMode? = nil,
    isolation: isolated Actor = #isolation
  ) -> StreamingTextMessage {
    let message = StreamingTextMessage()
    streamNextMessage(
      in: conversation,
      systemPrompt: systemPrompt,
      model: model,
      maxOutputTokens: maxOutputTokens,
      imagePreprocessingMode: imagePreprocessingMode ?? .recommended(quality: 1),
      into: message,
      isolation: isolation
    )
    return message
  }

  /// - Parameters:
  ///   - toolInvocationStrategy: If `true` tool use blocks will automatically invoke their tools, if `false` they will wait until `requestInvocation` is explicitly called.
  public func nextMessage<ToolOutput>(
    in conversation: Conversation,
    systemPrompt: SystemPrompt? = nil,
    tools: Tools<ToolOutput>,
    invokeTools toolInvocationStrategy: StreamingMessageToolInvocationStrategy = .manually,
    toolChoice: ToolChoice? = nil,
    model: Model? = nil,
    maxOutputTokens: Int? = nil,
    /// The isolation checker barfs if this has a default value other than `nil`
    imagePreprocessingMode: Image.PreprocessingMode? = nil,
    isolation: isolated Actor = #isolation
  ) -> StreamingMessage<ToolOutput> {
    let message = StreamingMessage<ToolOutput>(
      toolInvocationStrategy: toolInvocationStrategy
    )
    streamNextMessage(
      in: conversation,
      systemPrompt: systemPrompt,
      tools: tools,
      toolChoice: toolChoice,
      model: model,
      maxOutputTokens: maxOutputTokens,
      imagePreprocessingMode: imagePreprocessingMode ?? .recommended(quality: 1),
      into: message,
      isolation: isolation
    )
    return message
  }

}

// MARK: - Streaming Text Message

public typealias StreamingTextMessage = Claude.StreamingTextMessage

extension Claude {

  /// - note: Unlike content blocks, `StreamingTextMessage`'s ID is its object identifier since we don't have an ID prior to receiving a `message_start`
  @Observable
  public final class StreamingTextMessage: Identifiable {

    public typealias Metadata = ClaudeClient.MessagesEndpoint.Metadata
    public private(set) var currentMetadata = Metadata()

    public func metadata(
      isolation: isolated Actor = #isolation
    ) async throws -> Metadata {
      try await untilNotNil(\.streamingResult)
      return currentMetadata
    }

    public var isStreamingComplete: Bool {
      streamingResult != nil
    }

    public typealias TextBlock = StreamingMessageTextBlock
    public private(set) var currentTextBlocks: [TextBlock] = []

    public var textBlocks: some Claude.OpaqueAsyncSequence<TextBlock> {
      ObservableAppendOnlyCollectionPropertyStream(
        root: self,
        elementsKeyPath: \.currentTextBlocks,
        resultKeyPath: \.streamingResult
      )
      .flatMap { $0.async }
      .opaque
    }

    public var textFragments: some Claude.OpaqueAsyncSequence<Substring> {
      textBlocks
        .flatMap { $0.textFragments }
        .opaque
    }

    public func text(
      isolation: isolated Actor = #isolation
    ) async throws -> String {
      var segments: [String] = []
      for try await textBlock in textBlocks {
        segments.append(try await textBlock.text())
      }
      return segments.joined()
    }

    /// Waits until streaming this message is complete
    /// - note: This does not wait for tool invocations to complete
    public func streamingComplete(
      isolation: isolated Actor = #isolation
    ) async throws {
      try await untilNotNil(\.streamingResult)
    }

    public var currentError: Error? {
      guard case .failure(let error) = streamingResult else { return nil }
      return error
    }

    fileprivate init() {

    }

    private var streamingResult: Result<Void, Error>? {
      didSet {
        assert(oldValue == nil && streamingResult != nil)
      }
    }

  }

}

extension Claude.StreamingTextMessage: Claude.StreamingMessageProtocol {

  func appendContentBlock(
    with event: ContentBlockStart,
    client: ClaudeClient,
    tools: Claude.StreamingMessageTools<Never>,
    isolation: isolated Actor
  ) throws -> any Claude.StreamingMessageContentBlockProtocol {
    guard let messageID = currentMetadata.messageID else {
      assertionFailure()
      throw NoMessageID()
    }

    switch event.contentBlock {
    case .text(let textEvent):
      let block = Claude.StreamingMessageTextBlock(
        id: .init(
          messageID: messageID,
          index: event.index
        ),
        initialText: textEvent.text
      )
      currentTextBlocks.append(block)
      return block
    case .toolUse:
      throw Claude.ToolUseUnavailable()
    }
  }

  func updateMetadata(with newMetadata: Metadata) {
    currentMetadata = newMetadata
  }

  func stop(dueTo error: Error?) {
    if let error {
      streamingResult = .failure(error)
    } else {
      streamingResult = .success(())
    }
  }

}

// MARK: - Streaming Message (with Tool Use)

public typealias StreamingMessage = Claude.StreamingMessage

extension Claude {

  /// - note: Unlike content blocks, `StreamingTextMessage`'s ID is its object identifier since we don't have an ID prior to receiving a `message_start`
  @Observable
  public final class StreamingMessage<ToolOutput>: Identifiable {

    public typealias Metadata = ClaudeClient.MessagesEndpoint.Metadata
    public private(set) var currentMetadata = Metadata()

    public func metadata(
      isolation: isolated Actor = #isolation
    ) async throws -> Metadata {
      try await untilNotNil(\.result)
      return currentMetadata
    }

    public typealias TextBlock = StreamingMessageTextBlock
    public typealias ToolUseBlock = any StreamingMessageToolUseBlock<ToolOutput>
    public enum ContentBlock: Identifiable {
      case textBlock(TextBlock)
      case toolUseBlock(ToolUseBlock)

      public var textBlock: TextBlock? {
        guard case .textBlock(let textBlock) = self else {
          return nil
        }
        return textBlock
      }

      public var toolUseBlock: ToolUseBlock? {
        guard case .toolUseBlock(let toolUseBlock) = self else {
          return nil
        }
        return toolUseBlock
      }

      public struct ID: Hashable {
        /// Wrap this so it doesn't `==` the specific content block IDs.
        fileprivate let wrapped: StreamingMessageContentBlockID
      }
      public var id: ID {
        switch self {
        case .textBlock(let textBlock):
          ID(wrapped: textBlock.id)
        case .toolUseBlock(let toolUseBlock):
          ID(wrapped: toolUseBlock.id)
        }
      }
    }
    public private(set) var currentContentBlocks: [ContentBlock] = []

    public var contentBlocks: some Claude.OpaqueAsyncSequence<ContentBlock> {
      ObservableAppendOnlyCollectionPropertyStream(
        root: self,
        elementsKeyPath: \.currentContentBlocks,
        resultKeyPath: \.result
      )
      .flatMap { $0.async }
      .opaque
    }

    /// Waits until streaming this message is complete
    /// - note: This does not wait for tool invocations to complete
    public func streamingComplete(
      isolation: isolated Actor = #isolation
    ) async throws {
      try await untilNotNil(\.result)
    }

    public var isStreamingComplete: Bool {
      result != nil
    }

    /// Requests the invocation of all tool use blocks
    public func requestToolInvocations() {
      for block in currentContentBlocks.compactMap(\.toolUseBlock) {
        block.requestInvocation()
      }

      /// Subsequent content blocks will immediately request tool invocation
      toolInvocationStrategy = .whenInputAvailable
    }

    public func toolInvocationComplete(
      isolation: isolated Actor = #isolation
    ) async throws {
      try await streamingComplete()
      for contentBlock in currentContentBlocks {
        _ = try await contentBlock.toolUseBlock?.output()
      }
    }

    public var isToolInvocationCompleteOrFailed: Bool {
      guard result != nil else {
        return false
      }
      for block in currentContentBlocks.compactMap(\.toolUseBlock) {
        guard block.isInvocationCompleteOrFailed else {
          return false
        }
      }
      return true
    }

    public var currentError: Error? {
      if case .failure(let error) = result {
        return error
      } else {
        return currentContentBlocks.compactMap(\.toolUseBlock?.currentError).first
      }
    }

    fileprivate init(
      toolInvocationStrategy: StreamingMessageToolInvocationStrategy
    ) {
      self.toolInvocationStrategy = toolInvocationStrategy
    }

    private var result: Result<Void, Error>? {
      didSet {
        assert(oldValue == nil && result != nil)
      }
    }

    /// This can change, for example if `requestToolInvocations` is called while streaming, this becomes `immediate`
    private var toolInvocationStrategy: StreamingMessageToolInvocationStrategy

  }

}

// MARK: - Converting to AssistantMessage

extension StreamingTextMessage {

  public func currentAssistantMessage(
    streamingFailureEncodingStrategy: Claude.StreamingMessageStreamingFailureEncodingStrategy,
    stopDueToMaxTokensEncodingStrategy: Claude.StreamingMessageStopDueToMaxTokensEncodingStrategy
  ) -> AssistantMessage? {
    currentAssistantMessage(
      encodeStreamingFailure: streamingFailureEncodingStrategy.encode,
      encodeStopDueToMaxTokens: stopDueToMaxTokensEncodingStrategy.encode()
    )
  }

  public func assistantMessage(
    streamingFailureEncodingStrategy: Claude.StreamingMessageStreamingFailureEncodingStrategy,
    stopDueToMaxTokensEncodingStrategy: Claude.StreamingMessageStopDueToMaxTokensEncodingStrategy,
    isolation: isolated Actor = #isolation
  ) async throws -> AssistantMessage {
    /// Try to construct an assistant message even on failure
    try? await untilNotNil(\.streamingResult)

    let message = currentAssistantMessage(
      encodeStreamingFailure: streamingFailureEncodingStrategy.encode,
      encodeStopDueToMaxTokens: stopDueToMaxTokensEncodingStrategy.encode()
    )

    guard let message else {
      /// `currentAssistantMessage` should only return `nil` during streaming
      assertionFailure()
      throw Claude.NoAssistantMessageAfterStop()
    }
    return message
  }

  private func currentAssistantMessage<Failure>(
    encodeStreamingFailure: (Error) throws(Failure) -> AssistantMessage?,
    encodeStopDueToMaxTokens: @autoclosure () throws(Failure) -> AssistantMessage?
  ) throws(Failure) -> AssistantMessage? {

    /// For messages that have failed, we can optionally include the failure in the message's representation for the subsequent conversation turn.
    /// Process this early so if we throw an error we don't need to collate the rest of the content
    let messageFailureContent: AssistantMessage?
    switch streamingResult {
    case .success:
      if currentMetadata.stopReason == .stopSequence {
        messageFailureContent = try encodeStopDueToMaxTokens()
      } else {
        messageFailureContent = nil
      }
    case .failure(let error):
      messageFailureContent = try encodeStreamingFailure(error)
    case .none:
      /// If we haven't finished streaming, the assistant message is `nil`
      return nil
    }

    var message = AssistantMessage(
      self.currentTextBlocks.map { $0.currentText }.joined()
    )

    if let messageFailureContent {
      message.append(contentsOf: messageFailureContent)
    }

    return message
  }

}

extension Claude.StreamingMessage {

  public func currentAssistantMessage(
    inputDecodingFailureEncodingStrategy: Claude
      .StreamingMessageInputDecodingFailureEncodingStrategy,
    streamingFailureEncodingStrategy: Claude.StreamingMessageStreamingFailureEncodingStrategy,
    stopDueToMaxTokensEncodingStrategy: Claude.StreamingMessageStopDueToMaxTokensEncodingStrategy
  ) -> AssistantMessage? {
    currentAssistantMessage(
      encodeInputDecodingFailure: inputDecodingFailureEncodingStrategy.encode,
      encodeStreamingFailure: streamingFailureEncodingStrategy.encode,
      encodeStopDueToMaxTokens: stopDueToMaxTokensEncodingStrategy.encode()
    )
  }

  public func assistantMessage(
    inputDecodingFailureEncodingStrategy: Claude
      .StreamingMessageInputDecodingFailureEncodingStrategy,
    streamingFailureEncodingStrategy: Claude.StreamingMessageStreamingFailureEncodingStrategy,
    stopDueToMaxTokensEncodingStrategy: Claude.StreamingMessageStopDueToMaxTokensEncodingStrategy,
    isolation: isolated Actor = #isolation
  ) async throws -> AssistantMessage {
    /// Try to construct an assistant message even on failure
    try? await untilNotNil(\.result)

    let message = currentAssistantMessage(
      encodeInputDecodingFailure: inputDecodingFailureEncodingStrategy.encode,
      encodeStreamingFailure: streamingFailureEncodingStrategy.encode,
      encodeStopDueToMaxTokens: stopDueToMaxTokensEncodingStrategy.encode()
    )

    guard let message else {
      /// `currentAssistantMessage` should only return `nil` during streaming
      assertionFailure()
      throw Claude.NoAssistantMessageAfterStop()
    }
    return message
  }

  private func currentAssistantMessage<Failure>(
    encodeInputDecodingFailure: (Error?) throws(Failure) -> Encodable,
    encodeStreamingFailure: (Error) throws(Failure) -> AssistantMessage?,
    encodeStopDueToMaxTokens: @autoclosure () throws(Failure) -> AssistantMessage?
  ) throws(Failure) -> AssistantMessage? {

    /// For messages that have failed, we can optionally include the failure in the message's representation for the subsequent conversation turn.
    /// This goes at the end but we process this early so if we throw an error we don't need to collate the rest of the content
    let failureMessage: AssistantMessage?
    switch result {
    case .success:
      if currentMetadata.stopReason == .stopSequence {
        failureMessage = try encodeStopDueToMaxTokens()
      } else {
        failureMessage = nil
      }
    case .failure(let error):
      failureMessage = try encodeStreamingFailure(error)
    case .none:
      /// If we haven't finished streaming, the assistant message is `nil`
      return nil
    }

    var message = AssistantMessage()
    for contentBlock in currentContentBlocks {
      switch contentBlock {
      case .textBlock(let textBlock):
        message.append(textBlock.currentText)
      case .toolUseBlock(let toolUseBlock):
        /// We consider input decoding to be part of the streaming message step, roughly equivalent to decoding the `content_block_stop` payload.
        /// If input decoding fails, we replace the tool input JSON with a different type indicating an error has occurred.
        let input: any Encodable
        if let error = toolUseBlock.inputDecodingError {
          input = try encodeInputDecodingFailure(error)
        } else if let encodableInput = toolUseBlock.currentEncodableInput {
          input = encodableInput
        } else {
          input = try encodeInputDecodingFailure(nil)
        }
        message.messageContent.components.append(
          .passthrough(
            .toolUse(
              id: toolUseBlock.toolUseID,
              name: toolUseBlock.toolName,
              input: input
            )
          )
        )
      }
    }
    if let failureMessage {
      message.append(contentsOf: failureMessage)
    }
    return message
  }

}

extension Claude.StreamingMessage {

  /// A `ToolInvocationResults` representing the results of invoked tools.
  /// This will be `nil` unless the message has completed streaming and **all** tools have finished being invoked.
  public func currentToolInvocationResults(
    renderOutput: (ToolOutput) throws -> ToolInvocationResultContent?
  ) -> Claude.ToolInvocationResults? {
    guard case .some(.success) = result else { return nil }

    var content = Claude.MessageContent()
    for contentBlock in currentContentBlocks {
      guard let block = contentBlock.toolUseBlock else {
        continue
      }
      guard let output = block.currentOutput else {
        /// If any tool isn't finished invoking, return `nil` results
        return nil
      }

      do {
        content.components.append(
          .toolResult(
            id: block.toolUseID,
            content: try renderOutput(output)
          )
        )
      } catch {
        content.components.append(
          .toolResult(
            id: block.toolUseID,
            content: "Error: \(error)",
            isError: true
          )
        )
      }
    }
    return Claude.ToolInvocationResults(messageContent: content)
  }

  public func toolInvocationResults(
    render: (ToolOutput) throws -> ToolInvocationResultContent?,
    isolation: isolated Actor = #isolation
  ) async throws -> Claude.ToolInvocationResults {
    var content = Claude.MessageContent()
    for try await block in contentBlocks.compactMap(\.toolUseBlock) {
      let component: Claude.MessageContent.Component
      do {
        component = .toolResult(
          id: block.toolUseID,
          content: try render(await block.output())
        )
      } catch {
        component = .toolResult(
          id: block.toolUseID,
          content: "Error: \(error)",
          isError: true
        )
      }
      content.components.append(component)
    }
    return Claude.ToolInvocationResults(messageContent: content)
  }

}

extension Claude.StreamingMessage where ToolOutput == String {

  public var currentToolInvocationResults: Claude.ToolInvocationResults? {
    currentToolInvocationResults { output in
      .init(output)
    }
  }

  public func toolInvocationResults(
    isolation: isolated Actor
  ) async throws -> Claude.ToolInvocationResults {
    try await toolInvocationResults(
      render: { output in
        .init(output)
      }
    )
  }

}

extension Claude.StreamingMessage where ToolOutput == ToolInvocationResultContent {

  public var currentToolInvocationResults: Claude.ToolInvocationResults? {
    currentToolInvocationResults { output in
      .init(output)
    }
  }

  public func toolInvocationResults(
    isolation: isolated Actor
  ) async throws -> Claude.ToolInvocationResults {
    try await toolInvocationResults(
      render: { output in
        .init(output)
      }
    )
  }

}

extension Claude {

  /// Specifies how to encode input decoding failures when creating an assistant message
  public struct StreamingMessageInputDecodingFailureEncodingStrategy {

    public static var encodeErrorInPlaceOfInput: Self {
      Self { error in
        guard let error else {
          return Failure(
            errorMessage: "Error: No input was decoded"
          )
        }
        return Failure(
          errorMessage: "Error: \(error)"
        )
      }
    }

    public static func custom(
      _ encode: @escaping (Error?) -> Encodable
    ) -> Self {
      Self(encode: encode)
    }

    fileprivate let encode: (Error?) -> Encodable

    private struct Failure: Encodable {
      let errorMessage: String
    }
  }

  public struct StreamingMessageStreamingFailureEncodingStrategy {

    /// Appends an error message to the end of the assistant response.
    /// The format of this message may change over time.
    public static var appendErrorMessage: Self {
      Self { error in
        "Error: \(error)"
      }
    }

    /// Ignores streaming errors
    public static var ignore: Self {
      Self { _ in
        nil
      }
    }

    /// Appends the specified message content
    public static func custom(
      _ encode: @escaping (Error) -> AssistantMessage
    ) -> Self {
      Self(encode: encode)
    }

    fileprivate let encode: (Error) -> AssistantMessage?
  }

  public struct StreamingMessageStopDueToMaxTokensEncodingStrategy {

    /// Appends a message saying that the maximum token limit was reached to the end of the assistant message.
    /// The format of this message may change over time.
    public static var appendErrorMessage: Self {
      Self {
        "Error: Max tokens reached"
      }
    }

    /// Ignores the stop reason
    public static var ignore: Self {
      Self {
        nil
      }
    }

    /// Appends the specified message content to the message if stopped due to max tokens
    public static func custom(
      _ encode: @escaping () -> AssistantMessage
    ) -> Self {
      Self(encode: encode)
    }

    fileprivate let encode: () -> AssistantMessage?
  }

  private struct NoAssistantMessageAfterStop: Error {

  }

  private struct NoToolResultsAfterStop: Error {

  }

}

// MARK: Streaming

extension Claude.StreamingMessage: Claude.StreamingMessageProtocol {

  func appendContentBlock(
    with event: ContentBlockStart,
    client: ClaudeClient,
    tools: Claude.StreamingMessageTools<ToolOutput>,
    isolation: isolated Actor
  ) throws -> any Claude.StreamingMessageContentBlockProtocol {
    guard let messageID = currentMetadata.messageID else {
      assertionFailure()
      throw NoMessageID()
    }
    let id = Claude.StreamingMessageContentBlockID(
      messageID: messageID,
      index: event.index
    )

    switch event.contentBlock {
    case .text(let textEvent):
      let block = Claude.StreamingMessageTextBlock(
        id: id,
        initialText: textEvent.text
      )
      currentContentBlocks.append(.textBlock(block))
      return block
    case .toolUse(let toolUseEvent):
      let block =
        try tools
        .tool(named: toolUseEvent.name)
        .toolUseBlock(
          id: id,
          toolUseID: toolUseEvent.id,
          client: client,
          invocationStrategy: toolInvocationStrategy,
          isolation: isolation
        )
      currentContentBlocks.append(.toolUseBlock(block.contentBlock))
      return block.streamingContentBlock
    }
  }

  func updateMetadata(with newMetadata: Metadata) {
    currentMetadata = newMetadata
  }

  func stop(dueTo error: Error?) {
    if let error {
      result = .failure(error)
    } else {
      result = .success(())

      if case .whenStreamingSuccessful = toolInvocationStrategy.kind {
        for block in currentContentBlocks.compactMap(\.toolUseBlock) {
          block.requestInvocation()
        }
      }
    }
  }

}

// MARK: - Content Blocks

extension Claude {

  public struct StreamingMessageContentBlockID: Hashable {
    fileprivate init(
      messageID: MessageID,
      index: Int
    ) {
      self.messageID = messageID
      self.index = index
    }
    private let messageID: MessageID
    private let index: Int
  }

}

// MARK: - Text Block

extension Claude {

  @Observable
  public final class StreamingMessageTextBlock: Identifiable {

    public typealias ID = StreamingMessageContentBlockID
    public let id: ID

    public private(set) var currentText: String

    public var textFragments: some Claude.OpaqueAsyncSequence<Substring> {
      ObservableAppendOnlyCollectionPropertyStream(
        root: self,
        elementsKeyPath: \.currentText,
        resultKeyPath: \.result
      )
      .opaque
    }

    public func text(
      isolation: isolated Actor = #isolation
    ) async throws -> String {
      try await untilNotNil(\.result)
      return currentText
    }

    public var currentError: Error? {
      guard case .failure(let error) = result else { return nil }
      return error
    }

    fileprivate init(
      id: ID,
      initialText: String
    ) {
      self.id = id
      self.currentText = initialText
    }

    private var result: Result<Void, Error>? {
      didSet {
        assert(oldValue == nil && result != nil)
      }
    }

  }

}

extension Claude.StreamingMessageTextBlock: Claude.StreamingMessageContentBlockProtocol {

  func update(with delta: Delta) throws {
    currentText.append(try delta.asTextDelta.text)
  }

  func stop(dueTo error: Error?, isolation: isolated Actor) async throws {
    if let error {
      result = .failure(error)
    } else {
      result = .success(())
    }
  }

}

// MARK: - Tool Use Block (Public)

extension Claude {

  public protocol StreamingMessageToolUseBlock<ToolOutput>: Identifiable
  where ID == StreamingMessageContentBlockID {
    associatedtype ToolOutput

    var toolUseID: Claude.ToolUse.ID { get }

    var tool: any Claude.Tool<ToolOutput> { get }

    var toolName: String { get }

    var currentInputJSON: String { get }

    func inputJSON(
      isolation: isolated Actor
    ) async throws -> String

    var currentEncodableInput: Encodable? { get }

    func encodableInput(
      isolation: isolated Actor
    ) async throws -> any Encodable

    func requestInvocation()

    var currentOutput: ToolOutput? { get }

    func output(
      isolation: isolated Actor
    ) async throws -> ToolOutput

    var isInvocationCompleteOrFailed: Bool { get }

    var streamingError: Error? { get }

    var inputDecodingError: Error? { get }

    var invocationError: Error? { get }

  }

  public struct StreamingMessageToolInvocationStrategy {

    /// Tools are only ever invoked after `requestInvocation()` is explicitly called on that tool
    public static var manually: Self { .init(kind: .manually) }

    /// Tools are invoked immediately when their input is available
    public static var whenInputAvailable: Self { .init(kind: .whenInputAvailable) }

    /// All tools are invoked once the message finishes streaming successfully
    public static var whenStreamingSuccessful: Self { .init(kind: .whenStreamingSuccessful) }

    fileprivate enum Kind {
      case manually, whenInputAvailable, whenStreamingSuccessful
    }
    fileprivate let kind: Kind

    private init(kind: Kind) {
      self.kind = kind
    }

  }

}

extension Claude.StreamingMessageToolUseBlock {

  public func inputJSON(
    isolation: isolated Actor = #isolation
  ) async throws -> String {
    try await inputJSON(isolation: isolation)
  }

  public func encodableInput(
    isolation: isolated Actor = #isolation
  ) async throws -> any Encodable {
    try await encodableInput(isolation: isolation)
  }

  public func output(
    isolation: isolated Actor = #isolation
  ) async throws -> ToolOutput {
    try await output(isolation: isolation)
  }

  public var currentError: Error? {
    let errors = [streamingError, inputDecodingError, invocationError].compactMap { $0 }
    /// At most one error should be non-`nil` since these represent serial stages of execution
    assert(errors.count < 2)
    return errors.first
  }

}

// MARK: Tool Use Block (Private)

extension Claude {

  @Observable
  fileprivate final class StreamingMessageConcreteToolUseBlock<Tool: Claude.Tool>:
    StreamingMessageToolUseBlock
  {

    public let id: StreamingMessageContentBlockID

    public let toolUseID: ToolUse.ID

    public typealias ToolOutput = Tool.Output

    public var tool: any Claude.Tool<Tool.Output> {
      toolWithContext.tool
    }
    public var toolName: String {
      toolWithContext.toolName
    }
    private let toolWithContext: any ConcreteToolWithContextProtocol<Tool>

    public private(set) var currentInputJSON = ""

    public var inputJSONFragments: some Claude.OpaqueAsyncSequence<Substring> {
      ObservableAppendOnlyCollectionPropertyStream(
        root: self,
        elementsKeyPath: \.currentInputJSON,
        resultKeyPath: \.streamingResult
      )
      .opaque
    }

    public func inputJSON(
      isolation: isolated Actor = #isolation
    ) async throws -> String {
      try await untilNotNil(\.streamingResult)
      return currentInputJSON
    }

    public var currentInput: Tool.Input? {
      try? inputDecodingResult?.get()
    }

    public var currentEncodableInput: Encodable? {
      guard let currentInput else {
        return nil
      }
      guard
        let encodableInput = try? Claude.ToolInputEncoder<Tool>.encode(currentInput)
      else {
        /// Encoding tool input shouldn't fail for properly defined tools
        assertionFailure()
        return nil
      }
      return encodableInput
    }

    public func input(
      isolation: isolated Actor = #isolation
    ) async throws -> Tool.Input {
      try await untilNotNil(\.inputDecodingResult)
    }

    public func encodableInput(
      isolation: isolated Actor
    ) async throws -> any Encodable {
      let input = try await input()
      return try Claude.ToolInputEncoder<Tool>.encode(input)
    }

    public func requestInvocation() {
      invocationRequests.continuation.yield()
    }

    public private(set) var currentOutput: Tool.Output? {
      didSet {
        /// `currentOutput` may be set multiple times, but it should never be set to `nil`
        assert(currentOutput != nil)
      }
    }

    public func output(
      isolation: isolated Actor = #isolation
    ) async throws -> Tool.Output {
      /// Go through each result so the proper error is thrown
      try await untilNotNil(\.streamingResult)
      _ = try await untilNotNil(\.inputDecodingResult)
      try await untilNotNil(\.invocationResult)

      guard let currentOutput else {
        /// `invocationResult` should be `failure` in this case
        assertionFailure()
        throw InvocationDidNotSetOutput()
      }
      return currentOutput
    }

    public var isInvocationCompleteOrFailed: Bool {
      if streamingError != nil {
        return true
      } else if inputDecodingError != nil {
        return true
      } else {
        return invocationResult != nil
      }
    }

    public var streamingError: Error? {
      guard case .failure(let error) = streamingResult else {
        return nil
      }
      return error
    }

    public var inputDecodingError: Error? {
      guard case .failure(let error) = inputDecodingResult else {
        return nil
      }
      return error
    }

    public var invocationError: Error? {
      guard case .failure(let error) = invocationResult else {
        return nil
      }
      return error
    }

    fileprivate init(
      id: StreamingMessageContentBlockID,
      toolWithContext: any ConcreteToolWithContextProtocol<Tool>,
      toolUseID: ToolUse.ID,
      inputDecoder: ToolInputDecoder<Tool>,
      invocationStrategy: StreamingMessageToolInvocationStrategy
    ) {
      self.id = id
      self.toolWithContext = toolWithContext
      self.toolUseID = toolUseID
      self.inputDecoder = inputDecoder

      if invocationStrategy.kind == .whenInputAvailable {
        invocationRequests.continuation.yield()
      }
    }

    deinit {
      /// If this block is deinitialized early, cancel any pending tool invocations
      invocationTask?.cancel()
      invocationRequests.continuation.finish(throwing: CancellationError())
    }

    /// The result of streaming this block's data from the messages endpoint
    private var streamingResult: Result<Void, Error>? {
      didSet {
        assert(
          [
            oldValue == nil,
            streamingResult != nil,
            inputDecodingResult == nil,
            invocationTask == nil,
            invocationResult == nil,
          ].allSatisfy(\.self)
        )
      }
    }

    /// The result of attempting to decode the tool input
    private var inputDecodingResult: Result<Tool.Input, Error>? {
      didSet {
        assert(
          [
            oldValue == nil,
            streamingResult != nil,
            inputDecodingResult != nil,
            invocationTask == nil,
            invocationResult == nil,
          ].allSatisfy(\.self)
        )
      }
    }

    /// The asynchronous task responsible for invoking the tool
    private var invocationTask: Task<Void, Never>? {
      didSet {
        assert(
          [
            oldValue == nil,
            streamingResult != nil,
            inputDecodingResult != nil,
            invocationTask != nil,
            invocationResult == nil,
          ].allSatisfy(\.self)
        )
      }
    }

    /// The result of invoking the tool
    private var invocationResult: Result<Void, Error>? {
      didSet {
        assert(
          [
            oldValue == nil,
            streamingResult != nil,
            inputDecodingResult != nil,
            invocationTask != nil,
            invocationResult != nil,
          ].allSatisfy(\.self)
        )
        if case .success = invocationResult {
          /// If the result is `success`, `output` must have been set
          assert(currentOutput != nil)
        }
      }
    }

    private let inputDecoder: ToolInputDecoder<Tool>

    private let invocationRequests = AsyncThrowingStream<Void, Error>.makeStream()

    private struct InvocationDidNotSetOutput: Error {}
  }

}

extension Claude.StreamingMessageConcreteToolUseBlock: Claude.StreamingMessageContentBlockProtocol {

  func update(with delta: Delta) throws {
    currentInputJSON.append(try delta.asInputJsonDelta.partialJson)
  }

  func stop(dueTo error: Error?, isolation: isolated Actor) async throws {
    /// Complete streaming
    if let error {
      streamingResult = .failure(error)
    } else {
      streamingResult = .success(())
    }

    /// Decode input
    let input: Tool.Input
    do {
      let json: String
      if currentInputJSON.isEmpty {
        /// The way the streaming format works, the `content_block_start` for a tool use block has an empty JSON object for input, which we ignore.
        /// If there is no input (i.e. the tool is a void function), the backend will send an empty `partial_json` seemingly meaning "no change".
        /// We work around this issue by explicitly passing the empty object instead.
        json = "{}"
      } else {
        json = currentInputJSON
      }

      input = try await Tool.decodeInput(
        from: .init(json: json),
        using: inputDecoder,
        isolation: isolation
      )
      inputDecodingResult = .success(input)
    } catch {
      inputDecodingResult = .failure(error)
      return
    }

    /// Asynchronously invoke tool
    invocationTask = Task { [weak self, invocationRequests] in
      _ = isolation
      do {
        /// Await at least one invocation request
        for try await _ in invocationRequests.stream {
          break
        }

        /// Strongly reference `tool` but not `self`
        guard let toolWithContext = self?.toolWithContext else {
          /// Since `self` is `nil`, no further action is required
          return
        }

        self?.currentOutput = try await toolWithContext.tool.invoke(
          with: input,
          in: toolWithContext.context,
          isolation: isolation
        )

        guard let self else {
          /// If `self` has gone away, don't throw the error so "Swift Error" breakpoints are less confusing
          return
        }
        guard self.currentOutput != nil else {
          throw InvocationDidNotSetOutput()
        }
        self.invocationResult = .success(())
      } catch {
        self?.invocationResult = .failure(error)
      }
    }

  }

}

extension Claude.ConcreteToolWithContextProtocol {

  /// Un-type-erase the tool and context
  fileprivate func toolUseBlock(
    id: Claude.StreamingMessageContentBlockID,
    toolUseID: Claude.ToolUse.ID,
    client: ClaudeClient,
    invocationStrategy: Claude.StreamingMessageToolInvocationStrategy,
    isolation: isolated Actor
  ) -> (
    contentBlock: any Claude.StreamingMessageToolUseBlock<Tool.Output>,
    streamingContentBlock: some Claude.StreamingMessageContentBlockProtocol
  ) {
    let block = Claude.StreamingMessageConcreteToolUseBlock<Tool>(
      id: id,
      toolWithContext: self,
      toolUseID: toolUseID,
      inputDecoder: Claude.ToolInputDecoder(client: client),
      invocationStrategy: invocationStrategy
    )
    /// Have to return both because Swift gets confused if we unify the protocols
    return (block, block)
  }

}

// MARK: - Implementation Details

private typealias MessageID = ClaudeClient.MessagesEndpoint.Response.Event.MessageStart.Message.ID

private struct NoMessageID: Error {}

// MARK: - Async Observation

extension Observable {

  fileprivate func untilNotNil<T>(
    _ keyPath: WritableKeyPath<Self, Result<T, Error>?>,
    isolation: isolated Actor = #isolation
  ) async throws -> T {
    let changes = AsyncStream<Void>.makeStream()
    var changesIterator = changes.stream.makeAsyncIterator()

    repeat {
      let value: Result<T, Error>?
      do {
        /// If this is deinitialized because the observed object is released, releasing the `onChange` closure without calling it, it wil finish the stream.
        let continuation = ContinuationThatFinishesIfItDidntYield(
          wrapped: changes.continuation
        )
        value = withObservationTracking {
          self[keyPath: keyPath]
        } onChange: {
          continuation.yield()
        }
      }

      if let value {
        return try value.get()
      } else {
        continue
      }
    } while await changesIterator.next() != nil
    throw CancellationError()
  }

}

private struct ObservableAppendOnlyCollectionPropertyStream<Root: Observable, Elements: Collection>:
  Claude.OpaqueAsyncSequence
{

  typealias Element = Elements.SubSequence

  struct AsyncIterator: AsyncIteratorProtocol {

    mutating func next() async throws -> Elements.SubSequence? {
      try await next(isolation: nil)
    }

    mutating func next(
      isolation actor: isolated Actor?
    ) async throws -> Elements.SubSequence? {
      let changes = AsyncStream<Void>.makeStream()
      var changesIterator = changes.stream.makeAsyncIterator()

      repeat {
        let elements: Elements
        let result: Result<Void, Error>?

        do {
          /// If this is deinitialized because the observed object is released, releasing the `onChange` closure without calling it, it wil finish the stream.
          let continuation = ContinuationThatFinishesIfItDidntYield(
            wrapped: changes.continuation
          )
          (elements, result) = withObservationTracking {
            (root[keyPath: elementsKeyPath], root[keyPath: resultKeyPath])
          } onChange: {
            continuation.yield()
          }
        }

        let newEndIndex = elements.endIndex
        if lastEndIndex > newEndIndex {
          throw EndIndexDecreased()
        } else if lastEndIndex == newEndIndex {
          if let result {
            /// The stream is complete
            try result.get()
            return nil
          } else {
            /// Wait for the next change
            continue
          }
        } else {
          defer { lastEndIndex = newEndIndex }
          return elements[lastEndIndex..<newEndIndex]
        }
      } while await changesIterator.next() != nil

      /// The observed values (and thus the observation closure) were released
      throw CancellationError()
    }

    fileprivate init(
      root: Root,
      elementsKeyPath: KeyPath<Root, Elements>,
      resultKeyPath: KeyPath<Root, Result<Void, Error>?>
    ) {
      self.root = root
      self.elementsKeyPath = elementsKeyPath
      self.resultKeyPath = resultKeyPath
      self.lastEndIndex = root[keyPath: elementsKeyPath].startIndex
    }
    private let root: Root
    private let elementsKeyPath: KeyPath<Root, Elements>
    private let resultKeyPath: KeyPath<Root, Result<Void, Error>?>
    private var lastEndIndex: Elements.Index

    private struct EndIndexDecreased: Error {}
  }
  func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(
      root: root,
      elementsKeyPath: elementsKeyPath,
      resultKeyPath: resultKeyPath
    )
  }

  fileprivate init(
    root: Root,
    elementsKeyPath: KeyPath<Root, Elements>,
    resultKeyPath: KeyPath<Root, Result<Void, Error>?>
  ) {
    self.root = root
    self.elementsKeyPath = elementsKeyPath
    self.resultKeyPath = resultKeyPath
  }
  private let root: Root
  private let elementsKeyPath: KeyPath<Root, Elements>
  private let resultKeyPath: KeyPath<Root, Result<Void, Error>?>
}

/// A simple continuation that either yields, or finishes
private actor ContinuationThatFinishesIfItDidntYield: Sendable {

  init(wrapped: AsyncStream<Void>.Continuation) {
    self.wrapped = wrapped
  }

  deinit {
    wrapped?.finish()
  }

  nonisolated func yield() {
    Task {
      await self.doYield()
    }
  }

  private func doYield() {
    guard let wrapped else {
      assertionFailure()
      return
    }
    wrapped.yield()
    self.wrapped = nil
  }

  private var wrapped: AsyncStream<Void>.Continuation?
}

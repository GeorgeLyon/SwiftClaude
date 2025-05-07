public import ClaudeClient
public import ClaudeMessagesEndpoint
public import Observation
public import Tool

public typealias ToolUseProtocol = Claude.ToolUseProtocol

extension Claude {

  public protocol ToolUseProtocol<Output>: Identifiable {

    associatedtype Output

    var id: Claude.ToolUse.ID { get }

    var tool: any Claude.Tool<Output> { get }

    var toolName: String { get }

    var currentInputJSON: String { get }

    var inputJSONFragments: any Claude.OpaqueAsyncSequence<Substring> { get }

    func inputJSON(
      isolation: isolated Actor
    ) async throws -> String

    var isInvocationCompleteOrFailed: Bool { get }

    var currentError: Error? { get }

    var currentOutput: Output? { get }

    func output(
      isolation: isolated Actor
    ) async throws -> Output

    func requestInvocation()

  }

}

extension Claude.ToolUseProtocol {

  public func inputJSON(
    isolation: isolated Actor = #isolation
  ) async throws -> String {
    try await inputJSON(isolation: isolation)
  }

  public func output(
    isolation: isolated Actor = #isolation
  ) async throws -> Output {
    try await output(isolation: isolation)
  }

}

// MARK: - Tool Use

public typealias ToolUse = Claude.ToolUse

extension Claude {

  @Observable
  public final class ToolUse<Tool: Claude.Tool>: ToolUseProtocol {

    public typealias ID = ClaudeClient.MessagesEndpoint.ToolUse.ID
    public let id: ID

    public typealias Output = Tool.Output

    public var tool: any Claude.Tool<Output> {
      concreteTool
    }

    let concreteTool: Tool

    public var toolName: String {
      tool.definition.name
    }

    public private(set) var currentInputJSON = ""

    public var inputJSONFragments: any Claude.OpaqueAsyncSequence<Substring> {
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
      get throws {
        try inputDecodingResult?.get()
      }
    }

    public func input(
      isolation: isolated Actor = #isolation
    ) async throws -> Tool.Input {
      try await untilNotNil(\.inputDecodingResult)
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
      return try await untilNotNil(\.invocationResult)
    }

    public var isStreamingCompleteOrFailed: Bool {
      streamingResult != nil
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

    public var currentError: Error? {
      let errors = [streamingError, inputDecodingError, invocationError].compactMap { $0 }
      /// At most one error should be non-`nil` since these represent serial stages of execution
      assert(errors.count < 2)
      return errors.first
    }

    init(
      id: ToolUse.ID,
      tool: Tool,
      client: ClaudeClient,
      invocationStrategy: ToolInvocationStrategy
    ) {
      self.id = id
      self.concreteTool = tool
      self.client = client

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
    private(set) var invocationResult: Result<Output, Error>? {
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
          /// If the result is `success`, `currentOutput` must have been set
          assert(currentOutput != nil)
        }
      }
    }

    /// Only used for decoding the input
    private let client: ClaudeClient

    private let invocationRequests = AsyncThrowingStream<Void, Error>.makeStream()

    private struct InvocationDidNotSetOutput: Error {}
  }

}

public typealias ToolInvocationStrategy = Claude.ToolInvocationStrategy

extension Claude {

  public struct ToolInvocationStrategy {

    /// Tools are only ever invoked after `requestInvocation()` is explicitly called on that tool
    public static var manually: Self { .init(kind: .manually) }

    /// Tools are invoked immediately when their input is available
    public static var whenInputAvailable: Self { .init(kind: .whenInputAvailable) }

    /// All tools are invoked once the message finishes streaming successfully
    public static var whenStreamingSuccessful: Self { .init(kind: .whenStreamingSuccessful) }

    enum Kind {
      case manually, whenInputAvailable, whenStreamingSuccessful
    }
    let kind: Kind

    private init(kind: Kind) {
      self.kind = kind
    }

  }
}

// MARK: Streaming Message Proxy

private struct StreamingMessageToolUseProxy<Tool: Claude.Tool>:
  ClaudeClient.MessagesEndpoint.StreamingMessageContentBlock
{

  mutating func update(with delta: Delta) throws {
    try toolUse.update(with: delta)
  }

  func stop(dueTo error: Error?, isolation: isolated Actor) async throws {
    try await toolUse.stop(dueTo: error, isolation: isolation)
  }

  init(toolUse: Claude.ToolUse<Tool>) {
    self.toolUse = toolUse
  }
  private var toolUse: Claude.ToolUse<Tool>

}

extension Claude.ToolUse {

  var proxy: any ClaudeClient.MessagesEndpoint.StreamingMessageContentBlock {
    StreamingMessageToolUseProxy(toolUse: self)
  }

  fileprivate typealias Delta = ClaudeClient.MessagesEndpoint.Response.Event.ContentBlockDelta.Delta
  fileprivate func update(with delta: Delta) throws {
    currentInputJSON.append(try delta.asInputJsonDelta.partialJson)
  }

  fileprivate func stop(dueTo error: Error?, isolation: isolated Actor) async throws {
    if let error {
      streamingResult = .failure(error)
      return
    }

    /// Streaming success is only set _after_ we've decoded the input so there isn't a "streaming complete but input not yet decoded" phase.
    /// Such a phase would add complexity but not really be useful in any way

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
        for: toolWithContext.tool,
        from: .init(json: json),
        using: inputDecoder,
        isolation: isolation
      )
      streamingResult = .success(())
      inputDecodingResult = .success(input)
    } catch {
      streamingResult = .success(())
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

        let output = try await toolWithContext.tool.invoke(
          with: input,
          in: toolWithContext.context,
          isolation: isolation
        )
        self?.currentOutput = output

        guard let self else {
          /// If `self` has gone away, don't throw the error so "Swift Error" breakpoints are less confusing
          return
        }
        guard self.currentOutput != nil else {
          throw InvocationDidNotSetOutput()
        }
        self.invocationResult = .success(output)
      } catch {
        self?.invocationResult = .failure(error)
      }
    }

  }

}

public import ClaudeClient
public import ClaudeMessagesEndpoint
public import Observation

private import struct Foundation.Data

#if canImport(ClaudeToolInput)
  public import ClaudeToolInput
#endif

// MARK: - Tool

extension Claude {

  /// You should not implement this protocol directly.
  /// Instead, use the `@Tool` macro.
  public protocol Tool<Output> {
    var definition: ToolDefinition<Self> { get }

    associatedtype Input
    associatedtype Output
    associatedtype Failure: Swift.Error

    /// Invoke the tool
    func invoke(
      with input: Input,
      in context: ToolInvocationContext<Self>,
      isolation: isolated Actor
    ) async throws(Failure) -> Output

    static func decodeInput(
      from payload: Claude.ToolInputDecoder<Self>.Payload,
      using decoder: Claude.ToolInputDecoder<Self>,
      isolation: isolated Actor
    ) async throws -> Input

    static func encodeInput(
      _ input: Input,
      to encoder: inout ToolInputEncoder<Self>
    )

    /// This is a very rough API that allows us to track how image preprocessing affects the computer tool's coordinates
    associatedtype _ToolInvocationContextPrivateData = ()

  }

}

extension Claude.Tool where _ToolInvocationContextPrivateData == Void {
  static func _toolInvocationContext(
    for model: Claude.Model,
    imagePreprocessingMode: Claude.Image.PreprocessingMode
  ) -> Claude.ToolInvocationContext<Self> {
    Claude.ToolInvocationContext<Self>(privateData: ())
  }
}

extension Claude.Tool {

  /// This is phrased weirdly because we want the return value to be `sending` but also want to return `toolWithContext`.
  func messagesRequestToolDefinition(
    for model: Claude.Model,
    imagePreprocessingMode: Claude.Image.PreprocessingMode
  ) throws -> (
    element: ClaudeClient.MessagesEndpoint.Request.ToolDefinitions.Element,
    toolWithContext: any Claude.ToolWithContextProtocol<Output>
  ) {
    switch definition.kind {
    #if canImport(ClaudeToolInput)
      case let .userDefined(name, description, toolInput, privateData):
        return (
          element: .tool(
            name: name,
            description: description,
            inputSchema: toolInput.encodablToolInputSchema
          ),
          toolWithContext: Claude.ConcereteToolWithContext(
            toolName: name,
            tool: self,
            context: Claude.ToolInvocationContext(privateData: privateData)
          )
        )
    #endif
    case let .computer(displaySize, displayNumber, privateData):
      let adjustedDisplaySize = try model.imageEncoder.recommendedSize(
        forSourceImageOfSize: displaySize,
        preprocessingMode: imagePreprocessingMode
      )
      let definition = ClaudeClient.MessagesEndpoint.Request.AnthropicToolDefinition.computer(
        displaySize: adjustedDisplaySize,
        displayNumber: displayNumber
      )
      return (
        element: .tool(definition),
        toolWithContext: Claude.ConcereteToolWithContext(
          toolName: definition.name,
          tool: self,
          context: Claude.ToolInvocationContext(
            privateData: privateData(adjustedDisplaySize)
          )
        )
      )
    }
  }

}

#if canImport(ClaudeToolInput)

  extension ToolInput {
    fileprivate static var encodablToolInputSchema: any Encodable & Sendable {
      ToolInputStaticSchemaEncodingContainer<Self>()
    }
  }

  private struct ToolInputStaticSchemaEncodingContainer<ToolInput: ClaudeToolInput.ToolInput>:
    Encodable, Sendable
  {
    func encode(to encoder: any Encoder) throws {
      try ToolInputSchemaEncodingContainer(schema: ToolInput.toolInputSchema)
        .encode(to: encoder)
    }
  }

#endif

// MARK: Tool Definition

extension Claude {

  public struct ToolDefinition<Tool: Claude.Tool> {

    typealias Output = Tool.Output

    static func computer(
      displaySize: Claude.Image.Size,
      displayNumber: Int? = nil
    ) -> ToolDefinition
    where Tool: Claude.Beta.ComputerTool {
      ToolDefinition(
        kind: .computer(
          displaySize: displaySize,
          displayNumber: displayNumber,
          privateData: { Tool._ToolInvocationContextPrivateData(adjustedDisplaySize: $0) }
        )
      )
    }

    enum Kind {
      #if canImport(ClaudeToolInput)
        case userDefined(
          name: String,
          description: String,
          toolInput: any ToolInput.Type,
          privateData: Tool._ToolInvocationContextPrivateData
        )
      #endif
      case computer(
        displaySize: Claude.Image.Size,
        displayNumber: Int?,
        privateData: (Claude.Image.Size) -> Tool._ToolInvocationContextPrivateData
      )
    }
    let kind: Kind

  }

}

#if canImport(ClaudeToolInput)

  extension Claude.ToolDefinition {

    public static func userDefined(
      tool: Tool.Type,
      name: String,
      description: String
    ) -> Self
    where
      Tool.Input: ToolInput,
      Tool._ToolInvocationContextPrivateData == Void
    {
      Self(
        kind: .userDefined(
          name: name,
          description: description,
          toolInput: Tool.Input.self,
          privateData: ()
        )
      )
    }

  }

#endif

// MARK: Tool Input

/// We use a custom encoder and decoder to discourage folks from depending on the encoding/decoding behavior of tool inputs as we may change it in the future.
extension Claude {

  public struct ToolInputDecoder<Tool: Claude.Tool> {

    public struct Payload {
      init(json: String) {
        self.json = json
      }
      fileprivate let json: String
    }

    init(
      client: ClaudeClient,
      context: ToolInvocationContext<Tool>
    ) {
      self.client = client
      self.context = context
    }

    let context: ToolInvocationContext<Tool>

    #if canImport(ClaudeToolInput)

      func decodeInput(
        from payload: Payload,
        isolation: isolated Actor = #isolation
      ) async throws -> Tool.Input
      where Tool.Input: ToolInput {
        let data = Data(payload.json.utf8)
        return try await client.decode(
          ToolInputDecodableContainer<Tool.Input>.self,
          fromResponseData: data
        ).toolInput
      }

    #endif

    func decodeInput<Input: Decodable>(
      of type: Input.Type = Input.self,
      from payload: Payload,
      isolation: isolated Actor = #isolation
    ) async throws -> Input {
      let data = Data(payload.json.utf8)
      return try await client.decode(type, fromResponseData: data)
    }

    private let client: ClaudeClient
  }

  public struct ToolInputEncoder<Tool: Claude.Tool> {

    static func encode(_ input: Tool.Input) throws -> Encodable & Sendable {
      var encoder = ToolInputEncoder()
      Tool.encodeInput(input, to: &encoder)
      guard let value = encoder.toolInput else {
        assertionFailure()
        throw EncodingFailed()
      }
      return value
    }

    mutating func encode(_ input: Encodable & Sendable) {
      self.toolInput = input
    }

    fileprivate var toolInput: (Encodable & Sendable)?

    private struct EncodingFailed: Error {

    }
  }

  /// Specifies how to encode input decoding failures when
  public struct ToolInputDecodingFailureEncodingStrategy {

    public static var encodeErrorInPlaceOfInput: Self {
      Self(kind: .encodeErrorInPlaceOfInput)
    }

    func encode(_ error: Error) -> Encodable & Sendable {
      switch kind {
      case .encodeErrorInPlaceOfInput:
        return Failure(error: "\(error)")
      }
    }

    private enum Kind {
      case encodeErrorInPlaceOfInput
    }
    private let kind: Kind

    private struct Failure: Encodable {
      let error: String
    }
  }

}

#if canImport(ClaudeToolInput)

  extension Claude.Tool where Input: ToolInput {

    public static func encodeInput(
      _ input: Input,
      to encoder: inout Claude.ToolInputEncoder<Self>
    ) {
      assert(encoder.toolInput == nil)
      encoder.toolInput = ToolInputEncodableContainer(toolInput: input)
    }

    public static func decodeInput(
      from payload: Claude.ToolInputDecoder<Self>.Payload,
      using decoder: Claude.ToolInputDecoder<Self>,
      isolation: isolated Actor
    ) async throws -> Input {
      try await decoder.decodeInput(from: payload)
    }

  }

#endif

// MARK: Tool Results

public typealias ToolInvocationResultContent = Claude.ToolInvocationResultContent

extension Claude {

  /// The result of invoking a single tool, rendered as a message that can be sent back to Claude
  public struct ToolInvocationResultContent: MessageContentRepresentable,
    SupportsImagesInMessageContent
  {

    public init(messageContent: MessageContent) {
      self.messageContent = messageContent
    }

    public var messageContent: MessageContent

  }

}

// MARK: - Tool Use

public typealias ToolUseProtocol = Claude.ToolUseProtocol
public typealias ToolUse = Claude.ToolUse

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

extension Claude {

  @Observable
  public final class ToolUse<Tool: Claude.Tool>: ToolUseProtocol {

    public typealias ID = ClaudeClient.MessagesEndpoint.ToolUse.ID
    public let id: ID

    public typealias Output = Tool.Output

    public var tool: any Claude.Tool<Output> {
      toolWithContext.tool
    }
    public var toolName: String {
      toolWithContext.toolName
    }
    private let toolWithContext: any ConcreteToolWithContextProtocol<Tool>

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
      try? inputDecodingResult?.get()
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

    func currentEncodableInput(
      inputDecodingFailureEncodingStrategy: ToolInputDecodingFailureEncodingStrategy
    ) -> (Encodable & Sendable)? {
      guard let currentInput else {
        return nil
      }
      do {
        return try Claude.ToolInputEncoder<Tool>.encode(currentInput)
      } catch {
        return inputDecodingFailureEncodingStrategy.encode(error)
      }
    }

    init(
      id: ToolUse.ID,
      toolWithContext: any ConcreteToolWithContextProtocol<Tool>,
      inputDecoder: ToolInputDecoder<Tool>,
      invocationStrategy: ToolInvocationStrategy
    ) {
      self.id = id
      self.toolWithContext = toolWithContext
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

    private let inputDecoder: ToolInputDecoder<Tool>

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

// MARK: Tool Invocation Context

extension Claude {

  public struct ToolInvocationContext<Tool: Claude.Tool> {

    let privateData: Tool._ToolInvocationContextPrivateData

  }

  protocol ConcreteToolWithContextProtocol<Tool> {
    var toolName: String { get }

    associatedtype Tool: Claude.Tool
    var tool: Tool { get }
    var context: ToolInvocationContext<Tool> { get }
  }

  /// Protocol to use when you have a heterogenous list of tools, such as when iterating over content blocks
  protocol ToolWithContextProtocol<Output>: ConcreteToolWithContextProtocol
  where Output == Tool.Output {
    associatedtype Output
  }

  private struct ConcereteToolWithContext<Tool: Claude.Tool>: ToolWithContextProtocol {
    typealias Output = Tool.Output
    let toolName: String
    let tool: Tool
    let context: ToolInvocationContext<Tool>

    fileprivate init(
      toolName: String,
      tool: Tool,
      context: ToolInvocationContext<Tool>
    ) {
      self.toolName = toolName
      self.tool = tool
      self.context = context
    }
  }

}

// MARK: - Tools

public typealias Tools = Claude.Tools

extension Claude {

  public struct Tools<Output>: ExpressibleByArrayLiteral {

    public init() {
      elements = []
    }

    public init(_ tool: any Tool<Output>) {
      elements = [.tool(tool)]
    }

    public init(_ tools: [any Tool<Output>]) {
      elements = tools.map(Element.tool)
    }

    public init(arrayLiteral tools: any Tool<Output>...) {
      elements = tools.map(Element.tool)
    }

    public init(_ cacheBreakpoint: CacheBreakpoint) {
      elements = [.cacheBreakpoint(cacheBreakpoint)]
    }

    public mutating func append(
      _ tool: any Tool<Output>,
      cacheBreakpoint: CacheBreakpoint? = nil
    ) {
      elements.append(.tool(tool))
      if let cacheBreakpoint {
        append(cacheBreakpoint)
      }
    }

    public mutating func append(_ cacheBreakpoint: CacheBreakpoint) {
      elements.append(.cacheBreakpoint(cacheBreakpoint))
    }

    public typealias CacheBreakpoint = ClaudeClient.MessagesEndpoint.Request.CacheBreakpoint

    fileprivate init(elements: some Sequence<Element>) {
      self.elements = Array(elements)
    }

    enum Element {
      case tool(any Tool<Output>)
      case cacheBreakpoint(CacheBreakpoint)

      var tool: (any Tool<Output>)? {
        guard case .tool(let tool) = self else { return nil }
        return tool
      }
    }
    private(set) var elements: [Element] = []

  }

}

extension Sequence {

  func joined<Output>() -> Claude.Tools<Output>
  where Element == Claude.Tools<Output> {
    Claude.Tools(elements: map(\.elements).joined())
  }

}

extension Claude.Tools {

  public init(@Builder _ builder: () -> Claude.Tools<Output>) {
    self = builder()
  }

  @resultBuilder
  public struct Builder {

    public static func buildExpression<Tool: Claude.Tool>(_ tool: Tool) -> Component
    where Tool.Output == Output {
      Component(tools: .init(tool))
    }

    public static func buildExpression(_ tool: any Claude.Tool<Output>) -> Component {
      Component(tools: .init(tool))
    }

    public static func buildExpression(_ cacheBreakpoint: CacheBreakpoint) -> Component {
      Component(tools: .init(cacheBreakpoint))
    }

    public static func buildBlock(_ components: Component...) -> Claude.Tools<Output> {
      components.map(\.tools).joined()
    }

    public struct Component {
      fileprivate let tools: Claude.Tools<Output>
    }

  }

}

// MARK: Tool Kit

extension Claude.Tools {

  func compile(
    for model: Claude.Model,
    imagePreprocessingMode: Claude.Image.PreprocessingMode
  ) throws -> (ToolKit<Output>, ClaudeClient.MessagesEndpoint.Request.ToolDefinitions) {
    var toolsByName: [String: any Claude.ToolWithContextProtocol<Output>] = [:]
    var toolDefinitions = ClaudeClient.MessagesEndpoint.Request.ToolDefinitions()

    for element in elements {
      switch element {
      case .cacheBreakpoint(let breakpoint):
        toolDefinitions.elements.append(.cacheBreakpoint(breakpoint))
      case .tool(let tool):
        let (definition, toolWithContext) = try tool.messagesRequestToolDefinition(
          for: model,
          imagePreprocessingMode: imagePreprocessingMode
        )
        let name = toolWithContext.toolName
        guard toolsByName.updateValue(toolWithContext, forKey: name) == nil else {
          throw MultipleToolsWithSameName(name: name)
        }
        toolDefinitions.elements.append(definition)
      }
    }

    return (
      ToolKit(toolsByName: toolsByName),
      toolDefinitions
    )
  }

  private struct MultipleToolsWithSameName: Error {
    let name: String
  }

}

struct ToolKit<Output> {

  func tool(named name: String) throws -> any Claude.ToolWithContextProtocol<Output> {
    guard let tool = toolsByName[name] else {
      throw UnknownTool(name: name)
    }
    return tool
  }

  fileprivate init(
    toolsByName: [String: any Claude.ToolWithContextProtocol<Output>]
  ) {
    self.toolsByName = toolsByName
  }

  private let toolsByName: [String: any Claude.ToolWithContextProtocol<Output>]

  private struct UnknownTool: Error {
    let name: String
  }

}

// MARK: - Macros Boilerplate

#if canImport(ClaudeToolInput)

  @attached(extension)
  @attached(
    extension,
    conformances: Claude.Tool,
    names: named(definition), named(Input), named(invoke)
  )
  public macro Tool(name: String? = nil) =
    #externalMacro(
      module: "ClaudeMacros",
      type: "ToolMacro"
    )

  @attached(extension)
  @attached(
    extension,
    conformances: Claude.ToolInput,
    names:
      named(ToolInputSchema),
    named(toolInputSchema),
    named(init(toolInputSchemaDescribedValue:)),
    named(toolInputSchemaDescribedValue)
  )
  public macro ToolInput() =
    #externalMacro(
      module: "ClaudeMacros",
      type: "ToolInputMacro"
    )

  /// Expose types referenced by macro expansion
  extension Claude {

    /// Compound Schemas
    public typealias ToolInput = ClaudeToolInput.ToolInput
    public typealias ToolInputSchema = ClaudeToolInput.ToolInputSchema
    public typealias ToolInputKeyedTupleSchema = ClaudeToolInput.ToolInputKeyedTupleSchema
    public typealias ToolInputEnumSchema = ClaudeToolInput.ToolInputEnumSchema

    /// Primitive Schemas
    public typealias ToolInputStringSchema = ClaudeToolInput.ToolInputStringSchema
    public typealias ToolInputNumberSchema = ClaudeToolInput.ToolInputNumberSchema
    public typealias ToolInputIntegerSchema = ClaudeToolInput.ToolInputIntegerSchema
    public typealias ToolInputBoolSchema = ClaudeToolInput.ToolInputBoolSchema
    public typealias ToolInputVoidSchema = ClaudeToolInput.ToolInputVoidSchema

    /// Miscellaneous types
    public typealias ToolInputSchemaKey = ClaudeToolInput.ToolInputSchemaKey
    public typealias ToolInputEnumNoCaseSpecified = ClaudeToolInput.ToolInputEnumNoCaseSpecified

  }

#endif

// MARK: - Errors

extension Claude {

  struct ToolUseUnavailable: Error {}

}

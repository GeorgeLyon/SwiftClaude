public import ClaudeClient
public import ClaudeMessagesEndpoint
@_exported public import Tool

// MARK: - Tool

extension Claude {

  public typealias Tool = _ImplementationDetails._Tool

}

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

// MARK: - Tools

public typealias Tools = Claude.Tools

extension Claude {

  public struct Tools<Output>: ExpressibleByArrayLiteral {

    public init() {
      elements = []
    }

    public init(_ tool: any Tool<Output>) {
      elements = [.clientDefinedTool(tool)]
    }

    public init(_ tools: [any Tool<Output>]) {
      elements = tools.map(Element.clientDefinedTool)
    }

    public init(arrayLiteral tools: any Tool<Output>...) {
      elements = tools.map(Element.clientDefinedTool)
    }

    public init(_ cacheBreakpoint: CacheBreakpoint) {
      elements = [.cacheBreakpoint(cacheBreakpoint)]
    }

    public mutating func append(
      _ tool: any Tool<Output>,
      cacheBreakpoint: CacheBreakpoint? = nil
    ) {
      elements.append(.clientDefinedTool(tool))
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
      case clientDefinedTool(any Tool<Output>)
      case cacheBreakpoint(CacheBreakpoint)

      var tool: (any Tool<Output>)? {
        guard case .clientDefinedTool(let tool) = self else { return nil }
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

  func compile() throws -> (ToolKit<Output>, ClaudeClient.MessagesEndpoint.Request.ToolDefinitions)
  {
    var toolsByName: [String: any Tool<Output>] = [:]
    var toolDefinitions = ClaudeClient.MessagesEndpoint.Request.ToolDefinitions()

    for element in elements {
      switch element {
      case .cacheBreakpoint(let breakpoint):
        toolDefinitions.elements.append(.cacheBreakpoint(breakpoint))
      case .clientDefinedTool(let tool):
        let definition = tool.definition
        let name = definition.name
        guard toolsByName.updateValue(tool, forKey: name) == nil else {
          throw MultipleToolsWithSameName(name: name)
        }
        toolDefinitions.elements.append(.tool(definition))
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

  func tool(named name: String) throws -> any Tool<Output> {
    guard let tool = toolsByName[name] else {
      throw UnknownTool(name: name)
    }
    return tool
  }

  fileprivate init(
    toolsByName: [String: any Tool<Output>]
  ) {
    self.toolsByName = toolsByName
  }

  private let toolsByName: [String: any Tool<Output>]

  private struct UnknownTool: Error {
    let name: String
  }

}

// MARK: - Errors

extension Claude {

  /// Specifies how to encode input decoding failures
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

  struct ToolUseUnavailable: Error {}

}

// MARK: - Implementation Details

extension Claude._ImplementationDetails {
  public typealias _Tool = Tool
}

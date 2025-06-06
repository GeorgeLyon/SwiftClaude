// MARK: - Tool

public protocol Tool<Output> {

  associatedtype Definition: ToolDefinition<Input>
  var definition: Definition { get }

  associatedtype Input: Sendable
  associatedtype Output
  associatedtype Failure: Swift.Error

  func invoke(
    with input: Input,
    isolation: isolated Actor
  ) async throws(Failure) -> Output

}

extension Tool {

  public func invoke(
    with input: Input,
    isolation: isolated Actor = #isolation
  ) async throws(Failure) -> Output {
    try await self.invoke(with: input, isolation: isolation)
  }

}

// MARK: - Tool Definition

public protocol ToolDefinition<Input>: Sendable {

  var name: String { get }

  associatedtype Input

  associatedtype InputSchema: Schema where InputSchema.Value == Input
  var inputSchema: InputSchema { get }

}

public struct ClientDefinedToolDefinition<InputSchema: Schema>: ToolDefinition {

  public init(
    name: String,
    description: String?,
    inputSchema: InputSchema
  ) {
    self.name = name
    self.description = description
    self.inputSchema = inputSchema
  }

  public let name: String

  private let description: String?

  public let inputSchema: InputSchema

}

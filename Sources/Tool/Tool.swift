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

public protocol ToolDefinition<Input>: Encodable & Sendable {

  var name: String { get }

  associatedtype Input

  associatedtype InputSchema: ToolInput.Schema where InputSchema.Value == Input
  var inputSchema: InputSchema { get }

}

public struct ClientDefinedToolDefinition<InputSchema: ToolInput.Schema>: ToolDefinition {

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

extension ClientDefinedToolDefinition: Encodable {

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKey.self)
    try container.encode(name, forKey: .name)
    try container.encodeIfPresent(description, forKey: .description)
    try inputSchema.encodeSchemaDefinition(
      to: ToolInput.SchemaEncoder(wrapped: container.superEncoder(forKey: .inputSchema))
    )
  }

  private enum CodingKey: Swift.CodingKey {
    case name, description, inputSchema
  }

}

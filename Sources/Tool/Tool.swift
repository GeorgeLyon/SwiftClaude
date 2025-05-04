public protocol Tool {

  var definition: ToolDefinition<Self> { get }

  associatedtype InputSchema: ToolInput.Schema
  associatedtype Output
  associatedtype Failure: Swift.Error

  func invoke(
    with input: InputSchema.Value,
    isolation: isolated Actor
  ) async throws(Failure) -> Output

}

public struct ToolDefinition<ConcreteTool: Tool> {

  public init(
    name: String,
    description: String?,
    inputSchema: ConcreteTool.InputSchema
  ) {
    self.name = name
    self.description = description
    self.inputSchema = inputSchema
  }

  private let name: String
  private let description: String?
  private let inputSchema: ConcreteTool.InputSchema

}

extension ToolDefinition: Encodable {

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

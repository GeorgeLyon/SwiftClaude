public import SchemaCoding

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

  associatedtype InputSchema: SchemaCoding.Schema where InputSchema.Value == Input
  var inputSchema: InputSchema { get }

}

public struct ClientDefinedToolDefinition<InputSchema: SchemaCoding.Schema>: ToolDefinition {

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

// MARK: - Tool Input

public enum ToolInput {
  public typealias Schema = SchemaCoding.Schema
  public typealias SchemaCodable = SchemaCoding.SchemaCodable
  public typealias SchemaCodingSupport = SchemaCoding.SchemaCodingSupport
}

// MARK: - Macros

@attached(
  extension,
  conformances: Tool,
  names: named(definition), named(Input), named(invoke)
)
public macro Tool() =
  #externalMacro(
    module: "Macros",
    type: "ToolMacro"
  )

@attached(
  extension,
  conformances: ToolInput.SchemaCodable,
  names: named(schema), named(init)
)
public macro ToolInput() =
  #externalMacro(
    module: "Macros",
    type: "ToolInputMacro"
  )

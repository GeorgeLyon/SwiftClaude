import Foundation
import MCP

import struct Tool.ToolResultContent

@MainActor
public protocol MCPServer: SendableMetatype {
  init()
  var name: String { get }
  var version: String { get }
  var tools: Tools { get }
}

extension MCPServer {
  public static func main() async throws {
    try await Self().serve()
  }

  private func serve() async throws {
    let server = Server(
      name: name,
      version: version,
      capabilities: .init(
        tools: .init()
      )
    )
    let transport = StdioTransport()
    try await server.start(transport: transport)

    await server.withMethodHandler(ListTools.self) { @MainActor _ in
      return .init(
        tools: try mcpTools()
      )
    }

    await server.withMethodHandler(CallTool.self) { @MainActor params in
      guard let tool = tools.toolsByName[params.name] else {
        return .init(content: [.text("Unknown tool")], isError: true)
      }
      guard let arguments = params.arguments else {
        return .init(content: [.text("Missing arguments")], isError: true)
      }

      let decoder = JSONDecoder()
      let encoder = JSONEncoder()
      let argumentsData = try encoder.encode(arguments)

      return await tool.invoke(argumentsData: argumentsData, decoder: decoder)
    }

    try await Task.sleep(for: .seconds(60 * 60 * 24))
  }

  private func mcpTools() throws -> [Tool] {
    let decoder = JSONDecoder()
    let encoder = JSONEncoder()
    return try tools.tools.map { tool in
      let data = try encoder.encode(tool.definition)
      return try decoder.decode(Tool.self, from: data)
    }
  }
}

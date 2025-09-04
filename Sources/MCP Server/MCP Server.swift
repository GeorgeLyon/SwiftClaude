import Foundation
import MCP

@MainActor
public protocol MCPServer: SendableMetatype {
  init()
  var tools: Tools { get }
}

extension MCPServer {
  public static func main() async throws {
    try await Self().serve()
  }

  private func serve() async throws {
    let server = Server(
      name: "SwiftClaudeExample",
      version: "0.0.0",
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

    await server.withMethodHandler(CallTool.self) { params in
      switch params.name {
      case "add":
        if let a = params.arguments?["a"]?.intValue,
          let b = params.arguments?["b"]?.intValue
        {
          return .init(content: [.text("\(a + b)")], isError: false)
        } else {
          return .init(content: [.text("Missing parameter")], isError: true)
        }

      default:
        return .init(content: [.text("Unknown tool")], isError: true)
      }
    }

    try await Task.sleep(for: .seconds(60 * 60 * 24))
  }

  private func mcpTools() throws -> [Tool] {
    let decoder = JSONDecoder()
    let encoder = JSONEncoder()
    let datas = try tools.tools.map { tool in
      try encoder.encode(tool.definition)
    }
    let string =
      datas
      .map { data in
        String(decoding: data, as: UTF8.self)
      }
      .joined(separator: "\n")
    return try datas.map { data in
      try decoder.decode(Tool.self, from: data)
    }
  }
}

import MCPServer
import Tool

@main
struct MCPServerExample: MCPServer {

  let name = "MCPServerExample"
  let version = "0.0.0"

  let tools: Tools = [
    ExampleAddTool()
  ]

}

@Tool
struct ExampleAddTool {

  func invoke(a: Int, b: Int) -> ToolResultContent {
    "\(a + b)"
  }

}

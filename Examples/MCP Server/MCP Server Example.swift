import MCPServer
import Tool

@main
struct MCPServerExample: MCPServer {

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

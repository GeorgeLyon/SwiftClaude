public import Tool

public struct Tools: ExpressibleByArrayLiteral {

  public init(arrayLiteral tools: (any Tool)...) {
    self.tools = tools
  }

  public init(_ tools: [any Tool]) {
    self.tools = tools
  }

  let tools: [any Tool]

}

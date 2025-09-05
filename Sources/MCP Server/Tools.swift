import Foundation
public import Tool

import enum MCP.CallTool

public struct Tools: ExpressibleByArrayLiteral {

  public init(arrayLiteral tools: (any Tool)...) {
    self.init(tools)
  }

  public init(_ tools: [any Tool]) {
    self.tools = tools

    var toolsByName: [String: any Tool] = [:]
    for tool in tools {
      let key = tool.definition.name
      guard !toolsByName.keys.contains(key) else {
        assertionFailure()
        continue
      }
      toolsByName[key] = tool
    }
    self.toolsByName = toolsByName
  }

  let tools: [any Tool]
  let toolsByName: [String: any Tool]

}

extension Tool {

  func invoke(argumentsData: Data, decoder: JSONDecoder) async -> CallTool.Result {
    do {
      let input = try decoder.decodeValue(using: definition.inputSchema, from: argumentsData)
      let output = try await invoke(with: input)
      let result = render(output)
      return .init(
        content: result.components.map { component in
          switch component {
          case .text(let string):
            return .text(string)
          case .image(let image):
            do {
              let block = try image.block(
                vision: .anthropicDefault,
                preprocessingMode: .recommended()
              )
              return .image(
                data: block.source.data.base64EncodedString(),
                mimeType: block.source.mediaType.rawValue,
                metadata: nil
              )
            } catch {
              return .text("Error processing image: \(error)\n")
            }
          }
        })
    } catch {
      return .init(content: [.text("\(error)")], isError: true)
    }
  }

}

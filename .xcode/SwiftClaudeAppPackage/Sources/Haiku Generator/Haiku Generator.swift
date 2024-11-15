import Claude
import SwiftUI

public struct HaikuGenerator: View {

  public init(authenticator: Claude.KeychainAuthenticator) {
    self.claude = Claude(
      authenticator: authenticator,
      defaultModel: .claude35haiku20241022
    )
  }

  public var body: some View {
    ScrollView {
      TextField("Haiku Topic", text: $haikuTopic)
        .onSubmit {
          submit()
        }
        .disabled(!conversation.messages.isEmpty)
      
      ForEach(conversation.messages) { message in
        switch message {
        case .user(let user):
          Text(user.text)
        case .assistant(let assistant):
          ForEach(assistant.currentContentBlocks) { block in
            switch block {
            case .textBlock(let textBlock):
              Text(textBlock.currentText)
            case .toolUseBlock(let toolUseBlock):
              if let output = toolUseBlock.toolUse.currentOutput {
                Text("[Using \(toolUseBlock.toolUse.toolName): \(output)]")
              } else {
                Text("[Using \(toolUseBlock.toolUse.toolName)]")
              }
            }
          }
        }
      }
      
      switch conversation.state {
      case .idle:
        if conversation.messages.isEmpty {
          Button("Write Haiku") {
            submit()
          }
        } else {
          Button("Reset") {
            conversation = Conversation()
          }
        }
      case .toolInvocationResultsAvailable:
        Button("Respond to tool use request") {
          submit()
        }
      case .streaming, .waitingForToolInvocationResults:
        ProgressView()
      }
    }
  }

  private func submit() {
    if conversation.messages.isEmpty {
      conversation.messages.append(
        .user(.init("Write me a haiku about \(haikuTopic)."))
      )
    }
    let message = claude.nextMessage(
      in: conversation,
      tools: Tools {
        CatEmojiTool()
        EmojiTool()
      },
      invokeTools: .whenInputAvailable
    )
    conversation.messages.append(.assistant(message))
    Task {
      for try await block in message.contentBlocks {
        switch block {
        case .textBlock(let textBlock):
          for try await textFragment in textBlock.textFragments {
            print(textFragment, terminator: "")
            fflush(stdout)
          }
        case .toolUseBlock(let toolUseBlock):
          print("[Using \(toolUseBlock.toolUse.toolName): \(try await toolUseBlock.toolUse.output())]")
        }
      }
      print()
      print("Message Stopped: \(message.currentMetadata.stopReason as Any)")
    }
  }

  @State
  private var claude: Claude

  @State
  private var haikuTopic = ""
  
  @State
  private var conversation = Conversation()
  
}

@Observable
private final class Conversation: Claude.Conversation {

  final class UserMessage: Identifiable {
    init(_ text: String) {
      self.text = text
    }
    let text: String
  }
  
  struct ToolUseBlock: Identifiable {
    init<Tool: Claude.Tool>(_ toolUse: ToolUse<Tool>) where Tool.Output == String {
      self.toolUse = toolUse
    }
    let toolUse: any ToolUseProtocol<ToolOutput>
    
    var id: ToolUse.ID { toolUse.id }
  }
  
  var messages: [Message] = []
  
  func append(_ assistantMessage: AssistantMessage) {
    messages.append(.assistant(assistantMessage))
  }
  
  static func userMessageContent(for message: UserMessage) -> Claude.UserMessageContent {
    .init(message.text)
  }
  
  static func toolUseBlock<Tool: Claude.Tool>(
    _ toolUse: Claude.ToolUse<Tool>
  ) throws -> ToolUseBlock where Tool.Output == String {
    ToolUseBlock(toolUse)
  }
  
  static func toolInvocationResultContent(
    for toolOutput: String
  ) -> Claude.ToolInvocationResultContent {
    .init(toolOutput)
  }
  
  var tools: Tools<String>? {
    Tools {
      CatEmojiTool()
      EmojiTool()
    }
  }
  
}

@Tool
private struct CatEmojiTool {

  /// Displays a cat emoji
  /// Great for spicing up a haiku!
  private func invoke() -> String {
    "😻"
  }

}

@Tool
private struct EmojiTool {

  /// Displays an emoji
  /// Great for spicing up a haiku!
  private func invoke(
    _ emoji: String
  ) -> String {
    emoji
  }

}

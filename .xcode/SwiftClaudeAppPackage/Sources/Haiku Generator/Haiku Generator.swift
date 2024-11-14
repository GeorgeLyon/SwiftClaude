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
        .disabled(!messages.isEmpty)
      if case .assistant(let message) = messages.last {
        if message.isToolInvocationCompleteOrFailed {
          if message.currentMetadata.stopReason == .toolUse {
            Button("Respond to tool use request") {
              submit()
            }
          } else {
            Button("Reset") {
              conversation = Conversation()
            }
          }
        } else {
          ProgressView()
        }
      } else {
        Button("Write Haiku") {
          submit()
        }
      }
      ForEach(messages) { message in
        switch message {
        case .user(let user):
          Text(user.text)
        case .assistant(let assistant):
          ForEach(assistant.currentContentBlocks) { block in
            switch block {
            case .textBlock(let textBlock):
              Text(textBlock.currentText)
            case .toolUseBlock(let toolUseBlock):
              Text("tool use")
              //            if let output = toolUseBlock.currentOutput {
              //              Text("[Using \(toolUseBlock.toolName): \(output)]")
              //            } else {
              //              Text("[Using \(toolUseBlock.toolName)]")
              //            }
            }
          }
        }
      }
      if
        case let .assistant(message) = messages.last,
        let error = message.currentError
      {
        Text("Error: \(error)")
      }
    }
  }

  private func submit() {
    conversation.messages.append(.user(.init("Write me a haiku about \(haikuTopic).")))
    let message = claude.nextMessage(in: conversation)
    conversation.messages.append(.assistant(message))
    Task {
      for try await block in message.contentBlocks {
        switch block {
        case .textBlock(let textBlock):
          for try await textFragment in textBlock.textFragments {
            print(textFragment, terminator: "")
            fflush(stdout)
          }
        case .toolUseBlock(let toolUse):
          switch toolUse {
            
          }
//          print("[Using \(toolUse.toolName): \(try await toolUse.output())]")
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

  private var messages: [Conversation.Message] {
    conversation.messages
  }
  
}

@Observable
private final class Conversation: Claude.Conversation {

  final class UserMessage: Identifiable {
    init(_ text: String) {
      self.text = text
    }
    let text: String
  }
  
  var messages: [Message] = []
  
  func append(_ assistantMessage: AssistantMessage) {
    messages.append(.assistant(assistantMessage))
  }
  
  static func content(for message: UserMessage) -> Claude.UserMessageContent {
    .init(message.text)
  }
  
  let tools = Tools {
    CatEmojiTool()
    EmojiTool()
  }
  
}

@Tool
private struct CatEmojiTool {

  /// Displays a cat emoji
  private func invoke() -> String {
    "😻"
  }

}

@Tool
private struct EmojiTool {

  /// Displays an emoji
  private func invoke(
    _ emoji: String
  ) -> String {
    emoji
  }

}

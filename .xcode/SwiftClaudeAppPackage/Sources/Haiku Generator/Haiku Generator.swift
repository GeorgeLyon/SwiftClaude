import Claude
import SwiftUI

public struct HaikuGenerator: View {

  public init(claude: Claude) {
    self.claude = claude
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
          ForEach(user.contentBlocks) { block in
            switch block {
            case .textBlock(let textBlock):
              Text(textBlock.text)
            case .imageBlock(let imageBlock):
              Image(uiImage: imageBlock.image)
            }
          }
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
            reset()
          }
        }
      case .toolInvocationResultsAvailable:
        Button("Provide tool invocation results") {
          submit()
        }
      case .streaming, .waitingForToolInvocationResults:
        ProgressView()
      case .failed(let error):
        Text("Error: \(error)")
        Button("Reset") {
          reset()
        }
      }
    }
  }

  private func submit() {
    if conversation.messages.isEmpty {
      conversation.messages.append(
        .user("Write me a haiku about \(raw: haikuTopic).")
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
    }
  }
  
  private func reset() {
    haikuTopic = ""
    conversation = Conversation()
  }

  @State
  private var haikuTopic = ""
  
  @State
  private var conversation = Conversation()
  
  private let claude: Claude
  
}

@Observable
private final class Conversation: Claude.Conversation {

  var messages: [Message] = []
  
  typealias UserMessageImage = UIImage
  
  typealias ToolOutput = String
  
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

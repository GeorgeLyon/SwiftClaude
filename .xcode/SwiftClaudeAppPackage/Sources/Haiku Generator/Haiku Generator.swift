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
          Text(user.text)
        /// If you want to support images, you can do something like the following:
        // ForEach(user.contentBlocks) { block in
        //   switch block {
        //   case .textBlock(let textBlock):
        //     Text(textBlock.text)
        //   case .imageBlock(let imageBlock):
        //     Image(uiImage: imageBlock.image)
        //   }
        // }
        case .assistant(let assistant):
          #if TOOL_USE_DISABLED
            Text(assistant.currentText)
          #else
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
          #endif
        }
      }

      switch conversation.currentState {
      case .ready(for: let nextStep):
        switch nextStep {
        case .user:
          if conversation.messages.isEmpty {
            Button("Write Haiku") {
              submit()
            }
          } else {
            Button("Reset") {
              reset()
            }
          }
        case .toolUseResult:
          Button("Provide tool invocation results") {
            submit()
          }
        }
      case .responding:
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
        .user("Write me a haiku about \(haikuTopic).")
      )
    }
    #if TOOL_USE_DISABLED
      let message = claude.nextMessage(
        in: conversation
      )
    #else
      let message = claude.nextMessage(
        in: conversation,
        tools: Tools {
          CatEmojiTool()
          EmojiTool()
        },
        invokeTools: .whenInputAvailable
      )
    #endif
    conversation.messages.append(.assistant(message))
    Task {
      #if TOOL_USE_DISABLED
        for try await segment in message.textSegments {
          print(segment, terminator: "")
          fflush(stdout)
        }
        print()
      /// Or, all at once:
      // print(try await message.text())
      #else
        for try await block in message.contentBlocks {
          switch block {
          case .textBlock(let textBlock):
            for try await textFragment in textBlock.textFragments {
              print(textFragment, terminator: "")
              fflush(stdout)
            }
          case .toolUseBlock(let toolUseBlock):
            print("[Using \(toolUseBlock.toolName): \(try await toolUseBlock.output())]")
          }
        }
        print()
      #endif
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

private struct Conversation: Claude.Conversation {

  var messages: [Message] = []

  #if !TOOL_USE_DISABLED
    typealias ToolOutput = String
  #endif

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

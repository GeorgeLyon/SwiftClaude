import Claude
import SwiftUI

struct ContentView: View {
  var body: some View {
    VStack {
      switch authenticator.authenticationState {
      case .authenticated(let summary):
        HStack {
          Text(summary)
          Spacer()
          Button("Change API Key") {
            _ = try? authenticator.deleteApiKey()
          }
        }
        HaikuView(authenticator: authenticator)
      case .unauthenticated:
        APIKeyEntryView(authenticator: authenticator)
          .padding()
      case .failed(let error):
        Text("Failed: \(error)")
      }
      Spacer()
    }
    .padding()
  }

  @State
  private var authenticator = Claude.KeychainAuthenticator(
    namespace: "com.codebygeorge.SwiftClaude.HaikuGenerator",
    identifier: "api-key"
  )
}

private struct APIKeyEntryView: View {

  let authenticator: Claude.KeychainAuthenticator

  var body: some View {
    HStack {
      TextField("API Key", text: $apiKey)
        .onSubmit {
          try? authenticator.save(Claude.APIKey(apiKey))
        }
      Button("Save") {
        try? authenticator.save(Claude.APIKey(apiKey))
      }
    }
  }

  @State
  private var apiKey: String = ""

}

private struct HaikuView: View {

  init(authenticator: Claude.KeychainAuthenticator) {
    self.claude = Claude(
      authenticator: authenticator,
      defaultModel: .claude3haiku20240307
    )
  }

  var body: some View {
    TextField("Haiku Topic", text: $haikuTopic)
      .onSubmit {
        submit()
      }
      .disabled(!messages.isEmpty)
    if let message = messages.last {
      if message.isToolInvocationCompleteOrFailed {
        if message.currentMetadata.stopReason == .toolUse {
          Button("Respond to tool use request") {
            submit()
          }
        } else {
          Button("Reset") {
            messages.removeAll()
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
      ForEach(message.currentContentBlocks) { contentBlock in
        switch contentBlock {
        case .textBlock(let textBlock):
          Text(textBlock.currentText)
        case .toolUseBlock(let toolUseBlock):
          if let output = toolUseBlock.currentOutput {
            Text("[Using \(toolUseBlock.toolName): \(output)]")
          } else {
            Text("[Using \(toolUseBlock.toolName)]")
          }
        }
      }
    }
    if let error = messages.last?.currentError {
      Text("Error: \(error)")
    }
  }

  private func submit() {
    var conversation = Conversation {
      "Write me a haiku about \(haikuTopic), then add some flair using the various emoji tools."
    }
    for message in messages {
      guard
        let assistantMessage = message.currentAssistantMessage(
          inputDecodingFailureEncodingStrategy: .encodeErrorInPlaceOfInput,
          streamingFailureEncodingStrategy: .appendErrorMessage,
          stopDueToMaxTokensEncodingStrategy: .appendErrorMessage
        ),
        let toolInvocationResult = message.currentToolInvocationResults
      else {
        assertionFailure()
        continue
      }
      conversation.append(assistantMessage)
      conversation.append(UserMessage(toolInvocationResult))
    }
    let message = claude.nextMessage(
      in: conversation,
      tools: Tools<String> {
        CatEmojiTool()
        EmojiTool()
      },
      toolInvocationStrategy: .immediate
    )
    self.messages.append(message)
    Task {
      for try await block in message.contentBlocks {
        switch block {
        case .textBlock(let textBlock):
          for try await textFragment in textBlock.textFragments {
            print(textFragment, terminator: "")
            fflush(stdout)
          }
        case .toolUseBlock(let toolUse):
          print("[Using \(toolUse.toolName): \(try await toolUse.output())]")
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
  private var messages: [StreamingMessage<String>] = []

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

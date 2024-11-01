import Claude
import SwiftUI

/// Currently computer use doesn't work great, probably something to do with the image resizing logic

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
        ComputerUseView(authenticator: authenticator)
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
    namespace: "com.codebygeorge.SwiftClaude.ComputerUse",
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

private struct ComputerUseView: View {

  init(authenticator: Claude.KeychainAuthenticator) {
    self.claude = Claude(
      authenticator: authenticator,
      defaultModel: .claude35Sonnet20241022
    )
  }

  var body: some View {
    VStack {
      #if canImport(AppKit)
        let image = Image(nsImage: screenshot)
      #elseif canImport(UIKit)
        let image = Image(uiImage: screenshot)
      #endif
      image
        .resizable()
        .aspectRatio(contentMode: .fit)
        .overlay(alignment: .topLeading) {
          GeometryReader { geometry in
            Circle()
              .stroke(tapped ? .green : .purple, lineWidth: 2)
              .frame(
                width: 8,
                height: 8
              )
              .offset(
                x: (geometry.size.width * normalizedMousePosition.x) - 4,
                y: (geometry.size.height * normalizedMousePosition.y) - 4
              )

          }
        }
      if let message = messages.last {
        ZStack {
          ProgressView().opacity(message.isToolInvocationCompleteOrFailed ? 0 : 1)
          if message.isToolInvocationCompleteOrFailed {
            if message.currentMetadata.stopReason == .toolUse {
              Button("Continue tool use") {
                submit()
              }
            } else {
              Button("Reset") {
                messages = []
              }
            }
          }
        }
        if let error = message.currentError {
          Text("Error: \(error)")
        }
      } else {
        Button("Tap Safari") {
          submit()
        }
      }
    }
  }

  private func submit() {
    var conversation = Conversation {
      "Open the safari app"
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

    let computer = Computer(
      onNormalizedMouseMove: { x, y in
        await withCheckedContinuation { continuation in
          withAnimation {
            normalizedMousePosition = .init(x: x, y: y)
          } completion: {
            continuation.resume()
          }
        }
      },
      onLeftClick: {
        Task<Void, Never> { @MainActor in
          tapped = true
        }
      }
    )

    let message = claude.nextMessage(
      in: conversation,
      tools: Tools<ToolInvocationResultContent> {
        computer
      },
      invokeTools: .whenInputAvailable
    )
    messages.append(message)
    Task<Void, Never> {
      do {
        for try await block in message.contentBlocks {
          switch block {
          case .textBlock(let text):
            for try await fragment in text.textFragments {
              print(fragment, terminator: "")
              fflush(stdout)
            }
            print()
          case .toolUseBlock(let toolUse):
            print("🛠️ Using Tool: \(toolUse.toolName) 🛠️")
            print("Input Received: \(try await toolUse.inputJSON())")
            break
          }
        }
        print("Done")
      } catch {
        print("Error: \(error)")
      }
    }
  }

  @State
  private var normalizedMousePosition: CGPoint = .zero

  @State
  private var tapped: Bool = false

  @State
  private var claude: Claude

  @State
  private var messages: [StreamingMessage<ToolInvocationResultContent>] = []

  @State
  private var screenshot = ComputerUseExample.screenshot

}

private struct Computer: Claude.Beta.Computer {

  let onNormalizedMouseMove: @MainActor (Double, Double) async throws -> Void
  let onLeftClick: @MainActor () async throws -> Void

  func takeScreenshot(
    isolation: isolated Actor
  ) async throws -> Claude.Image {
    Claude.Image(screenshot)
  }

  func moveMouse(
    toNormalizedPosition position: (x: Double, y: Double),
    isolation: isolated Actor
  ) async throws {
    try await onNormalizedMouseMove(position.x, position.y)
  }

  func leftClick(
    isolation: isolated Actor
  ) async throws {
    try await onLeftClick()
  }

  var displaySize: Claude.Image.Size {
    let screenshot = screenshot
    return Claude.Image.Size(
      widthInPixels: Int(screenshot.size.width),
      heightInPixels: Int(screenshot.size.height)
    )
  }

}

#if canImport(AppKit)
  public var screenshot: NSImage {
    let path = Bundle.module.path(forResource: "Screenshot", ofType: "png")!
    return NSImage(contentsOfFile: path)!
  }
#elseif canImport(UIKit)
  public var screenshot: UIImage {
    let path = Bundle.module.path(forResource: "Screenshot", ofType: "png")!
    return UIImage(contentsOfFile: path)!
  }
#endif

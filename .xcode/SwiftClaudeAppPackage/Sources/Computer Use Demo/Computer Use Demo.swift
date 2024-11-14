import SwiftClaude
public import ClaudeClient
import SwiftUI

public struct ComputerUseDemo: View {

  public init(authenticator: Claude.KeychainAuthenticator) {
    self.claude = Claude(
      authenticator: authenticator,
      defaultModel: .claude35Sonnet20241022
    )
  }

  public var body: some View {
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
  private var screenshot = demoScreenshot
  
}

private struct Computer: Claude.Beta.ComputerTool {

  let onNormalizedMouseMove: @MainActor (Double, Double) async throws -> Void

  let onLeftClick: @MainActor () async throws -> Void

  func invoke(
    with input: Input,
    in context: Claude.ToolInvocationContext<Computer>,
    isolation: isolated any Actor
  ) async throws -> ToolInvocationResultContent {
    switch input.action {
    case .screenshot:
      return "\(demoScreenshot)"
    case let .mouseMove(x, y):
      try await onNormalizedMouseMove(x, y)
      return "Moved"
    case .leftClick:
      try await onLeftClick()
      return "Clicked"
    default:
      return "\(input.action) is not supported"
    }
  }

  var displaySize: Claude.ImageSize {
    return Claude.ImageSize(
      widthInPixels: Int(demoScreenshot.size.width),
      heightInPixels: Int(demoScreenshot.size.height)
    )
  }

}

#if canImport(AppKit)
  public var demoScreenshot: NSImage {
    let path = Bundle.module.path(forResource: "Screenshot", ofType: "png")!
    return NSImage(contentsOfFile: path)!
  }
#elseif canImport(UIKit)
  public var demoScreenshot: UIImage {
    let path = Bundle.module.path(forResource: "Screenshot", ofType: "png")!
    return UIImage(contentsOfFile: path)!
  }
#endif

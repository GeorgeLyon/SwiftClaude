import Claude
import SwiftUI

public struct ComputerUseDemo: View {

  public init(claude: Claude) {
    self.claude = claude
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
      switch conversation.currentState {
      case .ready(for: let nextMessage):
        switch nextMessage {
        case .user:
          if conversation.messages.count == 1 {
            Button("Tap Safari") {
              submit()
            }
          } else {
            Button("Reset") {
              conversation = Conversation()
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
          conversation = Conversation()
        }
      }
    }
  }

  private func submit() {
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
      model: .claude35Sonnet20241022,
      tools: Tools<ToolInvocationResultContent> {
        computer
      },
      invokeTools: .whenInputAvailable
    )
    conversation.messages.append(.assistant(message))
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
          case .toolUseBlock(let toolUseBlock):
            print("🛠️ Using Tool: \(toolUseBlock.toolUse.toolName) 🛠️")
            print("Input Received: \(try await toolUseBlock.toolUse.inputJSON())")
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
  private var conversation = Conversation()

  @State
  private var screenshot = demoScreenshot

}

@Observable
private final class Conversation: Claude.Conversation {

  var messages: [Message] = [
    .user("Tap on Safari")
  ]

  typealias ToolOutput = ToolInvocationResultContent

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

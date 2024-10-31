extension Claude.Beta {

  public protocol Computer {
    func takeScreenshot(
      isolation: isolated Actor
    ) async throws -> Claude.Image

    func moveMouse(
      toNormalizedPosition position: (x: Double, y: Double),
      isolation: isolated Actor
    ) async throws

    func leftClick(
      isolation: isolated Actor
    ) async throws

    var displaySize: Claude.Image.Size { get }
  }

}

extension Tools.Builder where Output == ToolInvocationResultContent {

  public static func buildExpression(
    _ computer: some Claude.Beta.Computer
  ) -> Component {
    buildExpression(Claude.Beta.ComputerTool(computer: computer))
  }

}

// MARK: - Tool

extension Claude.Beta {

  struct ComputerTool<Computer: Claude.Beta.Computer>: Claude.Tool {

    /// - Parameters:
    ///   - displaySize:
    ///     The size of the display.
    ///     This should be the same as the size of screenshots `Computer` will provide.
    ///     The actual value sent to the backend may be different, as `Claude` accounts for image preprocessing.
    public init(
      computer: Computer
    ) {
      self.computer = computer
      /// Ensure this doesn't change while invoking this tool
      self.displaySize = computer.displaySize
    }

    public let displaySize: Claude.Image.Size
    public let computer: Computer

    public var definition: Claude.ToolDefinition<Self> {
      .computer(displaySize: displaySize)
    }

    public func invoke(
      with toolInput: Input,
      in context: Claude.ToolInvocationContext<Self>,
      isolation: isolated Actor
    ) async throws -> ToolInvocationResultContent {
      let input = try ComputerToolInput(
        input: toolInput,
        displaySize: context.privateData.adjustedDisplaySize
      )

      switch input.action {
      case .screenshot:
        let screenshot = try await computer.takeScreenshot(isolation: isolation)
        assert(screenshot.size.widthInPixels == displaySize.widthInPixels)
        assert(screenshot.size.heightInPixels == displaySize.heightInPixels)
        return "\(screenshot)"
      case let .mouseMove(x, y):
        try await computer.moveMouse(
          toNormalizedPosition: (x: x, y: y),
          isolation: isolation
        )
        return "Moved."
      case .leftClick:
        try await computer.leftClick(isolation: isolation)
        return "Clicked."
      default:
        throw UnsupportedAction()
      }
    }

    public struct Input: Decodable {
      fileprivate struct Payload: Codable {
        enum Action: String, Codable {
          case key
          case type
          case mouse_move
          case left_click
          case left_click_drag
          case right_click
          case middle_click
          case double_click
          case screenshot
          case cursor_position
        }
        let action: Action
        let coordinate: [Int]?
        let text: String?
      }
      fileprivate let payload: Payload
    }

    public static func decodeInput(
      from payload: Claude.ToolInputDecoder<Self>.Payload,
      using decoder: Claude.ToolInputDecoder<Self>,
      isolation: isolated Actor
    ) async throws -> Input {
      let payload = try await decoder.decodeInput(
        of: Input.Payload.self,
        from: payload, isolation: isolation
      )
      return Input(payload: payload)
    }

    public static func encodeInput(
      _ input: Input,
      to encoder: inout Claude.ToolInputEncoder<Self>
    ) {
      encoder.encode(input.payload)
    }

    public struct _ToolInvocationContextPrivateData {
      /// Size that allows us to account for image processing in display coordinate calculations
      init(adjustedDisplaySize: Claude.Image.Size) {
        self.adjustedDisplaySize = adjustedDisplaySize
      }
      fileprivate let adjustedDisplaySize: Claude.Image.Size
    }

    private struct UnsupportedAction: Error {

    }
  }

  public struct ComputerToolInput {
    public enum Action {
      case key(String)
      case type(String)
      case mouseMove(x: Double, y: Double)
      case leftClick
      case leftClickDrag(x: Double, y: Double)
      case rightClick
      case middleClick
      case doubleClick
      case screenshot
      case cursorPosition
    }
    public let action: Action

    fileprivate init<Computer>(
      input: ComputerTool<Computer>.Input,
      displaySize: Claude.Image.Size
    ) throws {
      let payload = input.payload
      switch payload.action {
      case .key:
        guard let text = payload.text else {
          throw Claude.Beta.ComputerToolInput.InvalidPayload()
        }
        action = .key(text)
      case .type:
        guard let text = payload.text else {
          throw Claude.Beta.ComputerToolInput.InvalidPayload()
        }
        action = .type(text)
      case .mouse_move:
        guard
          let coordinates = payload.coordinate,
          coordinates.count == 2
        else {
          throw Claude.Beta.ComputerToolInput.InvalidPayload()
        }
        action = .mouseMove(
          x: Double(coordinates[0]) / Double(displaySize.widthInPixels),
          y: Double(coordinates[1]) / Double(displaySize.heightInPixels)
        )
      case .left_click:
        action = .leftClick
      case .left_click_drag:
        guard
          let coordinates = payload.coordinate,
          coordinates.count == 2
        else {
          throw Claude.Beta.ComputerToolInput.InvalidPayload()
        }
        action = .leftClickDrag(
          x: Double(coordinates[0]) / Double(displaySize.widthInPixels),
          y: Double(coordinates[1]) / Double(displaySize.heightInPixels)
        )
      case .right_click:
        action = .rightClick
      case .middle_click:
        action = .middleClick
      case .double_click:
        action = .doubleClick
      case .screenshot:
        action = .screenshot
      case .cursor_position:
        action = .cursorPosition
      }
    }

    fileprivate struct InvalidPayload: Error {
    }
  }

}
